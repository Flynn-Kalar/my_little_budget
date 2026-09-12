package com.my_little_budget

import org.junit.Assert.assertSame
import org.junit.Assert.assertEquals
import org.junit.Test

class NoteAlarmPresentationPolicyTest {
    @Test
    fun `notification tap opens alarm screen when full screen presentation is declined`() {
        val openNote = Any()
        val alarmScreen = Any()

        val target = NoteAlarmPresentationPolicy.notificationTapTarget(
            openNote = openNote,
            alarmScreen = alarmScreen,
        )

        assertSame(alarmScreen, target)
        assertEquals("눌러서 알람 화면 열기", NoteAlarmPresentationPolicy.NOTIFICATION_TEXT)
        assertEquals("알람 끄기", NoteAlarmPresentationPolicy.STOP_ACTION_LABEL)
    }
}
