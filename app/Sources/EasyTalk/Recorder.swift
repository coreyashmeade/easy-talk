import AVFoundation

/// Records the microphone into memory as 16 kHz mono floats. Audio is never written to disk (R41)
/// and the mic is only open between start() and stop() (R42).
final class Recorder {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var peakLevel: Float = 0
    private(set) var isRunning = false
    /// Latest input level 0...1 for the pill's sound bars.
    private(set) var level: Float = 0

    static let sampleRate: Double = 16000

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw NSError(domain: "EasyTalk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported microphone format"])
        }
        lock.withLock { samples.removeAll(keepingCapacity: true); peakLevel = 0 }
        input.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let ratio = Self.sampleRate / inFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
            var fed = false
            var err: NSError?
            converter.convert(to: out, error: &err) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            guard err == nil, let ch = out.floatChannelData?[0] else { return }
            let chunk = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
            var sum: Float = 0
            for s in chunk { sum += s * s }
            let rms = chunk.isEmpty ? 0 : (sum / Float(chunk.count)).squareRoot()
            self.lock.withLock {
                self.samples.append(contentsOf: chunk)
                self.peakLevel = max(self.peakLevel, rms)
            }
            self.level = min(1, rms * 12)
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// Stops recording and hands back the audio (and clears it from this object).
    func stop() -> (samples: [Float], peak: Float) {
        guard isRunning else { return ([], 0) }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        level = 0
        return lock.withLock {
            let out = (samples, peakLevel)
            samples = []
            return out
        }
    }

    var elapsed: TimeInterval { lock.withLock { Double(samples.count) / Self.sampleRate } }
}
