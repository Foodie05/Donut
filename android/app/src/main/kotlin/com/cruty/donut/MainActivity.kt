package com.cruty.donut

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var fileOpenChannel: MethodChannel? = null
    private var pendingPath: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileOpenChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "donut/file_open"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialFile" -> {
                        result.success(pendingPath)
                        pendingPath = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        val cached = pendingPath
        if (cached != null) {
            fileOpenChannel?.invokeMethod("openFile", cached)
            pendingPath = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val path = uriToImportablePath(uri) ?: return
        dispatchPath(path)
    }

    private fun dispatchPath(path: String) {
        if (fileOpenChannel == null) {
            pendingPath = path
        } else {
            fileOpenChannel?.invokeMethod("openFile", path)
        }
    }

    private fun uriToImportablePath(uri: Uri): String? {
        return when (uri.scheme?.lowercase()) {
            "file" -> {
                val path = uri.path ?: return null
                if (isSupported(path)) path else null
            }
            "content" -> {
                val ext = resolveExtension(uri) ?: return null
                if (ext != "pdf" && ext != "dpdf") return null
                val outFile = File(cacheDir, "external_import_${System.currentTimeMillis()}.$ext")
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                } ?: return null
                outFile.absolutePath
            }
            else -> null
        }
    }

    private fun resolveExtension(uri: Uri): String? {
        val displayName = queryDisplayName(uri)
        if (displayName != null) {
            val dotIndex = displayName.lastIndexOf('.')
            if (dotIndex > 0 && dotIndex < displayName.length - 1) {
                return displayName.substring(dotIndex + 1).lowercase()
            }
        }

        val mime = contentResolver.getType(uri)?.lowercase()
        return when (mime) {
            "application/pdf" -> "pdf"
            "application/x-dpdf" -> "dpdf"
            else -> null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } finally {
            cursor?.close()
        }
    }

    private fun isSupported(path: String): Boolean {
        val lower = path.lowercase()
        return lower.endsWith(".pdf") || lower.endsWith(".dpdf")
    }
}
