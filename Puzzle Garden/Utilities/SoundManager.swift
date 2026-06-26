@preconcurrency import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private var isEngineRunning = false

    private var didConfigureSession = false

    private init() {}

    /// Lazily configures the audio session and starts the engine the first time
    /// a sound is needed. Returns true if the engine is running and safe to use.
    ///
    /// Note: `engine.start()` can raise an uncatchable Objective-C exception if the
    /// graph has no output chain, so we touch `mainMixerNode` first to force the
    /// output node to be built before starting.
    @discardableResult
    private func ensureEngineRunning() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if isEngineRunning && engine.isRunning { return true }

        do {
            if !didConfigureSession {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                didConfigureSession = true
            }
            // Force the output graph to exist before starting so start() can't
            // hit the "required condition is false" assertion.
            _ = engine.mainMixerNode
            engine.prepare()
            try engine.start()
            isEngineRunning = engine.isRunning
            return isEngineRunning
        } catch {
            // Engine setup failed; sounds will be silently skipped.
            isEngineRunning = false
            return false
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

    /// A short, vocal "meow" — a pitch that rises then falls, with a little harmonic
    /// for a cat-like timbre. Played when the wandering cat is tapped.
    func playMeow() {
        guard soundEnabled else { return }
        playGlide(duration: 0.5, amplitude: 0.20)
    }

    // MARK: - Synthesis

    private func makePCMBuffer(sampleRate: Double, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        buf?.frameLength = frameCount
        return buf
    }

    private func playTone(frequency: Float, duration: Float, amplitude: Float) {
        guard ensureEngineRunning() else { return }
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
        guard ensureEngineRunning() else { return }
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
        guard ensureEngineRunning() else { return }
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

    /// A pitched glide whose frequency rises then falls across the duration — the
    /// contour of a little "meow". Phase is accumulated so the bend stays smooth.
    private func playGlide(duration: Float, amplitude: Float) {
        guard ensureEngineRunning() else { return }
        let sr: Double = 44100
        let frames = AVAudioFrameCount(sr * Double(duration))
        guard let buffer = makePCMBuffer(sampleRate: sr, frameCount: frames) else { return }
        let data = buffer.floatChannelData![0]
        var phase: Float = 0
        for i in 0..<Int(frames) {
            let p = Float(i) / Float(frames)                 // 0…1 through the sound
            let freq = 380 + 320 * sin(.pi * p)              // 380 → 700 → 380 Hz
            phase += 2 * .pi * freq / Float(sr)
            let attack: Float = p < 0.08 ? p / 0.08 : 1
            let release: Float = p > 0.7 ? max(0, 1 - (p - 0.7) / 0.3) : 1
            let env = attack * release * amplitude
            data[i] = (sin(phase) + 0.35 * sin(2 * phase)) * env
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
