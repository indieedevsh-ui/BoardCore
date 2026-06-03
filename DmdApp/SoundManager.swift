//
//  SoundManager.swift
//  DmdApp
//

import AVFAudio
import UIKit

enum SoundManager {
    private static let engine = AVAudioEngine()
    private static let playerNode = AVAudioPlayerNode()
    private static var isConfigured = false

    static func playTap(volume: Double) {
        playTone(volume: volume, frequency: 1_200, duration: 0.07, decay: 90, amplitudeScale: 0.35)
    }

    static func playSkipTurn(volume: Double) {
        playSequence(
            volume: volume,
            tones: [(480, 0.1, 0.4), (280, 0.14, 0.32)],
            gap: 0.04
        )
    }

    static func playStatsReveal(volume: Double) {
        playSequence(
            volume: volume,
            tones: [(660, 0.08, 0.28), (880, 0.09, 0.3), (1_098, 0.12, 0.32)],
            gap: 0.05
        )
    }

    static func playStatsRevealStep(volume: Double) {
        playTone(volume: volume, frequency: 880, duration: 0.06, decay: 88, amplitudeScale: 0.24)
    }

    static func playShopOpen(volume: Double) {
        playSequence(
            volume: volume,
            tones: [(784, 0.07, 0.3), (988, 0.08, 0.32), (1_318, 0.13, 0.34)],
            gap: 0.045
        )
    }

    static func playShopPurchase(volume: Double) {
        playMetallicSequence(
            volume: volume,
            tones: [
                (880, 0.038, 0.34, 145),
                (1_120, 0.048, 0.38, 125),
                (1_480, 0.065, 0.36, 105),
                (1_760, 0.055, 0.28, 90),
            ],
            gap: 0.022
        )
    }

    static func playShopSell(volume: Double) {
        playMetallicSequence(
            volume: volume,
            tones: [
                (1_620, 0.042, 0.36, 135),
                (1_140, 0.052, 0.38, 115),
                (780, 0.062, 0.34, 95),
                (520, 0.075, 0.3, 80),
            ],
            gap: 0.028
        )
    }

    /// Krótki, papierowy szelest przy zmianie monet (dodanie / odejmowanie).
    static func playCoinPaper(volume: Double, adding: Bool) {
        playCoinPaperTicks(volume: volume, adding: adding, count: 1)
    }

    /// Szybki papierowy „tik” — jeden krok licznika kasy.
    static func playCoinPaperTick(volume: Double, adding: Bool) {
        playCoinPaperTicks(volume: volume, adding: adding, count: 1)
    }

    /// Seria szybkich tików (efekt liczenia / dodawania monet).
    static func playCoinPaperTicks(volume: Double, adding: Bool, count: Int) {
        guard volume > 0.01, count > 0 else { return }

        do {
            try configureIfNeeded()
            let tickDuration = 0.028
            let gap = 0.017
            var nextStartFrame: AVAudioFramePosition = 0

            for index in 0..<count {
                guard let buffer = makePaperTickBuffer(volume: volume, adding: adding) else { continue }

                if index == 0 {
                    playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                } else {
                    let startTime = AVAudioTime(sampleTime: nextStartFrame, atRate: 44_100)
                    playerNode.scheduleBuffer(buffer, at: startTime, options: [], completionHandler: nil)
                }

                nextStartFrame += AVAudioFramePosition((tickDuration + gap) * 44_100)
            }

            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            // Dźwięk jest opcjonalny.
        }
    }

    static func playDrawShuffleTick(volume: Double, tickIndex: Int) {
        let base = 820.0 + Double(tickIndex % 6) * 95
        playTone(volume: volume, frequency: base, duration: 0.045, decay: 105, amplitudeScale: 0.26)
    }

    static func playDrawReveal(volume: Double) {
        playSequence(
            volume: volume,
            tones: [(620, 0.05, 0.28), (880, 0.07, 0.32), (1_176, 0.11, 0.36), (1_480, 0.16, 0.38)],
            gap: 0.035
        )
    }

