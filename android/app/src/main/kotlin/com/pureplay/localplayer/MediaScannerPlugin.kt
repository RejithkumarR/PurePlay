package com.pureplay.localplayer

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

class MediaScannerPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel =
        MethodChannel(
            messenger,
            "com.pureplay.localplayer/media_scanner"
        )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "scanMedia" -> {
                try {
                    result.success(scanMedia())
                } catch (e: Exception) {
                    result.error(
                        "MEDIA_SCAN_ERROR",
                        e.message,
                        null
                    )
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun scanMedia(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()

        scanVideos(results)
        scanAudio(results)

        return results
    }

    private fun scanVideos(
        results: MutableList<Map<String, Any?>>
    ) {
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(
                    MediaStore.VOLUME_EXTERNAL
                )
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }

        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.RELATIVE_PATH,
            MediaStore.Video.Media.DATA
        )

        val sortOrder =
            "${MediaStore.Video.Media.DATE_MODIFIED} DESC"

        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            sortOrder
        )?.use { cursor ->

            val idColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Video.Media._ID
                )

            val nameColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Video.Media.DISPLAY_NAME
                )

            val sizeColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Video.Media.SIZE
                )

            val modifiedColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Video.Media.DATE_MODIFIED
                )

            val relativePathColumn =
                cursor.getColumnIndex(
                    MediaStore.Video.Media.RELATIVE_PATH
                )

            val dataColumn =
                cursor.getColumnIndex(
                    MediaStore.Video.Media.DATA
                )

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)

                val name =
                    cursor.getString(nameColumn)
                        ?: "Unknown video"

                val size =
                    cursor.getLong(sizeColumn)

                val modified =
                    cursor.getLong(modifiedColumn) * 1000L

                val relativePath =
                    if (relativePathColumn >= 0) {
                        cursor.getString(relativePathColumn)
                    } else {
                        null
                    }

                val path =
                    if (dataColumn >= 0) {
                        cursor.getString(dataColumn)
                    } else {
                        null
                    }

                val uri =
                    ContentUris.withAppendedId(
                        collection,
                        id
                    )

                results.add(
                    createMediaItem(
                        uri = uri,
                        path = path,
                        name = name,
                        size = size,
                        modified = modified,
                        relativePath = relativePath,
                        type = "video"
                    )
                )
            }
        }
    }

    private fun scanAudio(
        results: MutableList<Map<String, Any?>>
    ) {
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(
                    MediaStore.VOLUME_EXTERNAL
                )
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.RELATIVE_PATH,
            MediaStore.Audio.Media.DATA
        )

        val sortOrder =
            "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            sortOrder
        )?.use { cursor ->

            val idColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media._ID
                )

            val nameColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.DISPLAY_NAME
                )

            val sizeColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.SIZE
                )

            val modifiedColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.DATE_MODIFIED
                )

            val relativePathColumn =
                cursor.getColumnIndex(
                    MediaStore.Audio.Media.RELATIVE_PATH
                )

            val dataColumn =
                cursor.getColumnIndex(
                    MediaStore.Audio.Media.DATA
                )

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)

                val name =
                    cursor.getString(nameColumn)
                        ?: "Unknown audio"

                val size =
                    cursor.getLong(sizeColumn)

                val modified =
                    cursor.getLong(modifiedColumn) * 1000L

                val relativePath =
                    if (relativePathColumn >= 0) {
                        cursor.getString(relativePathColumn)
                    } else {
                        null
                    }

                val path =
                    if (dataColumn >= 0) {
                        cursor.getString(dataColumn)
                    } else {
                        null
                    }

                val uri =
                    ContentUris.withAppendedId(
                        collection,
                        id
                    )

                results.add(
                    createMediaItem(
                        uri = uri,
                        path = path,
                        name = name,
                        size = size,
                        modified = modified,
                        relativePath = relativePath,
                        type = "audio"
                    )
                )
            }
        }
    }

    private fun createMediaItem(
        uri: Uri,
        path: String?,
        name: String,
        size: Long,
        modified: Long,
        relativePath: String?,
        type: String
    ): Map<String, Any?> {

        val folderName =
            relativePath
                ?.trimEnd('/')
                ?.split('/')
                ?.lastOrNull()
                ?.takeIf { it.isNotBlank() }
                ?: "Internal storage"

        return mapOf(
            "uri" to uri.toString(),
            "path" to (path ?: ""),
            "title" to name,
            "folderName" to folderName,
            "size" to size,
            "modified" to modified,
            "type" to type
        )
    }
}