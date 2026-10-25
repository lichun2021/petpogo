package com.junxin.device_media

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.*
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.util.ArrayDeque
import java.util.concurrent.Executors

class DeviceMediaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val main = Handler(Looper.getMainLooper())
    private val exportWorker = Executors.newSingleThreadExecutor()
    private val lock = Object()
    private val pending = ArrayDeque<ByteArray>()
    private var queuedBytes = 0
    @Volatile private var track: AudioTrack? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "petpogo/device_media")
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        closeAudio(); channel.setMethodCallHandler(null); exportWorker.shutdown()
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "openAudio" -> { openAudio(); result.success(null) }
                "closeAudio" -> { closeAudio(); result.success(null) }
                "setVolume" -> { track?.setVolume((call.arguments as Number).toFloat()); result.success(null) }
                "feedAudio" -> {
                    val bytes = call.arguments as ByteArray
                    synchronized(lock) {
                        if (track != null && bytes.isNotEmpty()) {
                            val chunk = if (bytes.size > 9600) bytes.copyOfRange(bytes.size - 9600, bytes.size) else bytes
                            while (queuedBytes + chunk.size > 9600 && pending.isNotEmpty()) queuedBytes -= pending.removeFirst().size
                            pending.addLast(chunk); queuedBytes += chunk.size; lock.notifyAll()
                        }
                    }
                    result.success(null)
                }
                "encodeRecording" -> {
                    val path = call.arguments as String
                    exportWorker.execute {
                        try { val output = Mp4Exporter.export(path); main.post { result.success(output) } }
                        catch (e: Exception) { main.post { result.error("EXPORT_FAILED", e.message, null) } }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) { result.error("DEVICE_MEDIA", e.message, null) }
    }
    private fun openAudio() {
        closeAudio()
        val player = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setAudioFormat(AudioFormat.Builder().setSampleRate(16000).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(maxOf(6400, AudioTrack.getMinBufferSize(16000, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT))).build()
        check(player.state == AudioTrack.STATE_INITIALIZED) { "音频输出初始化失败" }
        track = player; player.play()
        Thread({
            try {
                while (track === player) {
                    val bytes = synchronized(lock) {
                        while (pending.isEmpty() && track === player) lock.wait()
                        if (track !== player) null else pending.removeFirst().also { queuedBytes -= it.size }
                    } ?: break
                    var offset = 0
                    while (offset < bytes.size && track === player) {
                        val count = player.write(bytes, offset, bytes.size - offset, AudioTrack.WRITE_BLOCKING)
                        if (count <= 0) break
                        offset += count
                    }
                }
            } catch (_: Exception) { /* 关闭时中断阻塞播放。 */ }
        }, "device-pcm").start()
    }
    private fun closeAudio() {
        val previous = track; track = null
        synchronized(lock) { pending.clear(); queuedBytes = 0; lock.notifyAll() }
        if (previous != null) { try { previous.pause(); previous.flush() } finally { previous.release() } }
    }
}