    static func playArtifactCrystalPulse(volume: Double, tickIndex: Int, phase: Double) {
        let base = 1_280.0 + Double(tickIndex % 5) * 165 + phase * 320
        playCrystallineTone(
            volume: volume,
            frequency: base,
            duration: 0.055,
            decay: 72 + phase * 18,
            amplitudeScale: 0.22 + phase * 0.14
        )
    }

    static func playArtifactReveal(volume: Double, positive: Bool) {
        if positive {
            playCrystallineSequence(
                volume: volume,
                tones: [
                    (1_420, 0.07, 0.3, 68),
                    (1_780, 0.08, 0.34, 62),
                    (2_120, 0.11, 0.36, 56),
                    (2_480, 0.14, 0.32, 50),
                ],
                gap: 0.04
            )
        } else {
            playCrystallineSequence(
                volume: volume,
                tones: [
                    (980, 0.08, 0.3, 58),
                    (760, 0.09, 0.32, 52),
                    (540, 0.12, 0.28, 46),
                ],
                gap: 0.045
            )
        }
    }

    private static func playCrystallineTone(
        volume: Double,
        frequency: Double,
        duration: Double,
        decay: Double,
        amplitudeScale: Double
    ) {
        guard volume > 0.01 else { return }

        do {
            try configureIfNeeded()
            guard let buffer = makeCrystallineToneBuffer(
                volume: volume,
                frequency: frequency,
                duration: duration,
                decay: decay,
                amplitudeScale: amplitudeScale
            ) else { return }
            playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            // Dźwięk jest opcjonalny.
        }
    }

    private static func playCrystallineSequence(
        volume: Double,
        tones: [(Double, Double, Double, Double)],
        gap: Double
    ) {
        guard volume > 0.01 else { return }

        do {
            try configureIfNeeded()
            var nextStartFrame: AVAudioFramePosition = 0

            for (index, tone) in tones.enumerated() {
                guard let buffer = makeCrystallineToneBuffer(
                    volume: volume,
                    frequency: tone.0,
                    duration: tone.1,
                    decay: tone.3,
                    amplitudeScale: tone.2
                ) else { continue }

                if index == 0 {
                    playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                } else {
                    let startTime = AVAudioTime(sampleTime: nextStartFrame, atRate: 44_100)
                    playerNode.scheduleBuffer(buffer, at: startTime, options: [], completionHandler: nil)
                }

                nextStartFrame += AVAudioFramePosition((tone.1 + gap) * 44_100)
            }

            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            // Dźwięk jest opcjonalny.
        }
    }

    private static func playTone(
        volume: Double,
        frequency: Double,
        duration: Double,
        decay: Double,
        amplitudeScale: Double
    ) {
        guard volume > 0.01 else { return }

        do {
            try configureIfNeeded()
            guard let buffer = makeToneBuffer(
                volume: volume,
                frequency: frequency,
                duration: duration,
                decay: decay,
                amplitudeScale: amplitudeScale
            ) else { return }
            playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            // Dźwięk jest opcjonalny — brak dźwięku nie blokuje UI.
        }
    }

    private static func playMetallicSequence(
        volume: Double,
        tones: [(Double, Double, Double, Double)],
        gap: Double
    ) {
        guard volume > 0.01 else { return }

        do {
            try configureIfNeeded()
            var nextStartFrame: AVAudioFramePosition = 0

            for (index, tone) in tones.enumerated() {
                guard let buffer = makeMetallicToneBuffer(
                    volume: volume,
                    frequency: tone.0,
                    duration: tone.1,
                    decay: tone.3,
                    amplitudeScale: tone.2
                ) else { continue }

                if index == 0 {
                    playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                } else {
                    let startTime = AVAudioTime(sampleTime: nextStartFrame, atRate: 44_100)
                    playerNode.scheduleBuffer(buffer, at: startTime, options: [], completionHandler: nil)
                }

                nextStartFrame += AVAudioFramePosition((tone.1 + gap) * 44_100)
            }

            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            // Dźwięk jest opcjonalny.
        }
    }

