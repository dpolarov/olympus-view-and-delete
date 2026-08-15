package com.flynew.photomanager

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val MEDIA_CHANNEL = "com.flynew.photomanager/media_store"
        private const val BACKGROUND_CHANNEL = "com.flynew.photomanager/background_download"
        private const val UPDATE_CHANNEL = "com.flynew.photomanager/app_update"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerMediaStoreChannel(flutterEngine)
        registerBackgroundDownloadChannel(flutterEngine)
        registerUpdateChannel(flutterEngine)
    }

    private fun registerMediaStoreChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveCameraFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val filename = call.argument<String>("filename")
                val bytes = call.argument<ByteArray>("bytes")
                if (filename.isNullOrBlank() || bytes == null) {
                    result.error("invalid_arguments", "filename and bytes are required", null)
                    return@setMethodCallHandler
                }

                Thread {
                    try {
                        val savedLocation = saveCameraFile(filename, bytes)
                        runOnUiThread { result.success(savedLocation) }
                    } catch (_: StoragePermissionRequiredException) {
                        runOnUiThread {
                            result.error(
                                "storage_permission_required",
                                "Storage permission is required on Android 9 and older",
                                null,
                            )
                        }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error(
                                "media_store_error",
                                error.message ?: "Unable to save file",
                                null,
                            )
                        }
                    }
                }.start()
            }
    }

    private fun registerBackgroundDownloadChannel(flutterEngine: FlutterEngine) {
        val history = DownloadHistoryStore(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDownloadedKeys" -> result.success(history.getKeys().toList())
                    "markDownloaded" -> {
                        history.mark(call.argument<String>("key") ?: "")
                        result.success(null)
                    }
                    "isRunning" -> result.success(BackgroundDownloadService.isRunning)
                    "start" -> {
                        if (BackgroundDownloadService.isRunning) {
                            result.error(
                                "download_in_progress",
                                "A background camera download is already running",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        if (
                            Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            result.error(
                                "storage_permission_required",
                                "Storage permission is required on Android 9 and older",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val itemsJson = call.argument<String>("itemsJson")
                        if (itemsJson.isNullOrBlank()) {
                            result.error("invalid_arguments", "itemsJson is required", null)
                            return@setMethodCallHandler
                        }

                        val queueFile = File(cacheDir, "background_download_queue.json")
                        queueFile.writeText(itemsJson)
                        val serviceIntent = Intent(this, BackgroundDownloadService::class.java)
                            .putExtra(
                                BackgroundDownloadService.EXTRA_QUEUE_PATH,
                                queueFile.absolutePath,
                            )
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerUpdateChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentVersion" -> {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "versionName" to (info.versionName ?: "0.0.0"),
                                "versionCode" to versionCode,
                            ),
                        )
                    }
                    "canInstallUnknownApps" -> result.success(canInstallUnknownApps())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "startUpdateDownload" -> {
                        if (!BuildConfig.ALLOW_EXTERNAL_UPDATE) {
                            result.error(
                                "external_updates_disabled",
                                "External APK updates are disabled for this distribution",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        if (!canInstallUnknownApps()) {
                            result.error(
                                "install_permission_required",
                                "Allow Olympus View to install unknown apps first",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val url = call.argument<String>("url")
                        val version = call.argument<String>("version") ?: "update"
                        if (url.isNullOrBlank()) {
                            result.error("invalid_arguments", "url is required", null)
                            return@setMethodCallHandler
                        }
                        UpdateDownloadReceiver.enqueue(this, url, version)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canInstallUnknownApps(): Boolean {
        if (!BuildConfig.ALLOW_EXTERNAL_UPDATE) return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (!BuildConfig.ALLOW_EXTERNAL_UPDATE) return
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        startActivity(intent)
    }

    private fun saveCameraFile(filename: String, bytes: ByteArray): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(filename, bytes)
        } else {
            saveLegacy(filename, bytes)
        }
    }

    private fun saveWithMediaStore(filename: String, bytes: ByteArray): String {
        val mimeType = mimeTypeFor(filename)
        val collection = if (isGalleryImage(filename)) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DCIM}/OlympusView",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = contentResolver.insert(collection, values)
            ?: error("MediaStore could not create the destination file")

        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: error("MediaStore could not open the destination file")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return uri.toString()
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(filename: String, bytes: ByteArray): String {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw StoragePermissionRequiredException()
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
            output.write(bytes)
            output.flush()
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeTypeFor(filename)),
            null,
        )
        return file.absolutePath
    }

    private fun isGalleryImage(filename: String): Boolean {
        return when (filename.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg", "png", "gif", "webp", "heic", "heif" -> true
            else -> false
        }
    }

    private fun mimeTypeFor(filename: String): String {
        return when (filename.substringAfterLast('.', "").lowercase()) {
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
    }

    private class StoragePermissionRequiredException : Exception()
}
