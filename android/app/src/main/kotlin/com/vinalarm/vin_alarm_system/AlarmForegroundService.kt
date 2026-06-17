package com.vinalarm.vin_alarm_system

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmForegroundService : Service() {

    companion object {
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_SNOOZE = "ACTION_SNOOZE"
        const val NOTIF_ID = 9001
        const val CHANNEL_ID = "vin_alarm_ringing"
        private const val TAG = "AlarmForegroundService"
    }

    // Alert mode indices (must match Dart AlertMode enum)
    private val HAS_SOUND = setOf(1, 2, 5, 6)
    private val HAS_VIBRATE = setOf(0, 2, 4, 6)
    private val HAS_FLASH = setOf(3, 4, 5, 6)

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var flashHandler: Handler? = null
    private var flashRunnable: Runnable? = null
    private var flashOn = false

    private var alarmId = ""
    private var alarmLabel = "Alarm"
    private var alertMode = 2
    private var soundUri: String? = null
    private var isQuickAlarm = false
    private var ringDuration = 90
    private var timeoutHandler: Handler? = null
    private var timeoutRunnable: Runnable? = null

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        try {
            cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
            cameraId = cameraManager?.cameraIdList?.firstOrNull()
        } catch (e: Exception) {
            Log.e(TAG, "Camera init: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopEverything(); return START_NOT_STICKY }
            ACTION_SNOOZE -> { stopEverything(); return START_NOT_STICKY }
            ACTION_START -> {
                alarmId = intent.getStringExtra("alarm_id") ?: ""
                alarmLabel = intent.getStringExtra("alarm_label") ?: "Alarm"
                alertMode = intent.getIntExtra("alert_mode", 2)
                soundUri = intent.getStringExtra("sound_uri")
                isQuickAlarm = intent.getBooleanExtra("is_quick_alarm", false)
                ringDuration = intent.getIntExtra("ring_duration", 90)
                startForeground(NOTIF_ID, buildNotification())
                acquireWakeLock()
                startEffects()
                launchAlarmScreen()
                startTimeoutTimer()
            }
        }
        return START_NOT_STICKY
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        wakeLock = pm.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "VinAlarm:WakeLock"
        )
        wakeLock?.acquire(10 * 60 * 1000L)
    }

    private fun startEffects() {
        if (alertMode in HAS_SOUND) startSound()
        if (alertMode in HAS_VIBRATE) startVibration()
        if (alertMode in HAS_FLASH) startFlash()
    }

    private fun startSound() {
        try {
            var uri: android.net.Uri? = null
            if (!soundUri.isNullOrEmpty()) {
                try {
                    uri = android.net.Uri.parse(soundUri)
                } catch (e: Exception) {
                    Log.e(TAG, "Parsing soundUri failed: ${e.message}")
                }
            }
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(applicationContext, uri!!)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Sound error: ${e.message}")
            // Fallback play default
            try {
                val fallbackUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(applicationContext, fallbackUri)
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (ex: Exception) {
                Log.e(TAG, "Fallback sound error: ${ex.message}")
            }
        }
    }

    private fun startVibration() {
        val pattern = longArrayOf(0, 700, 300, 700, 300, 1200, 500)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun startFlash() {
        val cam = cameraManager ?: return
        val id = cameraId ?: return
        flashHandler = Handler(Looper.getMainLooper())
        flashRunnable = object : Runnable {
            override fun run() {
                try {
                    flashOn = !flashOn
                    cam.setTorchMode(id, flashOn)
                    flashHandler?.postDelayed(this, 400)
                } catch (e: Exception) {
                    Log.e(TAG, "Flash error: ${e.message}")
                }
            }
        }
        flashHandler?.post(flashRunnable!!)
    }

    private fun stopFlash() {
        flashHandler?.removeCallbacks(flashRunnable ?: return)
        flashHandler = null
        flashRunnable = null
        try {
            cameraId?.let { cameraManager?.setTorchMode(it, false) }
        } catch (e: Exception) { }
        flashOn = false
    }

    private fun launchAlarmScreen() {
        val screenIntent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_SHOW_ALARM
            putExtra("alarm_id", alarmId)
            putExtra("alarm_label", alarmLabel)
            putExtra("alert_mode", alertMode)
            putExtra("sound_uri", soundUri)
            putExtra("is_quick_alarm", isQuickAlarm)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                     Intent.FLAG_ACTIVITY_SINGLE_TOP or
                     Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(screenIntent)
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, AlarmForegroundService::class.java)
            .apply { action = ACTION_STOP }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_SHOW_ALARM
            putExtra("alarm_id", alarmId)
            putExtra("alarm_label", alarmLabel)
            putExtra("alert_mode", alertMode)
            putExtra("sound_uri", soundUri)
            putExtra("is_quick_alarm", isQuickAlarm)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val fullScreenPi = PendingIntent.getActivity(
            this, 1, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏰ $alarmLabel")
            .setContentText("Alarm is ringing!")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPi, true)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "STOP", stopPi)
            .build()
    }

    private fun startTimeoutTimer() {
        cancelTimeoutTimer()
        timeoutHandler = Handler(Looper.getMainLooper())
        timeoutRunnable = Runnable {
            Log.d(TAG, "Alarm ring duration expired. Triggering timeout.")
            // Broadcast com.vinalarm.ALARM_TIMEOUT
            val timeoutIntent = Intent("com.vinalarm.ALARM_TIMEOUT").apply {
                putExtra("alarm_id", alarmId)
            }
            sendBroadcast(timeoutIntent)
            stopEverything()
        }
        timeoutHandler?.postDelayed(timeoutRunnable!!, ringDuration * 1000L)
    }

    private fun cancelTimeoutTimer() {
        timeoutHandler?.removeCallbacks(timeoutRunnable ?: return)
        timeoutHandler = null
        timeoutRunnable = null
    }

    private fun stopEverything() {
        cancelTimeoutTimer()
        stopFlash()
        try { mediaPlayer?.stop(); mediaPlayer?.release() } catch (_: Exception) {}
        mediaPlayer = null
        vibrator?.cancel()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        
        // Broadcast that alarm has stopped so MainActivity can notify Flutter EventChannel
        val stoppedIntent = Intent("com.vinalarm.ALARM_STOPPED").apply {
            putExtra("alarm_id", alarmId)
        }
        sendBroadcast(stoppedIntent)
        
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID, "Alarm Ringing",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shown when alarm is ringing"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(chan)
        }
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }
}
