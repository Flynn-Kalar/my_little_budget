package com.my_little_budget

import android.database.sqlite.SQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Runs under a separate .remindertest application, never the user's budget DB. */
@RunWith(AndroidJUnit4::class)
class ReminderRepositoryTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var file: File
    private lateinit var db: SQLiteDatabase
    private lateinit var repository: ReminderRepository
    private lateinit var job: JSONObject

    @Before fun prepare() {
        check(context.packageName.endsWith(".remindertest"))
        file=File(context.cacheDir,"reminder-repository-test.sqlite")
        SQLiteDatabase.deleteDatabase(file)
        db=SQLiteDatabase.openOrCreateDatabase(file,null)
        db.execSQL("CREATE TABLE notes(id INTEGER PRIMARY KEY,notification_enabled INTEGER,schedule_type TEXT,completed INTEGER,updated_at TEXT)")
        db.execSQL("CREATE TABLE note_checklist_items(id INTEGER PRIMARY KEY,note_id INTEGER,is_checked INTEGER,updated_at TEXT)")
        db.execSQL("CREATE TABLE reminder_occurrences(id INTEGER PRIMARY KEY,note_id INTEGER,status TEXT,completed_at INTEGER,scheduled_at INTEGER,checklist_json TEXT NOT NULL DEFAULT '[]')")
        db.execSQL("""CREATE TABLE reminder_jobs(id INTEGER PRIMARY KEY,occurrence_id INTEGER,
            generation INTEGER,state TEXT,payload TEXT,fire_at INTEGER,snoozed_until INTEGER,
            delivered_at INTEGER,last_error TEXT)""")
        db.execSQL("CREATE TABLE calendar_events(id INTEGER PRIMARY KEY,notification_enabled INTEGER,deleted_at TEXT)")
        db.execSQL("CREATE TABLE calendar_occurrences(id INTEGER PRIMARY KEY,event_id INTEGER,status TEXT)")
        db.execSQL("CREATE TABLE calendar_jobs AS SELECT * FROM reminder_jobs WHERE 0")
        db.execSQL("""CREATE VIEW reminder_dispatch_jobs AS
            SELECT j.id,j.generation,j.payload,COALESCE(j.snoozed_until,j.fire_at) AS trigger_at,j.state
            FROM reminder_jobs j JOIN reminder_occurrences o ON o.id=j.occurrence_id JOIN notes n ON n.id=o.note_id
            WHERE o.status='pending' AND n.notification_enabled=1 UNION ALL
            SELECT -j.id,j.generation,j.payload,COALESCE(j.snoozed_until,j.fire_at),j.state
            FROM calendar_jobs j JOIN calendar_occurrences o ON o.id=j.occurrence_id
            JOIN calendar_events e ON e.id=o.event_id
            WHERE o.status='pending' AND e.notification_enabled=1 AND e.deleted_at IS NULL""")
        val now=System.currentTimeMillis()
        db.execSQL("INSERT INTO notes VALUES(1,1,'once',0,NULL)")
        db.execSQL("INSERT INTO note_checklist_items VALUES(1,1,0,NULL)")
        db.execSQL("INSERT INTO reminder_occurrences(id,note_id,status,completed_at,scheduled_at) VALUES(1,1,'pending',NULL,?)",arrayOf(now))
        val payload=JSONObject().put("noteId",1).put("occurrenceId",1)
            .put("title","테스트").put("triggerAt",now).put("snoozeMinutes",10)
        db.execSQL("INSERT INTO reminder_jobs VALUES(1,1,1,'scheduled',?,?,NULL,NULL,NULL)",
            arrayOf(payload.toString(),now))
        repository=ReminderRepository(context)
        repository.configure(file.absolutePath)
        job=repository.pending().single()
    }

    @After fun cleanup() { db.close(); SQLiteDatabase.deleteDatabase(file) }

    private fun calendarJob(): JSONObject {
        val now=System.currentTimeMillis()
        db.execSQL("INSERT INTO calendar_events VALUES(1,1,NULL)")
        db.execSQL("INSERT INTO calendar_occurrences VALUES(1,1,'pending')")
        val payload=JSONObject().put("calendarEventId",1).put("occurrenceId",1)
            .put("title","일정").put("triggerAt",now).put("alarmMode",false)
        db.execSQL("INSERT INTO calendar_jobs VALUES(1,1,1,'scheduled',?,?,NULL,NULL,NULL)",arrayOf(payload.toString(),now))
        return repository.pending().single { it.getInt("jobId")<0 }
    }

    @Test fun calendarAndNoteIdsDoNotCollideAndAcknowledgeIsIsolated() {
        val calendar=calendarJob()
        assertNotEquals(job.getInt("id"),calendar.getInt("id"))
        assertNotNull(repository.claim(calendar))
        assertTrue(repository.action(calendar,"complete"))
        assertFalse(repository.action(calendar,"complete"))
        assertEquals(1,repository.pending().size)
        assertNotNull(repository.claim(job))
        db.rawQuery("SELECT completed FROM notes WHERE id=1",null).use { c -> c.moveToFirst();assertEquals(0,c.getInt(0)) }
    }

    @Test fun calendarSnoozePersistsAndOldGenerationCannotAct() {
        val calendar=calendarJob()
        repository.claim(calendar)
        assertTrue(repository.action(calendar,"snooze",10))
        assertNull(repository.current(calendar))
        val next=ReminderRepository(context).pending().single { it.getInt("jobId")<0 }
        assertEquals(2,next.getInt("generation"))
        assertTrue(next.getLong("triggerAt")>System.currentTimeMillis()+590_000)
    }

    @Test fun deletedCalendarCannotDeliverAnOldAlarm() {
        val calendar=calendarJob()
        db.execSQL("DELETE FROM calendar_events WHERE id=1")
        assertNull(repository.claim(calendar))
        assertEquals(1,repository.pending().size)
    }

    @Test fun claimIsOnceAndOldGenerationIsRejected() {
        assertNotNull(repository.claim(job))
        assertNull(repository.claim(job))
        db.execSQL("UPDATE reminder_jobs SET generation=2,state='pending'")
        assertNull(repository.current(job))
    }

    @Test fun completeIsAtomicAndIdempotent() {
        repository.claim(job)
        assertTrue(repository.action(job,"complete"))
        assertFalse(repository.action(job,"complete"))
        db.rawQuery("SELECT status FROM reminder_occurrences",null).use { c ->
            c.moveToFirst(); assertEquals("completed",c.getString(0))
        }
        db.rawQuery("SELECT is_checked FROM note_checklist_items",null).use { c ->
            c.moveToFirst(); assertEquals(1,c.getInt(0))
        }
        assertTrue(repository.pending().isEmpty())
    }

    @Test fun snoozeSurvivesRepositoryReopenAndRejectsOldAction() {
        repository.claim(job)
        assertTrue(repository.action(job,"snooze",10))
        assertFalse(repository.action(job,"snooze",10))
        val scheduled=ReminderRepository(context).pending().single()
        assertEquals(job.getInt("id"),scheduled.getInt("id"))
        assertEquals(2,scheduled.getInt("generation"))
        assertTrue(scheduled.getLong("triggerAt")>System.currentTimeMillis()+590_000)
    }

    @Test fun dismissedIsNotCompletedAndIsNotScheduledAgain() {
        repository.claim(job)
        assertTrue(repository.action(job,"dismiss"))
        assertTrue(repository.pending().isEmpty())
        db.rawQuery("SELECT status FROM reminder_occurrences",null).use { c ->
            c.moveToFirst(); assertEquals("pending",c.getString(0))
        }
    }

    @Test fun openingReminderPreservesPartialChecklistAndDoesNotSnooze() {
        db.execSQL("UPDATE note_checklist_items SET is_checked=1 WHERE id=1")
        db.execSQL("INSERT INTO note_checklist_items VALUES(2,1,0,NULL)")
        db.execSQL("UPDATE reminder_occurrences SET checklist_json=? WHERE id=1",
            arrayOf("[{\"checked\":true},{\"checked\":false}]"))
        assertNotNull(repository.claim(job))
        val open = ReminderNavigation.intent(context, job)
        assertEquals(1, open.getIntExtra(NoteAlarmScheduler.EXTRA_NOTE_ID, -1))
        ReminderNavigation.consume(context, open)
        // Re-consuming an Activity intent must be harmless.
        ReminderNavigation.consume(context, open)
        db.rawQuery("SELECT is_checked FROM note_checklist_items ORDER BY id",null).use { c ->
            c.moveToFirst(); assertEquals(1,c.getInt(0))
            c.moveToNext(); assertEquals(0,c.getInt(0))
        }
        db.rawQuery("SELECT status,checklist_json FROM reminder_occurrences WHERE id=1",null).use { c ->
            c.moveToFirst(); assertEquals("pending",c.getString(0))
            assertEquals("[{\"checked\":true},{\"checked\":false}]",c.getString(1))
        }
        db.rawQuery("SELECT state,snoozed_until FROM reminder_jobs WHERE id=1",null).use { c ->
            c.moveToFirst(); assertEquals("dismissed",c.getString(0)); assertTrue(c.isNull(1))
        }
        db.rawQuery("SELECT completed FROM notes WHERE id=1",null).use { c ->
            c.moveToFirst(); assertEquals(0,c.getInt(0))
        }
        assertTrue(repository.pending().isEmpty())
    }

    @Test fun deletedNoteAndExpiredAlarmAreSuppressed() {
        db.execSQL("DELETE FROM notes")
        assertNull(repository.current(job))
        assertNull(repository.claim(job))
        db.execSQL("INSERT INTO notes VALUES(1,1,'once',0,NULL)")
        db.execSQL("UPDATE reminder_jobs SET fire_at=?",arrayOf(System.currentTimeMillis()-600_000))
        assertTrue(repository.pending().isEmpty())
    }

    @Test fun sameInstantDifferentOccurrencesAreKept() {
        db.execSQL("INSERT INTO reminder_occurrences(id,note_id,status,completed_at,scheduled_at) VALUES(2,1,'pending',NULL,?)",arrayOf(System.currentTimeMillis()))
        val payload=JSONObject(job.toString()).put("occurrenceId",2)
        db.execSQL("INSERT INTO reminder_jobs VALUES(2,2,1,'scheduled',?,?,NULL,NULL,NULL)",
            arrayOf(payload.toString(),job.getLong("triggerAt")))
        assertEquals(2,repository.pending().size)
        assertNotNull(repository.claim(job))
        val second=repository.pending().single()
        assertNotNull(repository.claim(second))
    }

    @Test fun headlessRefreshFinishesWithoutAnActivity() {
        val latch=java.util.concurrent.CountDownLatch(1)
        ReminderBackground.refresh(context) { latch.countDown() }
        assertTrue(latch.await(20,java.util.concurrent.TimeUnit.SECONDS))
        assertEquals("success",context.getSharedPreferences("reminder_background",0).getString("last_status",null))
        // Contract test against the real Drift-created database, in this test
        // application only. Verify Dart planning and native reading interoperate.
        val actual=File(context.applicationInfo.dataDir,"app_flutter/budget.sqlite")
        assertTrue(actual.isFile)
        val formatter=java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",java.util.Locale.US)
        formatter.timeZone=java.util.TimeZone.getTimeZone("UTC")
        SQLiteDatabase.openDatabase(actual.absolutePath,null,SQLiteDatabase.OPEN_READWRITE).use { real ->
            real.execSQL("DELETE FROM notes WHERE title='headless-contract-test'")
            real.execSQL("INSERT INTO notes(uuid,title,schedule_type,notification_enabled,reminder_at) VALUES(?,?,'once',1,?)",
                arrayOf(java.util.UUID.randomUUID().toString(),"headless-contract-test",formatter.format(java.util.Date(System.currentTimeMillis()+3_600_000))))
        }
        try {
            repository.configure(actual.absolutePath)
            val planned=java.util.concurrent.CountDownLatch(1)
            ReminderBackground.refresh(context) { planned.countDown() }
            assertTrue(planned.await(20,java.util.concurrent.TimeUnit.SECONDS))
            assertEquals("success",context.getSharedPreferences("reminder_background",0).getString("last_status",null))
            assertTrue(repository.pending().any { it.optString("title")=="headless-contract-test" })
        } finally {
            SQLiteDatabase.openDatabase(actual.absolutePath,null,SQLiteDatabase.OPEN_READWRITE).use { real ->
                real.setForeignKeyConstraintsEnabled(true)
                real.execSQL("DELETE FROM notes WHERE title='headless-contract-test'")
            }
            repository.configure(file.absolutePath)
        }
    }

    @Test fun scheduledAlarmStartsAudioAndOpeningChecklistStopsItWithoutCompletion() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        fun shell(command: String) {
            instrumentation.uiAutomation.executeShellCommand(command).use { fd ->
                java.io.FileInputStream(fd.fileDescriptor).use { it.readBytes() }
            }
        }
        // Permission changes are scoped to the throwaway test application.
        shell("pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS")
        shell("appops set ${context.packageName} SCHEDULE_EXACT_ALARM allow")
        NoteAlarmChannel.ensureCreated(context)
        val start=System.currentTimeMillis()
        val trigger=start+3000
        val payload=JSONObject(job.toString()).put("triggerAt",trigger)
            .put("soundKind","system").put("vibrationEnabled",false)
        db.execSQL("UPDATE reminder_jobs SET payload=?,fire_at=?",arrayOf(payload.toString(),trigger))
        try {
            NoteAlarmScheduler.replace(context,emptyList())
            val deadline=start+12_000
            while(System.currentTimeMillis()<deadline && context.getSharedPreferences("reminder_playback",0)
                    .getLong("last_sound_started_at",0)<start) Thread.sleep(100)
            assertTrue("Scheduled receiver must reach MediaPlayer.start()",
                context.getSharedPreferences("reminder_playback",0).getLong("last_sound_started_at",0)>=start)
            val previousStop=context.getSharedPreferences("reminder_playback",0).getLong("last_sound_stopped_at",0)
            ReminderNavigation.consume(context, ReminderNavigation.intent(context, payload))
            val stoppedDeadline=System.currentTimeMillis()+3000
            while(System.currentTimeMillis()<stoppedDeadline && context.getSharedPreferences("reminder_playback",0)
                    .getLong("last_sound_stopped_at",0)<=previousStop) Thread.sleep(100)
            assertTrue("Opening the checklist must stop the alarm audio",
                context.getSharedPreferences("reminder_playback",0).getLong("last_sound_stopped_at",0)>previousStop)
            db.rawQuery("SELECT status FROM reminder_occurrences WHERE id=1",null).use { c ->
                c.moveToFirst(); assertEquals("pending",c.getString(0))
            }
        } finally {
            context.startService(android.content.Intent(context,NoteAlarmPlaybackService::class.java)
                .setAction(NoteAlarmPlaybackService.ACTION_STOP))
            Thread.sleep(300)
            assertTrue(context.getSharedPreferences("reminder_playback",0)
                .getLong("last_sound_stopped_at",0)>=start)
        }
    }
}
