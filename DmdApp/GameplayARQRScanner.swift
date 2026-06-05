//
//  GameplayARQRScanner.swift
//  DmdApp
//
//  Wspólny skaner QR w AR / kamerze (walka z bossem, Arena PvP).
//

import ARKit
import AVFoundation
import SwiftUI
import UIKit

final class GameplayARCameraContainerView: UIView {
    let arView = ARSCNView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.automaticallyUpdatesLighting = true
        addSubview(arView)
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: trailingAnchor),
            arView.topAnchor.constraint(equalTo: topAnchor),
            arView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct GameplayARQRScanner: UIViewRepresentable {
    let cameraPosition: QRScanCameraPosition
    let onPayloads: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPayloads: onPayloads)
    }

    func makeUIView(context: Context) -> GameplayARCameraContainerView {
        let container = GameplayARCameraContainerView(frame: .zero)
        context.coordinator.attach(to: container)
        context.coordinator.updateCameraPosition(cameraPosition)
        return container
    }

    func updateUIView(_ uiView: GameplayARCameraContainerView, context: Context) {
        context.coordinator.onPayloads = onPayloads
        context.coordinator.updateCameraPosition(cameraPosition)
        context.coordinator.layoutPreview(in: uiView)
    }

    static func dismantleUIView(_ uiView: GameplayARCameraContainerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator: NSObject, ARSessionDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onPayloads: ([String]) -> Void

        private let visionQueue = DispatchQueue(label: "dmd.gameplay.ar", qos: .userInitiated)
        private let captureQueue = DispatchQueue(label: "dmd.gameplay.capture", qos: .userInitiated)
        private var lastProcessedAt: TimeInterval = 0
        private var cameraPosition: QRScanCameraPosition = .front
        private var appliedCameraPosition: QRScanCameraPosition?
        private weak var containerView: GameplayARCameraContainerView?

        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var isCaptureConfigured = false

        init(onPayloads: @escaping ([String]) -> Void) {
            self.onPayloads = onPayloads
        }

        func attach(to container: GameplayARCameraContainerView) {
            containerView = container
            container.arView.session.delegate = self
        }

        func updateCameraPosition(_ position: QRScanCameraPosition) {
            guard cameraPosition != position || appliedCameraPosition != position else { return }
            cameraPosition = position
            guard containerView != nil else { return }
            applyCameraMode()
        }

        func layoutPreview(in container: GameplayARCameraContainerView) {
            previewLayer?.frame = container.bounds
        }

        func teardown() {
            containerView?.arView.session.pause()
            captureQueue.async { [captureSession] in
                if captureSession.isRunning {
                    captureSession.stopRunning()
                }
            }
        }

        private func applyCameraMode() {
            guard let container = containerView else { return }

            if let configuration = cameraPosition.makeARConfiguration() {
                stopCaptureSession()
                container.arView.isHidden = false
                previewLayer?.removeFromSuperlayer()
                previewLayer = nil
                container.arView.transform = .identity
                container.arView.session.run(
                    configuration,
                    options: [.resetTracking, .removeExistingAnchors]
                )
            } else {
                container.arView.session.pause()
                container.arView.isHidden = true
                startCaptureSession(in: container)
            }

            appliedCameraPosition = cameraPosition
        }

        private func stopCaptureSession() {
            captureQueue.async { [weak self] in
                guard let self else { return }
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
                self.captureSession.beginConfiguration()
                self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
                self.captureSession.outputs.forEach { self.captureSession.removeOutput($0) }
                self.captureSession.commitConfiguration()
                self.isCaptureConfigured = false
            }
        }

        private func startCaptureSession(in container: GameplayARCameraContainerView) {
            captureQueue.async { [weak self] in
                guard let self else { return }

                if !self.isCaptureConfigured {
                    self.captureSession.beginConfiguration()
                    self.captureSession.sessionPreset = .high

                    guard self.addCaptureInput() else {
                        self.captureSession.commitConfiguration()
                        return
                    }

                    let videoOutput = AVCaptureVideoDataOutput()
                    videoOutput.alwaysDiscardsLateVideoFrames = true
                    videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
                    if self.captureSession.canAddOutput(videoOutput) {
                        self.captureSession.addOutput(videoOutput)
                    }

                    self.captureSession.commitConfiguration()
                    self.isCaptureConfigured = true
                    self.appliedCameraPosition = self.cameraPosition

                    DispatchQueue.main.async {
                        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                        preview.videoGravity = .resizeAspectFill
                        preview.frame = container.bounds
                        container.layer.insertSublayer(preview, at: 0)
                        self.previewLayer = preview
                        self.applyPreviewMirroring()
                    }
                } else {
                    self.reconfigureCaptureInput()
                }

                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }

                DispatchQueue.main.async {
                    self.previewLayer?.frame = container.bounds
                    self.applyPreviewMirroring()
                }
            }
        }

        private func reconfigureCaptureInput() {
            let wasRunning = captureSession.isRunning
            if wasRunning {
                captureSession.stopRunning()
            }

            captureSession.beginConfiguration()
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            let success = addCaptureInput()
            captureSession.commitConfiguration()

            guard success else { return }
            appliedCameraPosition = cameraPosition

            DispatchQueue.main.async { [weak self] in
                self?.applyPreviewMirroring()
            }

            if wasRunning {
                captureSession.startRunning()
            }
        }

        @discardableResult
        private func addCaptureInput() -> Bool {
            guard
                let device = QRScanCameraDevice.captureDevice(for: cameraPosition),
                let input = try? AVCaptureDeviceInput(device: device),
                captureSession.canAddInput(input)
            else { return false }

            captureSession.addInput(input)
            return true
        }

        private func applyPreviewMirroring() {
            guard let connection = previewLayer?.connection else { return }
            guard connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = cameraPosition == .front
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            processPixelBuffer(frame.capturedImage)
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            processPixelBuffer(pixelBuffer)
        }

        private func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
            let timestamp = CACurrentMediaTime()
            guard timestamp - lastProcessedAt >= 0.12 else { return }
            lastProcessedAt = timestamp

            let orientation = cameraPosition.visionOrientation
            visionQueue.async { [weak self] in
                let payloads = ARQRDetector.detect(
                    in: pixelBuffer,
                    orientation: orientation
                ).map(\.payload)
                guard let self else { return }
                DispatchQueue.main.async {
                    self.onPayloads(payloads)
                }
            }
        }
    }
}
