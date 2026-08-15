package com.flynew.photomanager

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.MediaStore
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class BackgroundDownloadService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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

        isRunning = true
        startForeground(
            PROGRESS_NOTIFICATION_ID,
            buildProgressNotification(0, items.length(), "Starting download…"),
        )

        Thread {
            var success = 0
            var failed = 0
            val history = DownloadHistoryStore(this)
            try {
                for (index in 0 until items.length()) {
                    val item = items.getJSONObject(index)
                    val filename = item.getString("filename")
                    val url = item.getString("url")
                    val historyKey = item.getString("historyKey")

                    updateProgress(index, items.length(), filename)
                    try {
                        downloadAndSave(url, filename)
                        history.mark(historyKey)
                        success++
                    } catch (_: Exception) {
                        failed++
                    }
                    updateProgress(index + 1, items.length(), filename)
                }
            } finally {
                queueFile.delete()
                isRunning = false
                stopForegroundCompat()
                showCompletionNotification(success, failed)
                stopSelf(startId)
            }
        }.start()

        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun downloadAndSave(url: String, filename: String) {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 120_000
            connection.requestMethod = "GET"
            connection.setRequestProperty("User-Agent", "OI.Share v2")
            connection.setRequestProperty("Host", "192.168.0.10")
            connection.setRequestProperty("Connection", "Keep-Alive")
            connection.connect()

            if (connection.responseCode !in 200..299) {
                error("Camera returned HTTP ${connection.responseCode}")
            }

            connection.inputStream.buffered().use { input ->
                saveStream(filename, input)
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun saveStream(filename: String, input: InputStream) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(filename, input)
        } else {
            saveLegacy(filename, input)
        }
    }

    private fun saveWithMediaStore(filename: String, input: InputStream) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeTypeFor(filename))
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DCIM}/OlympusView",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = if (isGalleryImage(filename)) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val uri = contentResolver.insert(collection, values)
            ?: error("MediaStore could not create destination")

        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                input.copyTo(output, DEFAULT_BUFFER_SIZE)
                output.flush()
            } ?: error("MediaStore could not open destination")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(filename: String, input: InputStream) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            error("Storage permission is required")
        }

        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            "OlympusView",
        )
        if (!directory.exists() && !directory.mkdirs()) {
            error("Could not create ${directory.absolutePath}")
        }

        val file = File(directory, filename)
        FileOutputStream(file).use { output ->
            input.copyTo(output, DEFAULT_BUFFER_SIZE)
            output.flush()
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeTypeFor(filename)),
            null,
        )
    }

    private fun updateProgress(done: Int, total: Int, filename: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(
            PROGRESS_NOTIFICATION_ID,
            buildProgressNotification(done, total, filename),
        )
    }

    private fun buildProgressNotification(done: Int, total: Int, filename: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_PROGRESS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle("Olympus View — downloading")
            .setContentText("$done / $total · $filename")
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setProgress(total, done.coerceAtMost(total), false)
            .build()
    }

    private fun showCompletionNotification(success: Int, failed: Int) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_COMPLETE)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val text = if (failed == 0) {
            "$success file(s) downloaded"
        } else {
            "$success downloaded, $failed failed"
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle("Olympus View — download complete")
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(COMPLETE_NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val progress = NotificationChannel(
            CHANNEL_PROGRESS,
            "Camera downloads",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Progress while photos are downloaded from the camera"
            setSound(null, null)
        }
        val complete = NotificationChannel(
            CHANNEL_COMPLETE,
            "Download completed",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Alerts when camera downloads finish"
            enableVibration(true)
        }
        manager.createNotificationChannel(progress)
        manager.createNotificationChannel(complete)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun isGalleryImage(filename: String): Boolean =
        when (filename.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg", "png", "gif", "webp", "heic", "heif" -> true
            else -> false
        }

    private fun mimeTypeFor(filename: String): String =
        when (filename.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "heic", "heif" -> "image/heic"
            "orf" -> "image/x-olympus-orf"
            "dng" -> "image/x-adobe-dng"
            "raw" -> "image/x-raw"
            else -> "application/octet-stream"
        }

    companion object {
        const val EXTRA_QUEUE_PATH = "queue_path"
        private const val CHANNEL_PROGRESS = "olympus_camera_downloads"
        private const val CHANNEL_COMPLETE = "olympus_camera_download_complete"
        private const val PROGRESS_NOTIFICATION_ID = 3101
        private const val COMPLETE_NOTIFICATION_ID = 3102

        @Volatile
        var isRunning: Boolean = false
            private set
    }
}
