package com.my_little_budget

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Bounded headless refresh. Existing OS alarms remain if refresh cannot finish. */
internal object ReminderBackground {
    private var running = false
    private val waiters = mutableListOf<() -> Unit>()
    fun refresh(context: Context, finished: () -> Unit) {
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            waiters.add(finished)
            if (running) return@post
            running = true
            var engine: FlutterEngine? = null
            var closed = false
            var succeeded = false
            fun close() {
                if (closed) return
                closed = true
                handler.post {
                    context.getSharedPreferences("reminder_background",Context.MODE_PRIVATE)
                        .edit().putString("last_status",if(succeeded) "success" else "failed_or_timed_out").apply()
                    engine?.destroy(); running = false
                    val callbacks=waiters.toList(); waiters.clear()
                    callbacks.forEach { it() }
                }
            }
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context.applicationContext)
                loader.ensureInitializationComplete(context.applicationContext,null)
                val instance = FlutterEngine(context.applicationContext)
                engine = instance
                MethodChannel(instance.dartExecutor.binaryMessenger,
                    "com.my_little_budget/reminder_background").setMethodCallHandler { call,result ->
                    when(call.method) {
                        "getTimeZone" -> result.success(java.util.TimeZone.getDefault().id)
                        "reschedule" -> {
                            runCatching { NoteAlarmScheduler.reschedule(context) }
                                .onSuccess { succeeded=true; result.success(null) }
                                .onFailure { result.error("schedule_failed",it.message,null) }
                        }
                        "finished" -> { result.success(null); close() }
                        else -> result.notImplemented()
                    }
                }
                instance.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(), "reminderBackgroundEntry"))
                handler.postDelayed({ close() }, 8500)
            } catch (_: Exception) { close() }
        }
    }
}
