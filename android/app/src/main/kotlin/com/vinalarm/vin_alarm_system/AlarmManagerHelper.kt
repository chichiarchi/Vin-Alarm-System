package com.vinalarm.vin_alarm_system

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object AlarmManagerHelper {

    fun scheduleAlarm(context: Context, args: Map<String, Any>) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val alarmId = args["id"] as? String ?: return
        val triggerMs = (args["triggerTime"] as? Long) ?: return
        val label = args["label"] as? String ?: "Alarm"
        val alertMode = (args["alertMode"] as? Int) ?: 2
        val soundUri = args["soundUri"] as? String
        val isQuickAlarm = (args["isQuickAlarm"] as? Boolean) ?: false
        val ringDuration = (args["ringDuration"] as? Int) ?: 90

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.vinalarm.ALARM_FIRE"
            putExtra("alarm_id", alarmId)
            putExtra("alarm_label", label)
            putExtra("alert_mode", alertMode)
            putExtra("sound_uri", soundUri)
            putExtra("is_quick_alarm", isQuickAlarm)
            putExtra("ring_duration", ringDuration)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerMs, pendingIntent)
        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
    }

    fun cancelAlarm(context: Context, alarmId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        pendingIntent?.let { alarmManager.cancel(it) }
    }
}
