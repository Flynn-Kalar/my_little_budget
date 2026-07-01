package com.my_little_budget

import android.animation.ValueAnimator
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextClock
import android.widget.TextView
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.hypot

class NoteAlarmActivity : Activity() {
    private lateinit var titleView: TextView
    private var receiverRegistered = false

    private val finishedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NoteAlarmPlaybackService.ACTION_FINISHED) closeScreen()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        setContentView(buildContent())
        updateJob(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        updateJob(intent)
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(NoteAlarmPlaybackService.ACTION_FINISHED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(finishedReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION") registerReceiver(finishedReceiver, filter)
        }
        receiverRegistered = true
    }

    override fun onStop() {
        if (receiverRegistered) {
            unregisterReceiver(finishedReceiver)
            receiverRegistered = false
        }
        super.onStop()
    }

    @Deprecated("The alarm screen intentionally blocks back navigation")
    override fun onBackPressed() = Unit

    private fun buildContent(): View {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(72), dp(24), dp(44))
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(Color.rgb(12, 0, 42), Color.rgb(31, 8, 74), Color.rgb(89, 57, 91)),
            )
        }
        val time = TextClock(this).apply {
            format24Hour = "HH:mm"
            format12Hour = "HH:mm"
            textSize = 104f
            setTextColor(Color.WHITE)
            gravity = android.view.Gravity.CENTER
            includeFontPadding = false
        }
        val date = TextView(this).apply {
            text = SimpleDateFormat("M월 d일 EEEE", Locale.KOREAN).format(Date())
            textSize = 27f
            setTextColor(Color.argb(235, 255, 255, 255))
            gravity = android.view.Gravity.CENTER
            setPadding(0, dp(14), 0, 0)
        }
        titleView = TextView(this).apply {
            textSize = 25f
            setTextColor(Color.WHITE)
            gravity = android.view.Gravity.CENTER
            setPadding(dp(12), dp(22), dp(12), 0)
            maxLines = 3
        }
        val spacer = Space(this)
        val dismiss = AlarmDismissView(this).apply {
            contentDescription = "알람 끄기. 버튼을 바깥 방향으로 드래그하세요."
            onDismiss = { stopAlarm() }
        }
        val hint = TextView(this).apply {
            text = "버튼을 바깥으로 드래그하여 알람 끄기"
            textSize = 16f
            setTextColor(Color.argb(210, 255, 255, 255))
            gravity = android.view.Gravity.CENTER
        }

        root.addView(time, LinearLayout.LayoutParams(-1, -2))
        root.addView(date, LinearLayout.LayoutParams(-1, -2))
        root.addView(titleView, LinearLayout.LayoutParams(-1, -2))
        root.addView(spacer, LinearLayout.LayoutParams(1, 0, 1f))
        root.addView(dismiss, LinearLayout.LayoutParams(-1, dp(320)))
        root.addView(hint, LinearLayout.LayoutParams(-1, -2))
        return root
    }

    private fun updateJob(source: Intent?) {
        val raw = source?.getStringExtra(NoteAlarmScheduler.EXTRA_JOB)
        titleView.text = raw?.let {
            runCatching { JSONObject(it).optString("title", "메모 알람") }.getOrDefault("메모 알람")
        } ?: "메모 알람"
    }

    private fun stopAlarm() {
        startService(
            Intent(this, NoteAlarmPlaybackService::class.java)
                .setAction(NoteAlarmPlaybackService.ACTION_STOP),
        )
        closeScreen()
    }

    private fun closeScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) finishAndRemoveTask() else finish()
    }
}

internal class AlarmDismissGesture(private val thresholdPx: Float) {
    var completed: Boolean = false
        private set

    fun release(dx: Float, dy: Float): Boolean {
        if (completed || hypot(dx, dy) < thresholdPx) return false
        completed = true
        return true
    }
}

internal class AlarmDismissView(context: Context) : View(context) {
    var onDismiss: (() -> Unit)? = null

