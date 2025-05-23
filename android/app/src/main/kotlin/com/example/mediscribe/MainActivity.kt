package com.example.mediscribe

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import java.util.*

class MainActivity : FlutterActivity() {
    private val EXACT_ALARM_CHANNEL = "flutter_local_notifications_example"
    private val ALARM_CHANNEL = "alarm_channel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel for exact alarm permissions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXACT_ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "checkExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            val canScheduleExactAlarms = alarmManager.canScheduleExactAlarms()
                            result.success(canScheduleExactAlarms)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Channel for scheduling and canceling alarms
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        try {
                            val args = call.arguments as Map<String, Any>
                            val id = args["id"] as Int
                            val title = args["title"] as String
                            val body = args["body"] as String

                            // ✅ New fields
                            val year = (args["year"] as Number).toInt()
                            val month = (args["month"] as Number).toInt()
                            val day = (args["day"] as Number).toInt()
                            val hour = (args["hour"] as Number).toInt()
                            val minute = (args["minute"] as Number).toInt()

                            val intent = Intent(this, AlarmReceiver::class.java).apply {
                                putExtra("title", title)
                                putExtra("body", body)
                            }

                            val pendingIntent = PendingIntent.getBroadcast(
                                this,
                                id,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

                            val calendar = Calendar.getInstance().apply {
                                set(Calendar.YEAR, year)
                                set(Calendar.MONTH, month - 1) // Months are 0-indexed in Java!
                                set(Calendar.DAY_OF_MONTH, day)
                                set(Calendar.HOUR_OF_DAY, hour)
                                set(Calendar.MINUTE, minute)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }

                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                calendar.timeInMillis,
                                pendingIntent
                            )

                            Log.d("AlarmManager", "✅ Scheduled alarm (ID: $id) at ${calendar.time}")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("AlarmManager", "❌ Failed to schedule alarm: ${e.message}", e)
                            result.error("ALARM_ERROR", e.message, null)
                        }
                    }

                    "cancelAlarm" -> {
                        try {
                            val args = call.arguments as Map<String, Any>
                            val id = args["id"] as Int

                            val intent = Intent(this, AlarmReceiver::class.java)
                            val pendingIntent = PendingIntent.getBroadcast(
                                this,
                                id,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            alarmManager.cancel(pendingIntent)
                            pendingIntent.cancel()

                            Log.d("AlarmManager", "🛑 Cancelled alarm (ID: $id)")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("AlarmManager", "❌ Failed to cancel alarm: ${e.message}", e)
                            result.error("ALARM_CANCEL_ERROR", e.message, null)
                        }
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
