//
//  TrikiBoxerTestView.swift
//  DmdApp
//
//  Minigra testowa BOKSER — trzymaj kontroler do przodu, potem mocne uderzenie.
//

import SwiftUI
import VeltoKit

// MARK: - Model

private enum TrikiBoxerPhase: Equatable {
    case intro
    case holdForward
    case punchWindow
    case result
}

@Observable
@MainActor
private final class TrikiBoxerSession {
    var phase: TrikiBoxerPhase = .intro
    var statusMessage = "Naciśnij „Rozpocznij”, aby zmierzyć siłę uderzenia."
    var holdProgress: Double = 0
    var livePower: Double = 0
    var punchPowerPercent: Int = 0
    var punchRating = ""
    var uiGeneration = 0

    func begin() {
        phase = .holdForward
        holdProgress = 0
        livePower = 0
        punchPowerPercent = 0
        punchRating = ""
        statusMessage = "Trzymaj kontroler do przodu (przód / oś Y)…"
        bumpUI()
    }

    func applyResult(peak: Double) {
        let clamped = min(1, max(0, peak))
        punchPowerPercent = Int((clamped * 100).rounded())
        punchRating = Self.rating(for: punchPowerPercent)
        livePower = clamped
        phase = .result
        statusMessage = "Siła uderzenia zmierzona."
        bumpUI()
    }

    private func bumpUI() {
        uiGeneration += 1
    }

    private static func rating(for percent: Int) -> String {
        switch percent {
        case 0..<20: "Ledwo dotknięcie"
        case 20..<40: "Lekki cios"
        case 40..<60: "Solidny cios"
        case 60..<80: "Mocny nokaut"
        case 80..<95: "Ciężka ręka"
        default: "Mistrz ringu"
        }
    }
}

/// Wykrywa trzymanie „do przodu” i impuls uderzenia z VeltoKit (`posY`, prędkość, flick).
private struct TrikiBoxerPunchDetector {
    static let smoothBlend = 0.2
    static let forwardHoldThreshold = 0.34
    static let forwardMinDuringPunch = 0.14
    static let holdFramesRequired = 12
    static let punchWindowDuration: TimeInterval = 5
    static let punchSpikeThreshold = 0.42
    static let settleAfterHit: TimeInterval = 0.28

    private var smoothedPosY = 0.0
    private var forwardHoldFrames = 0
    private var punchWindowEndsAt: TimeInterval = 0
    private var peakPower = 0.0
    private var hitDetectedAt: TimeInterval?
    private var previousFlick = false

    mutating func reset() {
        smoothedPosY = 0
        forwardHoldFrames = 0
        punchWindowEndsAt = 0
        peakPower = 0
        hitDetectedAt = nil
        previousFlick = false
    }

    mutating func poll(
        input: GameInput,
        phase: TrikiBoxerPhase,
        now: TimeInterval
    ) -> TrikiBoxerPollUpdate? {
        smoothedPosY += (input.posY - smoothedPosY) * Self.smoothBlend

        switch phase {
        case .intro, .result:
            return nil

        case .holdForward:
            if smoothedPosY >= Self.forwardHoldThreshold {
                forwardHoldFrames += 1
            } else {
                forwardHoldFrames = max(0, forwardHoldFrames - 2)
            }
            let progress = min(1, Double(forwardHoldFrames) / Double(Self.holdFramesRequired))
            if forwardHoldFrames >= Self.holdFramesRequired {
                resetPunchWindow(now: now)
                return TrikiBoxerPollUpdate(
                    nextPhase: .punchWindow,
                    holdProgress: 1,
                    livePower: 0,
                    statusMessage: "Teraz uderz mocno, nadal trzymając do przodu!"
                )
            }
            return TrikiBoxerPollUpdate(
                holdProgress: progress,
                statusMessage: progress > 0.35
                    ? "Jeszcze chwilę trzymaj do przodu…"
                    : "Przechyl kontroler do przodu (przód)."
            )

        case .punchWindow:
            guard now < punchWindowEndsAt else {
                return TrikiBoxerPollUpdate(
                    nextPhase: .result,
                    peakPower: peakPower,
                    statusMessage: "Koniec czasu — wynik z najmocniejszego impulsu."
                )
            }

            let forwardOK = smoothedPosY >= Self.forwardMinDuringPunch
                || input.pointerDirection == .up

            let instant = instantPower(input: input, forwardOK: forwardOK)
            peakPower = max(peakPower, instant)

            if input.flick, !previousFlick, forwardOK {
                hitDetectedAt = hitDetectedAt ?? now
            }
            if input.shotTriggered, forwardOK {
                let shot = min(1, max(peakPower, input.throwPower))
                peakPower = shot
                hitDetectedAt = hitDetectedAt ?? now
            }
            if instant >= Self.punchSpikeThreshold, forwardOK {
                hitDetectedAt = hitDetectedAt ?? now
            }
            previousFlick = input.flick

            if let hitAt = hitDetectedAt, now - hitAt >= Self.settleAfterHit {
                return TrikiBoxerPollUpdate(
                    nextPhase: .result,
                    livePower: peakPower,
                    peakPower: peakPower,
                    statusMessage: "Uderzenie zarejestrowane!"
                )
            }

            return TrikiBoxerPollUpdate(
                livePower: peakPower,
                statusMessage: forwardOK
                    ? "Uderz mocno do przodu!"
                    : "Trzymaj kontroler do przodu i uderz."
            )
        }
    }

