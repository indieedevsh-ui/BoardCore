//
//  ThinkingModelPreferences.swift
//  DmdApp
//

import Foundation
import Observation

enum GameplayThinkingModel: String, CaseIterable, Identifiable, Codable {
    case masterAlgorithm
    case tinyLlama
    case llama7B

    var id: String { rawValue }

    var title: String {
        switch self {
        case .masterAlgorithm: "Algorytm Mistrza"
        case .tinyLlama: "TinyLlama 1.1B"
        case .llama7B: "Llama 2 7B"
        }
    }

    var subtitle: String {
        switch self {
        case .masterAlgorithm:
            "Deterministyczny indeks + Llama 7B · najlepsza interpretacja tekstu z ChatGPT"
        case .tinyLlama:
            "Lokalny LLM (~637 MB) · interpretacja narracji podczas gry"
        case .llama7B:
            "Lokalny LLM (~3,3 GB) · analiza kampanii"
        }
    }

    var requiresDownload: Bool {
        switch self {
        case .masterAlgorithm: false
        case .tinyLlama, .llama7B: true
        }
    }

    var llmRole: LocalLLMModelRole? {
        switch self {
        case .masterAlgorithm: nil
        case .tinyLlama: .gameplay
        case .llama7B: .analysis
        }
    }

    var systemImage: String {
        switch self {
        case .masterAlgorithm: "crown.fill"
        case .tinyLlama: "hare.fill"
        case .llama7B: "sparkles"
        }
    }
}

@Observable
final class ThinkingModelPreferences {
    private static let selectedModelKey = "gameplayThinkingModel"

    var selectedModel: GameplayThinkingModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: Self.selectedModelKey)
        }
    }

    init() {
        var raw = UserDefaults.standard.string(forKey: Self.selectedModelKey) ?? GameplayThinkingModel.masterAlgorithm.rawValue
        if raw == "mistral7B" {
            raw = GameplayThinkingModel.llama7B.rawValue
        }
        selectedModel = GameplayThinkingModel(rawValue: raw) ?? .masterAlgorithm
    }

    func resetToDefaults() {
        selectedModel = .masterAlgorithm
    }
}
