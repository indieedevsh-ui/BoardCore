//
//  SettingsView.swift
//  BoardCore
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CampaignStore.self) private var campaignStore
    @Environment(CampaignLLMService.self) private var llmService
    @Environment(GameplayLLMService.self) private var gameplayLLMService
    @Environment(ThinkingModelPreferences.self) private var thinkingPreferences
    @Environment(PlaythroughMemoryStore.self) private var playthroughStore
    @Environment(GameplayThinkingService.self) private var thinkingService
    @Environment(SavedGameStore.self) private var savedGameStore
    @Environment(\.modelContext) private var modelContext

    @State private var showResetConfirmation = false
    @State private var resetDone = false
    @State private var showTrikiPairingSheet = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsSectionHeader(title: "LLM")

                    SettingsTile {
                        NavigationLink {
                            GameLLMSettingsView()
                        } label: {
                            Label("LLM Gry", systemImage: "cpu")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSectionFooter(
                        text: "Pobierz lub odinstaluj model Llama 7B do analizy fabuły podczas gry."
                    )

                    SettingsSectionHeader(title: "Tryb dewelopera")

                    SettingsTile {
                        Toggle("Tryb dewelopera", isOn: $settings.developerModeEnabled)
                    }

                    SettingsSectionFooter(
                        text: "Włącza zakładkę DevCentrum (przedmioty, zdolności, ścieżki mocy, reguły gry). Domyślnie ukryta dla graczy."
                    )

                    SettingsSectionHeader(title: "Kampania fabularna")

                    SettingsTile {
                        Toggle("Kampanie włączone", isOn: $settings.campaignsEnabled)
                            .disabled(!settings.canEnableCampaigns)
                    }

                    SettingsSectionFooter(
                        text: settings.canEnableCampaigns
                            ? "Wyłączenie ukrywa zakładkę Kampanie i upraszcza przejście przez pole start (+\(StartFieldRewards.passCoins) monet bez fabuły)."
                            : "To urządzenie ma \(DeviceMemory.physicalMemoryLabel) RAM (maks. 5 GB) — kampanie fabularne są niedostępne ze względu na wymagania pamięci."
                    )

                    SettingsSectionHeader(title: "Wygląd")

                    SettingsTile {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Styl aplikacji", selection: $settings.visualStyle) {
                                ForEach(AppVisualStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(spacing: 10) {
                                Image(systemName: settings.visualStyle.icon)
                                    .font(.title3)
                                    .foregroundStyle(settings.accentColor)
                                Text(settings.visualStyle.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                Button("Przycisk") { settings.playTapSound() }
                                    .buttonStyle(.appProminent)
                                Button("Opcja") { settings.playTapSound() }
                                    .buttonStyle(.appSecondary)
                            }
                        }
                    }

                    SettingsSectionFooter(
                        text: "Elegancki — szklisty wygląd z pływającym paskiem zakładek. Kreskówkowy — grube obrysy, żywe kolory i czarny pasek zakładek przy dole ekranu."
                    )

                    SettingsTile {
                        VStack(alignment: .leading, spacing: 12) {
                            ColorPicker(
                                "Kolor poświaty (góra ekranu)",
                                selection: $settings.backgroundColor,
                                supportsOpacity: true
                            )

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.backgroundColor)
                                .frame(height: 44)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                                }

                            Text("Kolor przycisków")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.accentColor)
                                .frame(height: 44)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                                }
                                .allowsHitTesting(false)
                        }
                    }

                    SettingsSectionFooter(
                        text: "Poświata u góry przechodzi w czarne tło. Przyciski mają automatycznie jaśniejszy odcień wybranego koloru (np. fiolet → jasny fiolet)."
                    )

                    SettingsSectionHeader(title: "Dźwięk")

                    SettingsTile {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "speaker.fill")
                                    .foregroundStyle(.secondary)
                                AppSlider(value: $settings.volume, in: 0...1)
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundStyle(.secondary)
                            }

                            Text("Głośność: \(Int(settings.volume * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsTile {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundStyle(.secondary)
                                AppSlider(value: $settings.hapticIntensity, in: 0...1)
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundStyle(.secondary)
                            }

                            Text("Haptyka: \(Int(settings.hapticIntensity * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsSectionFooter(
                        text: "Głośność dotyczy dźwięków kliknięć. Haptyka — siła wibracji przy naciśnięciu przycisków (0% wyłącza)."
                    )

                    SettingsSectionHeader(title: "Skanowanie QR")

                    SettingsTile {
                        Picker("Kamera do skanowania", selection: $settings.qrScanCameraPosition) {
                            ForEach(QRScanCameraPosition.allCases) { position in
                                Text(position.label).tag(position)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsSectionFooter(
                        text: "Dotyczy skanera QR, pasywnego skanowania w grze i kamery AR w walce z bossem. Domyślnie przednia — wygodna przy kodach na ekranie; tylna lepiej na stole."
                    )

                    SettingsSectionHeader(title: "Kontroler Triki")

                    SettingsTile {
                        Toggle("Włącz Triki Kontroler", isOn: $settings.trikiControllerEnabled)
                    }

                    SettingsSectionFooter(
                        text: "Po włączeniu sterujesz listą opcji krótkim kliknięciem i długim przytrzymaniem fizycznego przycisku na kontrolerze."
                    )

                    SettingsSectionHeader(title: "Dane")

                    SettingsTile {
                        Button("Resetuj dane aplikacji", role: .destructive) {
                            settings.playTapSound()
                            showResetConfirmation = true
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SettingsSectionFooter(
                        text: "Usuwa zapisane fiszki, postęp i przywraca domyślne ustawienia."
                    )
                }
                .padding()
            }
            .appScrollSurface()
            .navigationTitle("Ustawienia")
            .confirmationDialog(
                "Resetować wszystkie dane?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Resetuj", role: .destructive) {
                    settings.playTapSound()
                    resetApplicationData()
                }
                Button("Anuluj", role: .cancel) {
                    settings.playTapSound()
                }
            } message: {
                Text("Tej operacji nie można cofnąć.")
            }
            .alert("Dane zresetowane", isPresented: $resetDone) {
                Button("OK", role: .cancel) {
                    settings.playTapSound()
                }
            } message: {
                Text("Aplikacja została przywrócona do stanu początkowego.")
            }
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onChange(of: settings.trikiControllerEnabled) { _, isEnabled in
                if isEnabled {
                    showTrikiPairingSheet = true
                }
            }
            .sheet(isPresented: $showTrikiPairingSheet) {
                TrikiPairingSheet(
                    isEnabled: $settings.trikiControllerEnabled,
                    onClose: { showTrikiPairingSheet = false }
                )
            }
        }
    }

    private func resetApplicationData() {
        do {
            try modelContext.delete(model: Item.self)
            try modelContext.save()
        } catch {
            // Brak zapisanych danych — kontynuuj reset ustawień.
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            settings.resetToDefaults()
            thinkingPreferences.resetToDefaults()
            campaignStore.reset()
            savedGameStore.clearSave()
            playthroughStore.reset()
            Task {
                await llmService.unloadModel()
                await gameplayLLMService.unloadModel()
                thinkingService.masterEngine.unload()
            }
        }
        resetDone = true
    }
}

