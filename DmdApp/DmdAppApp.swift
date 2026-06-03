//
//  DmdAppApp.swift
//  DmdApp
//
//  Created by Michał Wołtosz on 30/05/2026.
//

import SwiftUI
import SwiftData

@main
struct DmdAppApp: App {
    @State private var appSettings: AppSettings
    @State private var campaignStore: CampaignStore
    @State private var thinkingPreferences: ThinkingModelPreferences
    @State private var campaignLLMService: CampaignLLMService
    @State private var gameplayLLMService: GameplayLLMService
    @State private var masterAlgorithmEngine: MasterAlgorithmEngine
    @State private var playthroughMemoryStore: PlaythroughMemoryStore
    @State private var gameplayThinkingService: GameplayThinkingService
    @State private var savedGameStore: SavedGameStore
    @State private var creatorStore: CreatorStore
    @State private var playerSlotStore: PlayerSlotStore
    @State private var trikiDiagnostics = TrikiControllerDiagnosticsStore()
    @State private var trikiNavigation = TrikiNavigationCoordinator()

    init() {
        let appSettings = AppSettings()
        AppAppearance.configure()
        let campaignStore = CampaignStore()
        let thinkingPreferences = ThinkingModelPreferences()
        let campaignLLMService = CampaignLLMService()
        let gameplayLLMService = GameplayLLMService()
        let masterAlgorithmEngine = MasterAlgorithmEngine()
        let playthroughMemoryStore = PlaythroughMemoryStore()
        let savedGameStore = SavedGameStore()
        let creatorStore = CreatorStore()
        let playerSlotStore = PlayerSlotStore()

        _appSettings = State(initialValue: appSettings)
        _campaignStore = State(initialValue: campaignStore)
        _thinkingPreferences = State(initialValue: thinkingPreferences)
        _campaignLLMService = State(initialValue: campaignLLMService)
        _gameplayLLMService = State(initialValue: gameplayLLMService)
        _masterAlgorithmEngine = State(initialValue: masterAlgorithmEngine)
        _playthroughMemoryStore = State(initialValue: playthroughMemoryStore)
        _savedGameStore = State(initialValue: savedGameStore)
        _creatorStore = State(initialValue: creatorStore)
        _playerSlotStore = State(initialValue: playerSlotStore)
        _gameplayThinkingService = State(
            initialValue: GameplayThinkingService(
                preferences: thinkingPreferences,
                gameplayLLM: gameplayLLMService,
                analysisLLM: campaignLLMService,
                masterEngine: masterAlgorithmEngine,
                playthroughStore: playthroughMemoryStore
            )
        )
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
                .environment(campaignStore)
                .environment(thinkingPreferences)
                .environment(campaignLLMService)
                .environment(gameplayLLMService)
                .environment(masterAlgorithmEngine)
                .environment(playthroughMemoryStore)
                .environment(gameplayThinkingService)
                .environment(savedGameStore)
                .environment(creatorStore)
                .environment(playerSlotStore)
                .environment(trikiDiagnostics)
                .environment(trikiNavigation)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
