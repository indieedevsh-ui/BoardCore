//
//  ModelDownloadManager.swift
//  DmdApp
//

import Foundation

enum ModelDownloadError: LocalizedError {
    case invalidDownloadedFile(String)
    case downloadFailed(String)
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidDownloadedFile(let details): details
        case .downloadFailed(let details): details
        case .httpError(let statusCode):
            "Serwer zwrócił błąd HTTP \(statusCode). Spróbuj ponownie później."
        }
    }
}

@Observable
final class ModelDownloadManager: NSObject, URLSessionDownloadDelegate {
    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case finished
        case failed(String)
    }

    private(set) var state: State = .idle
    var onProgress: (@Sendable (Double) -> Void)?
    private var downloadSession: URLSession!
    private var resumeContinuation: CheckedContinuation<Void, Error>?
    private var didFinishSuccessfully = false
    private var currentURLIndex = 0
    private var downloadURLs: [URL] = []
    private var activeRole: LocalLLMModelRole = .analysis

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 60 * 60 * 8
        config.waitsForConnectivity = true
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func downloadModelIfNeeded(role: LocalLLMModelRole = .analysis) async throws {
        LocalLLMConfig.removeLegacyModels()
        activeRole = role

        if LocalLLMConfig.isModelOnDisk(role) {
            state = .finished
            return
        }

        try FileManager.default.createDirectory(at: LocalLLMConfig.modelsDirectory, withIntermediateDirectories: true)

        downloadURLs = [role.downloadURL] + role.fallbackURLs
        currentURLIndex = 0

        var lastError: Error = ModelDownloadError.downloadFailed("Nie udało się pobrać modelu.")

        while currentURLIndex < downloadURLs.count {
            state = .downloading(progress: 0)
            didFinishSuccessfully = false

            do {
                try await downloadFromCurrentURL()
                return
            } catch {
                lastError = error
                try? FileManager.default.removeItem(at: role.fileURL())
                currentURLIndex += 1
            }
        }

        throw lastError
    }

    private func downloadFromCurrentURL() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            resumeContinuation = continuation

            var request = URLRequest(url: downloadURLs[currentURLIndex])
            request.setValue("DmdApp/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")

            let task = downloadSession.downloadTask(with: request)
            task.resume()
        }
    }

    func removeDownloadedModel(role: LocalLLMModelRole = .analysis) throws {
        let destination = role.fileURL()
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        state = .idle
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ModelDownloadError.httpError(statusCode: http.statusCode)
            }

            let destination = activeRole.fileURL()

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(at: location, to: destination)

            let validation = LocalLLMConfig.validateModelFile(at: destination, role: activeRole)
            guard validation.isValid else {
                try? FileManager.default.removeItem(at: destination)
                throw ModelDownloadError.invalidDownloadedFile(validation.message)
            }

            didFinishSuccessfully = true
            state = .finished
            resumeContinuation?.resume()
            resumeContinuation = nil
        } catch {
            state = .failed(error.localizedDescription)
            resumeContinuation?.resume(throwing: error)
            resumeContinuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : activeRole.expectedSizeBytes
        let progress = min(1, Double(totalBytesWritten) / Double(expected))
        Task { @MainActor in
            state = .downloading(progress: progress)
            onProgress?(progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, !didFinishSuccessfully else { return }
        state = .failed(error.localizedDescription)
        resumeContinuation?.resume(throwing: ModelDownloadError.downloadFailed(error.localizedDescription))
        resumeContinuation = nil
    }
}
