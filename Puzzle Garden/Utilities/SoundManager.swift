@preconcurrency import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private var isEngineRunning = false

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        #if targetEnvironment(simulator)
        return
        #else
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isEngineRunning = true
        } catch {
            // Engine setup failed; sounds will be silently skipped
        }
        #endif
    }

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    func playDigMark() {
        guard soundEnabled else { return }
        playTone(frequency: 220, duration: 0.15, amplitude: 0.18)
    }

    func playFlowerPlaced() {
        guard soundEnabled else { return }
        playChime(frequencies: [523.25, 659.25], duration: 0.4, amplitude: 0.22)
    }

    func playSolve() {
        guard soundEnabled else { return }
        playChord(frequencies: [523.25, 659.25, 783.99, 1046.50], duration: 1.2, amplitude: 0.20)
    }

    // MARK: - Synthesis

    private func makePCMBuffer(sampleRate: Double, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        buf?.frameLength = frameCount
        return buf
    }

    private func playTone(frequency: Float, duration: Float, amplitude: Float) {
        guard isEngineRunning else { return }
        let sr: Double = 44100
        let frames = AVAudioFrameCount(sr * Double(duration))
        guard let buffer = makePCMBuffer(sampleRate: sr, frameCount: frames) else { return }
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Float(i) / Float(sr)
            let env = exp(-t * 18) * amplitude
            data[i] = sin(2 * .pi * frequency * t) * env
        }
        scheduleBuffer(buffer)
    }

    private func playChime(frequencies: [Float], duration: Float, amplitude: Float) {
        guard isEngineRunning else { return }
        let sr: Double = 44100
        let frames = AVAudioFrameCount(sr * Double(duration))
        guard let buffer = makePCMBuffer(sampleRate: sr, frameCount: frames) else { return }
        let data = buffer.floatChannelData![0]
        let perFreq = amplitude / Float(frequencies.count)
        for i in 0..<Int(frames) {
            let t = Float(i) / Float(sr)
            let attackEnv: Float = t < 0.015 ? t / 0.015 : 1.0
            let env = attackEnv * exp(-t * 4) * perFreq
            var sample: Float = 0
            for (idx, freq) in frequencies.enumerated() {
                let tAdj = max(0, t - Float(idx) * 0.04)
                sample += sin(2 * .pi * freq * tAdj) * env
            }
            data[i] = sample
        }
        scheduleBuffer(buffer)
    }

    private func playChord(frequencies: [Float], duration: Float, amplitude: Float) {
        guard isEngineRunning else { return }
        let sr: Double = 44100
        let frames = AVAudioFrameCount(sr * Double(duration))
        guard let buffer = makePCMBuffer(sampleRate: sr, frameCount: frames) else { return }
        let data = buffer.floatChannelData![0]
        let perFreq = amplitude / Float(frequencies.count)
        for i in 0..<Int(frames) {
            let t = Float(i) / Float(sr)
            let attackEnv: Float = t < 0.06 ? t / 0.06 : 1.0
            let env = attackEnv * exp(-t * 2.5) * perFreq
            var sample: Float = 0
            for (idx, freq) in frequencies.enumerated() {
                let tAdj = max(0, t - Float(idx) * 0.07)
                sample += sin(2 * .pi * freq * tAdj) * env
            }
            data[i] = sample
        }
        scheduleBuffer(buffer)
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        player.scheduleBuffer(buffer, at: nil, options: []) {
            DispatchQueue.main.async {
                self.engine.detach(player)
            }
        }
        player.play()
    }
}
