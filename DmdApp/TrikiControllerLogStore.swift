//
//  TrikiControllerLogStore.swift
//  DmdApp
//
//  Pełny log działania kontrolera Triki (BLE, gesty, przycisk, nawigacja).
//

import Foundation
import Observation
import VeltoKit

enum TrikiLogCategory: String, CaseIterable, Sendable {
    case connection = "BLE"
    case gesture = "Gest"
    case button = "Przycisk"
    case navigation = "Nawigacja"
    case speed = "Prędkość"
    case system = "System"
    case sensor = "Sensor"

    var symbol: String {
        switch self {
        case .connection: "antenna.radiowaves.left.and.right"
        case .gesture: "hand.draw"
        case .button: "button.programmable"
        case .navigation: "arrow.left.arrow.right"
        case .speed: "speedometer"
        case .system: "gearshape"
        case .sensor: "waveform.path.ecg"
        }
    }
}

struct TrikiControllerLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: TrikiLogCategory
    let title: String
    let detail: String

    init(
        category: TrikiLogCategory,
        title: String,
        detail: String = "",
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.category = category
        self.title = title
        self.detail = detail
    }

    var formattedLine: String {
        let time = Self.timeFormatter.string(from: timestamp)
        if detail.isEmpty {
            return "[\(time)] [\(category.rawValue)] \(title)"
        }
        return "[\(time)] [\(category.rawValue)] \(title) · \(detail)"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

@Observable
@MainActor
final class TrikiControllerLogStore {
    private(set) var entries: [TrikiControllerLogEntry] = []
    var isRecording = false
    var includesSensorSamples = false

    private var lastConnectionSignature = ""
    private var lastSensorSampleAt: TimeInterval = 0
    private static let maxEntries = 400
    private static let sensorSampleInterval: TimeInterval = 0.5

    func setRecording(_ enabled: Bool) {
        isRecording = enabled
        if !enabled {
            lastConnectionSignature = ""
            lastSensorSampleAt = 0
        } else if entries.isEmpty {
            record(.system, title: "Nagrywanie logu włączone")
        }
    }

    func clear() {
        entries.removeAll()
        lastConnectionSignature = ""
        lastSensorSampleAt = 0
    }

    func record(
        _ category: TrikiLogCategory,
        title: String,
        detail: String = "",
        timestamp: Date = Date()
    ) {
        guard isRecording else { return }
        append(TrikiControllerLogEntry(category: category, title: title, detail: detail, timestamp: timestamp))
    }

    func recordGesture(_ kind: TrikiInferredGestureKind, detail: String) {
        let category: TrikiLogCategory = kind == .speedBurst ? .speed : .gesture
        record(category, title: kind.rawValue, detail: detail)
    }

    func exportText() -> String {
        exportFullReport(coordinator: nil, diagnostics: nil)
    }

    /// Log aplikacji + zdarzenia monitora diagnostycznego + snapshot sensorów w jednym pliku.
    func exportFullReport(
        coordinator: TrikiNavigationCoordinator?,
        diagnostics: TrikiControllerDiagnosticsStore?
    ) -> String {
        let now = Date()
        var sections: [String] = []

        sections.append(
            """
            TRIKI — PEŁNY RAPORT DZIAŁANIA
            \(Self.exportDateFormatter.string(from: now))
            SDK: VeltoKit (https://github.com/koderhack/veltokit) — MotionSDK + GameInput
            ════════════════════════════════════════════════════════════════════════
            """
        )

        if let coordinator {
            sections.append(snapshotSection(coordinator: coordinator, diagnostics: diagnostics))
        }

        if let diagnostics, !diagnostics.events.isEmpty {
            let monitorLines = diagnostics.events.map { event in
                let time = Self.timeFormatter.string(from: event.timestamp)
                if event.detail.isEmpty {
                    return "[\(time)] \(event.title)"
                }
                return "[\(time)] \(event.title) · \(event.detail)"
            }.joined(separator: "\n")
            sections.append(
                """

                [HISTORIA MONITORA DIAGNOSTYCZNEGO] (\(diagnostics.events.count) zdarzeń, tryb: \(diagnostics.monitorMode.title))
                ────────────────────────────────────────
                \(monitorLines)
                """
            )
        } else if diagnostics != nil {
            sections.append(

                """

                [HISTORIA MONITORA DIAGNOSTYCZNEGO]
                ────────────────────────────────────────
                (brak zdarzeń w bieżącym trybie)
                """
            )
        }

        let logHeader = """

        [LOG DZIAŁANIA APLIKACJI] (\(entries.count) wpisów\(isRecording ? ", nagrywanie aktywne" : ""))
        ────────────────────────────────────────
        """
        sections.append(logHeader)
        if entries.isEmpty {
            sections.append("(pusty — otwórz TRIKI KONTROLER i używaj kontrolera)")
        } else {
            sections.append(entries.reversed().map(\.formattedLine).joined(separator: "\n"))
        }

        return sections.joined(separator: "\n")
    }

    private func snapshotSection(
        coordinator: TrikiNavigationCoordinator,
        diagnostics: TrikiControllerDiagnosticsStore?
    ) -> String {
        let trikiOn = coordinator.isEnabled ? "włączone" : "wyłączone"
        let ble: String
        if !coordinator.isEnabled {
            ble = "Triki wyłączone w aplikacji"
        } else if coordinator.isBLEReceiving {
            ble = "połączono · odbiór danych"
        } else if coordinator.isBLEConnected {
            ble = "połączono · brak pakietów"
        } else if coordinator.isTrikiConnectionActive {
            ble = "skanowanie BLE"
        } else {
            ble = "nieaktywne"
        }

        let monitorMode = diagnostics?.monitorMode.title ?? "—"
        let lastAction = diagnostics?.lastDetectedAction ?? "—"
        let liveSummary = diagnostics?.liveSensorSummary ?? "—"

        return """

        [STAN BIEŻĄCY]
        ────────────────────────────────────────
        Triki w aplikacji: \(trikiOn)
        Połączenie BLE: \(ble)
        Komunikat: \(coordinator.connectionMessage.isEmpty ? "—" : coordinator.connectionMessage)
        Kalibracja sesji: \(coordinator.showsCalibrationPrompt ? "oczekuje promptu" : "zakończona lub pominięta")
        Tryb monitora: \(monitorMode)
        Ostatnia akcja monitora: \(lastAction)
        Podgląd na żywo: \(liveSummary)
        Sensory: posX \(String(format: "%+.3f", coordinator.livePointerX)) · \(coordinator.debugPointerDirection)
          tilt \(String(format: "%+.3f/%+.3f", coordinator.debugTiltX, coordinator.debugTiltY))
          mot \(String(format: "%.3f", coordinator.debugSensorMotion))
          spd \(String(format: "%.3f", coordinator.debugSensorSpeed))
          relY \(String(format: "%+.3f", coordinator.debugRelY))
          gest: \(coordinator.debugSwingPhase)
          BLE tryb: \(coordinator.trikiBLEModeLabel)
          przycisk: \(coordinator.debugButtonHeld ? "wciśnięty" : "puszczony")
          bleClick: \(coordinator.lastGameInput.bleButtonClick ? "tak" : "nie")
          wybór: \(coordinator.highlightIndex.map { String($0) } ?? "—") / \(coordinator.activeButtons.count) opcji
        """
    }

    func ingest(from coordinator: TrikiNavigationCoordinator) {
        guard isRecording else { return }
        logConnectionIfNeeded(coordinator)
        if includesSensorSamples {
            appendSensorSampleIfNeeded(from: coordinator)
        }
    }

    private func append(_ entry: TrikiControllerLogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
    }

    private func logConnectionIfNeeded(_ coordinator: TrikiNavigationCoordinator) {
        let signature: String
        if !coordinator.isEnabled {
            signature = "off"
        } else if coordinator.isBLEReceiving {
            signature = "rx"
        } else if coordinator.isBLEConnected {
            signature = "connected"
        } else if coordinator.isTrikiConnectionActive {
            signature = "scan"
        } else {
            signature = "idle"
        }

        guard signature != lastConnectionSignature else { return }
        lastConnectionSignature = signature

        let title: String
        let detail = coordinator.connectionMessage
        switch signature {
        case "off": title = "Triki wyłączone"
        case "scan": title = "Szukanie kontrolera"
        case "connected": title = "Połączono — brak pakietów"
        case "rx": title = "Połączono — odbiór danych"
        default: title = "Stan połączenia"
        }
        record(.connection, title: title, detail: detail)
    }

    private func appendSensorSampleIfNeeded(from coordinator: TrikiNavigationCoordinator) {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastSensorSampleAt >= Self.sensorSampleInterval else { return }
        lastSensorSampleAt = now

        let detail = String(
            format: "posX %+.2f · %@ · tilt %+.2f/%+.2f · mot %.2f · spd %.2f · rssi %@",
            coordinator.livePointerX,
            coordinator.debugPointerDirection,
            coordinator.debugTiltX,
            coordinator.debugTiltY,
            coordinator.debugSensorMotion,
            coordinator.debugSensorSpeed,
            coordinator.debugConnectedRSSI.map(String.init) ?? "—"
        )
        record(.sensor, title: "Próbka", detail: detail)
    }

    private static let exportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        f.locale = Locale(identifier: "pl_PL")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