    private val density = resources.displayMetrics.density
    private val threshold = 96f * density
    private val knobRadius = 55f * density
    private val haloRadius = 92f * density
    private val gesture = AlarmDismissGesture(threshold)
    private var dragging = false
    private var downX = 0f
    private var downY = 0f
    private var dragDistance = 0f
    private var returnAnimator: ValueAnimator? = null

    private val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val knobPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(70, 255, 255, 255)
        style = Paint.Style.FILL
    }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * density
    }
    private val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 5f * density
        strokeCap = Paint.Cap.ROUND
    }
    private val wavePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 2f * density
    }
    private val xPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 5f * density
        strokeCap = Paint.Cap.ROUND
    }

    init {
        isClickable = true
        isFocusable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val centerX = width / 2f
        val centerY = height / 2f
        val progress = (dragDistance / threshold).coerceIn(0f, 1f)
        val pulseRadius = haloRadius + 70f * density * progress

        haloPaint.shader = RadialGradient(
            centerX,
            centerY,
            pulseRadius,
            intArrayOf(
                Color.argb((55 + 75 * progress).toInt(), 255, 255, 255),
                Color.TRANSPARENT,
            ),
            floatArrayOf(0.25f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(centerX, centerY, pulseRadius, haloPaint)

        for (index in 0..2) {
            val phase = ((progress + index / 3f) % 1f)
            val alpha = (95 * (1f - phase) * progress).toInt()
            if (alpha > 0) {
                wavePaint.color = Color.argb(alpha, 255, 255, 255)
                canvas.drawCircle(centerX, centerY, knobRadius + phase * 125f * density, wavePaint)
            }
        }

        canvas.drawCircle(centerX, centerY, knobRadius, knobPaint)
        canvas.drawCircle(centerX, centerY, knobRadius, ringPaint)

        if (progress > 0f) {
            progressPaint.alpha = (115 + 140 * progress).toInt()
            val bounds = RectF(
                centerX - knobRadius - 11f * density,
                centerY - knobRadius - 11f * density,
                centerX + knobRadius + 11f * density,
                centerY + knobRadius + 11f * density,
            )
            canvas.drawArc(bounds, -90f, 360f * progress, false, progressPaint)
            progressPaint.alpha = 255
        }

        val arm = 17f * density
        val path = Path().apply {
            moveTo(centerX - arm, centerY - arm)
            lineTo(centerX + arm, centerY + arm)
            moveTo(centerX + arm, centerY - arm)
            lineTo(centerX - arm, centerY + arm)
        }
        canvas.drawPath(path, xPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (gesture.completed) return true
        val centerX = width / 2f
        val centerY = height / 2f
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                if (hypot(event.x - centerX, event.y - centerY) > knobRadius + 28f * density) return false
                parent?.requestDisallowInterceptTouchEvent(true)
                returnAnimator?.cancel()
                dragging = true
                downX = event.x
                downY = event.y
                return true
            }
            MotionEvent.ACTION_MOVE -> if (dragging) {
                dragDistance = hypot(event.x - downX, event.y - downY)
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP -> if (dragging) {
                dragging = false
                val dx = event.x - downX
                val dy = event.y - downY
                if (gesture.release(dx, dy)) {
                    performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                    onDismiss?.invoke()
                } else {
                    animateHome()
                }
                return true
            }
            MotionEvent.ACTION_CANCEL -> if (dragging) {
                dragging = false
                animateHome()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        if (!gesture.completed && gesture.release(threshold, 0f)) {
            performHapticFeedback(HapticFeedbackConstants.CONFIRM)
            onDismiss?.invoke()
        }
        return true
    }

    private fun animateHome() {
        val start = dragDistance
        returnAnimator = ValueAnimator.ofFloat(1f, 0f).apply {
            duration = 180
            addUpdateListener {
                val value = it.animatedValue as Float
                dragDistance = start * value
                invalidate()
            }
            start()
        }
    }
}
