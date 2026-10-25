package com.creativeease.ce_tailor_rentals

import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.tts.TextToSpeech
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.Locale

class MainActivity : FlutterFragmentActivity(), TextToSpeech.OnInitListener {
    private lateinit var speechChannel: MethodChannel
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var ttsInitializationError: Pair<String, String>? = null
    private var pendingSpeech: Triple<String, String, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.creativeease.ce_tailor_rentals/text_to_speech",
        )
        speechChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")?.trim()
                    val locale = call.argument<String>("locale")?.trim().orEmpty()
                    if (text.isNullOrEmpty()) {
                        result.error("empty_text", "Speech text cannot be empty.", null)
                    } else if (ttsInitializationError != null) {
                        val (code, message) = ttsInitializationError!!
                        result.error(code, message, null)
                    } else if (ttsReady) {
                        speak(text, locale.ifEmpty { "en-US" }, result)
                    } else {
                        pendingSpeech?.third?.error(
                            "speech_replaced",
                            "A pending speech reply was replaced.",
                            null,
                        )
                        pendingSpeech = Triple(text, locale.ifEmpty { "en-US" }, result)
                    }
                }
                "stop" -> {
                    pendingSpeech?.third?.success(null)
                    pendingSpeech = null
                    textToSpeech?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val reportShareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.creativeease.ce_tailor_rentals/report_share",
        )
        reportShareChannel.setMethodCallHandler { call, result ->
            if (call.method != "sharePdf") {
                result.notImplemented()
            } else {
                shareReportPdf(call, result)
            }
        }
        textToSpeech = TextToSpeech(this, this)
    }

    private fun shareReportPdf(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.size < 5 ||
            !bytes.copyOfRange(0, 5).contentEquals("%PDF-".toByteArray())
        ) {
            result.error("invalid_pdf", "The report PDF is invalid.", null)
            return
        }

        val requestedName = call.argument<String>("filename").orEmpty()
        val safeName = requestedName
            .replace(Regex("[^A-Za-z0-9._-]"), "-")
            .take(100)
            .let { if (it.endsWith(".pdf", ignoreCase = true)) it else "$it.pdf" }
        val shareDirectory = File(cacheDir, "report_share")
        if (!shareDirectory.exists() && !shareDirectory.mkdirs()) {
            result.error("share_storage_unavailable", "Could not prepare the report for sharing.", null)
            return
        }
        val reportFile = File(shareDirectory, "${System.currentTimeMillis()}-$safeName")
        try {
            reportFile.writeBytes(bytes)
        } catch (error: IOException) {
            result.error("share_file_write_failed", error.message, null)
            return
        }

        val reportUri = try {
            FileProvider.getUriForFile(
                this,
                "$packageName.report.share",
                reportFile,
            )
        } catch (error: IllegalArgumentException) {
            result.error("share_file_provider_failed", error.message, null)
            return
        }

        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, reportUri)
            putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("title"))
            putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(Intent.createChooser(sendIntent, call.argument<String>("title")))
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("share_target_unavailable", error.message, null)
        }
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) {
            ttsInitializationError = "tts_initialization_failed" to
                "Android text-to-speech could not be initialized."
            pendingSpeech?.third?.error(
                ttsInitializationError!!.first,
                ttsInitializationError!!.second,
                null,
            )
            pendingSpeech = null
            return
        }

        if (textToSpeech == null) return
        ttsReady = true
        pendingSpeech?.let { (text, locale, result) ->
            pendingSpeech = null
            speak(text, locale, result)
        }
    }

    private fun speak(text: String, languageTag: String, result: MethodChannel.Result) {
        val engine = textToSpeech
        val languageStatus = engine?.setLanguage(Locale.forLanguageTag(languageTag))
        if (languageStatus == TextToSpeech.LANG_MISSING_DATA ||
            languageStatus == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            result.error(
                "tts_language_unavailable",
                "Text-to-speech voice data is unavailable for $languageTag.",
                null,
            )
            return
        }
        val status = engine?.speak(
            text,
            TextToSpeech.QUEUE_FLUSH,
            null,
            "assistant_reply",
        )
        if (status == TextToSpeech.SUCCESS) {
            result.success(null)
        } else {
            result.error(
                "tts_speak_failed",
                "Android text-to-speech could not speak the reply.",
                null,
            )
        }
    }

    override fun onDestroy() {
        pendingSpeech?.third?.success(null)
        pendingSpeech = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
