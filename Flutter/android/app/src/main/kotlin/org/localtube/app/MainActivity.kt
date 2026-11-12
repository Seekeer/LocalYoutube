package org.localtube.app

import android.Manifest
import android.app.NotificationChannel
import android.content.pm.PackageManager
import android.media.MediaRecorder
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
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var voiceRecorder: MediaRecorder? = null
    private var voiceRecorderChannel: MethodChannel? = null

    // Outcome of a recording the system stopped in onStop, handed to the next "stop" call.
    private var interruptedRecordingStopped: Boolean? = null
    private var pendingMicrophoneResult: MethodChannel.Result? = null

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
        // Dictation clips for video notes. One Android API does not justify another Flutter package.
        val voiceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_RECORDER_CHANNEL,
        )
        voiceRecorderChannel = voiceChannel
        voiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(
                    packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
                )
                "requestPermission" -> requestMicrophone(result)
                "start" -> {
                    try {
                        startVoiceRecording(requireNotNull(call.argument<String>("path")))
                        result.success(null)
                    } catch (error: Exception) {
                        releaseVoiceRecorder()
                        result.error("record_failed", error.message ?: "Cannot start recording", null)
                    }
                }
                // true when the clip file was finished properly.
                "stop" -> result.success(stopVoiceRecording())
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

    private fun requestMicrophone(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingMicrophoneResult?.success(false)
        pendingMicrophoneResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MICROPHONE_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MICROPHONE_REQUEST_CODE) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingMicrophoneResult?.success(granted)
        pendingMicrophoneResult = null
    }

    private fun startVoiceRecording(path: String) {
        releaseVoiceRecorder()
        interruptedRecordingStopped = null
        val file = File(path)
        file.parentFile?.mkdirs()
        @Suppress("DEPRECATION")
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            MediaRecorder()
        }
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        recorder.setAudioChannels(1)
        recorder.setAudioSamplingRate(16000)
        recorder.setAudioEncodingBitRate(64000)
        recorder.setOutputFile(file.absolutePath)
        voiceRecorder = recorder
        recorder.prepare()
        recorder.start()
    }

    private fun stopVoiceRecording(): Boolean {
        val recorder = voiceRecorder
        if (recorder == null) {
            val interrupted = interruptedRecordingStopped ?: false
            interruptedRecordingStopped = null
            return interrupted
        }
        var stopped = true
        try {
            recorder.stop()
        } catch (error: Exception) {
            // MediaRecorder throws when it got no valid data; the file is unusable.
            Log.w("VoiceRecorder", "Recording stopped without data", error)
            stopped = false
        }
        releaseVoiceRecorder()
        return stopped
    }

    override fun onStop() {
        // The microphone is not kept recording in the background. Dart collects the clip.
        if (voiceRecorder != null) {
            interruptedRecordingStopped = stopVoiceRecording()
            voiceRecorderChannel?.invokeMethod("interrupted", null)
        }
        super.onStop()
    }

    private fun releaseVoiceRecorder() {
        try {
            voiceRecorder?.release()
        } catch (error: Exception) {
            Log.w("VoiceRecorder", "Recorder release failed", error)
        }
        voiceRecorder = null
    }

    override fun onDestroy() {
        releaseVoiceRecorder()
        super.onDestroy()
    }

    private companion object {
        const val PLAYER_NETWORK_LOCK_CHANNEL =
            "org.localtube.app/player_network_lock"
        const val PLAYBACK_SCREEN_WAKE_LOCK_CHANNEL =
            "org.localtube.app/playback_screen_wake_lock"
        const val APP_CONTROL_CHANNEL = "org.localtube.app/app_control"
        const val DEVICE_INFO_CHANNEL = "org.localtube.app/device_info"
        const val VOICE_RECORDER_CHANNEL = "org.localtube.app/voice_recorder"
        const val MICROPHONE_REQUEST_CODE = 4711
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
