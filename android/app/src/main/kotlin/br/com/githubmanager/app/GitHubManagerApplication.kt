package br.com.githubmanager.app

import android.app.Application
import android.content.Context
import android.os.Build
import android.os.Process
import org.json.JSONObject
import kotlin.system.exitProcess

class GitHubManagerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        installCrashCapture()
    }

    private fun installCrashCapture() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val packageInfo = packageManager.getPackageInfo(packageName, 0)
                val payload = JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("thread", thread.name)
                    put("type", throwable.javaClass.name)
                    put("message", sanitize(throwable.message.orEmpty()).take(4000))
                    put("stackTrace", sanitize(throwable.stackTraceToString()).take(16000))
                    put("androidSdk", Build.VERSION.SDK_INT)
                    put("device", "${Build.MANUFACTURER} ${Build.MODEL}".trim())
                    put("appVersion", packageInfo.versionName.orEmpty())
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        put("versionCode", packageInfo.longVersionCode)
                    } else {
                        @Suppress("DEPRECATION")
                        put("versionCode", packageInfo.versionCode)
                    }
                }
                getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY_LAST_NATIVE_CRASH, payload.toString())
                    .commit()
            } catch (_: Throwable) {
                // A captura nunca deve substituir nem bloquear o crash original.
            } finally {
                if (previous != null) {
                    previous.uncaughtException(thread, throwable)
                } else {
                    Process.killProcess(Process.myPid())
                    exitProcess(10)
                }
            }
        }
    }

    private fun sanitize(value: String): String {
        var output = value
        val patterns = listOf(
            Regex("(?i)(authorization\\s*:\\s*bearer\\s+)[^\\s,}]+"),
            Regex("(?i)((token|api[_-]?key|password|secret)\\s*[=:]\\s*)[^\\s,}]+"),
            Regex("github_pat_[A-Za-z0-9_]+"),
            Regex("gh[pousr]_[A-Za-z0-9]+"),
        )
        patterns.forEach { pattern ->
            output = pattern.replace(output) { match ->
                val prefix = if (match.groupValues.size > 1) match.groupValues[1] else ""
                "${prefix}[REDACTED]"
            }
        }
        return output
    }

    companion object {
        private const val PREFS_NAME = "github_manager_crash_telemetry"
        private const val KEY_LAST_NATIVE_CRASH = "last_native_crash"

        fun consumePendingNativeCrash(context: Context): String? {
            val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val report = preferences.getString(KEY_LAST_NATIVE_CRASH, null)
            if (report != null) {
                preferences.edit().remove(KEY_LAST_NATIVE_CRASH).apply()
            }
            return report
        }
    }
}
