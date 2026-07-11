package dev.younghwan.geunyang_reader

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingFile: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingFile = resolveIntentFile(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "geunyang/native")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    result.success(pendingFile)
                    pendingFile = null
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("ARG", "path required", null)
                    } else {
                        installApk(path)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val path = resolveIntentFile(intent) ?: return
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("openFile", path)
        } else {
            pendingFile = path
        }
    }

    /** VIEW 인텐트의 content:// 파일을 캐시로 복사하고 경로를 돌려준다. */
    private fun resolveIntentFile(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri: Uri = intent.data ?: return null
        return try {
            when (uri.scheme) {
                "file" -> uri.path
                "content" -> {
                    var name = "document"
                    contentResolver.query(uri, null, null, null, null)?.use { c ->
                        val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0 && c.moveToFirst()) name = c.getString(idx) ?: name
                    }
                    name = name.replace(Regex("[/\\\\:*?\"<>|]"), "_")
                    val dir = File(cacheDir, "opened").apply { mkdirs() }
                    val out = File(dir, name)
                    contentResolver.openInputStream(uri)?.use { input ->
                        out.outputStream().use { input.copyTo(it) }
                    } ?: return null
                    out.absolutePath
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun installApk(path: String) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
        val install = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(install)
    }
}