private struct TrikiPairingSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator

    @Binding var isEnabled: Bool
    let onClose: () -> Void

    private enum Step {
        case connecting
        case calibrate
        case done
    }

    @State private var step: Step = .connecting

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .connecting:
                    connectingContent
                case .calibrate:
                    TrikiCalibrationOverlay(showsSkip: false) {
                        step = .done
                    }
                case .done:
                    doneContent
                }
            }
            .navigationTitle("Parowanie Triki")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(step != .done)
            .onAppear {
                step = .connecting
                coordinator.beginConnectionHold()
            }
            .onDisappear {
                coordinator.endConnectionHold()
            }
            .onChange(of: coordinator.isBLEReceiving) { _, receiving in
                if receiving, step == .connecting {
                    step = .calibrate
                }
            }
            .onChange(of: coordinator.isBLEConnected) { _, connected in
                if !connected {
                    step = .connecting
                }
            }
        }
    }

    private var connectingContent: some View {
        VStack(spacing: 14) {
            Text(coordinator.connectionMessage.isEmpty ? "Szukam urządzeń BLE…" : coordinator.connectionMessage)
                .font(.headline.bold())
                .multilineTextAlignment(.center)

            Text("VeltoKit łączy się automatycznie z czapką „Triki” w nazwie BLE. Przy kolejnym uruchomieniu używa zapamiętanego urządzenia.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !coordinator.isBLEConnected {
                ProgressView()
                    .controlSize(.large)
                    .padding(.vertical, 8)
            }

            Button("Połącz (skan BLE)") {
                settings.playTapSound()
                coordinator.startScanningForPairing()
            }
            .buttonStyle(.appProminent)

            if coordinator.hasCachedBLEDevice {
                Button("Połącz z ostatnim urządzeniem") {
                    settings.playTapSound()
                    coordinator.connectToCachedDevice()
                }
                .buttonStyle(.appSecondary)
            }

            Button("Anuluj") {
                settings.playTapSound()
                isEnabled = false
                onClose()
            }
            .buttonStyle(.appSecondary)
        }
        .padding(24)
        .onAppear {
            coordinator.startScanningForPairing()
        }
    }

    private var doneContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            Text("Triki gotowy")
                .font(.headline.bold())

            Text("Kontroler jest sparowany i skalibrowany.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Gotowe") {
                settings.playTapSound()
                onClose()
            }
            .buttonStyle(.appProminent)
            .padding(.top, 6)
        }
        .padding(24)
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
        .environment(CampaignStore())
        .environment(ThinkingModelPreferences())
        .environment(CampaignLLMService())
        .environment(GameplayLLMService())
        .environment(MasterAlgorithmEngine())
        .environment(PlaythroughMemoryStore())
        .environment(SavedGameStore())
        .environment(
            GameplayThinkingService(
                preferences: ThinkingModelPreferences(),
                gameplayLLM: GameplayLLMService(),
                analysisLLM: CampaignLLMService(),
                masterEngine: MasterAlgorithmEngine(),
                playthroughStore: PlaythroughMemoryStore()
            )
        )
        .modelContainer(for: Item.self, inMemory: true)
        .environment(TrikiNavigationCoordinator())
}
