//
//  ARQRDetector.swift
//  DmdApp
//

import CoreVideo
import Vision

struct ARQRDetection: Identifiable {
    let id = UUID()
    let payload: String
    /// Prostokąt Vision (znormalizowany 0–1, origin lewy-dolny).
    let visionBoundingBox: CGRect
}

enum ARQRDetector {
    static func detect(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .right
    ) -> [ARQRDetection] {
        var observations: [VNBarcodeObservation] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNDetectBarcodesRequest { request, _ in
            observations = request.results as? [VNBarcodeObservation] ?? []
            semaphore.signal()
        }
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        try? handler.perform([request])
        semaphore.wait()

        return observations.compactMap { observation in
            guard
                let payload = observation.payloadStringValue,
                !payload.isEmpty,
                observation.confidence > 0.05
            else { return nil }

            return ARQRDetection(
                payload: payload,
                visionBoundingBox: observation.boundingBox
            )
        }
    }
}
