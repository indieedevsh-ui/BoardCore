//
//  PassiveQRCodeMonitor.swift
//  BoardCore
//

import AVFoundation
import SwiftUI
import Vision

/// Pasywne skanowanie QR w rozgrywce — bez podglądu kamery.
struct PassiveQRCodeMonitor: UIViewRepresentable {
    let isEnabled: Bool
    let cameraPosition: QRScanCameraPosition
    let onGameplayCode: (QRGameplayScanResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onGameplayCode: onGameplayCode)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onGameplayCode = onGameplayCode
        context.coordinator.updateCameraPosition(cameraPosition)
        if isEnabled {
            context.coordinator.startIfNeeded()
        } else {
            context.coordinator.stop()
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onGameplayCode: (QRGameplayScanResult) -> Void

        private let session = AVCaptureSession()
        private let visionQueue = DispatchQueue(label: "dmd.passive.qr", qos: .userInitiated)
        private var isConfigured = false
        private var isRunning = false
        private var cameraPosition: QRScanCameraPosition = .front
        private var appliedCameraPosition: QRScanCameraPosition?
        private var lastDetectionAt = Date.distantPast
        private var lastOCRAt = Date.distantPast
        private weak var hostView: UIView?

        init(onGameplayCode: @escaping (QRGameplayScanResult) -> Void) {
            self.onGameplayCode = onGameplayCode
        }

        func attach(to view: UIView) {
            hostView = view
        }

        func updateCameraPosition(_ position: QRScanCameraPosition) {
            cameraPosition = position
            guard isConfigured, appliedCameraPosition != position else { return }
            reconfigureCameraInput()
        }

        func startIfNeeded() {
            guard !isRunning else { return }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                break
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        self?.startIfNeeded()
                    }
                }
                return
            default:
                return
            }

            if !isConfigured {
                configureSession()
            }
            guard isConfigured else { return }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self, !self.session.isRunning else { return }
                self.session.startRunning()
                self.isRunning = true
            }
        }

        func stop() {
            guard isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                self.isRunning = false
            }
        }

        private func configureSession() {
            session.beginConfiguration()
            session.sessionPreset = .high

            guard addCameraInput(for: cameraPosition) else {
                session.commitConfiguration()
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            session.commitConfiguration()
            isConfigured = true
            appliedCameraPosition = cameraPosition
        }

        private func reconfigureCameraInput() {
            let wasRunning = session.isRunning
            if wasRunning {
                session.stopRunning()
            }

            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            let success = addCameraInput(for: cameraPosition)
            session.commitConfiguration()

            guard success else { return }
            appliedCameraPosition = cameraPosition

            if wasRunning {
                session.startRunning()
                isRunning = true
            }
        }

        @discardableResult
        private func addCameraInput(for position: QRScanCameraPosition) -> Bool {
            guard
                let device = QRScanCameraDevice.captureDevice(for: position),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { return false }

            session.addInput(input)
            return true
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard
                let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                object.type == .qr,
                let value = object.stringValue,
                let result = QRGameplayScanParser.parse(value)
            else { return }

            reportDetection(result)
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            let now = Date()
            guard now.timeIntervalSince(lastOCRAt) >= 0.5 else { return }
            lastOCRAt = now

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let request = VNRecognizeTextRequest { [weak self] request, _ in
                guard let self else { return }
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                guard
                    let code = PaperCodeRecognizer.bestCode(from: lines, context: .passiveGameplay),
                    let result = QRGameplayScanParser.parse(code)
                else { return }
                DispatchQueue.main.async {
                    self.reportDetection(result)
                }
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.025

            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: cameraPosition.visionOrientation,
                options: [:]
            )
            try? handler.perform([request])
        }

        private func reportDetection(_ result: QRGameplayScanResult) {
            let now = Date()
            guard now.timeIntervalSince(lastDetectionAt) >= 1.4 else { return }
            lastDetectionAt = now
            onGameplayCode(result)
        }
    }
}
