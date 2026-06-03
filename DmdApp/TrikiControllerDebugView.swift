//
//  TrikiControllerDebugView.swift
//  DmdApp
//

import SwiftUI
import Combine

struct TrikiControllerDebugView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator
    @Environment(TrikiControllerDiagnosticsStore.self) private var diagnostics

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    connectionSection
                    liveSection
                    eventsSection
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
                    Button("Wyczyść") {
                        settings.playTapSound()
                        diagnostics.clearEvents()
                    }
                }
            }
            .onAppear {
                diagnostics.setMonitoring(true)
            }
            .onDisappear {
                diagnostics.setMonitoring(false)
            }
            .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
                diagnostics.ingest(from: coordinator)
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
                Text("Brak zdarzeń — porusz kontrolerem lub naciśnij przycisk.")
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
}

#Preview {
    TrikiControllerDebugView()
        .environment(AppSettings())
        .environment(TrikiNavigationCoordinator())
        .environment(TrikiControllerDiagnosticsStore())
}
