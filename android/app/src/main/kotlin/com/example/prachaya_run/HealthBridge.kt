package com.example.prachaya_run

import android.app.Activity
import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * `prachaya/health`: workouts other apps (Samsung Health, Garmin Connect,
 * Zepp…) wrote to Health Connect, for Dart's NativeHealthSource. Read only;
 * times cross the channel as epoch milliseconds.
 *
 * A route another app wrote may need the user's consent per session
 * (ExerciseRouteResult.ConsentRequired); such a workout comes without a
 * route for now.
 */
class HealthBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        const val REQUEST_CODE = 0x4843 // "HC"
        private const val READ_ROUTES = "android.permission.health.READ_EXERCISE_ROUTES"
        private val KINDS = mapOf(
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING to "run",
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL to "run",
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING to "ride",
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY to "ride",
            ExerciseSessionRecord.EXERCISE_TYPE_HIKING to "hike",
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING to "walk",
        )
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val permissions = setOf(
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ElevationGainedRecord::class),
    )
    private val contract = PermissionController.createRequestPermissionResultContract()
    private var pendingAccess: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "prachaya/health").setMethodCallHandler(::handle)
    }

    private fun status(): String = when (HealthConnectClient.getSdkStatus(activity)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "needsUpdate"
        else -> "unavailable"
    }

    private fun client() = HealthConnectClient.getOrCreate(activity)

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val sdk = status()
        if (sdk != "available") {
            if (call.method == "availability" || call.method == "requestAccess") {
                result.success(sdk)
            } else {
                result.success(if (call.method == "detail") null else emptyList<Any>())
            }
            return
        }
        when (call.method) {
            "availability" -> run(result) {
                val granted = client().permissionController.getGrantedPermissions()
                if (granted.containsAll(permissions)) "granted" else "denied"
            }
            "requestAccess" -> {
                pendingAccess?.success("denied")
                pendingAccess = result
                activity.startActivityForResult(
                    contract.createIntent(activity, permissions + READ_ROUTES),
                    REQUEST_CODE,
                )
            }
            "workouts" -> run(result) { workouts(call.from(), call.to()) }
            "detail" -> run(result) {
                detail(call.argument<String>("id")!!, call.from(), call.to())
            }
            "heartRate" -> run(result) { heartRate(call.from(), call.to()) }
            else -> result.notImplemented()
        }
    }

    /** Forwarded from MainActivity.onActivityResult. */
    fun onPermissionResult(resultCode: Int, data: Intent?) {
        val granted = contract.parseResult(resultCode, data)
        pendingAccess?.success(if (granted.containsAll(permissions)) "granted" else "denied")
        pendingAccess = null
    }

    private suspend fun workouts(from: Instant, to: Instant): List<Map<String, Any?>> {
        val own = activity.packageName
        val items = mutableListOf<Map<String, Any?>>()
        var page: String? = null
        do {
            val response = client().readRecords(
                ReadRecordsRequest(
                    ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(from, to),
                    pageToken = page,
                ),
            )
            for (s in response.records) {
                val kind = KINDS[s.exerciseType] ?: continue
                val origin = s.metadata.dataOrigin
                if (origin.packageName == own) continue
                val totals = client().aggregate(
                    AggregateRequest(
                        metrics = setOf<AggregateMetric<*>>(
                            ExerciseSessionRecord.EXERCISE_DURATION_TOTAL,
                            DistanceRecord.DISTANCE_TOTAL,
                            ElevationGainedRecord.ELEVATION_GAINED_TOTAL,
                        ),
                        timeRangeFilter = TimeRangeFilter.between(s.startTime, s.endTime),
                        dataOriginFilter = setOf(DataOrigin(origin.packageName)),
                    ),
                )
                val device = s.metadata.device?.let {
                    listOfNotNull(it.manufacturer, it.model).joinToString(" ").ifBlank { null }
                }
                items += mapOf(
                    "id" to s.metadata.id,
                    "source" to "health-connect",
                    "kind" to kind,
                    "start" to s.startTime.toEpochMilli(),
                    "end" to s.endTime.toEpochMilli(),
                    "activeMs" to totals[ExerciseSessionRecord.EXERCISE_DURATION_TOTAL]?.toMillis(),
                    "distanceM" to totals[DistanceRecord.DISTANCE_TOTAL]?.inMeters,
                    "elevationM" to totals[ElevationGainedRecord.ELEVATION_GAINED_TOTAL]?.inMeters,
                    "app" to origin.packageName,
                    "device" to device,
                )
            }
            page = response.pageToken
        } while (page != null)
        return items
    }

    private suspend fun detail(id: String, from: Instant, to: Instant): Map<String, Any?> {
        val session = client().readRecord(ExerciseSessionRecord::class, id).record
        val route = when (val r = session.exerciseRouteResult) {
            is ExerciseRouteResult.Data -> r.exerciseRoute.route.map {
                mapOf(
                    "lat" to it.latitude,
                    "lng" to it.longitude,
                    "alt" to it.altitude?.inMeters,
                    "acc" to it.horizontalAccuracy?.inMeters,
                    "t" to it.time.toEpochMilli(),
                )
            }
            else -> emptyList()
        }
        return mapOf("route" to route, "heartRate" to heartRate(from, to))
    }

    private suspend fun heartRate(from: Instant, to: Instant): List<Map<String, Any>> {
        val samples = mutableListOf<Map<String, Any>>()
        var page: String? = null
        do {
            val response = client().readRecords(
                ReadRecordsRequest(
                    HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(from, to),
                    pageToken = page,
                ),
            )
            for (record in response.records) {
                for (s in record.samples) {
                    samples += mapOf("t" to s.time.toEpochMilli(), "bpm" to s.beatsPerMinute)
                }
            }
            page = response.pageToken
        } while (page != null)
        return samples.sortedBy { it["t"] as Long }
    }

    private fun run(result: MethodChannel.Result, block: suspend () -> Any?) {
        scope.launch {
            try {
                result.success(block())
            } catch (e: Exception) {
                result.error("health_error", e.message, null)
            }
        }
    }

    private fun MethodCall.from() = Instant.ofEpochMilli(argument<Number>("from")!!.toLong())

    private fun MethodCall.to() = Instant.ofEpochMilli(argument<Number>("to")!!.toLong())
}