    private static func playSequence(volume: Double, tones: [(Double, Double, Double)], gap: Double) {
        guard volume > 0.01 else { return }

        do {
            try configureIfNeeded()
            var nextStartFrame: AVAudioFramePosition = 0

            for (index, tone) in tones.enumerated() {
                guard let buffer = makeToneBuffer(
                    volume: volume,
                    frequency: tone.0,
                    duration: tone.1,
                    decay: 75,
                    amplitudeScale: tone.2
                ) else { continue }

                if index == 0 {
                    playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                } else {
                    let startTime = AVAudioTime(sampleTime: nextStartFrame, atRate: 44_100)
                    playerNode.scheduleBuffer(buffer, at: startTime, options: [], completionHandler: nil)
                }

                nextStartFrame += AVAudioFramePosition((tone.1 + gap) * 44_100)
            }

            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            // Dźwięk jest opcjonalny.
        }
    }

    private static func configureIfNeeded() throws {
        guard !isConfigured else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        try engine.start()
        isConfigured = true
    }

    private static func makePaperTickBuffer(volume: Double, adding: Bool) -> AVAudioPCMBuffer? {
        makePaperRustleBuffer(
            volume: volume,
            duration: 0.028,
            adding: adding,
            tick: true
        )
    }

    private static func makePaperRustleBuffer(
        volume: Double,
        duration: Double,
        adding: Bool,
        tick: Bool = false
    ) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        let amplitude = Float(volume) * (tick ? 0.26 : 0.22)
        let toneHz = adding ? (tick ? 620.0 : 540.0) : (tick ? 500.0 : 470.0)

        for index in 0..<Int(frameCount) {
            let time = Double(index) / sampleRate
            let attackRate = tick ? 1_200.0 : 520.0
            let decayRate = tick ? (adding ? 52.0 : 58.0) : (adding ? 34.0 : 38.0)
            let attack = min(1.0, time * attackRate)
            let envelope = attack * exp(-time * decayRate)

            let rustleA = sin(time * 11_371.0) * sin(time * 73_891.0)
            let rustleB = sin(time * 5_437.0 + 0.8) * sin(time * 9_127.0)
            let rustleC = sin(time * 17_233.0 * 0.37) * cos(time * 4_811.0)
            let rustle = (rustleA * 0.42 + rustleB * 0.35 + rustleC * 0.23)

            let crease = sin(2 * .pi * toneHz * time) * 0.08
                + sin(2 * .pi * toneHz * 1.93 * time) * 0.05

            let sample = (rustle * 0.82 + crease) * envelope
            samples[index] = Float(sample) * amplitude
        }

        return buffer
    }

    private static func makeToneBuffer(
        volume: Double,
        frequency: Double,
        duration: Double,
        decay: Double,
        amplitudeScale: Double
    ) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        let amplitude = Float(volume) * Float(amplitudeScale)

        for index in 0..<Int(frameCount) {
            let time = Double(index) / sampleRate
            let envelope = exp(-time * decay)
            let wave = sin(2 * .pi * frequency * time) * envelope
            samples[index] = Float(wave) * amplitude
        }

        return buffer
    }

    private static func makeMetallicToneBuffer(
        volume: Double,
        frequency: Double,
        duration: Double,
        decay: Double,
        amplitudeScale: Double
    ) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        let amplitude = Float(volume) * Float(amplitudeScale)
        let clickFrames = Int(sampleRate * 0.004)

        for index in 0..<Int(frameCount) {
            let time = Double(index) / sampleRate
            let attack = min(1.0, time * 280)
            let envelope = attack * exp(-time * decay)

            let fundamental = sin(2 * .pi * frequency * time)
            let partial2 = sin(2 * .pi * frequency * 2.41 * time) * 0.42
            let partial3 = sin(2 * .pi * frequency * 3.17 * time) * 0.28
            let partial5 = sin(2 * .pi * frequency * 5.03 * time) * 0.16
            let squareGrind = sin(2 * .pi * frequency * 0.5 * time) * 0.12

            var sample = (fundamental + partial2 + partial3 + partial5 + squareGrind) * envelope

            if index < clickFrames {
                let clickEnv = exp(-time * 320)
                let clickNoise = sin(2 * .pi * 3_800 * time) * 0.55 + sin(2 * .pi * 6_200 * time) * 0.35
                sample += clickNoise * clickEnv * 0.55
            }

            samples[index] = Float(sample) * amplitude
        }

        return buffer
    }

    private static func makeCrystallineToneBuffer(
        volume: Double,
        frequency: Double,
        duration: Double,
        decay: Double,
        amplitudeScale: Double
    ) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        let amplitude = Float(volume) * Float(amplitudeScale)

        for index in 0..<Int(frameCount) {
            let time = Double(index) / sampleRate
            let attack = min(1.0, time * 420)
            let envelope = attack * exp(-time * decay)

            let fundamental = sin(2 * .pi * frequency * time)
            let partial2 = sin(2 * .pi * frequency * 2.76 * time) * 0.38
            let partial3 = sin(2 * .pi * frequency * 4.12 * time) * 0.24
            let partial5 = sin(2 * .pi * frequency * 6.08 * time) * 0.12
            let shimmer = sin(2 * .pi * frequency * 1.03 * time + sin(2 * .pi * 18 * time) * 0.08) * 0.18

            let sample = (fundamental + partial2 + partial3 + partial5 + shimmer) * envelope
            samples[index] = Float(sample) * amplitude
        }

        return buffer
    }
}

