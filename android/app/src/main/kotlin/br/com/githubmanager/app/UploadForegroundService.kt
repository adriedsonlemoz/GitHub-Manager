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

class UploadForegroundService : Service() {
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
        // Não encerramos o serviço ao remover o app dos recentes. O FlutterEngine
        // principal fica em cache e o upload continua enquanto o processo estiver vivo.
        super.onTaskRemoved(rootIntent)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Envios para o GitHub",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mantém envios de projetos ativos quando o GitHub Manager fica em segundo plano."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    data class Arguments(
        val uploadId: String,
        val projectName: String,
        val repositoryFullName: String,
        val phase: String,
        val current: Int,
        val total: Int,
        val indeterminate: Boolean,
        val activeCount: Int,
    ) {
        fun putInto(intent: Intent) {
            intent.putExtra("uploadId", uploadId)
            intent.putExtra("projectName", projectName)
            intent.putExtra("repositoryFullName", repositoryFullName)
            intent.putExtra("phase", phase)
            intent.putExtra("current", current)
            intent.putExtra("total", total)
            intent.putExtra("indeterminate", indeterminate)
            intent.putExtra("activeCount", activeCount)
        }

        companion object {
            fun fromIntent(intent: Intent?) = Arguments(
                uploadId = intent?.getStringExtra("uploadId").orEmpty(),
                projectName = intent?.getStringExtra("projectName").orEmpty().ifBlank { "projeto" },
                repositoryFullName = intent?.getStringExtra("repositoryFullName").orEmpty(),
                phase = intent?.getStringExtra("phase").orEmpty(),
                current = intent?.getIntExtra("current", 0) ?: 0,
                total = intent?.getIntExtra("total", 0) ?: 0,
                indeterminate = intent?.getBooleanExtra("indeterminate", true) ?: true,
                activeCount = intent?.getIntExtra("activeCount", 1) ?: 1,
            )
        }
    }

    companion object {
        private const val CHANNEL_ID = "github_upload_progress"
        private const val NOTIFICATION_ID = 9101
        private const val ACTION_SHOW = "br.com.githubmanager.app.UPLOAD_SHOW"

        fun show(context: Context, arguments: Arguments) {
            val intent = Intent(context, UploadForegroundService::class.java).apply {
                action = ACTION_SHOW
                arguments.putInto(this)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        @Volatile
        private var isRunning = false

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
                // A falta de permissão visual da notificação não interrompe o upload.
            }
        }

        fun stop(context: Context) {
            isRunning = false
            context.stopService(Intent(context, UploadForegroundService::class.java))
        }

        private fun buildNotification(context: Context, arguments: Arguments): Notification {
            val max = arguments.total.coerceAtLeast(0)
            val progress = if (max > 0) arguments.current.coerceIn(0, max) else 0
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle(
                    if (arguments.activeCount > 1) {
                        "${arguments.projectName} • ${arguments.activeCount} envios ativos"
                    } else {
                        "Enviando ${arguments.projectName}"
                    },
                )
                .setContentText(arguments.phase.ifBlank { arguments.repositoryFullName })
                .setSubText(arguments.repositoryFullName)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setContentIntent(openAppPendingIntent(context))
                .setProgress(
                    max,
                    progress,
                    arguments.indeterminate || max <= 0,
                )
                .build()
        }

        private fun openAppPendingIntent(context: Context): PendingIntent {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getActivity(context, 9102, launch, flags)
        }
    }
}
