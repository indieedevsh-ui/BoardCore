//
//  LlamaLog.swift
//  BoardCore
//

import Foundation
import LlamaSwift

private final class LlamaLogStorage: @unchecked Sendable {
    static let shared = LlamaLogStorage()
    private let lock = NSLock()
    private var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        messages.append(message)
        if messages.count > 12 {
            messages.removeFirst(messages.count - 12)
        }
        lock.unlock()
    }

    func reset() {
        lock.lock()
        messages.removeAll()
        lock.unlock()
    }

    var summary: String {
        lock.lock()
        defer { lock.unlock() }
        guard !messages.isEmpty else { return "" }
        return messages.suffix(3).joined(separator: " | ")
    }
}

private func llamaLogCallback(
    level: ggml_log_level,
    text: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let text else { return }
    let message = String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }
    LlamaLogStorage.shared.append(message)
}

enum LlamaLog {
    private static var isConfigured = false
    private static let configureLock = NSLock()

    static func configureIfNeeded() {
        configureLock.lock()
        defer { configureLock.unlock() }
        guard !isConfigured else { return }
        llama_log_set(llamaLogCallback, nil)
        isConfigured = true
    }

    static func reset() {
        LlamaLogStorage.shared.reset()
    }

    static var recentSummary: String {
        LlamaLogStorage.shared.summary
    }
}
