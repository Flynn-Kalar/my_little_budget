package com.my_little_budget

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmDismissGestureTest {
    @Test
    fun `threshold accepts every outward direction`() {
        assertTrue(AlarmDismissGesture(96f).release(96f, 0f))
        assertTrue(AlarmDismissGesture(96f).release(-96f, 0f))
        assertTrue(AlarmDismissGesture(96f).release(0f, 96f))
        assertTrue(AlarmDismissGesture(96f).release(0f, -96f))
        assertTrue(AlarmDismissGesture(96f).release(68f, 68f))
    }

    @Test
    fun `short drag returns to center`() {
        assertFalse(AlarmDismissGesture(96f).release(95f, 0f))
    }

    @Test
    fun `dismiss fires only once`() {
        val gesture = AlarmDismissGesture(96f)
        assertTrue(gesture.release(100f, 0f))
        assertFalse(gesture.release(100f, 0f))
    }
}
