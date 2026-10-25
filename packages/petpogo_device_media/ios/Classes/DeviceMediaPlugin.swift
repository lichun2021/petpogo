import Flutter
import UIKit
@preconcurrency import AVFoundation
import AudioToolbox

public class DeviceMediaPlugin: NSObject, FlutterPlugin {
    private let audioQueue = DispatchQueue(label: "petpogo.device.pcm")
    private let exportQueue = DispatchQueue(label: "petpogo.device.export", qos: .userInitiated)
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var buffered = 0
    private var audioGeneration = 0
    private var interruption: NSObjectProtocol?
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = DeviceMediaPlugin()
        let channel = FlutterMethodChannel(name: "petpogo/device_media", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "encodeRecording", let manifest = call.arguments as? String {
            exportQueue.async {
                do { let path = try Mp4Exporter.export(manifest); DispatchQueue.main.async { result(path) } }
                catch { DispatchQueue.main.async { result(FlutterError(code: "EXPORT_FAILED", message: error.localizedDescription, details: nil)) } }
            }
            return
        }
        audioQueue.async {
            do {
                switch call.method {
                case "openAudio": try self.openAudio()
                case "closeAudio": self.closeAudio()
                case "setVolume": self.player?.volume = Float((call.arguments as? NSNumber)?.doubleValue ?? 1)
                case "feedAudio":
                    if let bytes = call.arguments as? FlutterStandardTypedData { self.feed(bytes.data) }
                default: DispatchQueue.main.async { result(FlutterMethodNotImplemented) }; return
                }
                DispatchQueue.main.async { result(nil) }
            } catch { DispatchQueue.main.async { result(FlutterError(code: "DEVICE_MEDIA", message: error.localizedDescription, details: nil)) } }
        }
    }
    private func openAudio() throws {
        closeAudio()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredSampleRate(16000)
        try session.setActive(true)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare(); try engine.start(); player.play()
        self.engine = engine; self.player = player
    }
    private func feed(_ data: Data) {
        guard let player = player, let engine = engine else { return }
        if !engine.isRunning { try? engine.start(); player.play() }
        let count = data.count / 2
        guard count > 0, let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        if buffered + count > 4800 { player.stop(); player.play(); buffered = 0; audioGeneration += 1 }
        buffer.frameLength = AVAudioFrameCount(count)
        data.withUnsafeBytes { raw in
            guard let bytes = raw.baseAddress?.assumingMemoryBound(to: UInt8.self), let output = buffer.floatChannelData?[0] else { return }
            for index in 0..<count {
                let bits = UInt16(bytes[index * 2]) | UInt16(bytes[index * 2 + 1]) << 8
                output[index] = Float(Int16(bitPattern: bits)) / 32768
            }
        }
        let generation = audioGeneration
        buffered += count
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.audioQueue.async { [weak self] in
                guard let self = self, self.audioGeneration == generation else { return }
                self.buffered = max(0, self.buffered - count)
            }
        }
    }
    private func closeAudio() {
        audioGeneration += 1; player?.stop(); engine?.stop()
        player = nil; engine = nil; buffered = 0
        // 与 record 共用会话；不在麦克风尚未释放时强制停用系统音频会话。
    }
    deinit { if let interruption = interruption { NotificationCenter.default.removeObserver(interruption) } }
}

