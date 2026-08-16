package com.flynew.photomanager

import android.Manifest
import android.app.ActivityManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.Process
import android.os.StatFs
import android.os.SystemClock
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    companion object {
        private const val MEDIA_CHANNEL = "com.flynew.photomanager/media_store"
        private const val BACKGROUND_CHANNEL = "com.flynew.photomanager/background_download"
        private const val UPDATE_CHANNEL = "com.flynew.photomanager/app_update"
        private const val DEBUG_CHANNEL = "com.flynew.photomanager/debug_info"
        private val PROCESS_STARTED_AT_MS = System.currentTimeMillis()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerMediaStoreChannel(flutterEngine)
        registerBackgroundDownloadChannel(flutterEngine)
        registerUpdateChannel(flutterEngine)
        registerDebugInfoChannel(flutterEngine)
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
                        val info = currentPackageInfo()
                        result.success(
                            mapOf(
                                "versionName" to (info.versionName ?: "0.0.0"),
                                "versionCode" to versionCodeOf(info),
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

    private fun registerDebugInfoChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEBUG_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "getDebugInfo") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    result.success(buildDebugInfo())
                } catch (error: Exception) {
                    result.error(
                        "debug_info_error",
                        error.message ?: "Unable to collect debug information",
                        null,
                    )
                }
            }
    }

    private fun buildDebugInfo(): Map<String, Any?> {
        val packageInfo = currentPackageInfo(includePermissions = true)
        val appInfo = applicationInfo
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo().also(activityManager::getMemoryInfo)
        val storage = StatFs(filesDir.absolutePath)
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = connectivity.activeNetwork
        val capabilities = activeNetwork?.let(connectivity::getNetworkCapabilities)
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val metrics = resources.displayMetrics
        val permissions = requestedPermissions(packageInfo)
        val installer = installerPackageName()
        val transports = networkTransports(capabilities)

        val processStartedAtMs = PROCESS_STARTED_AT_MS
        val lastUpdateTimeMs = packageInfo.lastUpdateTime
        val staleProcess = processStartedAtMs + 1000L < lastUpdateTimeMs

        return mapOf(
            "packageName" to packageName,
            "versionName" to (packageInfo.versionName ?: "0.0.0"),
            "versionCode" to versionCodeOf(packageInfo),
            "firstInstallTimeMs" to packageInfo.firstInstallTime,
            "lastUpdateTimeMs" to lastUpdateTimeMs,
            "processStartedAtMs" to processStartedAtMs,
            "staleProcess" to staleProcess,
            "installerPackage" to installer,
            "buildType" to BuildConfig.BUILD_TYPE,
            "flavor" to BuildConfig.FLAVOR,
            "externalUpdaterEnabled" to BuildConfig.ALLOW_EXTERNAL_UPDATE,
            "debuggable" to ((appInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
            "compileSdk" to BuildConfig.COMPILE_SDK_VERSION,
            "targetSdk" to appInfo.targetSdkVersion,
            "minSdk" to appInfo.minSdkVersion,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "hardware" to Build.HARDWARE,
            "androidRelease" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "securityPatch" to Build.VERSION.SECURITY_PATCH,
            "androidBuildId" to Build.ID,
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "is64BitProcess" to Process.is64Bit(),
            "locale" to resources.configuration.locales[0].toLanguageTag(),
            "timeZone" to TimeZone.getDefault().id,
            "displayWidthPx" to metrics.widthPixels,
            "displayHeightPx" to metrics.heightPixels,
            "density" to metrics.density,
            "densityDpi" to metrics.densityDpi,
            "memoryAvailableBytes" to memoryInfo.availMem,
            "memoryTotalBytes" to memoryInfo.totalMem,
            "lowMemory" to memoryInfo.lowMemory,
            "storageAvailableBytes" to storage.availableBytes,
            "storageTotalBytes" to storage.totalBytes,
            "batteryPercent" to batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            "ignoringBatteryOptimizations" to powerManager.isIgnoringBatteryOptimizations(packageName),
            "networkTransports" to transports,
            "networkValidated" to (capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true),
            "networkMetered" to connectivity.isActiveNetworkMetered,
            "permissions" to permissions,
            "processId" to Process.myPid(),
            "deviceUptimeMs" to SystemClock.elapsedRealtime(),
            "nativeLibraryDir" to appInfo.nativeLibraryDir,
            "javaVmVersion" to System.getProperty("java.vm.version"),
        )
    }

    private fun currentPackageInfo(includePermissions: Boolean = false): PackageInfo {
        val flags = if (includePermissions) PackageManager.GET_PERMISSIONS else 0
        @Suppress("DEPRECATION")
        return packageManager.getPackageInfo(packageName, flags)
    }

    private fun versionCodeOf(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun requestedPermissions(info: PackageInfo): List<Map<String, Any>> {
        val names = info.requestedPermissions ?: return emptyList()
        return names.map { name ->
            mapOf(
                "name" to name,
                "granted" to (checkSelfPermission(name) == PackageManager.PERMISSION_GRANTED),
            )
        }
    }

    private fun installerPackageName(): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            packageManager.getInstallSourceInfo(packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstallerPackageName(packageName)
        }
    }

    private fun networkTransports(capabilities: NetworkCapabilities?): List<String> {
        if (capabilities == null) return emptyList()
        val transports = mutableListOf<String>()
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) transports += "Wi-Fi"
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) transports += "Cellular"
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) transports += "Ethernet"
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) transports += "VPN"
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) transports += "Bluetooth"
        return transports
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
