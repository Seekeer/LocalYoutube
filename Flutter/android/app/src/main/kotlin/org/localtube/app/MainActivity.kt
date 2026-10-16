package org.localtube.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureDownloadNotifications()
    }

    private fun configureDownloadNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Keep a valid channel for foreground transfers, but hide its notifications.
        // The media playback channel is separate and retains its system controls.
        val channelId = "background_downloader"
        notifications.createNotificationChannel(
            NotificationChannel(channelId, "LocalTube downloads", NotificationManager.IMPORTANCE_NONE).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            },
        )
        // Remove stale download notifications left by previous versions only.
        for (entry in notifications.activeNotifications) {
            if (entry.notification.channelId == channelId) {
                notifications.cancel(entry.tag, entry.id)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PLAYER_NETWORK_LOCK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    PlaybackNetworkLockManager.setEnabled(applicationContext, enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PLAYBACK_SCREEN_WAKE_LOCK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.addFlags(
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                        )
                    } else {
                        window.clearFlags(
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CONTROL_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "moveToBackground" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "org.localtube.app/app_updates",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installedApp" -> {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    @Suppress("DEPRECATION")
                    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        info.longVersionCode
                    } else {
                        info.versionCode.toLong()
                    }
                    result.success(mapOf(
                        "applicationId" to packageName,
                        "versionCode" to code,
                        "versionName" to (info.versionName ?: ""),
                    ))
                }
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "openInstallSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")))
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("settings_unavailable", "Cannot open installation settings", null)
                    }
                }
                "installApk" -> {
                    try {
                        check(Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls())
                        val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                        val root = File(filesDir, "app-updates").canonicalFile
                        check(file.parentFile == root && file.extension == "apk" && file.isFile)
                        check(file.length() == call.argument<Number>("size")?.toLong())
                        @Suppress("DEPRECATION")
                        val archive = requireNotNull(packageManager.getPackageArchiveInfo(file.path, 0))
                        @Suppress("DEPRECATION")
                        val current = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val archiveCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) archive.longVersionCode else archive.versionCode.toLong()
                        @Suppress("DEPRECATION")
                        val currentCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) current.longVersionCode else current.versionCode.toLong()
                        check(archive.packageName == packageName && archiveCode > currentCode)
                        check(archiveCode == call.argument<Number>("versionCode")?.toLong())
                        val uri = FileProvider.getUriForFile(this, "$packageName.app-updates", file)
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            clipData = android.content.ClipData.newRawUri("LocalTube update", uri)
                        })
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("install_unavailable", "Cannot install selected APK", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // The device model is the default name of a Cast Session device that has not been renamed.
        // One string from one Android API does not justify another Flutter package.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_INFO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidModel" -> result.success(Build.MODEL ?: "")
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val PLAYER_NETWORK_LOCK_CHANNEL =
            "org.localtube.app/player_network_lock"
        const val PLAYBACK_SCREEN_WAKE_LOCK_CHANNEL =
            "org.localtube.app/playback_screen_wake_lock"
        const val APP_CONTROL_CHANNEL = "org.localtube.app/app_control"
        const val DEVICE_INFO_CHANNEL = "org.localtube.app/device_info"
    }
}

private object PlaybackNetworkLockManager {
    private const val TAG = "PlaybackNetworkLock"
    private const val LOCK_TAG = "org.localtube.app:RemotePlaybackWifiLock"

    private var wifiLock: WifiManager.WifiLock? = null

    fun setEnabled(context: Context, enabled: Boolean) {
        if (enabled) {
            ensureWifiLock(context)
            return
        }
        releaseWifiLock()
    }

    private fun ensureWifiLock(context: Context) {
        val existing = wifiLock
        if (existing?.isHeld == true) {
            return
        }
        val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifiManager == null) {
            Log.w(TAG, "WifiManager is unavailable; cannot acquire WifiLock.")
            return
        }
        val nextLock =
            existing ?: wifiManager.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                LOCK_TAG,
            ).apply {
                setReferenceCounted(false)
            }
        nextLock.acquire()
        wifiLock = nextLock
        Log.i(TAG, "WifiLock acquired for remote playback.")
    }

    private fun releaseWifiLock() {
        val existing = wifiLock ?: return
        if (existing.isHeld) {
            existing.release()
            Log.i(TAG, "WifiLock released for remote playback.")
        }
    }
}
