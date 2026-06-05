//
//  QRScanCameraPosition.swift
//  BoardCore
//

import ARKit
import AVFoundation
import ImageIO

enum QRScanCameraPosition: String, CaseIterable, Identifiable {
    case front
    case back

    var id: String { rawValue }

    var label: String {
        switch self {
        case .front: "Przednia"
        case .back: "Tylna"
        }
    }

    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front: .front
        case .back: .back
        }
    }

    /// Orientacja bufora wideo dla Vision OCR (portret, aparat skierowany na kod).
    var visionOrientation: CGImagePropertyOrientation {
        switch self {
        case .front: .leftMirrored
        case .back: .right
        }
    }

    /// Konfiguracja ARKit dla podglądu kamery (tylna = world, przednia = face).
    func makeARConfiguration() -> ARConfiguration? {
        switch self {
        case .back:
            guard ARWorldTrackingConfiguration.isSupported else { return nil }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            return configuration
        case .front:
            guard ARFaceTrackingConfiguration.isSupported else { return nil }
            return ARFaceTrackingConfiguration()
        }
    }

    var supportsARKitPreview: Bool {
        makeARConfiguration() != nil
    }
}

enum QRScanCameraDevice {
    static func captureDevice(for position: QRScanCameraPosition) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition) {
            return device
        }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: position.avPosition
        ).devices.first
    }
}
