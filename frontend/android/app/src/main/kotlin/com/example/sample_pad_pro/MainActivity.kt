package com.bdjstudio.samplepadpro

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val safExecutor = Executors.newSingleThreadExecutor()

    companion object {
        private const val LEGACY_READ_REQUEST_CODE = 4103
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SecurityPlugin.registerWith(flutterEngine, this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bdj_studio/background_audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, PerformanceAudioService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, PerformanceAudioService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Import de carpetas vía SAF (Scoped Storage): enumera el árbol del
        // picker y copia los audios al cache interno preservando la jerarquía.
        val safChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bdj_studio/saf_import",
        )
        safChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "copyTreeToCache" -> {
                    val treeUri = call.argument<String>("treeUri")
                    val destName = call.argument<String>("destName") ?: "import"
                    if (treeUri.isNullOrEmpty()) {
                        result.error("bad_args", "treeUri requerido", null)
                        return@setMethodCallHandler
                    }
                    // La enumeración SAF puede tardar con carpetas grandes:
                    // se ejecuta fuera del main thread y el resultado vuelve al principal.
                    safExecutor.execute {
                        try {
                            val payload = SafTreeImporter.copyTreeToCache(
                                applicationContext,
                                Uri.parse(treeUri),
                                destName,
                            ) { copied ->
                                mainHandler.post { safChannel.invokeMethod("onProgress", copied) }
                            }
                            mainHandler.post { result.success(payload.toString()) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("copy_failed", e.message ?: "Error copiando carpeta", null)
                            }
                        }
                    }
                }
                "cleanup" -> {
                    val dir = call.argument<String>("dir")
                    if (!dir.isNullOrEmpty()) SafTreeImporter.cleanup(dir)
                    result.success(null)
                }
                "isAllFilesAccessGranted" -> result.success(isDirectStorageAccessGranted())
                "requestAllFilesAccess" -> {
                    try {
                        requestDirectStorageAccess()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("request_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Verdadero si la app puede leer almacenamiento compartido con File I/O
     * directo (dart:io): All-Files-Access en Android 11+, o el permiso
     * READ_EXTERNAL_STORAGE concedido en versiones anteriores.
     */
    private fun isDirectStorageAccessGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_EXTERNAL_STORAGE,
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    /** Abre ajustes (11+) o pide el permiso runtime (10-) para lectura completa. */
    private fun requestDirectStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ),
                )
            } catch (_: Exception) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                LEGACY_READ_REQUEST_CODE,
            )
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        safExecutor.shutdown()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
