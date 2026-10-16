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
            real.execSQL("INSERT INTO notes(title,schedule_type,notification_enabled,reminder_at) VALUES(?,'once',1,?)",
                arrayOf("headless-contract-test",formatter.format(java.util.Date(System.currentTimeMillis()+3_600_000))))
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

    @Test fun scheduledAlarmStartsAudioAndCanBeStopped() {
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
        } finally {
            context.startService(android.content.Intent(context,NoteAlarmPlaybackService::class.java)
                .setAction(NoteAlarmPlaybackService.ACTION_STOP))
            Thread.sleep(300)
            assertTrue(context.getSharedPreferences("reminder_playback",0)
                .getLong("last_sound_stopped_at",0)>=start)
        }
    }
}
