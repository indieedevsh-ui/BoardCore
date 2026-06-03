//
//  ARQRScreenMapper.swift
//  DmdApp
//

import ARKit
import CoreGraphics
import UIKit

enum ARQRScreenMapper {
    /// Punkt na ekranie odpowiadający środkowi QR (Vision: origin lewy-dolny, znormalizowane 0–1).
    static func screenCenter(
        for visionBoundingBox: CGRect,
        frame: ARFrame,
        viewportSize: CGSize,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGPoint {
        mapVisionPoint(
            CGPoint(x: visionBoundingBox.midX, y: visionBoundingBox.midY),
            frame: frame,
            viewportSize: viewportSize,
            interfaceOrientation: interfaceOrientation
        )
    }

    /// Punkt nad kodem QR (górna krawędź + margines).
    static func screenPointAboveQR(
        for visionBoundingBox: CGRect,
        frame: ARFrame,
        viewportSize: CGSize,
        interfaceOrientation: UIInterfaceOrientation,
        marginFraction: CGFloat = 0.45
    ) -> CGPoint {
        let visionY = min(visionBoundingBox.maxY + marginFraction * visionBoundingBox.height, 1.0)
        return mapVisionPoint(
            CGPoint(x: visionBoundingBox.midX, y: visionY),
            frame: frame,
            viewportSize: viewportSize,
            interfaceOrientation: interfaceOrientation
        )
    }

    /// Wysokość QR w pikselach ekranu (do estymacji odległości).
    static func screenHeight(
        for visionBoundingBox: CGRect,
        frame: ARFrame,
        viewportSize: CGSize,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGFloat {
        let top = mapVisionPoint(
            CGPoint(x: visionBoundingBox.midX, y: visionBoundingBox.maxY),
            frame: frame,
            viewportSize: viewportSize,
            interfaceOrientation: interfaceOrientation
        )
        let bottom = mapVisionPoint(
            CGPoint(x: visionBoundingBox.midX, y: visionBoundingBox.minY),
            frame: frame,
            viewportSize: viewportSize,
            interfaceOrientation: interfaceOrientation
        )
        return abs(top.y - bottom.y)
    }

    private static func mapVisionPoint(
        _ visionPoint: CGPoint,
        frame: ARFrame,
        viewportSize: CGSize,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGPoint {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return .zero }

        let transform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewportSize)
        let imagePoint = CGPoint(x: visionPoint.x, y: 1.0 - visionPoint.y)
        let viewportNormalized = imagePoint.applying(transform)
        return CGPoint(
            x: viewportNormalized.x * viewportSize.width,
            y: viewportNormalized.y * viewportSize.height
        )
    }
}