    private mutating func resetPunchWindow(now: TimeInterval) {
        punchWindowEndsAt = now + Self.punchWindowDuration
        peakPower = 0
        hitDetectedAt = nil
        previousFlick = false
    }

    private func instantPower(input: GameInput, forwardOK: Bool) -> Double {
        guard forwardOK else { return 0 }
        let velocityTerm = min(1, max(0, input.trikiVelocity / 2.4))
        let intensityTerm = min(1, max(0, input.intensity / 1.15))
        let thrustTerm = min(1, max(0, max(0, input.frameDeltaY) / 0.22))
        let gyroTerm = min(1, max(0, abs(input.sensors.gyroY) / 3.2))
        let throwTerm = input.shotTriggered ? min(1, input.throwPower) : 0

        let blended = max(
            throwTerm,
            velocityTerm * 0.38 + intensityTerm * 0.32 + thrustTerm * 0.2 + gyroTerm * 0.1
        )
        if input.flick { return min(1, blended * 1.08) }
        return blended
    }
}

private struct TrikiBoxerPollUpdate {
    var nextPhase: TrikiBoxerPhase?
    var holdProgress: Double?
    var livePower: Double?
    var peakPower: Double?
    var statusMessage: String?
}

// MARK: - View

struct TrikiBoxerTestView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator

    @State private var session = TrikiBoxerSession()
    @State private var pollTask: Task<Void, Never>?
    @State private var restoredMenuMode = false

    var body: some View {
        VStack(spacing: 20) {
            header
            mainPanel
            actionButtons
        }
        .padding()
        .navigationTitle("BOKSER")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            coordinator.motion.configure(for: .gestureGame)
            restoredMenuMode = false
            startPolling()
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
            if !restoredMenuMode {
                coordinator.motion.configure(for: .menu)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !settings.trikiControllerEnabled {
                Text("Włącz Triki Kontroler w Ustawieniach.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !settings.trikiControllerCalibrated {
                Text("Zalecana kalibracja Triki przed pomiarem.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text(session.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.boxing")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(settings.accentColor)
                .symbolEffect(.bounce, value: session.phase == .punchWindow)

            phaseContent
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .id(session.uiGeneration)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch session.phase {
        case .intro:
            Text("Zmierzymy moc uderzenia przy trzymaniu kontrolera skierowanego do przodu.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

        case .holdForward:
            VStack(spacing: 10) {
                ProgressView(value: session.holdProgress)
                    .tint(settings.accentColor)
                Text("\(Int(session.holdProgress * 100))% gotowości")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

        case .punchWindow:
            powerMeter(value: session.livePower, label: "Impuls na żywo")

        case .result:
            VStack(spacing: 12) {
                Text("\(session.punchPowerPercent)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(settings.accentColor)
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.punchRating)
                    .font(.title3.bold())
                powerMeter(value: Double(session.punchPowerPercent) / 100, label: "Siła uderzenia")
            }
        }
    }

    private func powerMeter(value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(powerColor(value))
                        .frame(width: max(4, geo.size.width * CGFloat(min(1, max(0, value)))))
                }
            }
            .frame(height: 14)
        }
    }

    private func powerColor(_ value: Double) -> Color {
        if value < 0.35 { return .orange }
        if value < 0.65 { return .yellow }
        return settings.accentColor
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch session.phase {
        case .intro:
            Button {
                settings.playTapSound()
                session.begin()
            } label: {
                Text("Rozpocznij")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.accentColor)

        case .holdForward, .punchWindow:
            Button("Anuluj") {
                settings.playTapSound()
                session.phase = .intro
                session.statusMessage = "Pomiar anulowany."
                session.uiGeneration += 1
            }
            .buttonStyle(.bordered)

        case .result:
            Button {
                settings.playTapSound()
                session.begin()
            } label: {
                Text("Jeszcze raz")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.accentColor)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            var detector = TrikiBoxerPunchDetector()
            let step: TimeInterval = 1.0 / 30.0

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(step))
                guard !Task.isCancelled else { break }
                guard settings.trikiControllerEnabled else { continue }

                let now = Date().timeIntervalSinceReferenceDate
                let input = coordinator.lastGameInput

                if let update = detector.poll(
                    input: input,
                    phase: session.phase,
                    now: now
                ) {
                    applyPollUpdate(update)
                }
            }
        }
    }

    private func applyPollUpdate(_ update: TrikiBoxerPollUpdate) {
        var needsRefresh = false

        if let progress = update.holdProgress, abs(progress - session.holdProgress) > 0.02 {
            session.holdProgress = progress
            needsRefresh = true
        }
        if let live = update.livePower, abs(live - session.livePower) > 0.02 {
            session.livePower = live
            needsRefresh = true
        }
        if let message = update.statusMessage, message != session.statusMessage {
            session.statusMessage = message
            needsRefresh = true
        }
        if let next = update.nextPhase {
            switch next {
            case .result:
                if let peak = update.peakPower {
                    session.applyResult(peak: peak)
                    settings.playTapSound()
                }
            case .punchWindow:
                session.phase = .punchWindow
                session.holdProgress = 1
                session.uiGeneration += 1
            default:
                session.phase = next
                session.uiGeneration += 1
            }
        } else if needsRefresh {
            session.uiGeneration += 1
        }
    }
}

#Preview {
    NavigationStack {
        TrikiBoxerTestView()
    }
    .environment(AppSettings())
    .environment(TrikiNavigationCoordinator())
}
