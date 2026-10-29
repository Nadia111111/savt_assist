package com.savt.savt_control_panel

import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.savt.savt_control_panel/downloads"

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "file_${System.currentTimeMillis()}"
                    val bytes = call.argument<ByteArray>("bytes")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

                    if (bytes == null) {
                        result.error("INVALID_ARGS", "Bytes cannot be null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val savedLocation = saveFileToPublicDownloads(fileName, bytes, mimeType)
                        result.success(savedLocation)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.localizedMessage ?: "Unknown error saving to Downloads", null)
                    }
                }
                "getClipboardImage" -> {
                    try {
                        val clipboardData = getClipboardImage()
                        result.success(clipboardData)
                    } catch (e: Exception) {
                        result.error("CLIPBOARD_FAILED", e.localizedMessage ?: "Failed to read clipboard", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getClipboardImage(): Map<String, Any?>? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return null
        if (!clipboard.hasPrimaryClip()) return null
        val clip = clipboard.primaryClip ?: return null
        if (clip.itemCount == 0) return null

        val item = clip.getItemAt(0)
        val uri = item.uri ?: return null
        val resolver = applicationContext.contentResolver
        val mimeType = resolver.getType(uri) ?: (if (clip.description.hasMimeType("image/*")) clip.description.getMimeType(0) else "image/png")

        if (!mimeType.startsWith("image/")) {
            return null
        }

        return try {
            resolver.openInputStream(uri)?.use { inputStream ->
                val bytes = inputStream.readBytes()
                var fileName = "clipboard_image_${System.currentTimeMillis()}"
                val ext = when {
                    mimeType.contains("jpeg") || mimeType.contains("jpg") -> ".jpg"
                    mimeType.contains("webp") -> ".webp"
                    mimeType.contains("gif") -> ".gif"
                    else -> ".png"
                }
                if (!fileName.endsWith(ext)) {
                    fileName += ext
                }
                mapOf(
                    "bytes" to bytes,
                    "mimeType" to mimeType,
                    "fileName" to fileName
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun saveFileToPublicDownloads(fileName: String, bytes: ByteArray, mimeType: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Не удалось создать запись в MediaStore.Downloads")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            } ?: throw Exception("Не удалось открыть поток записи в MediaStore")

            uri.toString()
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val targetFile = File(downloadsDir, fileName)
            FileOutputStream(targetFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }
            targetFile.absolutePath
        }
    }
}
