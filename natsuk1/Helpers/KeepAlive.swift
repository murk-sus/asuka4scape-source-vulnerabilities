import AVFoundation
import Foundation

final class KeepAlive {
    static let shared = KeepAlive()
    private var player: AVAudioPlayer?
    private var active = false

    private init() {}

    var isActive: Bool { active }

    func start() {
        guard !active else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let wav = Self.silentWavData()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("keepalive.wav")
            try wav.write(to: url)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.0
            p.prepareToPlay()
            p.play()
            player = p
            active = true
        } catch {
            NSLog("[KeepAlive] start failed: \(error)")
            active = false
        }
    }

    func stop() {
        guard active else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        active = false
    }

    private static func silentWavData() -> Data {
        let sampleRate: UInt32 = 8000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let durationSec: UInt32 = 1
        let numSamples = sampleRate * durationSec
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataSize = numSamples * UInt32(blockAlign)

        var d = Data()
        func u32(_ v: UInt32) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
        }
        func u16(_ v: UInt16) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
        }
        func str(_ s: String) { d.append(contentsOf: Array(s.utf8)) }

        str("RIFF"); u32(36 + dataSize); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(channels)
        u32(sampleRate); u32(byteRate); u16(blockAlign); u16(bitsPerSample)
        str("data"); u32(dataSize)
        d.append(Data(repeating: 0, count: Int(dataSize)))
        return d
    }
}
