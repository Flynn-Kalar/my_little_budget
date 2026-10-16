package com.my_little_budget

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import org.json.JSONArray
import java.io.File

/** Shared contract with reminder_schema.dart. Never creates or upgrades Drift's DB. */
internal class ReminderRepository(private val context: Context) {
    private val prefs get() = context.getSharedPreferences("reminder_database", Context.MODE_PRIVATE)

    fun configure(path: String) {
        require(File(path).isFile) { "Reminder database does not exist" }
        prefs.edit().putString("path", path).commit()
    }

    private fun <T> read(default: T, action: (SQLiteDatabase) -> T): T {
        val path = prefs.getString("path", null) ?: return default
        if (!File(path).isFile) return default
        return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            db.setForeignKeyConstraintsEnabled(true)
            db.rawQuery("PRAGMA busy_timeout=5000",null).use { it.moveToFirst() }
            // An update/boot receiver can run before Flutter migrates an older
            // installation. Leave migration to Dart's headless refresh.
            val ready = db.rawQuery("SELECT 1 FROM sqlite_master WHERE type='view' AND name='reminder_dispatch_jobs'",null).use { it.moveToFirst() }
            if(!ready) return@use default
            action(db)
        }
    }

    private fun jobs(db: SQLiteDatabase, where: String, args: Array<String>): List<JSONObject> {
        val result = mutableListOf<JSONObject>()
        db.rawQuery("""SELECT id,generation,payload,trigger_at FROM reminder_dispatch_jobs j
            WHERE ($where) ORDER BY trigger_at,j.id LIMIT 400""", args).use { c ->
            while (c.moveToNext()) result.add(JSONObject(c.getString(2)).apply {
                put("jobId", c.getInt(0)); put("id", if(c.getInt(0)<0) -740000+c.getInt(0) else 740000+c.getInt(0))
                put("generation", c.getInt(1)); put("triggerAt", c.getLong(3))
            })
        }
        return result
    }

    fun pending(): List<JSONObject> = read(emptyList()) { db ->
        val cutoff = System.currentTimeMillis() - 300_000L
        for(table in listOf("reminder_jobs","calendar_jobs")) db.execSQL("""UPDATE $table SET state='missed' WHERE
            state IN ('pending','scheduled','blocked','failed') AND
            COALESCE(snoozed_until,fire_at)<?""", arrayOf(cutoff))
        jobs(db, "j.state IN ('pending','scheduled','blocked','failed')", emptyArray())
    }

    fun current(job: JSONObject): JSONObject? = read(null) { db ->
        jobs(db, "j.id=CAST(? AS INTEGER) AND j.generation=CAST(? AS INTEGER) AND j.state NOT IN ('cancelled','dismissed','missed')",
            arrayOf(job.optInt("jobId").toString(), job.optInt("generation").toString())).firstOrNull()
    }

    fun validTokens(): Set<Pair<Int,Int>> = read(emptySet()) { db ->
        val tokens=mutableSetOf<Pair<Int,Int>>()
        db.rawQuery("""SELECT id,generation FROM reminder_dispatch_jobs
            WHERE state NOT IN ('cancelled','dismissed','missed')""",null).use { c ->
            while(c.moveToNext()) tokens.add(Pair(c.getInt(0),c.getInt(1)))
        }
        tokens
    }

    private fun table(job: JSONObject) = if(job.optInt("jobId")<0) "calendar_jobs" else "reminder_jobs"
    private fun localId(job: JSONObject) = kotlin.math.abs(job.optInt("jobId"))

    fun claim(job: JSONObject): JSONObject? = read(null) { db ->
        db.beginTransaction()
        try {
            val latest = jobs(db, "j.id=CAST(? AS INTEGER) AND j.generation=CAST(? AS INTEGER) AND j.state IN ('pending','scheduled','failed')",
                arrayOf(job.optInt("jobId").toString(),job.optInt("generation").toString())).firstOrNull()
            if (latest != null) {
                val delta = System.currentTimeMillis() - latest.getLong("triggerAt")
                if (delta in -1000L..300_000L) {
                    db.execSQL("UPDATE ${table(latest)} SET state='delivered',delivered_at=? WHERE id=?",
                        arrayOf(System.currentTimeMillis(),localId(latest)))
                    db.setTransactionSuccessful()
                    return@read latest
                }
                if (delta > 300_000L) db.execSQL("UPDATE ${table(latest)} SET state='missed' WHERE id=?", arrayOf(localId(latest)))
            }
            db.setTransactionSuccessful()
            null
        } finally { db.endTransaction() }
    }

    fun state(job: JSONObject, state: String, error: String? = null) = read(Unit) { db ->
        db.execSQL("""UPDATE ${table(job)} SET state=?,last_error=? WHERE id=? AND generation=?
            AND state NOT IN ('cancelled','dismissed','missed')""",
            arrayOf(state,error,localId(job),job.optInt("generation")))
    }

    /** Generation-checked, idempotent background action in a single transaction. */
    fun action(job: JSONObject, action: String, minutes: Int = 10): Boolean = read(false) { db ->
        db.beginTransaction()
        try {
            val latest = jobs(db, "j.id=CAST(? AS INTEGER) AND j.generation=CAST(? AS INTEGER) AND j.state='delivered'",
                arrayOf(job.optInt("jobId").toString(),job.optInt("generation").toString())).firstOrNull()
                ?: return@read false
            val occurrence = latest.getInt("occurrenceId")
            when (action) {
                "complete" -> {
                    if(latest.optInt("jobId")<0) {
                        db.execSQL("UPDATE calendar_occurrences SET status='completed' WHERE id=?",arrayOf(occurrence))
                        db.execSQL("UPDATE calendar_jobs SET state='cancelled',generation=generation+1 WHERE occurrence_id=?",arrayOf(occurrence))
                    } else {
                    db.rawQuery("SELECT checklist_json FROM reminder_occurrences WHERE id=?",
                        arrayOf(occurrence.toString())).use { c ->
                        if(c.moveToFirst()) {
                            val snapshot=JSONArray(c.getString(0))
                            for(i in 0 until snapshot.length()) snapshot.getJSONObject(i).put("checked",true)
                            db.execSQL("UPDATE reminder_occurrences SET checklist_json=? WHERE id=?",
                                arrayOf(snapshot.toString(),occurrence))
                        }
                    }
                    db.execSQL("UPDATE reminder_occurrences SET status='completed',completed_at=? WHERE id=?",
                        arrayOf(System.currentTimeMillis(),occurrence))
                    // Update the visible checklist only for the active cycle,
                    // not for a future occurrence's early reminder.
                    db.rawQuery("""SELECT n.id,n.schedule_type,o.scheduled_at,
                        (SELECT MAX(scheduled_at) FROM reminder_occurrences WHERE note_id=n.id AND scheduled_at<=?)
                        FROM reminder_occurrences o JOIN notes n ON n.id=o.note_id WHERE o.id=?""",
                        arrayOf(System.currentTimeMillis().toString(),occurrence.toString())).use { c ->
                        if (c.moveToFirst() && (c.getString(1)=="once" || c.getLong(2)==c.getLong(3))) {
                            db.execSQL("UPDATE note_checklist_items SET is_checked=1,updated_at=? WHERE note_id=?",
                                arrayOf(java.time.Instant.now().toString(),c.getInt(0)))
                            db.execSQL("UPDATE notes SET completed=1,updated_at=? WHERE id=?",
                                arrayOf(java.time.Instant.now().toString(),c.getInt(0)))
                        }
                    }
                    db.execSQL("UPDATE reminder_jobs SET state='cancelled',generation=generation+1 WHERE occurrence_id=?", arrayOf(occurrence))
                }
                }
                "snooze" -> {
                    val until = System.currentTimeMillis() + minutes.coerceIn(1,1440) * 60_000L
                    db.execSQL("UPDATE ${table(latest)} SET state='pending',generation=generation+1,snoozed_until=?,delivered_at=NULL WHERE id=?",
                        arrayOf(until,localId(latest)))
                    db.execSQL("""UPDATE ${table(latest)} SET state='dismissed',generation=generation+1
                        WHERE occurrence_id=? AND id<>? AND COALESCE(snoozed_until,fire_at)<=?""",
                        arrayOf(occurrence,localId(latest),until))
                }
                else -> db.execSQL("UPDATE ${table(latest)} SET state='dismissed' WHERE id=?", arrayOf(localId(latest)))
            }
            db.setTransactionSuccessful()
            true
        } finally { db.endTransaction() }
    }
}