private enum MediaExportError: LocalizedError {
    case failed(String)
    var errorDescription: String? { if case .failed(let message) = self { return message }; return nil }
}
private enum Mp4Exporter {
    static func export(_ manifestPath: String) throws -> String {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: manifestPath))) as? [String: Any]
        guard let manifest = json, let frames = manifest["frames"] as? [[String: Any]], !frames.isEmpty,
              let firstPath = frames[0]["path"] as? String,
              let first = UIImage(contentsOfFile: firstPath)?.cgImage,
              let output = manifest["outputPath"] as? String,
              let duration = manifest["durationUs"] as? NSNumber,
              let audioPath = manifest["audioPath"] as? String else { throw MediaExportError.failed("录像素材无效") }
        let scale = min(1.0, 1280.0 / Double(max(first.width, first.height)))
        let width = max(2, Int(Double(first.width) * scale) / 2 * 2)
        let height = max(2, Int(Double(first.height) * scale) / 2 * 2)
        let url = URL(fileURLWithPath: output)
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(400000, min(width * height * 5, 6000000))]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(video) else { throw MediaExportError.failed("设备不支持视频编码") }
        writer.add(video)
        let pcm = try Data(contentsOf: URL(fileURLWithPath: audioPath))
        let audio: AVAssetWriterInput? = pcm.isEmpty ? nil : AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000
        ])
        if let audio = audio {
            guard writer.canAdd(audio) else { throw MediaExportError.failed("设备不支持音频编码") }
            writer.add(audio)
        }
        guard writer.startWriting() else { throw writer.error ?? MediaExportError.failed("无法开始录像编码") }
        writer.startSession(atSourceTime: .zero)
        let group = DispatchGroup()
        let errorLock = NSLock()
        var failure: Error?
        func fail(_ error: Error) { errorLock.lock(); failure = error; errorLock.unlock() }
        func ready(_ input: AVAssetWriterInput) throws {
            var waited = 0
            while !input.isReadyForMoreMediaData {
                if writer.status != .writing { throw writer.error ?? MediaExportError.failed("录像编码中断") }
                Thread.sleep(forTimeInterval: 0.005); waited += 1
                if waited > 6000 { throw MediaExportError.failed("录像编码超时") }
            }
        }
        group.enter()
        DispatchQueue(label: "petpogo.export.video").async {
            defer { if writer.status == .writing { video.markAsFinished() }; group.leave() }
            do {
                var previous: Int64 = -1
                for frame in frames {
                    try ready(video)
                    try autoreleasepool {
                        guard let path = frame["path"] as? String, let image = UIImage(contentsOfFile: path)?.cgImage,
                              let timestamp = frame["timeUs"] as? NSNumber, let pool = adaptor.pixelBufferPool else {
                            throw MediaExportError.failed("读取录像画面失败")
                        }
                        var storage: CVPixelBuffer?
                        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &storage) == kCVReturnSuccess,
                              let buffer = storage else { throw MediaExportError.failed("无法分配录像缓冲") }
                        CVPixelBufferLockBaseAddress(buffer, [])
                        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
                        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                            throw MediaExportError.failed("无法解码录像画面")
                        }
                        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                        let time = max(previous + 1, timestamp.int64Value); previous = time
                        guard adaptor.append(buffer, withPresentationTime: CMTime(value: time, timescale: 1000000)) else {
                            throw writer.error ?? MediaExportError.failed("写入录像画面失败")
                        }
                    }
                }
            } catch { fail(error); writer.cancelWriting() }
        }
        if let audio = audio {
            group.enter()
            DispatchQueue(label: "petpogo.export.audio").async {
                defer { if writer.status == .writing { audio.markAsFinished() }; group.leave() }
                do {
                    var description = AudioStreamBasicDescription(mSampleRate: 16000, mFormatID: kAudioFormatLinearPCM,
                        mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                        mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
                    var format: CMAudioFormatDescription?
                    guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0,
                        layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format) == noErr,
                        let format = format else { throw MediaExportError.failed("PCM 格式无效") }
                    let total = Int(duration.int64Value * 16000 / 1000000) * 2
                    var offset = 0
                    while offset < total {
                        try ready(audio)
                        let count = min(2048, total - offset)
                        var chunk = Data(count: count)
                        if offset < pcm.count { chunk.replaceSubrange(0..<min(count, pcm.count - offset), with: pcm[offset..<min(offset + count, pcm.count)]) }
                        var block: CMBlockBuffer?
                        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: count,
                            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: count,
                            flags: 0, blockBufferOut: &block) == kCMBlockBufferNoErr, let block = block else {
                            throw MediaExportError.failed("无法分配音频缓冲")
                        }
                        let status = chunk.withUnsafeBytes { raw in CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: count) }
                        guard status == noErr else { throw MediaExportError.failed("无法写入音频缓冲") }
                        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 16000),
                            presentationTimeStamp: CMTime(value: Int64(offset / 2), timescale: 16000), decodeTimeStamp: .invalid)
                        var sample: CMSampleBuffer?; var sampleSize = 2
                        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
                            sampleCount: count / 2, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sample) == noErr,
                            let sample = sample, audio.append(sample) else {
                            throw writer.error ?? MediaExportError.failed("写入录像声音失败")
                        }
                        offset += count
                    }
                } catch { fail(error); writer.cancelWriting() }
            }
        }
        group.wait()
        errorLock.lock(); let error = failure; errorLock.unlock()
        if let error = error { try? FileManager.default.removeItem(at: url); throw error }
        writer.endSession(atSourceTime: CMTime(value: duration.int64Value, timescale: 1000000))
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }; done.wait()
        guard writer.status == .completed else { throw writer.error ?? MediaExportError.failed("录像合成失败") }
        return output
    }
}
