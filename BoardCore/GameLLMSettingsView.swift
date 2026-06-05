//
//  GameLLMSettingsView.swift
//  BoardCore
//

import SwiftUI

struct GameLLMSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CampaignLLMService.self) private var llmService
    @Environment(GameplayLLMService.self) private var gameplayLLMService

    @State private var showUninstallConfirmation = false

    private var isOnDisk: Bool { llmService.modelIsOnDisk }
    private var isLoaded: Bool { llmService.isReady }
    private var isBusy: Bool {
        switch llmService.status {
        case .downloading, .loadingModel, .analyzing: true
        default: false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statusCard
                actionButtons
                infoSection
            }
            .padding()
        }
        .appScrollSurface()
        .navigationTitle("LLM Gry")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            llmService.refreshModelValidation()
        }
        .confirmationDialog(
            "Odinstalować Llama 7B?",
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Odinstaluj", role: .destructive) {
                settings.playTapSound()
                Task {
                    await gameplayLLMService.unloadModel()
                    await llmService.removeModelAndReset()
                }
            }
            Button("Anuluj", role: .cancel) {
                settings.playTapSound()
            }
        } message: {
            Text("Plik modelu (~3,3 GB) zostanie usunięty z urządzenia. Analiza kampanii będzie działać tylko przez parser i Algorytm Mistrza.")
        }
        .appThemedScreen()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Llama 2 7B Chat", systemImage: "sparkles")
                .font(.title2.bold())
            Text("Model współpracuje z Algorytmem Mistrza przy analizie wklejonej kampanii. Wagi ładują się tylko na czas analizy — nie zajmują całej pamięci urządzenia.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusRow(title: "Plik na dysku", value: isOnDisk ? "Tak" : "Nie", positive: isOnDisk)
            statusRow(title: "W pamięci RAM", value: isLoaded ? "Załadowany" : "Zwolniony", positive: !isLoaded)

            Text(llmService.modelFileSizeLabel)
                .font(.subheadline)
                .foregroundStyle(isOnDisk ? .green : .secondary)

            if case .downloading(let progress) = llmService.status {
                ProgressView(value: progress)
                Text("Pobieranie: \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .loadingModel = llmService.status {
                ProgressView()
                Text("Ładowanie wag…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .analyzing = llmService.status {
                ProgressView()
                Text("Analiza kampanii…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !llmService.loadedProfileName.isEmpty {
                Text("Profil: \(llmService.loadedProfileName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Wolna pamięć: \(DeviceMemory.availableLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !llmService.lastAnalysisSummary.isEmpty {
                Text(llmService.lastAnalysisSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if case .error(let message) = llmService.status {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusRow(title: String, value: String, positive: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(positive ? .green : .secondary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if !isOnDisk {
            Button {
                settings.playTapSound()
                Task { await llmService.downloadModelToDisk() }
            } label: {
                Label("Pobierz Llama 7B", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.appProminent)
            .disabled(isBusy)
        } else {
            if isLoaded {
                Button {
                    settings.playTapSound()
                    Task { await llmService.unloadModel() }
                } label: {
                    Label("Zwolnij RAM", systemImage: "memorychip")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.appSecondary)
                .disabled(isBusy)
            }

            Button(role: .destructive) {
                settings.playTapSound()
                showUninstallConfirmation = true
            } label: {
                Label("Odinstaluj Llama 7B", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.appSecondary)
            .disabled(isBusy)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Optymalizacja")
                .font(.headline)
            Text("• Wariant Q3_K_M (~3,3 GB) — szybszy i lżejszy niż Q4")
            Text("• Kontekst dopasowany do wolnej RAM (do ~1280 tokenów)")
            Text("• Wagi przez mmap — nie rezerwują całych 12 GB")
            Text("• Po analizie model można zwolnić przyciskiem powyżej")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        GameLLMSettingsView()
            .environment(AppSettings())
            .environment(CampaignLLMService())
            .environment(GameplayLLMService())
    }
}
