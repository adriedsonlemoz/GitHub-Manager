package br.com.githubmanager.app

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var pendingStoragePermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.githubmanager.app/platform",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUri" -> openUri(
                    rawUri = call.argument<String>("uri"),
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                "openFile" -> openFile(
                    location = call.argument<String>("path"),
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                "installApk" -> installApk(
                    location = call.argument<String>("path"),
                    result = result,
                )
                "shareFile" -> shareFile(
                    location = call.argument<String>("path"),
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                "publishToDownloads" -> publishToDownloads(
                    sourcePath = call.argument<String>("sourcePath"),
                    fileName = call.argument<String>("fileName"),
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                "requestLegacyDownloadsPermission" -> requestLegacyDownloadsPermission(result)
                "deletePublishedDownload" -> deletePublishedDownload(
                    location = call.argument<String>("location"),
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun openUri(rawUri: String?, mimeType: String?, result: MethodChannel.Result) {
        if (rawUri.isNullOrBlank()) {
            result.error("URI_REQUIRED", "URI inválida", null)
            return
        }
        try {
            val uri = Uri.parse(rawUri)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                if (mimeType.isNullOrBlank()) {
                    data = uri
                } else {
                    setDataAndType(uri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("OPEN_URI_FAILED", error.message, null)
        }
    }

    private fun openFile(location: String?, mimeType: String?, result: MethodChannel.Result) {
        if (location.isNullOrBlank()) {
            result.error("FILE_REQUIRED", "Arquivo inválido", null)
            return
        }
        try {
            val uri = resolveShareUri(location)
            val resolvedMime = mimeType ?: contentResolver.getType(uri) ?: "application/octet-stream"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, resolvedMime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("OPEN_FILE_FAILED", error.message, null)
        }
    }

    private fun shareFile(location: String?, mimeType: String?, result: MethodChannel.Result) {
        if (location.isNullOrBlank()) {
            result.error("FILE_REQUIRED", "Arquivo inválido", null)
            return
        }
        try {
            val uri = resolveShareUri(location)
            val resolvedMime = mimeType ?: contentResolver.getType(uri) ?: "application/octet-stream"
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = resolvedMime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Compartilhar arquivo"))
            result.success(null)
        } catch (error: Exception) {
            result.error("SHARE_FILE_FAILED", error.message, null)
        }
    }

    private fun installApk(location: String?, result: MethodChannel.Result) {
        if (location.isNullOrBlank()) {
            result.error("APK_REQUIRED", "APK inválido", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                val settingsIntent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                )
                startActivity(settingsIntent)
                result.success("permission_required")
                return
            }
            val uri = resolveShareUri(location)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success("launched")
        } catch (error: Exception) {
            result.error("INSTALL_APK_FAILED", error.message, null)
        }
    }

    private fun publishToDownloads(
        sourcePath: String?,
        fileName: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
            result.error("DOWNLOAD_ARGUMENTS_REQUIRED", "Arquivo de download inválido", null)
            return
        }
        val source = File(sourcePath)
        if (!source.exists()) {
            result.error("DOWNLOAD_SOURCE_NOT_FOUND", "Arquivo temporário não encontrado", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType ?: "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Não foi possível criar o arquivo em Downloads")
                try {
                    contentResolver.openOutputStream(uri, "w").use { output ->
                        requireNotNull(output) { "Não foi possível abrir Downloads para escrita" }
                        FileInputStream(source).use { input -> input.copyTo(output) }
                    }
                    val completed = ContentValues().apply {
                        put(MediaStore.MediaColumns.IS_PENDING, 0)
                    }
                    contentResolver.update(uri, completed, null, null)
                    result.success(uri.toString())
                } catch (error: Exception) {
                    contentResolver.delete(uri, null, null)
                    throw error
                }
                return
            }

            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                result.error(
                    "STORAGE_PERMISSION_REQUIRED",
                    "Permissão para salvar na pasta Downloads é necessária neste Android.",
                    null,
                )
                return
            }

            @Suppress("DEPRECATION")
            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloads.exists()) {
                downloads.mkdirs()
            }
            val target = uniqueLegacyFile(downloads, fileName)
            FileInputStream(source).use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            }
            result.success(target.absolutePath)
        } catch (error: Exception) {
            val message = error.message.orEmpty()
            val storageFull = message.contains("ENOSPC", ignoreCase = true) ||
                message.contains("No space left", ignoreCase = true)
            result.error(
                if (storageFull) "STORAGE_FULL" else "DOWNLOAD_PUBLISH_FAILED",
                error.message,
                null,
            )
        }
    }

    private fun requestLegacyDownloadsPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            result.success(true)
            return
        }
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingStoragePermissionResult != null) {
            result.error("PERMISSION_REQUEST_ACTIVE", "Já existe um pedido de permissão em andamento", null)
            return
        }
        pendingStoragePermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            STORAGE_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == STORAGE_PERMISSION_REQUEST) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingStoragePermissionResult?.success(granted)
            pendingStoragePermissionResult = null
        }
    }

    private fun deletePublishedDownload(location: String?, result: MethodChannel.Result) {
        if (location.isNullOrBlank()) {
            result.success(null)
            return
        }
        try {
            if (location.startsWith("content://")) {
                contentResolver.delete(Uri.parse(location), null, null)
            } else {
                val file = File(location)
                if (file.exists()) {
                    file.delete()
                }
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("DELETE_DOWNLOAD_FAILED", error.message, null)
        }
    }

    private fun resolveShareUri(location: String): Uri {
        if (location.startsWith("content://")) {
            return Uri.parse(location)
        }
        val file = File(location)
        if (!file.exists()) {
            throw IllegalArgumentException("Arquivo não encontrado")
        }
        return FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
    }

    private fun uniqueLegacyFile(directory: File, requestedName: String): File {
        var target = File(directory, requestedName)
        if (!target.exists()) {
            return target
        }
        val dot = requestedName.lastIndexOf('.')
        val stem = if (dot > 0) requestedName.substring(0, dot) else requestedName
        val extension = if (dot > 0) requestedName.substring(dot) else ""
        var index = 2
        while (target.exists()) {
            target = File(directory, "$stem-$index$extension")
            index++
        }
        return target
    }

    companion object {
        private const val STORAGE_PERMISSION_REQUEST = 7012
    }
}
