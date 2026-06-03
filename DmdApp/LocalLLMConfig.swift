//
//  LocalLLMConfig.swift
//  DmdApp
//

import Foundation

enum LocalLLMModelRole: String, CaseIterable, Identifiable {
    case analysis
    case gameplay

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .analysis: "llama-2-7b-chat.Q3_K_M.gguf"
        case .gameplay: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
        }
    }

    var displayName: String {
        switch self {
        case .analysis: "Llama 2 7B Chat"
        case .gameplay: "TinyLlama 1.1B — interpretacja rozgrywki"
        }
    }

    var shortDescription: String {
        switch self {
        case .analysis: "Parsuje wklejoną kampanię (decyzje, wybory graczy)."
        case .gameplay: "Interpretuje zapisaną fabułę i wybory podczas gry."
        }
    }

    var downloadURL: URL {
        switch self {
        case .analysis:
            URL(string: "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.Q3_K_M.gguf")!
        case .gameplay:
            URL(string: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")!
        }
    }

    var fallbackURLs: [URL] {
        switch self {
        case .analysis:
            [
                URL(string: "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.Q4_K_M.gguf")!,
                URL(string: "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.Q4_0.gguf")!,
            ]
        case .gameplay:
            [URL(string: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf")!]
        }
    }

    var expectedSizeBytes: Int64 {
        switch self {
        case .analysis: 3_350_000_000
        case .gameplay: 668_788_096
        }
    }

    var minimumSizeBytes: Int64 {
        switch self {
        case .analysis: 3_000_000_000
        case .gameplay: 600_000_000
        }
    }

    var maxGenerationTokens: Int {
        switch self {
        case .analysis: 512
        case .gameplay: 384
        }
    }

    var loadProfiles: [LLMLoadProfile] {
        switch self {
        case .analysis:
            [
                LLMLoadProfile(name: "Llama 1280", contextLength: 1280, batchSize: 12, microBatchSize: 12, threads: 4),
                LLMLoadProfile(name: "Llama 1024", contextLength: 1024, batchSize: 8, microBatchSize: 8, threads: 3),
                LLMLoadProfile(name: "Llama 768", contextLength: 768, batchSize: 8, microBatchSize: 8, threads: 2),
                LLMLoadProfile(name: "Llama 512", contextLength: 512, batchSize: 8, microBatchSize: 8, threads: 2),
            ]
        case .gameplay:
            [
                LLMLoadProfile(name: "TinyLlama 512", contextLength: 512, batchSize: 16, microBatchSize: 16, threads: 2),
                LLMLoadProfile(name: "TinyLlama 384", contextLength: 384, batchSize: 8, microBatchSize: 8, threads: 2),
            ]
        }
    }

    func fileURL(in directory: URL = LocalLLMConfig.modelsDirectory) -> URL {
        directory.appendingPathComponent(fileName)
    }
}

enum LocalLLMConfig {
    static let minimumFreeMemoryBytes: UInt64 = 650_000_000

    /// Profile dopasowane do wolnej pamięci — bez rezerwowania maksymalnego kontekstu.
    static func adaptiveLoadProfiles(for role: LocalLLMModelRole) -> [LLMLoadProfile] {
        guard role == .analysis else { return role.loadProfiles }

        let budget = DeviceMemory.llamaContextMemoryBudgetBytes
        let candidates = role.loadProfiles

        func estimatedContextBytes(_ profile: LLMLoadProfile) -> UInt64 {
            UInt64(profile.contextLength) * 1_100_000 + UInt64(profile.batchSize) * 64_000
        }

        let fitting = candidates.filter { estimatedContextBytes($0) <= budget }
        if !fitting.isEmpty {
            return fitting
        }
        return Array(candidates.suffix(2))
    }

    static let legacyModelFileNames = [
        "mistral-7b-instruct-v0.2.Q2_K.gguf",
        "mistral-7b-instruct-v0.2.Q3_K_S.gguf",
        "llama-2-7b-chat.Q2_K.gguf",
        "llama-2-7b-chat.Q4_K_M.gguf",
        "Llama-3.2-3B-Instruct-Q3_K_L.gguf",
        "Llama-3.2-3B-Instruct-Q3_K_S.gguf",
        "Llama-3.2-3B-Instruct-IQ3_M.gguf",
    ]

    static var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Models", isDirectory: true)
    }

    // MARK: - Analysis (Llama 7B) — backward-compatible accessors

    static let modelFileName = LocalLLMModelRole.analysis.fileName
    static let modelDisplayName = LocalLLMModelRole.analysis.displayName
    static let modelDownloadURL = LocalLLMModelRole.analysis.downloadURL
    static let modelDownloadFallbackURLs = LocalLLMModelRole.analysis.fallbackURLs
    static let expectedModelSizeBytes = LocalLLMModelRole.analysis.expectedSizeBytes
    static let minimumModelSizeBytes = LocalLLMModelRole.analysis.minimumSizeBytes
    static let maxGenerationTokens = LocalLLMModelRole.analysis.maxGenerationTokens
    static let loadProfiles = LocalLLMModelRole.analysis.loadProfiles

    static var modelFileURL: URL {
        LocalLLMModelRole.analysis.fileURL()
    }

    static var isModelOnDisk: Bool {
        isModelOnDisk(.analysis)
    }

    static func isModelOnDisk(_ role: LocalLLMModelRole) -> Bool {
        validateModelFile(at: role.fileURL(), role: role).isValid
    }

    static func modelFileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    static func removeLegacyModels() {
        for name in legacyModelFileNames {
            let url = modelsDirectory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    static func validateModelFile(at url: URL, role: LocalLLMModelRole = .analysis) -> ModelValidationResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }

        let size = modelFileSize(at: url)
        guard size >= role.minimumSizeBytes else {
            return .tooSmall(size)
        }

        guard hasGGUFMagic(at: url) else {
            return .invalidFormat(size)
        }

        return .valid(size)
    }

    private static func hasGGUFMagic(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 4), data.count == 4 else { return false }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return magic == 0x4655_4747
    }
}

struct LLMLoadProfile {
    let name: String
    let contextLength: UInt32
    let batchSize: UInt32
    let microBatchSize: UInt32
    let threads: Int32
}

enum ModelValidationResult: Equatable {
    case missing
    case tooSmall(Int64)
    case invalidFormat(Int64)
    case valid(Int64)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .missing:
            "Brak pliku modelu."
        case .tooSmall(let size):
            if size < 1024 {
                "Serwer zwrócił błąd zamiast pliku modelu (\(size) B). Sprawdź połączenie i spróbuj ponownie."
            } else {
                "Plik jest za mały (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))) — pobieranie mogło się przerwać."
            }
        case .invalidFormat(let size):
            "Plik nie jest poprawnym GGUF (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))). Usuń go i pobierz ponownie."
        case .valid(let size):
            "Plik poprawny: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))."
        }
    }
}
