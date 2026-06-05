//
//  LlamaCampaignEngine.swift
//  BoardCore
//

import Foundation
import LlamaSwift

enum LlamaEngineError: LocalizedError {
    case modelNotFound(String)
    case invalidModelFile(String)
    case loadFailed(String)
    case contextFailed(String)
    case tokenizationFailed
    case decodeFailed
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let details): details
        case .invalidModelFile(let details): details
        case .loadFailed(let details): details
        case .contextFailed(let details): details
        case .tokenizationFailed: "Błąd tokenizacji tekstu kampanii."
        case .decodeFailed: "Błąd inferencji modelu."
        case .emptyOutput: "Model nie zwrócił odpowiedzi."
        }
    }
}

private struct LoadedLlamaHandles {
    let model: OpaquePointer
    let context: OpaquePointer
    let sampler: UnsafeMutablePointer<llama_sampler>
    let profileName: String
    let maxBatch: Int32
}

private enum LlamaBackend {
    private static let lock = NSLock()
    private static var initialized = false

    static func ensureInitialized() {
        lock.lock()
        defer { lock.unlock() }
        guard !initialized else { return }
        LlamaLog.configureIfNeeded()
        llama_backend_init()
        ggml_numa_init(GGML_NUMA_STRATEGY_DISABLED)
        initialized = true
    }
}

actor LlamaCampaignEngine {
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private var maxBatchSize: Int32 = 16
    private(set) var activeProfileName = ""
    private(set) var loadedRole: LocalLLMModelRole?

    var isLoaded: Bool { model != nil && context != nil && sampler != nil }

    func load(role: LocalLLMModelRole = .analysis) async throws {
        if isLoaded, loadedRole == role { return }
        unload()

        let modelURL = role.fileURL()
        let validation = LocalLLMConfig.validateModelFile(at: modelURL, role: role)
        guard validation.isValid else {
            throw LlamaEngineError.invalidModelFile(validation.message)
        }

        try DeviceMemory.ensureEnoughForModelLoad()

        let loadedModel = try await Task.detached(priority: .userInitiated) {
            try Self.loadModelWeights(from: modelURL)
        }.value

        var contextErrors: [String] = []

        for profile in LocalLLMConfig.adaptiveLoadProfiles(for: role) {
            freeContextAndSampler()

            do {
                let contextBundle = try Self.createContext(
                    model: loadedModel,
                    profile: profile
                )
                model = loadedModel
                context = contextBundle.context
                sampler = contextBundle.sampler
                maxBatchSize = contextBundle.maxBatch
                activeProfileName = profile.name
                loadedRole = role
                return
            } catch {
                contextErrors.append("\(profile.name): \(error.localizedDescription)")
            }
        }

        llama_model_free(loadedModel)
        throw LlamaEngineError.contextFailed(
            "Wczytano wagi, ale brak RAM na kontekst.\n" + contextErrors.joined(separator: "\n")
        )
    }

    func load() async throws {
        try await load(role: .analysis)
    }

    private static func loadModelWeights(from url: URL) throws -> OpaquePointer {
        LlamaBackend.ensureInitialized()

        let strategies: [(label: String, useMmap: Bool)] = [
            ("mmap", llama_supports_mmap()),
            ("bez-mmap", false),
        ]

        var errors: [String] = []

        for strategy in strategies where strategy.useMmap || strategy.label == "bez-mmap" {
            LlamaLog.reset()

            var modelParams = llama_model_default_params()
            modelParams.n_gpu_layers = 0
            modelParams.use_mmap = strategy.useMmap
            modelParams.use_mlock = false
            modelParams.check_tensors = false
            modelParams.vocab_only = false

            let loaded: OpaquePointer? = url.withUnsafeFileSystemRepresentation { cPath in
                guard let cPath else { return nil }
                return llama_model_load_from_file(cPath, modelParams)
            }

            if let loaded {
                return loaded
            }

            let hint = LlamaLog.recentSummary
            errors.append(
                hint.isEmpty
                    ? "\(strategy.label): nie wczytano wag"
                    : "\(strategy.label): \(hint)"
            )
        }

        throw LlamaEngineError.loadFailed(
            "Nie udało się wczytać wag modelu.\n" + errors.joined(separator: "\n")
        )
    }

    private static func createContext(
        model: OpaquePointer,
        profile: LLMLoadProfile
    ) throws -> (context: OpaquePointer, sampler: UnsafeMutablePointer<llama_sampler>, maxBatch: Int32) {
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = profile.contextLength
        contextParams.n_batch = profile.batchSize
        contextParams.n_ubatch = profile.microBatchSize
        contextParams.n_threads = profile.threads
        contextParams.n_threads_batch = profile.threads
        contextParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED
        contextParams.offload_kqv = false
        contextParams.no_perf = true
        contextParams.type_k = GGML_TYPE_Q4_0
        contextParams.type_v = GGML_TYPE_Q4_0

        guard let loadedContext = llama_init_from_model(model, contextParams) else {
            throw LlamaEngineError.contextFailed("Brak RAM na kontekst \(profile.contextLength).")
        }

        var samplerParams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(samplerParams) else {
            llama_free(loadedContext)
            throw LlamaEngineError.contextFailed("Błąd sampler'a.")
        }

        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(0.15))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(42))

        return (loadedContext, chain, Int32(profile.batchSize))
    }

    func unload() {
        freeContextAndSampler()
        if let model {
            llama_model_free(model)
            self.model = nil
        }
        activeProfileName = ""
        loadedRole = nil
        maxBatchSize = 16
    }

    private func freeContextAndSampler() {
        if let sampler {
            llama_sampler_free(sampler)
            self.sampler = nil
        }
        if let context {
            llama_free(context)
            self.context = nil
        }
    }

    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil
    ) throws -> String {
        guard let context, let model, let sampler else {
            throw LlamaEngineError.loadFailed("Model nie jest załadowany.")
        }

        guard let role = loadedRole else {
            throw LlamaEngineError.loadFailed("Nieznany typ załadowanego modelu.")
        }

        guard let vocab = llama_model_get_vocab(model) else {
            throw LlamaEngineError.loadFailed("Brak słownika modelu.")
        }

        llama_memory_clear(llama_get_memory(context), true)

        let tokenLimit = maxTokens ?? role.maxGenerationTokens
        let formattedPrompt = LocalLLMPromptFormatter.wrap(
            userPrompt: prompt,
            systemPrompt: systemPrompt,
            role: role
        )
        let tokens = tokenize(text: formattedPrompt, vocab: vocab, addBOS: true)
        guard !tokens.isEmpty else { throw LlamaEngineError.tokenizationFailed }

        let batchCapacity = Int32(max(tokens.count + 8, Int(maxBatchSize)))
        var batch = llama_batch_init(batchCapacity, 0, 1)
        defer { llama_batch_free(batch) }

        var output = ""
        var nCur = Int32(0)

        for (index, token) in tokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            if let seqID = batch.seq_id[index] {
                seqID[0] = 0
            }
            batch.logits[index] = index == tokens.count - 1 ? 1 : 0
        }
        batch.n_tokens = Int32(tokens.count)

        if llama_decode(context, batch) != 0 {
            throw LlamaEngineError.decodeFailed
        }

        nCur = batch.n_tokens
        var lastBatchIndex = batch.n_tokens - 1

        for _ in 0..<tokenLimit {
            let newToken = llama_sampler_sample(sampler, context, lastBatchIndex)

            if llama_vocab_is_eog(vocab, newToken) {
                break
            }

            if let piece = tokenToPiece(token: newToken, vocab: vocab) {
                output += piece
            }

            batch.n_tokens = 0
            batch.token[0] = newToken
            batch.pos[0] = nCur
            batch.n_seq_id[0] = 1
            if let seqID = batch.seq_id[0] {
                seqID[0] = 0
            }
            batch.logits[0] = 1
            batch.n_tokens = 1
            lastBatchIndex = 0

            if llama_decode(context, batch) != 0 {
                throw LlamaEngineError.decodeFailed
            }
            nCur += 1
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LlamaEngineError.emptyOutput }
        return trimmed
    }

    private func tokenize(text: String, vocab: OpaquePointer, addBOS: Bool) -> [llama_token] {
        let byteCount = Int32(text.utf8.count)
        let capacity = Int(byteCount) + 32
        let buffer = UnsafeMutablePointer<llama_token>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        let count = text.withCString { cString in
            llama_tokenize(
                vocab,
                cString,
                byteCount,
                buffer,
                Int32(capacity),
                addBOS,
                true
            )
        }

        guard count > 0 else { return [] }
        return (0..<Int(count)).map { buffer[$0] }
    }

    private func tokenToPiece(token: llama_token, vocab: OpaquePointer) -> String? {
        var buffer = [CChar](repeating: 0, count: 32)
        var length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)

        if length < 0 {
            let size = Int(-length)
            var bigBuffer = [CChar](repeating: 0, count: size)
            length = llama_token_to_piece(vocab, token, &bigBuffer, Int32(size), 0, false)
            guard length > 0 else { return nil }
            return String(cString: bigBuffer)
        }

        guard length > 0 else { return nil }
        return String(cString: Array(buffer.prefix(Int(length))) + [0])
    }
}

