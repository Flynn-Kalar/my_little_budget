package com.my_little_budget

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

object NoteAlarmScheduler {
    const val EXTRA_JOB = "note_alarm_job"
    const val EXTRA_NOTE_ID = "note_id"
    private const val PREFS = "note_alarm_jobs"
    private const val KEY_JOBS = "jobs"

    fun replace(context: Context, jobs: List<Map<String, Any?>>) {
        val latest=ReminderRepository(context).pending()
        val valid=ReminderRepository(context).validTokens()
        val manager=context.getSystemService(NotificationManager::class.java)
        for(shown in manager.activeNotifications) {
            val raw=shown.notification.extras.getString(EXTRA_JOB)?:continue
            val token=runCatching { JSONObject(raw) }.getOrNull()?:continue
            if(Pair(token.optInt("jobId"),token.optInt("generation")) !in valid) manager.cancel(shown.id)
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = JSONArray(prefs.getString(KEY_JOBS, "[]"))
        for (index in 0 until old.length()) {
            val previous=old.getJSONObject(index)
            cancel(context, previous.optInt("id"))
            if(Pair(previous.optInt("jobId"),previous.optInt("generation")) !in valid) {
                context.getSystemService(NotificationManager::class.java).cancel(previous.optInt("id"))
            }
        }
        val array = JSONArray()
        // SQLite is authoritative; Flutter's list is only a wake-up signal.
        latest.forEach { array.put(it) }
        prefs.edit().putString(KEY_JOBS, array.toString()).commit()
        scheduleStored(context, array)
    }

    fun reschedule(context: Context) {
        replace(context, emptyList())
    }

    fun snooze(context: Context, job: JSONObject) {
        ReminderRepository(context).action(job, "snooze", job.optInt("snoozeMinutes", 10))
        reschedule(context)
    }

    private fun scheduleStored(context: Context, jobs: JSONArray) {
        val now = System.currentTimeMillis()
        for (index in 0 until jobs.length()) {
            val job = jobs.getJSONObject(index)
            if (job.optLong("triggerAt") >= now - 300_000L) {
                try { schedule(context, job) }
                catch (error: Exception) { ReminderRepository(context).state(job,"failed",error.javaClass.simpleName) }
            }
        }
    }

    private fun schedule(context: Context, job: JSONObject) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms())) {
            ReminderRepository(context).state(job,"blocked","알림 또는 정확한 알람 권한 필요")
            return
        }
        val pending = PendingIntent.getBroadcast(
            context,
            job.getInt("id"),
            Intent(context, NoteAlarmReceiver::class.java).putExtra(EXTRA_JOB, job.toString()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, job.getLong("triggerAt"), pending)
        ReminderRepository(context).state(job,"scheduled")
    }

    private fun cancel(context: Context, id: Int) {
        val pending = PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, NoteAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }
}

class NoteAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if(intent.action in setOf(ReminderNotification.COMPLETE,ReminderNotification.SNOOZE,ReminderNotification.DISMISS)) {
            val raw=intent.getStringExtra(NoteAlarmScheduler.EXTRA_JOB)?:return
            val job=JSONObject(raw)
            val action=when(intent.action) {
                ReminderNotification.COMPLETE->"complete"
                ReminderNotification.SNOOZE->"snooze"
                else->"dismiss"
            }
            if(ReminderRepository(context).action(job,action,job.optInt("snoozeMinutes",10))) {
                context.getSystemService(NotificationManager::class.java).cancel(job.getInt("id"))
                NoteAlarmScheduler.reschedule(context)
            }
            val pending=goAsync()
            ReminderBackground.refresh(context) { pending.finish() }
            return
        }
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) {
            NoteAlarmScheduler.reschedule(context)
            val pending = goAsync()
            ReminderBackground.refresh(context) { pending.finish() }
            return
        }
        val raw = intent.getStringExtra(NoteAlarmScheduler.EXTRA_JOB) ?: return
        val job = ReminderRepository(context).claim(JSONObject(raw)) ?: return
        if(!job.optBoolean("alarmMode",true)) {
            try { ReminderNotification.show(context,job) }
            catch(error: Exception) { ReminderRepository(context).state(job,"failed",error.javaClass.simpleName) }
            val pending=goAsync()
            ReminderBackground.refresh(context) { pending.finish() }
            return
        }
        val service = Intent(context, NoteAlarmPlaybackService::class.java)
            .setAction(NoteAlarmPlaybackService.ACTION_PLAY)
            .putExtra(NoteAlarmScheduler.EXTRA_JOB, job.toString())
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(service)
            else context.startService(service)
        } catch (error: Exception) { ReminderRepository(context).state(job,"failed",error.javaClass.simpleName) }
        val pending = goAsync()
        ReminderBackground.refresh(context) { pending.finish() }
    }
}