enum HapticManager {
    /// Mocna haptyka przy naciśnięciu przycisku (skala 0…1).
    static func playButtonTap(intensity: Double) {
        guard intensity > 0.01 else { return }

        let strength = CGFloat(min(max(intensity, 0), 1))
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred(intensity: strength)

        guard strength > 0.2 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.prepare()
            rigid.impactOccurred(intensity: strength * 0.92)
        }
    }

    static func playStatReveal(intensity: Double = 1.0) {
        playButtonTap(intensity: intensity)
    }

    static func playSkipTurn(intensity: Double = 1.0) {
        guard intensity > 0.01 else { return }
        let strength = CGFloat(min(max(intensity, 0), 1))
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.prepare()
            medium.impactOccurred(intensity: strength * 0.75)
        }
    }

    /// Pulsująca haptyka podczas losowania (phase 0…1 w trakcie trwania animacji).
    static func playDrawPulse(intensity: Double, phase: Double) {
        guard intensity > 0.01 else { return }
        let wave = sin(phase * .pi * 10) * 0.5 + 0.5
        let strength = CGFloat(min(max(intensity * (0.28 + wave * 0.72), 0), 1))
        let style: UIImpactFeedbackGenerator.FeedbackStyle = wave > 0.65 ? .medium : .soft
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: strength)
    }

    /// Rosnąca haptyka podczas machania pędzlem artefaktu (phase 0…1).
    static func playArtifactBrushPulse(intensity: Double, phase: Double) {
        guard intensity > 0.01 else { return }
        let strength = CGFloat(min(max(intensity * (0.18 + phase * 0.82), 0), 1))
        let style: UIImpactFeedbackGenerator.FeedbackStyle = {
            if phase > 0.72 { return .rigid }
            if phase > 0.38 { return .medium }
            return .soft
        }()
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: strength)
    }

    static func playShopPurchase(intensity: Double = 1.0) {
        guard intensity > 0.01 else { return }
        let strength = CGFloat(min(max(intensity, 0), 1))
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        rigid.prepare()
        rigid.impactOccurred(intensity: strength * 0.95)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            heavy.impactOccurred(intensity: strength * 0.7)
        }
    }

    static func playShopSell(intensity: Double = 1.0) {
        guard intensity > 0.01 else { return }
        let strength = CGFloat(min(max(intensity, 0), 1))
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred(intensity: strength * 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.prepare()
            rigid.impactOccurred(intensity: strength * 0.65)
        }
    }

    /// Puls AR zależny od szybkości ruchu figurki (punkty ekranu / sekundę).
    static func playFigurineMotionPulse(intensity: Double, speed: CGFloat) {
        guard intensity > 0.01 else { return }
        let normalized = min(max((speed - 8) / 420, 0), 1)
        let strength = CGFloat(min(max(intensity * (0.4 + Double(normalized) * 0.6), 0), 1))
        let style: UIImpactFeedbackGenerator.FeedbackStyle = {
            if normalized > 0.65 { return .rigid }
            if normalized > 0.3 { return .medium }
            return .soft
        }()
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: max(strength, 0.35))
    }
}