enum LocalLLMPromptFormatter {
    static func wrap(userPrompt: String, systemPrompt: String?, role: LocalLLMModelRole) -> String {
        switch role {
        case .analysis:
            return Llama2PromptFormatter.wrap(userPrompt: userPrompt, systemPrompt: systemPrompt)
        case .gameplay:
            return TinyLlamaPromptFormatter.wrap(userPrompt: userPrompt, systemPrompt: systemPrompt)
        }
    }
}

enum Llama2PromptFormatter {
    static func wrap(userPrompt: String, systemPrompt: String? = nil) -> String {
        let system = systemPrompt ?? "Jesteś precyzyjnym parserem kampanii RPG dla 4 graczy. Odpowiadasz wyłącznie poprawnym JSON-em po polsku."
        return """
        <s>[INST] <<SYS>>
        \(system)
        <</SYS>>

        \(userPrompt) [/INST]
        """
    }
}

enum TinyLlamaPromptFormatter {
    static func wrap(userPrompt: String, systemPrompt: String? = nil) -> String {
        let system = systemPrompt ?? "Jesteś narratorem gry RPG. Opowiadasz po polsku, zwięźle i klimatycznie, trzymając się fabuły kampanii."
        return """
        <|system|>
        \(system)<|user|>
        \(userPrompt)<|assistant|>

        """
    }
}
