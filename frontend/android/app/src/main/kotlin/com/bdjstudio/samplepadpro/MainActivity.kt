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
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("settings_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val STORAGE_REQUEST_CODE = 4103
    }

    /**
     * Verdadero si la app tiene permiso para acceder a los audios del dispositivo.
     * En Android 13+ (API 33+) consulta READ_MEDIA_AUDIO.
     * En Android 6 a 12 (API 23 a 32) consulta READ_EXTERNAL_STORAGE.
     * En versiones anteriores (API < 23) los permisos se otorgan en la instalación.
     */
    private fun isDirectStorageAccessGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_AUDIO,
            ) == PackageManager.PERMISSION_GRANTED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_EXTERNAL_STORAGE,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Solicita los permisos adecuados según la versión de Android:
     * - Android 13+ (API 33+): READ_MEDIA_AUDIO
     * - Android 10 a 12 (API 29 a 32): READ_EXTERNAL_STORAGE
     * - Android 9 y anteriores (API <= 28): READ_EXTERNAL_STORAGE + WRITE_EXTERNAL_STORAGE
     */
    private fun requestDirectStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_MEDIA_AUDIO),
                STORAGE_REQUEST_CODE,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val permissions = if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                )
            } else {
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            ActivityCompat.requestPermissions(
                this,
                permissions,
                STORAGE_REQUEST_CODE,
            )
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        safExecutor.shutdown()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
