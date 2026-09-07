package com.cadence.cadence

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cadence.app/screentime"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsagePermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "getDailyUsageStats" -> {
                    val startEpoch = (call.argument<Number>("startEpoch")?.toLong()) ?: 0L
                    val endEpoch = (call.argument<Number>("endEpoch")?.toLong()) ?: System.currentTimeMillis()
                    val stats = getUsageStatistics(startEpoch, endEpoch)
                    result.success(stats)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getUsageStatistics(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return emptyList()
        val packageManager = packageManager

        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        ) ?: return emptyList()

        val aggregated = mutableMapOf<String, Long>()
        for (stat in usageStatsList) {
            val current = aggregated.getOrDefault(stat.packageName, 0L)
            aggregated[stat.packageName] = current + stat.totalTimeInForeground
        }

        val result = mutableListOf<Map<String, Any>>()
        for ((pkg, totalTimeMs) in aggregated) {
            if (totalTimeMs < 60000L) continue

            val appName = try {
                val appInfo = packageManager.getApplicationInfo(pkg, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                pkg.substringAfterLast('.')
            }

            val category = categorizePackage(pkg)

            result.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "totalTimeInForegroundMs" to totalTimeMs,
                    "durationMinutes" to (totalTimeMs / 60000L).toInt(),
                    "category" to category
                )
            )
        }

        result.sortByDescending { (it["durationMinutes"] as? Int) ?: 0 }
        return result
    }

    private fun categorizePackage(pkg: String): String {
        val p = pkg.lowercase()
        return when {
            p.contains("instagram") || p.contains("facebook") || p.contains("twitter") ||
            p.contains("x.android") || p.contains("tiktok") || p.contains("reddit") ||
            p.contains("snapchat") || p.contains("threads") || p.contains("linkedin") -> "social"

            p.contains("youtube") || p.contains("netflix") || p.contains("spotify") ||
            p.contains("twitch") || p.contains("hulu") || p.contains("disney") ||
            p.contains("primevideo") || p.contains("games") -> "entertainment"

            p.contains("slack") || p.contains("teams") || p.contains("zoom") ||
            p.contains("github") || p.contains("notion") || p.contains("obsidian") ||
            p.contains("docs") || p.contains("sheets") || p.contains("cadence") ||
            p.contains("code") || p.contains("studio") -> "productivity"

            p.contains("chrome") || p.contains("firefox") || p.contains("browser") ||
            p.contains("gmail") || p.contains("outlook") || p.contains("whatsapp") ||
            p.contains("telegram") || p.contains("signal") || p.contains("messenger") -> "communication"

            else -> "utilities"
        }
    }
}