class NoteAlarmPlaybackService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var startedAt = 0L
    private var clipStart = 0
    private var clipEnd: Int? = null
    private var alarmActive = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocus: AudioFocusRequest? = null
    private val focusListener=AudioManager.OnAudioFocusChangeListener { change ->
        if(change<0 && alarmActive) {
            activeJobs.values.forEach { ReminderRepository(this).state(it,"delivered","audio_focus_lost") }
            stopPlayback(notifyScreen=true)
            stopSelf()
        }
    }
    private val activeJobs = linkedMapOf<Int, JSONObject>()

    override fun onCreate() {
        super.onCreate()
        NoteAlarmChannel.ensureCreated(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_RECONCILE) {
            activeJobs.entries.removeAll { ReminderRepository(this).current(it.value) == null }
            if (activeJobs.isEmpty()) { stopPlayback(notifyScreen = true); stopSelf() }
            else startForeground(NOTIFICATION_ID, notification(activeJobs.values.first()))
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_COMPLETE) {
            val job = intent.getStringExtra(NoteAlarmScheduler.EXTRA_JOB)?.let { JSONObject(it) }
            if (job != null) {
                ReminderRepository(this).action(job,"complete")
                activeJobs.remove(job.optInt("jobId"))
                NoteAlarmScheduler.reschedule(this)
            }
            if (activeJobs.isEmpty()) { stopPlayback(notifyScreen = true); stopSelf() }
            else startForeground(NOTIFICATION_ID, notification(activeJobs.values.first()))
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_STOP) {
            activeJobs.values.forEach { ReminderRepository(this).action(it,"dismiss") }
            activeJobs.clear()
            stopPlayback(notifyScreen = true)
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_SNOOZE) {
            val raw = intent.getStringExtra(NoteAlarmScheduler.EXTRA_JOB)
            if (raw != null) { val job = JSONObject(raw); snooze(job); activeJobs.remove(job.optInt("jobId")) }
            if (activeJobs.isEmpty()) { stopPlayback(notifyScreen = true); stopSelf() }
            else startForeground(NOTIFICATION_ID, notification(activeJobs.values.first()))
            return START_NOT_STICKY
        }
        val raw = intent?.getStringExtra(NoteAlarmScheduler.EXTRA_JOB) ?: return START_NOT_STICKY
        val job = ReminderRepository(this).current(JSONObject(raw)) ?: return START_NOT_STICKY
        if (activeJobs.containsKey(job.getInt("jobId"))) return START_NOT_STICKY
        activeJobs[job.getInt("jobId")] = job
        if (alarmActive) startForeground(NOTIFICATION_ID, notification(activeJobs.values.first()))
        else play(job)
        return START_NOT_STICKY
    }

    private fun play(job: JSONObject) {
        stopPlayback(notifyScreen = false)
        alarmActive = true
        wakeLock=getSystemService(PowerManager::class.java).newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,"my_little_budget:reminder").apply { acquire(65_000) }
        val systemSettings = NoteAlarmChannel.playbackSettings(this)
        val playback = NoteAlarmPlaybackPolicy.resolve(
            systemSoundAllowed = systemSettings.soundAllowed,
            systemVibrationAllowed = systemSettings.vibrationAllowed,
            noteSoundAllowed = job.optBoolean("soundEnabled", true),
            noteVibrationAllowed = job.optBoolean("vibrationEnabled", true),
        )
        startForeground(NOTIFICATION_ID, notification(job))
        startedAt = System.currentTimeMillis()
        clipStart = job.optInt("clipStartMs", 0).coerceAtLeast(0)
        clipEnd = job.optInt("clipEndMs", -1).takeIf { it > clipStart }
        val audio=getSystemService(AudioManager::class.java)
        val focused=if(!playback.playSound) false else if(Build.VERSION.SDK_INT>=26) {
            audioFocus=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
                .setOnAudioFocusChangeListener(focusListener,handler).build()
            audio.requestAudioFocus(audioFocus!!)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            (audio.requestAudioFocus(focusListener,AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
        }
        if (playback.playSound && focused) {
            player = createPlayer(this, job)?.also { media ->
                media.setOnPreparedListener {
                    if(!alarmActive) return@setOnPreparedListener
                    clipStart=clipStart.coerceAtMost((it.duration-1000).coerceAtLeast(0))
                    clipEnd=clipEnd?.coerceAtMost(it.duration)?.takeIf { end -> end>clipStart }
                    if (clipStart > 0) it.seekTo(clipStart)
                    it.start()
                    getSharedPreferences("reminder_playback",MODE_PRIVATE).edit()
                        .putLong("last_sound_started_at",System.currentTimeMillis()).apply()
                    handler.post(progress)
                }
                media.setOnErrorListener { _, what, extra ->
                    activeJobs.values.forEach { ReminderRepository(this).state(it,"delivered","audio:$what:$extra") }
                    handler.post {
                        if(!alarmActive) return@post
                        player?.release()
                        val fallback=JSONObject(job.toString()).put("soundKind","system")
                        fallback.remove("soundUri")
                        clipStart=0; clipEnd=null
                        player=createPlayer(this,fallback)?.also { replacement ->
                            replacement.setOnPreparedListener { if(alarmActive) { it.isLooping=true; it.start() } }
                            replacement.setOnErrorListener { _,_,_ -> true }
                            replacement.prepareAsync()
                        }
                    }
                    true
                }
                media.setOnCompletionListener {
                    runCatching { it.seekTo(clipStart); it.start() }
                }
                media.prepareAsync()
            }
        }
        if (playback.vibrate) startVibration()
        handler.postDelayed(timeout, 60_000L)
    }

    private fun snooze(job: JSONObject) {
        NoteAlarmScheduler.snooze(this, job)
    }

    private val timeout = Runnable {
        activeJobs.values.forEach { ReminderRepository(this).state(it,"delivered","alarm_timeout_60s") }
        activeJobs.values.forEach { ReminderRepository(this).action(it,"dismiss") }
        activeJobs.clear()
        stopPlayback(notifyScreen = true)
        stopSelf()
    }

    private val progress = object : Runnable {
        override fun run() {
            val media = player ?: return
            val end = clipEnd ?: media.duration.takeIf { it > 0 }
            if (end != null && media.isPlaying && media.currentPosition >= end - 60) media.seekTo(clipStart)
            handler.postDelayed(this, 80)
        }
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION") getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 500, 350)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION") vibrator?.vibrate(pattern, 0)
        }
    }

    private fun notification(job: JSONObject): android.app.Notification {
        val title = job.optString("title", "메모 알람")
        val open = PendingIntent.getActivity(
            this,
            job.getInt("id"),
            ReminderNavigation.intent(this, job),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, NoteAlarmPlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val complete = PendingIntent.getService(this, job.getInt("id"),
            Intent(this, NoteAlarmPlaybackService::class.java).setAction(ACTION_COMPLETE)
                .putExtra(NoteAlarmScheduler.EXTRA_JOB,job.toString()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val snooze = PendingIntent.getService(
            this,
            job.getInt("id"),
            Intent(this, NoteAlarmPlaybackService::class.java)
                .setAction(ACTION_SNOOZE)
                .putExtra(NoteAlarmScheduler.EXTRA_JOB, job.toString()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmScreen = PendingIntent.getActivity(
            this,
            FULL_SCREEN_REQUEST_CODE,
            Intent(this, NoteAlarmActivity::class.java)
                .putExtra(NoteAlarmScheduler.EXTRA_JOB, job.toString())
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notificationTap = NoteAlarmPresentationPolicy.notificationTapTarget(
            openNote = open,
            alarmScreen = alarmScreen,
        )
        val builder = NotificationCompat.Builder(
            this,
            NoteAlarmPlaybackPolicy.PRESENTATION_CHANNEL_ID,
        )
            .setSmallIcon(com.my_little_budget.R.drawable.ic_notification)
            .setContentTitle(if (activeJobs.size > 1) "$title 외 ${activeJobs.size - 1}개" else title)
            .setContentText(NoteAlarmPresentationPolicy.NOTIFICATION_TEXT)
            .setContentIntent(notificationTap)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(alarmScreen, true)
            .addAction(0, ReminderNavigation.label(job), open)
            .addAction(0, "완료", complete)
        if (job.optInt("snoozeMinutes", 0) > 0) {
            builder.addAction(0, "${job.optInt("snoozeMinutes",10)}분 뒤 다시 알림", snooze)
        }
        builder.addAction(0, NoteAlarmPresentationPolicy.STOP_ACTION_LABEL, stop)
        return builder.build()
    }

    private fun stopPlayback(notifyScreen: Boolean) {
        handler.removeCallbacksAndMessages(null)
        player?.runCatching { stop() }
        player?.release()
        player = null
        val audio=getSystemService(AudioManager::class.java)
        if(Build.VERSION.SDK_INT>=26) audioFocus?.let { audio.abandonAudioFocusRequest(it) }
        else { @Suppress("DEPRECATION") audio.abandonAudioFocus(focusListener) }
        audioFocus=null
        wakeLock?.let { if(it.isHeld) it.release() }
        wakeLock=null
        vibrator?.cancel()
        vibrator = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (alarmActive && notifyScreen) {
            sendBroadcast(Intent(ACTION_FINISHED).setPackage(packageName))
        }
        alarmActive = false
        getSharedPreferences("reminder_playback",MODE_PRIVATE).edit()
            .putLong("last_sound_stopped_at",System.currentTimeMillis()).apply()
    }

    override fun onDestroy() {
        stopPlayback(notifyScreen = true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_PLAY = "com.my_little_budget.PLAY_NOTE_ALARM"
        const val ACTION_COMPLETE = "com.my_little_budget.COMPLETE_NOTE_ALARM"
        const val ACTION_RECONCILE = "com.my_little_budget.RECONCILE_NOTE_ALARM"
        const val ACTION_STOP = "com.my_little_budget.STOP_NOTE_ALARM"
        const val ACTION_SNOOZE = "com.my_little_budget.SNOOZE_NOTE_ALARM"
        const val ACTION_FINISHED = "com.my_little_budget.NOTE_ALARM_FINISHED"
        private const val NOTIFICATION_ID = 739999
        private const val FULL_SCREEN_REQUEST_CODE = 739998
    }
}

internal object NoteAlarmChannel {
    private val vibrationPattern = longArrayOf(0, 500, 350)

    fun ensureCreated(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val legacy = manager.getNotificationChannel(NoteAlarmPlaybackPolicy.LEGACY_CHANNEL_ID)
        if (manager.getNotificationChannel(NoteAlarmPlaybackPolicy.CHANNEL_ID) == null) {
            val importance = legacy?.importance ?: NotificationManager.IMPORTANCE_HIGH
            val soundAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val channel = NotificationChannel(
                NoteAlarmPlaybackPolicy.CHANNEL_ID,
                "메모 알람",
                importance,
            ).apply {
                description = "메모 알람의 소리와 진동 허용 여부"
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), soundAttributes)
                setVibrationPattern(vibrationPattern)
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }
        if (manager.getNotificationChannel(NoteAlarmPlaybackPolicy.PRESENTATION_CHANNEL_ID) == null) {
            val presentationChannel = NotificationChannel(
                NoteAlarmPlaybackPolicy.PRESENTATION_CHANNEL_ID,
                "메모 알람 화면",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "전체 화면 알람과 알람 끄기 버튼"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(presentationChannel)
        }
        if (legacy != null) {
            manager.deleteNotificationChannel(NoteAlarmPlaybackPolicy.LEGACY_CHANNEL_ID)
        }
    }

    fun playbackSettings(context: Context): NoteAlarmSystemPlaybackSettings {
        val notificationsAllowed = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return NoteAlarmPlaybackPolicy.systemSettings(
                notificationsAllowed = notificationsAllowed,
                channelEnabled = true,
                channelSoundAllowed = true,
                channelVibrationAllowed = true,
            )
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = manager.getNotificationChannel(NoteAlarmPlaybackPolicy.CHANNEL_ID)
        val presentationChannel = manager.getNotificationChannel(
            NoteAlarmPlaybackPolicy.PRESENTATION_CHANNEL_ID,
        )
        val presentationAllowed = presentationChannel != null &&
            presentationChannel.importance != NotificationManager.IMPORTANCE_NONE
        return NoteAlarmPlaybackPolicy.systemSettings(
            notificationsAllowed = notificationsAllowed,
            channelEnabled = presentationAllowed &&
                channel != null && channel.importance != NotificationManager.IMPORTANCE_NONE,
            channelSoundAllowed = channel != null &&
                channel.importance >= NotificationManager.IMPORTANCE_DEFAULT &&
                channel.sound != null,
            channelVibrationAllowed = channel?.shouldVibrate() == true,
        )
    }
}

object NoteAlarmPreview {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var tone: ToneGenerator? = null

    fun play(context: Context, values: Map<String, Any?>): Boolean {
        stop()
        val job = JSONObject(values)
        val start = job.optInt("clipStartMs", 0).coerceAtLeast(0)
        val end = job.optInt("clipEndMs", -1).takeIf { it > start }
        player = createPlayer(context, job)?.also { media ->
            media.setOnPreparedListener {
                if (start > 0) it.seekTo(start)
                it.start()
                if (end != null) handler.post(object : Runnable {
                    override fun run() {
                        if (media.currentPosition >= end - 60) stop() else handler.postDelayed(this, 80)
                    }
                })
            }
            media.setOnCompletionListener { stop() }
            media.prepareAsync()
        }
        if (player != null) return true

        return runCatching {
            tone = ToneGenerator(AudioManager.STREAM_ALARM, 100).also {
                it.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 1500)
            }
            handler.postDelayed({ stop() }, 1600)
            true
        }.getOrDefault(false)
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
        player?.runCatching { stop() }
        player?.release()
        player = null
        tone?.runCatching { stopTone() }
        tone?.release()
        tone = null
    }
}

private fun createPlayer(context: Context, job: JSONObject): MediaPlayer? {
    val configured = job.optString("soundUri").takeIf { it.isNotBlank() }
    val uri = if (job.optString("soundKind") == "custom") {
        configured?.let { value ->
            val file = File(Uri.parse(value).path ?: value)
            if (file.exists()) Uri.fromFile(file) else null
        }
    } else configured?.let(Uri::parse)
    for (source in alarmSoundCandidates(context, uri)) {
        val player = try {
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setDataSource(context, source)
            }
        } catch (_: Exception) {
            null
        }
        if (player != null) return player
    }
    return null
}

private fun alarmSoundCandidates(context: Context, preferred: Uri?): List<Uri> {
    return listOfNotNull(
        preferred,
        RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM),
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
        RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_NOTIFICATION),
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
        RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE),
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
    ).distinct()
}
