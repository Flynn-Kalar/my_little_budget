package com.my_little_budget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject

internal object ReminderNotification {
    private const val CHANNEL="note_regular_reminders_v1"
    const val COMPLETE="com.my_little_budget.REMINDER_COMPLETE"
    const val SNOOZE="com.my_little_budget.REMINDER_SNOOZE"
    const val DISMISS="com.my_little_budget.REMINDER_DISMISS"
    fun show(context: Context,job: JSONObject) {
        val manager=context.getSystemService(NotificationManager::class.java)
        if(Build.VERSION.SDK_INT>=26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL,"할 일 알림",NotificationManager.IMPORTANCE_DEFAULT))
        fun action(name: String)=PendingIntent.getBroadcast(context,job.getInt("id"),
            Intent(context,NoteAlarmReceiver::class.java).setAction(name)
                .putExtra(NoteAlarmScheduler.EXTRA_JOB,job.toString()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open=PendingIntent.getActivity(context,job.getInt("id"),
            Intent(context,MainActivity::class.java).putExtra(NoteAlarmScheduler.EXTRA_NOTE_ID,job.optInt("noteId",-1))
                .putExtra("occurrence_id",job.getInt("occurrenceId"))
                .putExtra("calendar_event_id",job.optInt("calendarEventId",-1)),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.notify(job.getInt("id"),NotificationCompat.Builder(context,CHANNEL)
            .setSmallIcon(com.my_little_budget.R.drawable.ic_notification)
            .setContentTitle(job.optString("title")).setContentText(if(job.has("calendarEventId")) "일정을 확인하세요" else "할 일을 확인하세요")
            .addExtras(android.os.Bundle().apply { putString(NoteAlarmScheduler.EXTRA_JOB,job.toString()) })
            .setContentIntent(open).setAutoCancel(true).setDeleteIntent(action(DISMISS))
            .addAction(0,if(job.has("calendarEventId")) "확인" else "완료",action(COMPLETE))
            .addAction(0,"다시 알림",action(SNOOZE)).build())
    }
}
