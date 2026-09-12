package com.my_little_budget

internal data class NoteAlarmSystemPlaybackSettings(
    val soundAllowed: Boolean,
    val vibrationAllowed: Boolean,
)

internal data class NoteAlarmPlaybackDecision(
    val playSound: Boolean,
    val vibrate: Boolean,
    val showAlarmPresentation: Boolean = true,
)

internal object NoteAlarmPlaybackPolicy {
    const val CHANNEL_ID = "note_alarm_playback_v2"
    const val PRESENTATION_CHANNEL_ID = "note_alarm_presentation_v1"
    const val LEGACY_CHANNEL_ID = "note_alarm_playback_v1"

    // Playback is performed by MediaPlayer/Vibrator so custom clips can loop.
    // The notification uses a separate silent high-importance channel. Calling
    // NotificationCompat.setSilent(true) is intentionally forbidden because it
    // creates a suppressive group that blocks full-screen intents on Android 15.
    const val NOTIFICATION_MUST_USE_SILENT_GROUP = false

    fun systemSettings(
        notificationsAllowed: Boolean,
        channelEnabled: Boolean,
        channelSoundAllowed: Boolean,
        channelVibrationAllowed: Boolean,
    ): NoteAlarmSystemPlaybackSettings {
        val presentationAllowed = notificationsAllowed && channelEnabled
        return NoteAlarmSystemPlaybackSettings(
            soundAllowed = presentationAllowed && channelSoundAllowed,
            vibrationAllowed = presentationAllowed && channelVibrationAllowed,
        )
    }

    fun shouldPlaySound(systemAllowed: Boolean, noteAllowed: Boolean): Boolean =
        systemAllowed && noteAllowed

    fun shouldVibrate(systemAllowed: Boolean, noteAllowed: Boolean): Boolean =
        systemAllowed && noteAllowed

    fun resolve(
        systemSoundAllowed: Boolean,
        systemVibrationAllowed: Boolean,
        noteSoundAllowed: Boolean,
        noteVibrationAllowed: Boolean,
    ) = NoteAlarmPlaybackDecision(
        playSound = shouldPlaySound(systemSoundAllowed, noteSoundAllowed),
        vibrate = shouldVibrate(systemVibrationAllowed, noteVibrationAllowed),
    )
}

/**
 * Keeps the notification fallback independently testable. Android may decline
 * a full-screen intent, so tapping the remaining notification must still lead
 * to the alarm UI where playback can be stopped.
 */
internal object NoteAlarmPresentationPolicy {
    const val NOTIFICATION_TEXT = "눌러서 알람 화면 열기"
    const val STOP_ACTION_LABEL = "알람 끄기"

    fun <T> notificationTapTarget(openNote: T, alarmScreen: T): T = alarmScreen
}
