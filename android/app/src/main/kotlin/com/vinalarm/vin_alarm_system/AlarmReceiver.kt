package com.vinalarm.vin_alarm_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarm_id") ?: return
        val label = intent.getStringExtra("alarm_label") ?: "Alarm"
        val alertMode = intent.getIntExtra("alert_mode", 2)
        val soundUri = intent.getStringExtra("sound_uri")
        val isQuickAlarm = intent.getBooleanExtra("is_quick_alarm", false)
        val ringDuration = intent.getIntExtra("ring_duration", 90)

        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START
            putExtra("alarm_id", alarmId)
            putExtra("alarm_label", label)
            putExtra("alert_mode", alertMode)
            putExtra("sound_uri", soundUri)
            putExtra("is_quick_alarm", isQuickAlarm)
            putExtra("ring_duration", ringDuration)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