/** 输入是本 App 临时目录的 JPEG+PCM 清单，全部编码在工作线程执行。 */
private object Mp4Exporter {
    private class Encoder(val codec: MediaCodec, path: String) {
        val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        var track = -1
        fun drain(end: Boolean = false) {
            val info = MediaCodec.BufferInfo()
            var idle = 0
            while (true) {
                val index = codec.dequeueOutputBuffer(info, if (end) 10000 else 0)
                if (index == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (!end) return
                    check(++idle < 500) { "视频编码超时" }; continue
                }
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    check(!started); track = muxer.addTrack(codec.outputFormat); muxer.start(); started = true
                } else if (index >= 0) {
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0) {
                        check(started); val buffer = codec.getOutputBuffer(index)!!
                        buffer.position(info.offset); buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    val done = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(index, false)
                    if (done) return
                }
            }
        }
        fun input(): Int {
            repeat(500) { val index = codec.dequeueInputBuffer(10000); if (index >= 0) return index; drain() }
            error("编码器输入超时")
        }
        fun finish(time: Long) { codec.queueInputBuffer(input(), 0, 0, time, MediaCodec.BUFFER_FLAG_END_OF_STREAM); drain(true) }
        fun close() {
            try { codec.stop() } finally { codec.release() }
            try { if (started) muxer.stop() } finally { muxer.release() }
        }
    }
    fun export(manifestPath: String): String {
        val manifest = JSONObject(File(manifestPath).readText())
        val frames = manifest.getJSONArray("frames"); check(frames.length() > 0) { "没有录像画面" }
        val duration = manifest.getLong("durationUs")
        val output = File(manifest.getString("outputPath"))
        val video = File(output.parentFile, "video.tmp.mp4")
        val audio = File(output.parentFile, "audio.tmp.m4a")
        try {
            val size = BitmapFactory.Options().also { it.inJustDecodeBounds = true }
            BitmapFactory.decodeFile(frames.getJSONObject(0).getString("path"), size)
            check(size.outWidth > 0 && size.outHeight > 0) { "JPEG 格式无效" }
            val scale = minOf(1.0, 1280.0 / maxOf(size.outWidth, size.outHeight))
            val width = ((size.outWidth * scale).toInt() / 2 * 2).coerceAtLeast(2)
            val height = ((size.outHeight * scale).toInt() / 2 * 2).coerceAtLeast(2)
            val codec = MediaCodec.createEncoderByType("video/avc")
            val format = MediaFormat.createVideoFormat("video/avc", width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
                setInteger(MediaFormat.KEY_BIT_RATE, (width * height * 5).coerceIn(400000, 6000000))
                setInteger(MediaFormat.KEY_FRAME_RATE, 10); setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE); codec.start()
            val encoder = Encoder(codec, video.path)
            try {
                var previousTime = -1L
                for (i in 0 until frames.length()) {
                    val frame = frames.getJSONObject(i)
                    val original = BitmapFactory.decodeFile(frame.getString("path")) ?: error("读取画面失败")
                    val bitmap = Bitmap.createScaledBitmap(original, width, height, true)
                    val index = encoder.input()
                    val image = codec.getInputImage(index) ?: error("设备编码器不支持 YUV 图像输入")
                    val pixels = IntArray(width * height); bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
                    val planes = image.planes
                    for (y in 0 until height) for (x in 0 until width) {
                        val color = pixels[y * width + x]; val r = color shr 16 and 255; val g = color shr 8 and 255; val b = color and 255
                        planes[0].buffer.put(y * planes[0].rowStride + x * planes[0].pixelStride, (((66*r + 129*g + 25*b + 128) shr 8) + 16).coerceIn(0,255).toByte())
                        if (x % 2 == 0 && y % 2 == 0) {
                            planes[1].buffer.put(y/2 * planes[1].rowStride + x/2 * planes[1].pixelStride, (((-38*r - 74*g + 112*b + 128) shr 8) + 128).coerceIn(0,255).toByte())
                            planes[2].buffer.put(y/2 * planes[2].rowStride + x/2 * planes[2].pixelStride, (((112*r - 94*g - 18*b + 128) shr 8) + 128).coerceIn(0,255).toByte())
                        }
                    }
                    val time = maxOf(previousTime + 1, frame.getLong("timeUs")); previousTime = time
                    codec.queueInputBuffer(index, 0, width * height * 3 / 2, time, 0)
                    if (bitmap !== original) bitmap.recycle(); original.recycle(); encoder.drain()
                }
                encoder.finish(maxOf(duration, previousTime + 1))
            } finally { encoder.close() }
            val pcm = File(manifest.getString("audioPath"))
            val inputs = mutableListOf(video)
            if (pcm.exists() && pcm.length() > 0) {
                encodeAudio(pcm, audio, duration); inputs.add(audio)
            }
            merge(inputs, output)
            return output.path
        } catch (e: Exception) { output.delete(); throw e }
        finally { video.delete(); audio.delete() }
    }
    private fun encodeAudio(pcm: File, output: File, duration: Long) {
        val codec = MediaCodec.createEncoderByType("audio/mp4a-latm")
        val format = MediaFormat.createAudioFormat("audio/mp4a-latm", 16000, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 64000); setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 8192)
        }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE); codec.start()
        val encoder = Encoder(codec, output.path)
        try {
            FileInputStream(pcm).use { source ->
                val total = duration * 16000 / 1000000 * 2
                var sent = 0L
                while (sent < total) {
                    val index = encoder.input(); val input = codec.getInputBuffer(index)!!; input.clear()
                    val count = minOf(input.remaining().toLong(), total - sent).toInt() / 2 * 2
                    val bytes = ByteArray(count); var read = 0
                    while (read < count) { val n = source.read(bytes, read, count - read); if (n < 0) break; read += n }
                    input.put(bytes)
                    codec.queueInputBuffer(index, 0, count, sent / 2 * 1000000 / 16000, 0)
                    sent += count; encoder.drain()
                }
                encoder.finish(duration)
            }
        } finally { encoder.close() }
    }
    private fun merge(inputs: List<File>, output: File) {
        val readers = inputs.map { file -> MediaExtractor().also { it.setDataSource(file.path); it.selectTrack(0) } }
        val muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        try {
            val tracks = readers.map { muxer.addTrack(it.getTrackFormat(0)) }; muxer.start(); started = true
            val data = ByteBuffer.allocate(4 * 1024 * 1024); val info = MediaCodec.BufferInfo()
            while (true) {
                val index = readers.indices.filter { readers[it].sampleTime >= 0 }.minByOrNull { readers[it].sampleTime } ?: break
                val reader = readers[index]; data.clear(); val count = reader.readSampleData(data, 0); if (count < 0) break
                info.set(0, count, reader.sampleTime, reader.sampleFlags)
                muxer.writeSampleData(tracks[index], data, info); reader.advance()
            }
        } finally { readers.forEach { it.release() }; try { if (started) muxer.stop() } finally { muxer.release() } }
    }
}
