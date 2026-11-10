package com.partygame.party_game_app

import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity: FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.fwpt.party_game/tts"
    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            tts = TextToSpeech(applicationContext, this)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat()
                    val rate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                    if (isTtsReady && text.isNotEmpty() && tts != null) {
                        tts?.setPitch(pitch)
                        tts?.setSpeechRate(rate)
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "Dice_${System.currentTimeMillis()}")
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stop" -> {
                    try {
                        tts?.stop()
                    } catch (e: Exception) {}
                    result.success(true)
                }
                "isLanguageAvailable" -> {
                    result.success(isTtsReady)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            try {
                val res = tts?.setLanguage(Locale.CHINESE)
                isTtsReady = (res != TextToSpeech.LANG_MISSING_DATA && res != TextToSpeech.LANG_NOT_SUPPORTED)
                if (!isTtsReady) {
                    val resSimp = tts?.setLanguage(Locale.SIMPLIFIED_CHINESE)
                    isTtsReady = (resSimp != TextToSpeech.LANG_MISSING_DATA && resSimp != TextToSpeech.LANG_NOT_SUPPORTED)
                }
            } catch (e: Exception) {
                isTtsReady = false
            }
        }
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (e: Exception) {}
        super.onDestroy()
    }
}
