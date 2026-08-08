package com.bdjstudio.samplepadpro

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SecurityPlugin : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL_SECURITY = "com.samplepadpro/security"
        private const val CHANNEL_INTEGRITY = "com.samplepadpro/integrity"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val securityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SECURITY)
            val securityPlugin = SecurityPlugin(context)
            securityChannel.setMethodCallHandler(securityPlugin)

            val integrityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_INTEGRITY)
            integrityChannel.setMethodCallHandler(securityPlugin)
        }
    }

    private val context: Context

    constructor(context: Context) {
        this.context = context
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkSecurity" -> result.success(checkSecurity())
            "checkEmulator" -> result.success(checkEmulator())
            "verifySignature" -> result.success(verifySignature())
            "getLibraryPath" -> result.success(context.applicationInfo.nativeLibraryDir)
            "getBundlePath" -> result.success(context.applicationInfo.sourceDir)
            else -> result.notImplemented()
        }
    }

    private fun checkSecurity(): Map<String, Any> {
        return mapOf(
            "isRooted" to checkRoot(),
            "isDebuggerAttached" to checkDebugger(),
            "isEmulator" to checkEmulator(),
            "isHookingDetected" to checkHooking(),
            "isMagiskDetected" to checkMagisk()
        )
    }

    private fun checkRoot(): Boolean {
        val rootPaths = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/system/sbin/su",
            "/vendor/bin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/app/SuperSU.apk",
            "/system/app/SuperSU"
        )

        for (path in rootPaths) {
            if (File(path).exists()) return true
        }

        try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val exitCode = process.waitFor()
            if (exitCode == 0) return true
        } catch (_: Exception) {}

        try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/bin/which", "su"))
            val exitCode = process.waitFor()
            if (exitCode == 0) return true
        } catch (_: Exception) {}

        try {
            val packageManager = context.packageManager
            packageManager.getPackageInfo("com.topjohnwu.magisk", 0)
            return true
        } catch (_: PackageManager.NameNotFoundException) {}

        return false
    }

    private fun checkDebugger(): Boolean {
        return android.os.Debug.isDebuggerConnected() ||
                isDebuggable()
    }

    private fun isDebuggable(): Boolean {
        return (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    private fun checkEmulator(): Boolean {
        return Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
    }

    private fun checkHooking(): Boolean {
        val suspiciousLibs = listOf(
            "libfrida-gadget.so",
            "libfrida.so",
            "libxposed_art.so",
            "liblspd.so",
            "libmemud.so"
        )

        for (lib in suspiciousLibs) {
            if (File("/data/local/tmp/$lib").exists()) return true
            if (File(context.applicationInfo.nativeLibraryDir + "/$lib").exists()) return true
        }

        try {
            val runtime = Runtime.getRuntime()
            val process = runtime.exec(arrayOf("ps", "-A"))
            val reader = process.inputStream.bufferedReader()
            val output = reader.readText()
            val suspiciousProcesses = listOf("frida", "xposed", "magisk", "supersu")
            for (processName in suspiciousProcesses) {
                if (output.contains(processName)) return true
            }
        } catch (_: Exception) {}

        return false
    }

    private fun checkMagisk(): Boolean {
        val magiskPaths = listOf(
            "/sbin/.magisk",
            "/data/adb/magisk",
            "/data/adb/magisk.img",
            "/data/adb/modules",
            "/cache/.disable_magisk",
            "/dev/kit"
        )

        for (path in magiskPaths) {
            if (File(path).exists()) return true
        }

        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "magisk"))
            val exitCode = process.waitFor()
            if (exitCode == 0) return true
        } catch (_: Exception) {}

        try {
            val packageManager = context.packageManager
            packageManager.getPackageInfo("com.topjohnwu.magisk", 0)
            return true
        } catch (_: PackageManager.NameNotFoundException) {}

        return false
    }

    private fun verifySignature(): Boolean {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES
                )
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures.isNullOrEmpty()) return false

            val cert = signatures[0].toByteArray()
            val md = java.security.MessageDigest.getInstance("SHA-256")
            val digest = md.digest(cert)

            digest.joinToString(":") { "%02X".format(it) }

            true
        } catch (_: Exception) {
            false
        }
    }
}
