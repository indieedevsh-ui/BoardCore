//
//  UploadCampaignView.swift
//  BoardCore
//

import SwiftUI

struct UploadCampaignView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CampaignStore.self) private var campaignStore
    @Environment(CampaignLLMService.self) private var llmService
    @Environment(GameplayLLMService.self) private var gameplayLLMService
    @Environment(GameplayThinkingService.self) private var thinkingService

    @State private var draftText = ""
    @State private var llmPreview: ParsedCampaign?
    @State private var copiedPrompt = false
    @State private var savedConfirmation = false
    @State private var isSaving = false
    @State private var isPasteSectionExpanded = false
    @State private var isPromptSectionExpanded = false
    @State private var savedSceneCount = 0
    @State private var savedDecisionCount = 0

    var body: some View {
        @Bindable var campaignStore = campaignStore

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                climateSection(selection: $campaignStore.climate)
                promptSection(prompt: campaignStore.generatedPrompt)
                pasteSection
                llmAnalysisSection
                previewSection
                saveSection
            }
            .padding()
        }
        .appScrollSurface()
        .navigationTitle("Wgraj kampanię")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draftText = campaignStore.rawText
            isPasteSectionExpanded = false
            isPromptSectionExpanded = false
        }
        .alert("Prompt skopiowany", isPresented: $copiedPrompt) {
            Button("OK", role: .cancel) {
                settings.playTapSound()
            }
        }
        .alert("Kampania zapisana", isPresented: $savedConfirmation) {
            Button("OK", role: .cancel) {
                settings.playTapSound()
            }
        } message: {
            Text("Wykryto \(savedSceneCount) scen i \(savedDecisionCount) decyzji w kampanii „\(campaignStore.title)”.")
        }
        .appThemedScreen()
    }

    private func promptSection(prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            promptSectionHeader

            Text("Skopiuj prompt, wklej go w ChatGPT i wygeneruj kampanię w wymaganym formacie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isPromptSectionExpanded {
                Text(prompt)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                promptSectionToggleButton(expanded: true)
            } else {
                promptSectionCollapsedSummary(prompt: prompt)
                promptSectionToggleButton(expanded: false)
            }

            Button {
                settings.playTapSound()
                UIPasteboard.general.string = prompt
                copiedPrompt = true
            } label: {
                Label("Kopiuj prompt", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.appProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isPromptSectionExpanded)
    }

    private var promptSectionHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Prompt do ChatGPT")
                .font(.title2.bold())

            Spacer(minLength: 8)

            if isPromptSectionExpanded {
                Button {
                    settings.playTapSound()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isPromptSectionExpanded = false
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.appSecondary)
                .controlSize(.small)
                .accessibilityLabel("Zwiń prompt")
            }
        }
    }

    private func promptSectionCollapsedSummary(prompt: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.quote")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Prompt zwinięty")
                    .font(.subheadline.bold())
                Text("\(prompt.count) znaków · dotknij ⋯ aby rozwinąć podgląd")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func promptSectionToggleButton(expanded: Bool) -> some View {
        Button {
            settings.playTapSound()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                isPromptSectionExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                Text(expanded ? "Zwiń" : "Rozwiń")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.appSecondary)
    }

    private func climateSection(selection: Binding<CampaignClimate>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Klimat kampanii")
                .font(.title2.bold())

            Text("Wybierz klimat — prompt poniżej zaktualizuje się automatycznie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Klimat", selection: selection) {
                ForEach(CampaignClimate.allCases) { climate in
                    Text(climate.title).tag(climate)
                }
            }
            .pickerStyle(.menu)

            Text(selection.wrappedValue.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            pasteSectionHeader

            if isPasteSectionExpanded {
                Text("Wklej tutaj gotową kampanię z ChatGPT: głęboka narracja (>>SCENY<<) oraz wybory (max \(CampaignPromptBuilder.choicesPerPlayer) opcji × \(CampaignPromptBuilder.playerCount) graczy przy każdej decyzji).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                TextEditor(text: $draftText)
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))

                if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Pole jest puste — wklej wygenerowaną kampanię lub użyj przycisku wklejania.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                pasteSectionCollapsedSummary
                pasteSectionToggleButton(expanded: false)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isPasteSectionExpanded)
    }

    private var pasteSectionHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Wklej kampanię")
                .font(.title2.bold())

            Spacer(minLength: 8)

            if isPasteSectionExpanded {
                HStack(spacing: 8) {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("Wklej tekst ze schowka")

                    Button {
                        settings.playTapSound()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            isPasteSectionExpanded = false
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Zwiń pole")

                    Button(role: .destructive) {
                        clearDraftText()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Wyczyść pole")
                }
                .buttonStyle(.appSecondary)
                .controlSize(.small)
            }
        }
    }

    private var pasteSectionCollapsedSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: pasteSectionHasContent ? "doc.text.fill" : "doc.text")
                .foregroundStyle(pasteSectionHasContent ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(pasteSectionHasContent ? "Tekst kampanii w polu" : "Pole zwinięte")
                    .font(.subheadline.bold())
                Text(pasteSectionStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func pasteSectionToggleButton(expanded: Bool) -> some View {
        Button {
            settings.playTapSound()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                isPasteSectionExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                Text(expanded ? "Zwiń" : "Rozwiń")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.appSecondary)
    }

    private var pasteSectionHasContent: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var pasteSectionStatusText: String {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Dotknij ⋯ na dole, aby wkleić lub edytować kampanię."
        }
        let characters = draftText.count
        let preview = currentPreview
        return "\(characters) znaków · \(preview.scenes.count) scen · \(preview.decisions.count) decyzji"
    }

    private func pasteFromClipboard() {
        settings.playTapSound()
        guard let clipboard = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty
        else { return }

        draftText = clipboard
        llmPreview = nil
    }

    private func clearDraftText() {
        settings.playTapSound()
        draftText = ""
        llmPreview = nil
    }

    private var llmAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analiza lokalnym LLM")
                .font(.title2.bold())

            Text("Llama 7B współpracuje z Algorytmem Mistrza — parser wykrywa wszystkie decyzje, Mistrz indeksuje, Llama uzupełnia zarys (analiza może potrwać kilkadziesiąt sekund).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if case .downloading(let progress) = llmService.status {
                ProgressView(value: progress)
                Text("Pobieranie modelu: \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .analyzing = llmService.status {
                ProgressView()
                Text("Llama analizuje kampanię…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                settings.playTapSound()
                Task {
                    if !llmService.isReady {
                        await llmService.prepareModel(unloadingGameplayFrom: gameplayLLMService)
                    }
                    let parserResult = CampaignParser.parse(draftText)
                    let parsed = await llmService.analyzeCampaignWithMaster(
                        draftText,
                        masterEngine: thinkingService.masterEngine
                    )
                    llmPreview = MasterLlamaCollaboration.mergeCampaign(parser: parserResult, llm: parsed)
                    await llmService.unloadModel()
                }
            } label: {
                Label("Analizuj (Mistrz + Llama)", systemImage: "brain.head.profile")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.appSecondary)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            NavigationLink {
                GameLLMSettingsView()
            } label: {
                Label("LLM Gry — pobierz / odinstaluj", systemImage: "cpu")
                    .font(.subheadline)
            }
        }
    }

    private var parserPreview: ParsedCampaign {
        CampaignParser.parse(draftText)
    }

    private var currentPreview: ParsedCampaign {
        MasterLlamaCollaboration.resolvedPreview(parser: parserPreview, llm: llmPreview)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Podgląd decyzji")
                .font(.title2.bold())

            let preview = currentPreview

            if preview.decisions.isEmpty && preview.scenes.isEmpty {
                Text("Nie wykryto jeszcze treści. Upewnij się, że kampania ma >>SCENY<<, >>DECYZJE<< oraz nagłówki * [DECYZJA N | SCENA M] * przy każdej decyzji.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tytuł: \(preview.title)")
                    .font(.headline)

                if !preview.scenes.isEmpty {
                    Text("Sceny narracji: \(preview.scenes.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(preview.decisions.enumerated()), id: \.element.id) { index, decision in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Decyzja \(index + 1) — \(decision.sceneTitle)")
                            .font(.subheadline.bold())
                        Text(decision.question)
                            .font(.subheadline)
                        if decision.choicesByPlayer.isEmpty {
                            ForEach(Array(decision.alternatives.enumerated()), id: \.offset) { altIndex, alternative in
                                Text("\(altIndex + 1)) \(alternative)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(Array(decision.choicesByPlayer.enumerated()), id: \.offset) { playerIndex, choices in
                                Text("Gracz \(playerIndex + 1) (\(choices.count) wyborów)")
                                    .font(.caption.bold())
                                ForEach(Array(choices.enumerated()), id: \.offset) { choiceIndex, choice in
                                    Text("\(choiceIndex + 1)) \(choice)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var saveSection: some View {
        VStack(spacing: 8) {
            Button {
                settings.playTapSound()
                guard !isSaving else { return }
                isSaving = true
                let text = draftText
                Task { @MainActor in
                    let parserResult = CampaignParser.parse(text)
                    var preview = parserResult
                    if llmService.isReady || thinkingService.masterEngine.isReady {
                        let enriched = await llmService.analyzeCampaignWithMaster(
                            text,
                            masterEngine: thinkingService.masterEngine
                        )
                        preview = MasterLlamaCollaboration.mergeCampaign(parser: parserResult, llm: enriched)
                    }
                    savedSceneCount = preview.scenes.count
                    savedDecisionCount = preview.decisions.count
                    await campaignStore.saveCampaign(text: text, parsed: preview)
                    llmPreview = preview
                    await llmService.unloadModel()
                    isSaving = false
                    savedConfirmation = true
                    Task(priority: .utility) {
                        await thinkingService.rebuildMasterIndex(for: preview)
                    }
                }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Zapisz kampanię")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.appProminent)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

            if isSaving {
                Text("Zapisuję kampanię…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        UploadCampaignView()
            .environment(AppSettings())
            .environment(CampaignStore())
            .environment(
                GameplayThinkingService(
                    preferences: ThinkingModelPreferences(),
                    gameplayLLM: GameplayLLMService(),
                    analysisLLM: CampaignLLMService(),
                    masterEngine: MasterAlgorithmEngine(),
                    playthroughStore: PlaythroughMemoryStore()
                )
            )
            .environment(ThinkingModelPreferences())
    }
}
