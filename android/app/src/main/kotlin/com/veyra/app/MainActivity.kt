package com.veyra.app

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportSourcePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Apply before Flutter renders its first frame so launch, screenshots,
        // screen sharing, and the task snapshot never expose vault content.
        enableGlobalScreenProtection()
        super.onCreate(savedInstanceState)
        disableRecentsScreenshotsWhenSupported()
    }

    override fun onResume() {
        super.onResume()
        // Reassert protection in case an OEM or activity recreation changed it.
        enableGlobalScreenProtection()
        disableRecentsScreenshotsWhenSupported()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.veyra.app/screen_security",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    enableGlobalScreenProtection()
                    result.success(null)
                }
                "disableSecure" -> {
                    // Protection is application-wide and cannot be disabled by
                    // a viewer leaving the navigation stack.
                    enableGlobalScreenProtection()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.veyra.app/file_export",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingExportResult != null) {
                result.error("export_in_progress", "Another export is active.", null)
                return@setMethodCallHandler
            }
            val sourcePath = call.argument<String>("sourcePath")
            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                result.error("invalid_export", "Missing export arguments.", null)
                return@setMethodCallHandler
            }
            val source = File(sourcePath)
            val appRoot = applicationContext.filesDir.parentFile?.canonicalFile
            val canonicalSource = source.canonicalFile
            val isInsideAppStorage = appRoot != null &&
                canonicalSource.path.startsWith(appRoot.path + File.separator)
            if (!source.exists() || !isInsideAppStorage) {
                result.error("invalid_export", "Invalid export source.", null)
                return@setMethodCallHandler
            }
            pendingExportResult = result
            pendingExportSourcePath = canonicalSource.path
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, File(fileName).name)
            }
            startActivityForResult(intent, EXPORT_FILE_REQUEST_CODE)
        }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != EXPORT_FILE_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingExportResult
        val sourcePath = pendingExportSourcePath
        pendingExportResult = null
        pendingExportSourcePath = null
        if (result == null || sourcePath == null) {
            return
        }
        val destination = data?.data
        if (resultCode != Activity.RESULT_OK || destination == null) {
            result.success(null)
            return
        }
        thread(name = "veyra-file-export") {
            try {
                val source = File(sourcePath)
                var bytesWritten = 0L
                contentResolver.openOutputStream(destination, "w").use { output ->
                    requireNotNull(output) { "Unable to open export destination." }
                    source.inputStream().use { input ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                            bytesWritten += count
                        }
                    }
                    output.flush()
                }
                check(bytesWritten == source.length()) { "Incomplete export." }
                runOnUiThread {
                    result.success(
                        mapOf(
                            "uri" to destination.toString(),
                            "bytesWritten" to bytesWritten,
                        ),
                    )
                }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("export_failed", error.message, null)
                }
            }
        }
    }

    private fun enableGlobalScreenProtection() {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun disableRecentsScreenshotsWhenSupported() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    private companion object {
        const val EXPORT_FILE_REQUEST_CODE = 9102
    }
}
