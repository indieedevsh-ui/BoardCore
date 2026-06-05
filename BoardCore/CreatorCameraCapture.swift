//
//  CreatorCameraCapture.swift
//  BoardCore
//

import SwiftUI
import UIKit

struct CreatorCameraSection: View {
    @Environment(AppSettings.self) private var settings
    @Binding var image: UIImage?
    let title: String
    var onPhotoConfirmed: ((UIImage) -> Void)? = nil

    @State private var showCamera = false
    @State private var draftImage: UIImage?
    @State private var showReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                settings.playTapSound()
                draftImage = nil
                showCamera = true
            } label: {
                Label(image == nil ? "Wykonaj zdjęcie" : "Wykonaj nowe zdjęcie", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.appProminent)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $draftImage)
                .ignoresSafeArea()
        }
        .onChange(of: draftImage) { _, newValue in
            guard newValue != nil else { return }
            showReview = true
        }
        .sheet(isPresented: $showReview) {
            photoReviewSheet
        }
    }

    private var photoReviewSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let draftImage {
                    Image(uiImage: draftImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Potwierdź zdjęcie lub wykonaj je ponownie.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Potwierdź") {
                    settings.playTapSound()
                    if let draftImage {
                        image = draftImage
                        onPhotoConfirmed?(draftImage)
                    }
                    showReview = false
                    showCamera = false
                }
                .buttonStyle(.appProminent)

                Button("Anuluj") {
                    settings.playTapSound()
                    draftImage = nil
                    showReview = false
                }
                .buttonStyle(.appProminent)
            }
            .padding()
            .navigationTitle("Podgląd")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .appScreenBackground()
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let photo = info[.originalImage] as? UIImage {
                parent.image = photo
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
