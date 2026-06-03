//
//  QRCodeImageView.swift
//  DmdApp
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum QRCodeImageGenerator {
    static func image(from string: String, dimension: CGFloat = 220) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct QRCodeImageView: View {
    let payload: String
    var dimension: CGFloat = 180

    var body: some View {
        Group {
            if let image = QRCodeImageGenerator.image(from: payload, dimension: dimension) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: dimension, height: dimension)
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
