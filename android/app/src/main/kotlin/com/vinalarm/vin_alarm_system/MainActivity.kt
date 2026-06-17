package com.vinalarm.vin_alarm_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val ACTION_SHOW_ALARM = "com.vinalarm.SHOW_ALARM"
        const val ACTION_ALARM_STOPPED = "com.vinalarm.ALARM_STOPPED"
        const val ACTION_ALARM_TIMEOUT = "com.vinalarm.ALARM_TIMEOUT"
        private const val SCHEDULE_CHANNEL = "vin.alarm/schedule"
        private const val CONTROL_CHANNEL = "vin.alarm/control"
        private const val EVENT_CHANNEL = "vin.alarm/events"
        private const val RINGTONE_PICKER_REQUEST_CODE = 999

        // Holds alarm data until Flutter EventChannel is ready
        var pendingAlarmData: Map<String, Any?>? = null
    }

    private var eventSink: EventChannel.EventSink? = null
    private var localReceiver: BroadcastReceiver? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenFlags()
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        applyLockScreenFlags()
        handleAlarmIntent(intent)
    }

    override fun onDestroy() {
        localReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    // ── Lock screen / wake ────────────────────────────────────────────────────

    private fun applyLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    // ── Alarm intent handling ─────────────────────────────────────────────────

    private fun handleAlarmIntent(intent: android.content.Intent?) {
        if (intent == null) return
        if (intent.action == ACTION_SHOW_ALARM) {
            val data: Map<String, Any?> = mapOf(
                "event"        to "ring",
                "id"           to (intent.getStringExtra("alarm_id") ?: ""),
                "label"        to (intent.getStringExtra("alarm_label") ?: "Alarm"),
                "alertMode"    to intent.getIntExtra("alert_mode", 2),
                "soundUri"     to intent.getStringExtra("sound_uri"),
                "isQuickAlarm" to intent.getBooleanExtra("is_quick_alarm", false)
            )
            sendOrPendingEvent(data)
        } else if (intent.action == ACTION_ALARM_STOPPED) {
            val data: Map<String, Any?> = mapOf(
                "event" to "stop",
                "id"    to (intent.getStringExtra("alarm_id") ?: "")
            )
            sendOrPendingEvent(data)
        } else if (intent.action == ACTION_ALARM_TIMEOUT) {
            val data: Map<String, Any?> = mapOf(
                "event" to "timeout",
                "id"    to (intent.getStringExtra("alarm_id") ?: "")
            )
            sendOrPendingEvent(data)
        }
    }

    private fun sendOrPendingEvent(data: Map<String, Any?>) {
        if (eventSink != null) {
            eventSink?.success(data)
        } else {
            pendingAlarmData = data
        }
    }

    // ── Ringtone Picker result handling ────────────────────────────────────────

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_PICKER_REQUEST_CODE) {
            val result = pendingRingtoneResult
            pendingRingtoneResult = null
            if (result == null) return

            if (resultCode == RESULT_OK && data != null) {
                val uri = data.getParcelableExtra<android.net.Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                if (uri != null) {
                    val ringtone = RingtoneManager.getRingtone(this, uri)
                    val title = ringtone?.getTitle(this) ?: "Ringtone"
                    result.success(mapOf(
                        "uri" to uri.toString(),
                        "title" to title
                    ))
                } else {
                    result.success(null)
                }
            } else {
                result.success(null)
            }
        }
    }

    // ── Flutter engine ────────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Schedule channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCHEDULE_CHANNEL)
            .setMethodCallHandler { call, result ->
                @Suppress("UNCHECKED_CAST")
                when (call.method) {
                    "scheduleAlarm" -> {
                        val args = call.arguments as Map<String, Any>
                        AlarmManagerHelper.scheduleAlarm(this, args)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        AlarmManagerHelper.cancelAlarm(this, call.arguments as String)
                        result.success(null)
                    }
                    "getPendingAlarm" -> {
                        result.success(pendingAlarmData)
                        pendingAlarmData = null
                    }
                    "pickRingtone" -> {
                        pendingRingtoneResult = result
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Alarm Ringtone")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        }
                        startActivityForResult(intent, RINGTONE_PICKER_REQUEST_CODE)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stopAlarm", "snoozeAlarm" -> {
                        startService(
                            android.content.Intent(this, AlarmForegroundService::class.java)
                                .apply { action = AlarmForegroundService.ACTION_STOP }
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // 3. Event channel — sends alarm-fire and alarm-stop events to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    pendingAlarmData?.let { events?.success(it); pendingAlarmData = null }
                }
                override fun onCancel(arguments: Any?) { eventSink = null }
            })

        // 4. Local broadcast listener (app is already open when alarm fires or stops)
        localReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, i: android.content.Intent) =
                handleAlarmIntent(i)
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_SHOW_ALARM)
            addAction(ACTION_ALARM_STOPPED)
            addAction(ACTION_ALARM_TIMEOUT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(localReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(localReceiver, filter)
        }
    }
}
