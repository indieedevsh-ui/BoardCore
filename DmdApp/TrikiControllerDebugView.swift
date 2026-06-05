//
//  TrikiControllerDebugView.swift
//  DmdApp
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct TrikiControllerDebugView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator
    @Environment(TrikiControllerDiagnosticsStore.self) private var diagnostics
    @Environment(TrikiControllerLogStore.self) private var activityLog

    @State private var copyConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    connectionSection
                    boxerTestSection
                    monitorModeSection
                    liveSection
                    eventsSection
                    activityLogSection
                }
                .padding()
            }
            .appScrollSurface()
            .navigationTitle("TRIKI KONTROLER")
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Wyczyść monitor") {
                            settings.playTapSound()
                            diagnostics.clearEvents()
                        }
                        Button("Wyczyść log") {
                            settings.playTapSound()
                            activityLog.clear()
                        }
                        Button("Wyczyść wszystko") {
                            settings.playTapSound()
                            diagnostics.clearEvents()
                            activityLog.clear()
                        }
                    } label: {
                        Text("Wyczyść")
                    }
                }
            }
            .onAppear {
                coordinator.activityLog = activityLog
                diagnostics.activityLog = activityLog
                diagnostics.setMonitoring(true)
                activityLog.setRecording(true)
                if diagnostics.lastDetectedAction == "—" {
                    diagnostics.lastDetectedAction = diagnostics.monitorMode.idleHint
                }
            }
            .onDisappear {
                diagnostics.setMonitoring(false)
                activityLog.setRecording(false)
            }
            .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
                diagnostics.ingest(from: coordinator)
                activityLog.ingest(from: coordinator)
            }
            .alert("Skopiowano log", isPresented: $copyConfirmation) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Połączenie", systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)

            HStack(spacing: 8) {
                Circle()
                    .fill(coordinator.isBLEReceiving ? Color.green : (coordinator.isBLEConnected ? Color.orange : Color.red))
                    .frame(width: 10, height: 10)
                Text(diagnostics.connectionStatus)
                    .font(.subheadline.bold())
            }

            Text(coordinator.connectionMessage.isEmpty ? "—" : coordinator.connectionMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if settings.trikiControllerEnabled, coordinator.isBLEConnected {
                Text("Tryb BLE: \(coordinator.trikiBLEModeLabel)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            if !settings.trikiControllerEnabled {
                Text("Włącz „Triki Kontroler” w Ustawieniach, aby nawiązać połączenie BLE.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if settings.trikiControllerCalibrated {
                Label("Skalibrowano wcześniej", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var boxerTestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Minigra testowa", systemImage: "figure.boxing")
                .font(.headline)

            NavigationLink {
                TrikiBoxerTestView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BOKSER")
                            .font(.subheadline.bold())
                        Text("Trzymaj kontroler do przodu i zmierz moc uderzenia.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .simultaneousGesture(TapGesture().onEnded {
                settings.playTapSound()
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var monitorModeSection: some View {
        HStack(spacing: 8) {
            ForEach(TrikiDiagnosticsMonitorMode.allCases) { mode in
                Button {
                    settings.playTapSound()
                    diagnostics.setMonitorMode(mode)
                } label: {
                    Text(mode.title)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(
                    TrikiMonitorModeButtonStyle(
                        isSelected: diagnostics.monitorMode == mode,
                        accent: settings.accentColor
                    )
                )
            }
        }
    }

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ostatnia wykryta akcja", systemImage: "waveform.path.ecg")
                .font(.headline)

            Text(diagnostics.lastDetectedAction)
                .font(.title3.bold())

            Text(diagnostics.liveSensorSummary.isEmpty ? "Brak danych na żywo." : diagnostics.liveSensorSummary)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Historia zdarzeń", systemImage: "list.bullet.rectangle")
                .font(.headline)

            if diagnostics.events.isEmpty {
                Text(emptyEventsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(diagnostics.events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.title)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Text(event.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyEventsHint: String {
        switch diagnostics.monitorMode {
        case .rotate:
            "Brak zdarzeń — obróć kontroler w lewo lub w prawo (oś X)."
        case .translation:
            "Brak zdarzeń — przechyl przód/tył lub w bok."
        case .actions:
            "Brak zdarzeń — gest rzutu (shotTriggered) lub swing (flick) z VeltoKit."
        case .speedometer:
            "Porusz czapką — monitoruje pole trikiVelocity z GameInput."
        }
    }

    private var activityLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Log działania", systemImage: "doc.text")
                .font(.headline)

            Text("Pełna historia: BLE, gesty, przycisk, nawigacja i (opcjonalnie) próbki sensorów.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Próbki sensorów (~2/s)", isOn: Binding(
                get: { activityLog.includesSensorSamples },
                set: { activityLog.includesSensorSamples = $0 }
            ))
            .font(.subheadline)

            HStack(spacing: 8) {
                Button {
                    settings.playTapSound()
                    copyLogToPasteboard()
                } label: {
                    Label("Kopiuj", systemImage: "doc.on.doc")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                ShareLink(item: activityLog.exportFullReport(coordinator: coordinator, diagnostics: diagnostics)) {
                    Label("Udostępnij", systemImage: "square.and.arrow.up")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }

            Text("\(activityLog.entries.count) wpisów")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            if activityLog.entries.isEmpty {
                Text("Log pusty — porusz kontrolerem lub naciśnij przycisk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activityLog.entries.prefix(60)) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: entry.category.symbol)
                            .font(.caption)
                            .foregroundStyle(settings.accentColor)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.title)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Text(entry.category.rawValue)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1), in: Capsule())
                                if !entry.detail.isEmpty {
                                    Text(entry.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 3)
                    Divider()
                }
                if activityLog.entries.count > 60 {
                    Text("… i \(activityLog.entries.count - 60) starszych wpisów (pełna lista w „Kopiuj” / „Udostępnij”).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func copyLogToPasteboard() {
#if canImport(UIKit)
        UIPasteboard.general.string = activityLog.exportFullReport(
            coordinator: coordinator,
            diagnostics: diagnostics
        )
        copyConfirmation = true
#endif
    }
}

private struct TrikiMonitorModeButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accent : Color.white.opacity(configuration.isPressed ? 0.22 : 0.12))
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

#Preview {
    TrikiControllerDebugView()
        .environment(AppSettings())
        .environment(TrikiNavigationCoordinator())
        .environment(TrikiControllerDiagnosticsStore())
        .environment(TrikiControllerLogStore())
}
