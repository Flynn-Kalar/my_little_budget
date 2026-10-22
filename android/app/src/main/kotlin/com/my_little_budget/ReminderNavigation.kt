package com.my_little_budget

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import org.json.JSONObject

/** Opens the reminder without completing its checklist or scheduling a snooze. */
internal object ReminderNavigation {
    private const val EXTRA_OPEN_JOB = "open_reminder_job"

    fun label(job: JSONObject) = if (job.has("calendarEventId")) "일정으로 이동" else "체크리스트로 이동"

    fun intent(context: Context, job: JSONObject): Intent =
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(NoteAlarmScheduler.EXTRA_NOTE_ID, job.optInt("noteId", -1))
            .putExtra("calendar_event_id", job.optInt("calendarEventId", -1))
            .putExtra("occurrence_id", job.optInt("occurrenceId", -1))
            .putExtra(EXTRA_OPEN_JOB, job.toString())

    fun consume(context: Context, intent: Intent?) {
        val raw = intent?.getStringExtra(EXTRA_OPEN_JOB) ?: return
        intent.removeExtra(EXTRA_OPEN_JOB)
        val job = runCatching { JSONObject(raw) }.getOrNull() ?: return
        ReminderRepository(context).action(job, "dismiss")
        context.getSystemService(NotificationManager::class.java).cancel(job.getInt("id"))
        // Reconciliation stops only dismissed jobs; other simultaneous alarms remain active.
        context.startService(Intent(context, NoteAlarmPlaybackService::class.java)
            .setAction(NoteAlarmPlaybackService.ACTION_RECONCILE))
    }
}
