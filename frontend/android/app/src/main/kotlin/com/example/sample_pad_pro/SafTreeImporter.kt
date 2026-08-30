package com.bdjstudio.samplepadpro

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * Copia un árbol de carpetas seleccionado con el picker SAF de Android
 * (ACTION_OPEN_DOCUMENT_TREE → content://.../tree/...) al cache interno de
 * la app, preservando la jerarquía completa de subcarpetas.
 *
 * Scoped Storage bloquea Directory.list()/File.copy sobre el almacenamiento
 * compartido, así que la enumeración y lectura se hacen aquí vía
 * DocumentsContract y los audios llegan a Dart como archivos locales normales.
 *
 * Diagnóstico: adb logcat -s BDJ_SAF
 */
object SafTreeImporter {

    private const val TAG = "BDJ_SAF"

    private val AUDIO_EXTS = hashSetOf(
        "wav", "mp3", "flac", "ogg", "aac", "m4a",
        "aiff", "aif", "wma", "opus", "webm",
    )

    /**
     * Enumera [treeUri] recursivamente, copia los audios al cache y devuelve:
     * { "cacheRoot": "<dir temporal>", "tree": nodo raíz }
     * donde cada nodo es { name, path?, files: [{name, path}], subfolders: [nodo] }.
     */
    fun copyTreeToCache(
        context: Context,
        treeUri: Uri,
        destName: String,
        onProgress: (Int) -> Unit,
    ): JSONObject {
        val resolver = context.contentResolver
        val rootDocId = DocumentsContract.getTreeDocumentId(treeUri)
        Log.d(TAG, "copyTreeToCache inicio: treeUri=$treeUri rootDocId=$rootDocId")

        var rootName = rootDocId.substringAfterLast(':', rootDocId)
        try {
            resolver.query(
                DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocId),
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)?.takeIf { it.isNotBlank() }?.let { rootName = it }
                }
            }
        } catch (_: Exception) {
            // Sin nombre visible se usa el docId (primary:MiCarpeta → MiCarpeta).
        }

        val cacheRoot = File(
            context.cacheDir,
            "saf_import_${sanitize(destName)}_${System.currentTimeMillis()}",
        )
        val targetRoot = File(cacheRoot, sanitize(rootName))
        if (!targetRoot.mkdirs() && !targetRoot.isDirectory) {
            throw IllegalStateException("No se pudo crear el directorio temporal de importación")
        }

        val copied = intArrayOf(0)
        val tree = enumerateAndCopy(context, treeUri, rootDocId, targetRoot, copied, onProgress)
        tree.put("name", sanitize(rootName))
        Log.d(TAG, "copyTreeToCache fin: audios copiados=${copied[0]} destino=${cacheRoot.absolutePath}")

        return JSONObject()
            .put("cacheRoot", cacheRoot.absolutePath)
            .put("tree", tree)
    }

    fun cleanup(path: String) {
        try {
            File(path).deleteRecursively()
        } catch (_: Exception) {
        }
    }

    private fun enumerateAndCopy(
        context: Context,
        treeUri: Uri,
        parentDocId: String,
        targetDir: File,
        copied: IntArray,
        onProgress: (Int) -> Unit,
    ): JSONObject {
        val node = JSONObject()
            .put("files", JSONArray())
            .put("subfolders", JSONArray())
        if (!targetDir.exists() && !targetDir.mkdirs()) return node

        // Recolectar las entradas antes de copiar para no sostener el Cursor
        // durante la recursión. Si un nivel no puede listarse (proveedor con
        // permisos parciales), se pierde solo esa rama, no todo el árbol.
        data class Entry(val docId: String, val name: String, val isDir: Boolean)

        val entries = ArrayList<Entry>()
        try {
            context.contentResolver.query(
                DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId),
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val docId = cursor.getString(0) ?: continue
                    val name = cursor.getString(1) ?: continue
                    val mime = cursor.getString(2) ?: ""
                    entries.add(Entry(docId, name, mime == DocumentsContract.Document.MIME_TYPE_DIR))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo listar docId=$parentDocId en ${targetDir.path}: $e")
            return node
        }
        Log.d(TAG, "Nivel ${targetDir.name}: ${entries.size} entrada(s)")

        for ((docId, name, isDir) in entries) {
            if (name.startsWith(".")) continue

            if (isDir) {
                val subDir = File(targetDir, sanitize(name))
                val subNode = enumerateAndCopy(context, treeUri, docId, subDir, copied, onProgress)
                subNode.put("name", sanitize(name))
                node.getJSONArray("subfolders").put(subNode)
                continue
            }

            val dot = name.lastIndexOf('.')
            if (dot <= 0) continue
            val ext = name.substring(dot + 1).lowercase()
            if (!AUDIO_EXTS.contains(ext)) continue

            val outFile = uniqueFile(targetDir, sanitize(name))
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
            var ok = false
            try {
                context.contentResolver.openInputStream(docUri)?.use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                        ok = true
                    }
                }
            } catch (e: SecurityException) {
                throw IllegalStateException("Acceso denegado al archivo: $name", e)
            } catch (_: java.io.IOException) {
                // Archivo ilegible; se omite sin abortar el resto del árbol.
            }

            if (ok) {
                node.getJSONArray("files")
                    .put(JSONObject().put("name", name.substring(0, dot)).put("path", outFile.absolutePath))
                copied[0]++
                if (copied[0] % 5 == 0) onProgress(copied[0])
            }
        }
        return node
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

    private fun sanitize(name: String): String {
        val cleaned = name
            .replace(Regex("[<>:\"/\\\\|?*\u0000]"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
        return if (cleaned.isEmpty()) "_" else cleaned.take(120)
    }
}
