package br.com.githubmanager.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

class DownloadForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val arguments = Arguments.fromIntent(intent)
        val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(this, arguments),
            serviceType,
        )
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15+ limita foreground services do tipo dataSync. Ao atingir
        // o limite, encerramos o serviço imediatamente para evitar
        // RemoteServiceException. O estado/checkpoint fica no lado Flutter e
        // é retomado automaticamente na próxima execução do aplicativo.
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf(startId)
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Mantém o processo em prioridade de foreground enquanto o download está ativo.
        // Isso evita que apenas minimizar ou remover dos recentes interrompa o Dio/Flutter.
        super.onTaskRemoved(rootIntent)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Downloads do GitHub Manager",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mantém APKs, ZIPs, artifacts e logs baixando em segundo plano."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    data class Arguments(
        val downloadId: String,
        val fileName: String,
        val repositoryFullName: String,
        val current: Int,
        val total: Int,
        val indeterminate: Boolean,
        val activeCount: Int,
    ) {
        fun putInto(intent: Intent) {
            intent.putExtra("downloadId", downloadId)
            intent.putExtra("fileName", fileName)
            intent.putExtra("repositoryFullName", repositoryFullName)
            intent.putExtra("current", current)
            intent.putExtra("total", total)
            intent.putExtra("indeterminate", indeterminate)
            intent.putExtra("activeCount", activeCount)
        }

        companion object {
            fun fromIntent(intent: Intent?) = Arguments(
                downloadId = intent?.getStringExtra("downloadId").orEmpty(),
                fileName = intent?.getStringExtra("fileName").orEmpty().ifBlank { "arquivo" },
                repositoryFullName = intent?.getStringExtra("repositoryFullName").orEmpty(),
                current = intent?.getIntExtra("current", 0) ?: 0,
                total = intent?.getIntExtra("total", 0) ?: 0,
                indeterminate = intent?.getBooleanExtra("indeterminate", true) ?: true,
                activeCount = intent?.getIntExtra("activeCount", 1) ?: 1,
            )
        }
    }

    companion object {
        private const val CHANNEL_ID = "github_download_progress"
        private const val NOTIFICATION_ID = 9201

        @Volatile
        private var isRunning = false

        fun show(context: Context, arguments: Arguments) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                arguments.putInto(this)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun update(context: Context, arguments: Arguments) {
            if (!isRunning) {
                show(context, arguments)
                return
            }
            try {
                NotificationManagerCompat.from(context).notify(
                    NOTIFICATION_ID,
                    buildNotification(context, arguments),
                )
            } catch (_: SecurityException) {
                // A falta de permissão visual não deve cancelar o download.
            }
        }

        fun stop(context: Context) {
            isRunning = false
            context.stopService(Intent(context, DownloadForegroundService::class.java))
        }

        private fun buildNotification(context: Context, arguments: Arguments): Notification {
            val max = arguments.total.coerceAtLeast(0)
            val progress = if (max > 0) arguments.current.coerceIn(0, max) else 0
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle(
                    if (arguments.activeCount > 1) {
                        "${arguments.activeCount} downloads ativos"
                    } else {
                        "Baixando ${arguments.fileName}"
                    },
                )
                .setContentText(arguments.repositoryFullName.ifBlank { "GitHub Manager" })
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setContentIntent(openAppPendingIntent(context))
                .setProgress(max, progress, arguments.indeterminate || max <= 0)
                .build()
        }

        private fun openAppPendingIntent(context: Context): PendingIntent {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getActivity(context, 9202, launch, flags)
        }
    }
}
