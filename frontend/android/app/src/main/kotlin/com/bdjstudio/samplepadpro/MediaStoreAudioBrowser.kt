package com.bdjstudio.samplepadpro

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.io.FileOutputStream

object MediaStoreAudioBrowser {

    private const val TAG = "BDJ_MediaStore"

    private val AUDIO_EXTS = hashSetOf(
        "wav", "mp3", "flac", "ogg", "aac", "m4a",
        "aiff", "aif", "wma", "opus", "webm",
    )

    private fun normalizeFolderPath(raw: String): String {
        return raw.trim()
            .replace('\\', '/')
            .trim('/')
    }

    private fun getFolderFromData(data: String): String {
        val parent = File(data).parent ?: return ""
        val normalized = parent.replace('\\', '/')
        val prefixes = arrayOf(
            "/storage/emulated/0/",
            "/storage/self/primary/",
            "/sdcard/",
        )
        for (prefix in prefixes) {
            if (normalized.startsWith(prefix, ignoreCase = true)) {
                return normalizeFolderPath(normalized.substring(prefix.length))
            }
        }
        return normalizeFolderPath(normalized.substringAfterLast('/'))
    }

    fun listAudioFolders(context: Context): List<Map<String, Any>> {
        val resolver = context.contentResolver
        val collectionUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.RELATIVE_PATH,
                MediaStore.Audio.Media.VOLUME_NAME,
            )
        } else {
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATA,
            )
        }

        class FolderStats(var count: Int = 0, var totalBytes: Long = 0L, var volume: String = "")
        val folderMap = mutableMapOf<String, FolderStats>()

        try {
            resolver.query(
                collectionUri,
                projection,
                null,
                null,
                null,
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
                val nameIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeIdx = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                val relPathIdx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
                } else -1
                val volIdx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    cursor.getColumnIndex(MediaStore.Audio.Media.VOLUME_NAME)
                } else -1
                val dataIdx = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                } else -1

                while (cursor.moveToNext()) {
                    val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""
                    val dot = name.lastIndexOf('.')
                    if (dot <= 0) continue
                    val ext = name.substring(dot + 1).lowercase()
                    if (!AUDIO_EXTS.contains(ext)) continue

                    val size = if (sizeIdx >= 0) cursor.getLong(sizeIdx) else 0L
                    var folderPath = ""
                    var volume = "external"

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && relPathIdx >= 0) {
                        val rawRel = cursor.getString(relPathIdx) ?: ""
                        folderPath = normalizeFolderPath(rawRel)
                        if (volIdx >= 0) {
                            volume = cursor.getString(volIdx) ?: "external"
                        }
                    } else if (dataIdx >= 0) {
                        val rawData = cursor.getString(dataIdx) ?: ""
                        folderPath = getFolderFromData(rawData)
                    }

                    if (folderPath.isEmpty()) {
                        folderPath = "Audio"
                    }

                    val stats = folderMap.getOrPut(folderPath) { FolderStats(volume = volume) }
                    stats.count++
                    stats.totalBytes += size
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error consultando MediaStore: $e")
        }

        return folderMap.map { (path, stats) ->
            mapOf(
                "path" to path,
                "volume" to stats.volume,
                "count" to stats.count,
                "totalBytes" to stats.totalBytes,
            )
        }.sortedBy { (it["path"] as String).lowercase() }
    }

    fun listAudioFiles(
        context: Context,
        folderPath: String,
        recursive: Boolean,
    ): List<Map<String, Any>> {
        val resolver = context.contentResolver
        val collectionUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.RELATIVE_PATH,
            )
        } else {
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATA,
            )
        }

        val normalizedTarget = normalizeFolderPath(folderPath).lowercase()
        val resultList = mutableListOf<Map<String, Any>>()

        try {
            resolver.query(
                collectionUri,
                projection,
                null,
                null,
                null,
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
                val nameIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeIdx = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                val relPathIdx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
                } else -1
                val dataIdx = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                } else -1

                while (cursor.moveToNext()) {
                    val id = if (idIdx >= 0) cursor.getLong(idIdx) else continue
                    val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else continue
                    val dot = name.lastIndexOf('.')
                    if (dot <= 0) continue
                    val ext = name.substring(dot + 1).lowercase()
                    if (!AUDIO_EXTS.contains(ext)) continue

                    val size = if (sizeIdx >= 0) cursor.getLong(sizeIdx) else 0L

                    var currentFolder = ""
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && relPathIdx >= 0) {
                        currentFolder = normalizeFolderPath(cursor.getString(relPathIdx) ?: "")
                    } else if (dataIdx >= 0) {
                        currentFolder = getFolderFromData(cursor.getString(dataIdx) ?: "")
                    }

                    val currentNorm = currentFolder.lowercase()
                    val matches = if (recursive) {
                        currentNorm == normalizedTarget || currentNorm.startsWith("$normalizedTarget/")
                    } else {
                        currentNorm == normalizedTarget
                    }

                    if (!matches) continue

                    // Calcular ruta relativa respecto a folderPath
                    val relativeSubPath = if (currentNorm == normalizedTarget) {
                        ""
                    } else {
                        currentFolder.substring(folderPath.length).trim('/')
                    }

                    val contentUri = ContentUris.withAppendedId(collectionUri, id)

                    resultList.add(
                        mapOf(
                            "uri" to contentUri.toString(),
                            "name" to name,
                            "relativeSubPath" to relativeSubPath,
                            "size" to size,
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error listando archivos en MediaStore: $e")
        }

        return resultList.sortedWith(
            compareBy(
                { (it["relativeSubPath"] as String).lowercase() },
                { (it["name"] as String).lowercase() },
            )
        )
    }

    fun copyAudioFiles(
        context: Context,
        items: List<Map<String, Any>>,
        destDir: String,
        onProgress: (Int) -> Unit,
    ): List<Map<String, String>> {
        val destDirectory = File(destDir)
        if (!destDirectory.exists() && !destDirectory.mkdirs()) {
            throw IllegalStateException("No se pudo crear el directorio de destino: $destDir")
        }

        // Comprobar espacio antes de iniciar la copia
        var totalBytes = 0L
        for (item in items) {
            val s = (item["size"] as? Number)?.toLong() ?: 0L
            if (s > 0) totalBytes += s
        }

        val stat = StatFs(destDirectory.absolutePath)
        val availableBytes = stat.availableBytes
        val baseMargin = 200L * 1024L * 1024L // 200 MB
        val tenPercentMargin = (totalBytes * 0.10).toLong()
        val safetyMargin = maxOf(baseMargin, tenPercentMargin)
        val requiredBytes = totalBytes + safetyMargin

        if (totalBytes > 0 && availableBytes < requiredBytes) {
            val neededMb = requiredBytes / (1024 * 1024)
            val availableMb = availableBytes / (1024 * 1024)
            throw IllegalStateException(
                "Necesitas $neededMb MB libres para importar esta carpeta; tienes $availableMb MB."
            )
        }

        val copiedFiles = mutableListOf<Map<String, String>>()
        val resolver = context.contentResolver
        var count = 0

        for (item in items) {
            val uriStr = item["uri"] as? String ?: continue
            val originalName = item["name"] as? String ?: continue
            val relSub = (item["relativeSubPath"] as? String ?: "").trim('/')

            val targetParent = if (relSub.isEmpty()) destDirectory else File(destDirectory, relSub)
            if (!targetParent.exists() && !targetParent.mkdirs()) {
                continue
            }

            val sanitizedName = sanitizeName(originalName)
            val outFile = uniqueFile(targetParent, sanitizedName)
            val uri = Uri.parse(uriStr)

            var success = false
            try {
                resolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(outFile).use { output ->
                        val buffer = ByteArray(64 * 1024) // 64 KB buffer
                        var bytesRead: Int
                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            output.write(buffer, 0, bytesRead)
                        }
                        success = true
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Fallo al copiar $uriStr a ${outFile.absolutePath}: $e")
                try {
                    if (outFile.exists()) outFile.delete()
                } catch (_: Exception) {}
            }

            if (success) {
                count++
                val dot = originalName.lastIndexOf('.')
                val cleanName = if (dot > 0) originalName.substring(0, dot) else originalName
                copiedFiles.add(
                    mapOf(
                        "name" to cleanName,
                        "path" to outFile.absolutePath,
                        "relativeSubPath" to relSub,
                    )
                )
                onProgress(count)
            }
        }

        return copiedFiles
    }

    private fun sanitizeName(name: String): String {
        val cleaned = name
            .replace(Regex("[<>:\"/\\\\|?*\u0000]"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
        return if (cleaned.isEmpty()) "_" else cleaned.take(120)
    }

    private fun uniqueFile(dir: File, name: String): File {
        var candidate = File(dir, name)
        if (!candidate.exists()) return candidate
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (candidate.exists()) {
            candidate = File(dir, "${base}_$i$ext")
            i++
        }
        return candidate
    }
}
