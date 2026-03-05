package com.example.photosync

import android.Manifest
import android.content.ContentUris
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.hierynomus.msdtyp.AccessMask
import com.hierynomus.msfscc.FileAttributes
import com.hierynomus.mssmb2.SMBApiException
import com.hierynomus.mssmb2.SMB2CreateDisposition
import com.hierynomus.mssmb2.SMB2CreateOptions
import com.hierynomus.mssmb2.SMB2ShareAccess
import com.hierynomus.smbj.SMBClient
import com.hierynomus.smbj.auth.AuthenticationContext
import com.hierynomus.smbj.share.DiskShare
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private companion object {
        const val MEDIA_CHANNEL = "app.media"
        const val SMB_CHANNEL = "app.smb"
        const val REQ_MEDIA_PERMISSION = 8801
    }

    private lateinit var mediaChannel: MethodChannel
    private lateinit var smbChannel: MethodChannel

    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
        smbChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMB_CHANNEL)

        mediaChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> handleRequestPermission(result)
                "listAssets" -> runIo(result) { handleListAssets(call) }
                "exportToTempFile" -> runIo(result) { handleExportToTempFile(call) }
                "getThumbnail" -> runIo(result) { handleGetThumbnail(call) }
                else -> result.notImplemented()
            }
        }

        smbChannel.setMethodCallHandler { call, result ->
            runIo(result) {
                when (call.method) {
                    "testConnection" -> handleTestConnection(call)
                    "exists" -> handleExists(call)
                    "ensureDir" -> {
                        handleEnsureDir(call)
                        null
                    }

                    "uploadFile" -> {
                        handleUploadFile(call)
                        null
                    }

                    else -> throw UnsupportedOperationException("Unknown method: ${call.method}")
                }
            }
        }
    }

    override fun onDestroy() {
        mediaChannel.setMethodCallHandler(null)
        smbChannel.setMethodCallHandler(null)
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_MEDIA_PERMISSION) return

        val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    private fun handleRequestPermission(result: MethodChannel.Result) {
        if (hasMediaPermission()) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "Permission request already in progress.", null)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, mediaPermissions(), REQ_MEDIA_PERMISSION)
    }

    private fun hasMediaPermission(): Boolean {
        return mediaPermissions().all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun mediaPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun handleListAssets(call: MethodCall): Map<String, Any?> {
        val startTimeMs = call.argument<Number>("startTimeMs")?.toLong() ?: 0L
        val limit = (call.argument<Number>("limit")?.toInt() ?: 200).coerceAtLeast(1)
        val offset = (call.argument<String>("cursor")?.toIntOrNull() ?: 0).coerceAtLeast(0)
        val ascending = call.argument<Boolean>("ascending") ?: true

        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.MIME_TYPE,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_TAKEN,
            MediaStore.Files.FileColumns.WIDTH,
            MediaStore.Files.FileColumns.HEIGHT,
            MediaStore.Files.FileColumns.DURATION,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )

        val selection = "${MediaStore.Files.FileColumns.DATE_TAKEN} >= ? AND " +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?)"
        val args = arrayOf(
            startTimeMs.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )

        val order = if (ascending) "ASC" else "DESC"
        val sort = "${MediaStore.Files.FileColumns.DATE_TAKEN} $order, " +
            "${MediaStore.Files.FileColumns._ID} $order"

        val items = mutableListOf<Map<String, Any?>>()
        var hasMore = false

        val uri = MediaStore.Files.getContentUri("external")
        contentResolver.query(uri, projection, selection, args, sort)?.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val mimeIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateTakenIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_TAKEN)
            val widthIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.WIDTH)
            val heightIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.HEIGHT)
            val durationIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DURATION)
            val mediaTypeIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)

            var skipped = 0
            while (cursor.moveToNext()) {
                if (skipped < offset) {
                    skipped++
                    continue
                }
                if (items.size >= limit) {
                    hasMore = true
                    break
                }

                val id = cursor.getLong(idIdx)
                val mediaType = cursor.getInt(mediaTypeIdx)
                val itemUri = when (mediaType) {
                    MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE ->
                        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)

                    MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
                        ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)

                    else -> ContentUris.withAppendedId(uri, id)
                }

                val item = mapOf(
                    "id" to id.toString(),
                    "uri" to itemUri.toString(),
                    "fileName" to cursor.getString(nameIdx),
                    "mimeType" to (cursor.getString(mimeIdx) ?: "application/octet-stream"),
                    "fileSize" to cursor.getLong(sizeIdx),
                    "dateTakenMs" to cursor.getLong(dateTakenIdx),
                    "width" to cursor.getInt(widthIdx),
                    "height" to cursor.getInt(heightIdx),
                    "durationMs" to cursor.getLong(durationIdx),
                    "mediaType" to if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) "video" else "image",
                )
                items.add(item)
            }
        }

        return mapOf(
            "items" to items,
            "nextCursor" to if (hasMore) (offset + items.size).toString() else null,
            "hasMore" to hasMore,
        )
    }

    private fun handleExportToTempFile(call: MethodCall): Map<String, Any?> {
        val assetId = call.argument<String>("assetId")?.trim().orEmpty()
        if (assetId.isEmpty()) {
            throw IllegalArgumentException("assetId is required")
        }

        val id = assetId.toLongOrNull()
            ?: throw IllegalArgumentException("assetId must be a numeric MediaStore id")

        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.MIME_TYPE,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )

        val queryUri = MediaStore.Files.getContentUri("external")
        var fileName = "asset_$id"
        var mimeType = "application/octet-stream"
        var mediaType = MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE

        contentResolver.query(
            queryUri,
            projection,
            "${MediaStore.Files.FileColumns._ID} = ?",
            arrayOf(id.toString()),
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) {
                throw IllegalArgumentException("assetId not found")
            }
            val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val mimeIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            val typeIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)

            fileName = cursor.getString(nameIdx) ?: fileName
            mimeType = cursor.getString(mimeIdx) ?: mimeType
            mediaType = cursor.getInt(typeIdx)
        } ?: throw IllegalArgumentException("assetId not found")

        val contentUri = when (mediaType) {
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
                ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)

            else -> ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        }

        val safeName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val tmpDir = File(cacheDir, "media_export").apply { mkdirs() }
        val outFile = File(tmpDir, "${id}_$safeName")

        contentResolver.openInputStream(contentUri)?.use { input ->
            FileOutputStream(outFile).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                }
            }
        } ?: throw IllegalStateException("Failed to open input stream for asset")

        return mapOf(
            "localPath" to outFile.absolutePath,
            "fileName" to fileName,
            "mimeType" to mimeType,
            "fileSize" to outFile.length(),
        )
    }

    private fun handleTestConnection(call: MethodCall): Boolean {
        return withDiskShare(call) { _, _, share, cfg ->
            val baseDir = cfg.baseDir.trim('/').takeIf { it.isNotEmpty() }
            if (baseDir == null) {
                true
            } else {
                share.folderExists(baseDir) || share.fileExists(baseDir)
            }
        }
    }

    private fun handleExists(call: MethodCall): Boolean {
        val remotePath = call.argument<String>("remotePath")?.trim().orEmpty()
        if (remotePath.isEmpty()) {
            throw IllegalArgumentException("remotePath is required")
        }

        return withDiskShare(call) { _, _, share, cfg ->
            val fullPath = buildRemotePath(cfg.baseDir, remotePath)
            share.fileExists(fullPath) || share.folderExists(fullPath)
        }
    }

    private fun handleGetThumbnail(call: MethodCall): ByteArray {
        val assetId = call.argument<String>("assetId")?.trim().orEmpty()
        if (assetId.isEmpty()) {
            throw IllegalArgumentException("assetId is required")
        }
        val id = assetId.toLongOrNull()
            ?: throw IllegalArgumentException("assetId must be a numeric MediaStore id")
        val width = (call.argument<Number>("width")?.toInt() ?: 256).coerceAtLeast(32)
        val height = (call.argument<Number>("height")?.toInt() ?: 256).coerceAtLeast(32)

        val contentUri = resolveAssetContentUri(id)
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentResolver.loadThumbnail(contentUri, Size(width, height), null)
        } else {
            contentResolver.openInputStream(contentUri)?.use { input ->
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeStream(input, null, options)
                val sampleSize = computeInSampleSize(options.outWidth, options.outHeight, width, height)

                contentResolver.openInputStream(contentUri)?.use { input2 ->
                    BitmapFactory.decodeStream(
                        input2,
                        null,
                        BitmapFactory.Options().apply { inSampleSize = sampleSize },
                    )
                }
            }
        } ?: throw IllegalStateException("Failed to decode thumbnail")

        ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
            return output.toByteArray()
        }
    }

    private fun resolveAssetContentUri(id: Long): Uri {
        val queryUri = MediaStore.Files.getContentUri("external")
        contentResolver.query(
            queryUri,
            arrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE),
            "${MediaStore.Files.FileColumns._ID} = ?",
            arrayOf(id.toString()),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE))
                return when (type) {
                    MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
                        ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)

                    else -> ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                }
            }
        }
        throw IllegalArgumentException("assetId not found")
    }

    private fun computeInSampleSize(
        srcWidth: Int,
        srcHeight: Int,
        reqWidth: Int,
        reqHeight: Int,
    ): Int {
        var sample = 1
        var width = srcWidth
        var height = srcHeight
        while (width / 2 >= reqWidth && height / 2 >= reqHeight) {
            width /= 2
            height /= 2
            sample *= 2
        }
        return sample.coerceAtLeast(1)
    }

    private fun handleEnsureDir(call: MethodCall) {
        val remoteDir = call.argument<String>("remoteDir")?.trim().orEmpty()
        if (remoteDir.isEmpty()) {
            throw IllegalArgumentException("remoteDir is required")
        }

        withDiskShare(call) { _, _, share, cfg ->
            ensureDirectoryExists(share, buildRemotePath(cfg.baseDir, remoteDir))
            Unit
        }
    }

    private fun handleUploadFile(call: MethodCall) {
        val localPath = call.argument<String>("localPath")?.trim().orEmpty()
        val remotePath = call.argument<String>("remotePath")?.trim().orEmpty()
        val overwrite = call.argument<Boolean>("overwrite") ?: true
        val createParentDirs = call.argument<Boolean>("createParentDirs") ?: true
        val chunkSize = (call.argument<Number>("chunkSize")?.toInt() ?: 256 * 1024).coerceAtLeast(8 * 1024)

        if (localPath.isEmpty()) throw IllegalArgumentException("localPath is required")
        if (remotePath.isEmpty()) throw IllegalArgumentException("remotePath is required")

        val localFile = File(localPath)
        if (!localFile.exists() || !localFile.isFile) {
            throw IllegalArgumentException("localPath not found: $localPath")
        }

        withDiskShare(call) { _, _, share, cfg ->
            val fullRemotePath = buildRemotePath(cfg.baseDir, remotePath)
            val parent = fullRemotePath.substringBeforeLast('\\', "")
            if (createParentDirs && parent.isNotEmpty()) {
                ensureDirectoryExists(share, parent)
            }

            val disposition = if (overwrite) {
                SMB2CreateDisposition.FILE_OVERWRITE_IF
            } else {
                SMB2CreateDisposition.FILE_CREATE
            }

            share.openFile(
                fullRemotePath,
                setOf(AccessMask.FILE_WRITE_DATA, AccessMask.GENERIC_WRITE),
                setOf(FileAttributes.FILE_ATTRIBUTE_NORMAL),
                setOf(SMB2ShareAccess.FILE_SHARE_READ),
                disposition,
                setOf(SMB2CreateOptions.FILE_NON_DIRECTORY_FILE),
            ).use { smbFile ->
                FileInputStream(localFile).use { input ->
                    smbFile.outputStream.use { output ->
                        val buffer = ByteArray(chunkSize)
                        while (true) {
                            val n = input.read(buffer)
                            if (n <= 0) break
                            output.write(buffer, 0, n)
                        }
                        output.flush()
                    }
                }
            }
            Unit
        }
    }

    private fun ensureDirectoryExists(share: DiskShare, dirPath: String) {
        val normalized = dirPath.trim('\\', '/').replace('/', '\\')
        if (normalized.isEmpty()) return

        val segments = normalized.split('\\').filter { it.isNotBlank() }
        var current = ""
        for (segment in segments) {
            current = if (current.isEmpty()) segment else "$current\\$segment"
            if (!share.folderExists(current)) {
                share.mkdir(current)
            }
        }
    }

    private data class SmbConfig(
        val host: String,
        val port: Int,
        val share: String,
        val username: String,
        val password: String,
        val domain: String,
        val baseDir: String,
    )

    @Suppress("UNCHECKED_CAST")
    private fun parseSmbConfig(call: MethodCall): SmbConfig {
        val config = call.argument<Map<String, Any?>>("config")
            ?: throw IllegalArgumentException("config is required")

        val host = (config["host"] as? String)?.trim().orEmpty()
        val rawShare = (config["share"] as? String)?.trim().orEmpty()
        val username = (config["username"] as? String)?.trim().orEmpty()
        val password = (config["password"] as? String).orEmpty()
        val domain = ((config["domain"] as? String) ?: "").trim()
        val baseDir = ((config["baseDir"] as? String) ?: "").trim()
        val port = ((config["port"] as? Number)?.toInt() ?: 445)

        val shareParts = rawShare
            .trim('\\', '/')
            .replace('\\', '/')
            .split('/')
            .filter { it.isNotBlank() }
        val share = shareParts.firstOrNull().orEmpty()
        val shareSubPath = if (shareParts.size > 1) {
            shareParts.drop(1).joinToString("/")
        } else {
            ""
        }
        val mergedBaseDir = joinPathParts(shareSubPath, baseDir)

        if (host.isEmpty()) throw IllegalArgumentException("config.host is required")
        if (share.isEmpty()) {
            throw IllegalArgumentException("config.share is required (example: public)")
        }

        return SmbConfig(host, port, share, username, password, domain, mergedBaseDir)
    }

    private fun buildRemotePath(baseDir: String, relative: String): String {
        val cleanBase = baseDir.trim().trim('\\', '/').replace('/', '\\')
        val cleanRelative = relative.trim().trim('\\', '/').replace('/', '\\')

        return when {
            cleanBase.isEmpty() -> cleanRelative
            cleanRelative.isEmpty() -> cleanBase
            else -> "$cleanBase\\$cleanRelative"
        }
    }

    private fun joinPathParts(first: String, second: String): String {
        val parts = listOf(first, second)
            .flatMap { it.trim().trim('\\', '/').replace('\\', '/').split('/') }
            .filter { it.isNotBlank() }
        return parts.joinToString("/")
    }

    private fun <T> withDiskShare(call: MethodCall, block: (SMBClient, com.hierynomus.smbj.connection.Connection, DiskShare, SmbConfig) -> T): T {
        val cfg = parseSmbConfig(call)

        val client = SMBClient()
        client.use { smbClient ->
            smbClient.connect(cfg.host, cfg.port).use { connection ->
                val auth = AuthenticationContext(cfg.username, cfg.password.toCharArray(), cfg.domain)
                connection.authenticate(auth).use { session ->
                    val share = try {
                        session.connectShare(cfg.share)
                    } catch (e: SMBApiException) {
                        val status = e.status?.name ?: ""
                        if (status == "STATUS_BAD_NETWORK_NAME") {
                            throw IllegalArgumentException(
                                "SMB share '${cfg.share}' not found on ${cfg.host}. " +
                                    "Use share name only (e.g. public), without / or \\\\."
                            )
                        }
                        throw e
                    }
                    if (share !is DiskShare) {
                        share.close()
                        throw IllegalStateException("Share '${cfg.share}' is not a disk share")
                    }
                    share.use { diskShare ->
                        return block(smbClient, connection, diskShare, cfg)
                    }
                }
            }
        }
    }

    private fun <T> runIo(result: MethodChannel.Result, action: () -> T) {
        ioExecutor.execute {
            try {
                val value = action()
                mainHandler.post { result.success(value) }
            } catch (e: UnsupportedOperationException) {
                mainHandler.post { result.notImplemented() }
            } catch (e: IllegalArgumentException) {
                mainHandler.post { result.error("INVALID_ARGUMENT", e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("NATIVE_ERROR", e.message, e.stackTraceToString()) }
            }
        }
    }
}
