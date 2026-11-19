package com.bikrito.bikrito

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val whatsappChannel = "com.bikrito.bikrito/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, whatsappChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendImageToWhatsApp" -> {
                        val filePath = call.argument<String>("filePath")
                        val phone = call.argument<String>("phone")
                        val text = call.argument<String>("text")
                        try {
                            sendImageToWhatsApp(filePath, phone, text)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WHATSAPP_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendImageToWhatsApp(filePath: String?, phone: String?, text: String?) {
        if (filePath.isNullOrEmpty()) throw IllegalArgumentException("Missing file path")
        val file = File(filePath)
        if (!file.exists()) throw IllegalArgumentException("File does not exist")

        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/*"
            setPackage("com.whatsapp")
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (!text.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            val digits = phone?.replace(Regex("\\D"), "") ?: ""
            if (digits.isNotEmpty()) putExtra("jid", "$digits@s.whatsapp.net")
        }
        startActivity(intent)
    }
}
