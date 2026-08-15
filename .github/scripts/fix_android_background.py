from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Expected text not found in {path}: {old[:120]!r}")
    target.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "android/app/src/main/kotlin/com/flynew/photomanager/MainActivity.kt",
    "                        val serviceIntent = Intent(this, BackgroundDownloadService::class.java)\n"
    "                            .putExtra(BackgroundDownloadService.EXTRA_ITEMS_JSON, itemsJson)\n",
    "                        val queueFile = File(cacheDir, \"background_download_queue.json\")\n"
    "                        queueFile.writeText(itemsJson)\n"
    "                        val serviceIntent = Intent(this, BackgroundDownloadService::class.java)\n"
    "                            .putExtra(\n"
    "                                BackgroundDownloadService.EXTRA_QUEUE_PATH,\n"
    "                                queueFile.absolutePath,\n"
    "                            )\n",
)
replace_once(
    "android/app/src/main/kotlin/com/flynew/photomanager/MainActivity.kt",
    '            "orf" -> "image/x-olymus-orf"\n',
    '            "orf" -> "image/x-olympus-orf"\n',
)

service = Path("android/app/src/main/kotlin/com/flynew/photomanager/BackgroundDownloadService.kt")
text = service.read_text(encoding="utf-8")
old_start = """    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val itemsJson = intent?.getStringExtra(EXTRA_ITEMS_JSON)
        if (itemsJson.isNullOrBlank()) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (isRunning) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val items = JSONArray(itemsJson)
        if (items.length() == 0) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
"""
new_start = """    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val queuePath = intent?.getStringExtra(EXTRA_QUEUE_PATH)
        if (queuePath.isNullOrBlank()) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (isRunning) return START_NOT_STICKY

        val queueFile = File(queuePath)
        val items = try {
            JSONArray(queueFile.readText())
        } catch (_: Exception) {
            queueFile.delete()
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (items.length() == 0) {
            queueFile.delete()
            stopSelf(startId)
            return START_NOT_STICKY
        }
"""
if old_start not in text:
    raise SystemExit("Background service start block not found")
text = text.replace(old_start, new_start, 1)
text = text.replace(
    "            } finally {\n                isRunning = false\n",
    "            } finally {\n                queueFile.delete()\n                isRunning = false\n",
    1,
)
text = text.replace(
    "        return START_NOT_STICKY\n    }\n\n    override fun onDestroy()",
    "        return START_REDELIVER_INTENT\n    }\n\n    override fun onDestroy()",
    1,
)
text = text.replace(
    '        const val EXTRA_ITEMS_JSON = "items_json"\n',
    '        const val EXTRA_QUEUE_PATH = "queue_path"\n',
    1,
)
service.write_text(text, encoding="utf-8")

print("Android background queue hardened")
