package com.example.year4_project

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

// Health Connect imports
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.request.ReadRecordsRequest

// Coroutines for suspend functions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import java.time.Instant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.year4_project/health_connect"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->

            when (call.method) {

                // Check if Health Connect is available
                "checkAvailability" -> {
                    val status = HealthConnectClient.getSdkStatus(this)
                    // If status != SDK_UNAVAILABLE, Health Connect is available
                    val isAvailable = (status != HealthConnectClient.SDK_UNAVAILABLE)
                    result.success(isAvailable)
                }

                // Get total steps in a specified time range
                "getStepCount" -> {
                    val startTime = call.argument<Long>("startTime")
                    val endTime = call.argument<Long>("endTime") ?: Instant.now().toEpochMilli()

                    if (startTime == null) {
                        result.error("INVALID_ARGUMENT", "startTime is required", null)
                        return@setMethodCallHandler
                    }

                    // Launch a coroutine to call suspend functions
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            // Create or retrieve the Health Connect client
                            val client = HealthConnectClient.getOrCreate(this@MainActivity)

                            // Create a time range filter from the incoming arguments
                            val timeRange = TimeRangeFilter.between(
                                Instant.ofEpochMilli(startTime),
                                Instant.ofEpochMilli(endTime)
                            )

                            // Build the read request (positional arguments in alpha11)
                            val readRequest = ReadRecordsRequest(
                                StepsRecord::class,
                                timeRange // pass time range as second argument
                            )

                            // This is a suspend function, must be called in a coroutine
                            val response = client.readRecords(readRequest)

                            // Sum up all steps in the returned records
                            val totalSteps = response.records.sumOf { record -> record.count }

                            // Send result back to Flutter on the main thread
                            runOnUiThread {
                                result.success(totalSteps)
                            }

                        } catch (e: Exception) {
                            // Send error back to Flutter on the main thread
                            runOnUiThread {
                                result.error("READ_ERROR", e.localizedMessage, null)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
