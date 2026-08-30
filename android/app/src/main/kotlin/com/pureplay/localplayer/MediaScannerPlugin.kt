package com.pureplay.localplayer

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MediaScannerPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(
        messenger,
        "com.pureplay.localplayer/media_scanner"
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "scanMedia" -> result.success(scanMedia())
                "renameMedia" -> result.success(renameMedia(call))
                "deleteMedia" -> result.success(deleteMedia(call))
                "moveMedia" -> result.success(moveMedia(call))
                "copyMedia" -> result.success(copyMedia(call))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("MEDIA_OPERATION_ERROR", e.message ?: "Media operation failed", null)
        }
    }

    private fun scanMedia(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        scanVideos(results)
        scanAudio(results)
        return results
    }

    private fun scanVideos(results: MutableList<Map<String, Any?>>) {
        val collection = videoCollection()
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.RELATIVE_PATH,
            MediaStore.Video.Media.DATA
        )
        queryMedia(collection, projection, MediaStore.Video.Media.DATE_MODIFIED, "video", results)
    }

    private fun scanAudio(results: MutableList<Map<String, Any?>>) {
        val collection = audioCollection()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.RELATIVE_PATH,
            MediaStore.Audio.Media.DATA
        )
        queryMedia(collection, projection, MediaStore.Audio.Media.DATE_MODIFIED, "audio", results)
    }

    private fun queryMedia(
        collection: Uri,
        projection: Array<String>,
        modifiedColumn: String,
        type: String,
        results: MutableList<Map<String, Any?>>
    ) {
        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            "$modifiedColumn DESC"
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val modifiedIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            val relativePathColumn = cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
            val dataColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val name = cursor.getString(nameColumn) ?: "Unknown"
                val size = cursor.getLong(sizeColumn)
                val modified = cursor.getLong(modifiedIndex) * 1000L
                val relativePath = if (relativePathColumn >= 0) cursor.getString(relativePathColumn) else null
                val path = if (dataColumn >= 0) cursor.getString(dataColumn) else null
                val uri = ContentUris.withAppendedId(collection, id)
                val folderName = relativePath?.trimEnd('/')?.split('/')?.lastOrNull()
                    ?.takeIf { it.isNotBlank() } ?: "Internal storage"

                results.add(
                    mapOf(
                        "uri" to uri.toString(),
                        "path" to (path ?: ""),
                        "title" to name,
                        "folderName" to folderName,
                        "relativePath" to (relativePath ?: ""),
                        "size" to size,
                        "modified" to modified,
                        "type" to type
                    )
                )
            }
        }
    }

    private fun renameMedia(call: MethodCall): Boolean {
        val uri = parseUri(call)
        val name = requireString(call, "name")
        require(name.isNotBlank()) { "File name cannot be empty" }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name.trim())
        }
        return context.contentResolver.update(uri, values, null, null) > 0
    }

    private fun deleteMedia(call: MethodCall): Boolean {
        val uri = parseUri(call)
        return context.contentResolver.delete(uri, null, null) > 0
    }

    private fun moveMedia(call: MethodCall): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("Moving media requires Android 10 or newer")
        }
        val uri = parseUri(call)
        val relativePath = normalizeRelativePath(requireString(call, "relativePath"))
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
        }
        return context.contentResolver.update(uri, values, null, null) > 0
    }

    private fun copyMedia(call: MethodCall): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("Copying media requires Android 10 or newer")
        }
        val source = parseUri(call)
        val destinationPath = normalizeRelativePath(requireString(call, "relativePath"))
        val requestedName = call.argument<String>("name")?.trim()
        val name = requestedName?.takeIf { it.isNotEmpty() } ?: queryDisplayName(source)
        val mime = context.contentResolver.getType(source) ?: "application/octet-stream"
        val collection = if (mime.startsWith("audio/")) audioCollection() else videoCollection()

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, destinationPath)
        }

        val destination = context.contentResolver.insert(collection, values)
            ?: throw IOException("Unable to create destination media file")

        try {
            val input = context.contentResolver.openInputStream(source)
                ?: throw IOException("Unable to read source media file")
            val output = context.contentResolver.openOutputStream(destination)
                ?: throw IOException("Unable to write destination media file")
            input.use { sourceStream ->
                output.use { destinationStream ->
                    sourceStream.copyTo(destinationStream)
                }
            }
            context.contentResolver.update(
                destination,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null
            )
            return true
        } catch (e: Exception) {
            context.contentResolver.delete(destination, null, null)
            throw e
        }
    }

    private fun queryDisplayName(uri: Uri): String {
        context.contentResolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0) ?: "Copied media"
        }
        return "Copied media"
    }

    private fun parseUri(call: MethodCall): Uri {
        return Uri.parse(requireString(call, "uri"))
    }

    private fun requireString(call: MethodCall, key: String): String {
        return call.argument<String>(key)?.trim()
            ?: throw IllegalArgumentException("Missing $key")
    }

    private fun normalizeRelativePath(path: String): String {
        val normalized = path.replace('\\', '/').trim('/')
        require(normalized.isNotEmpty()) { "Destination folder cannot be empty" }
        return "$normalized/"
    }

    private fun videoCollection(): Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
    } else {
        MediaStore.Video.Media.EXTERNAL_CONTENT_URI
    }

    private fun audioCollection(): Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
    } else {
        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
    }
}
