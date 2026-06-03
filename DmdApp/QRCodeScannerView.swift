//
//  QRCodeScannerView.swift
//  DmdApp
//

import AVFoundation
import SwiftUI
import Vision

private enum CameraAccessState {
    case pending
    case authorized
    case denied
}

struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    let context: QRScannerContext
    let onCodeScanned: (String) -> Void

    @State private var manualCode = ""
    @State private var cameraAccess: CameraAccessState = .pending

    init(context: QRScannerContext = .lobbyPlayer, onCodeScanned: @escaping (String) -> Void) {
        self.context = context
        self.onCodeScanned = onCodeScanned
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            VStack(spacing: 20) {
                switch cameraAccess {
                case .pending:
                    ProgressView("Ładowanie aparatu…")
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                case .denied:
                    ContentUnavailableView(
                        "Brak dostępu do aparatu",
                        systemImage: "camera.fill",
                        description: Text("Włącz aparat w ustawieniach iPhone lub wpisz kod ręcznie poniżej.")
                    )
                case .authorized:
                    QRScannerRepresentable(
                        context: context,
                        cameraPosition: settings.qrScanCameraPosition
                    ) { code in
                        settings.playTapSound()
                        onCodeScanned(code)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                    }
                    .padding(.horizontal)

                    Text("Skieruj aparat na kod QR lub na numer na kartce (np. 3812).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Wpisz kod ręcznie")
                        .font(.headline)
                    HStack {
                        TextField(context.manualPlaceholder, text: $manualCode)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                        Button("Zatwierdź") {
                            submitManualCode()
                        }
                        .buttonStyle(.appProminent)
                        .disabled(manualCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal)

                qrReferenceList

                Spacer()
            }
            .padding(.top)
            .appScrollSurface()
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        settings.playTapSound()
                        dismiss()
                    }
                }
            }
            .task {
                await resolveCameraAccess()
            }
        }
        .background(Color.clear)
        .appThemedScreen()
    }

    @ViewBuilder
    private var qrReferenceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch context {
            case .lobbyPlayer:
                Text("Kody graczy (4001–4004)")
                    .font(.headline)
                ForEach(PlayerSlotCode.allCases) { slot in
                    Text("\(slot.qrID) — \(slot.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Możesz też wpisać: gracz 1, gracz 2…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .passiveGameplay:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func submitManualCode() {
        settings.playTapSound()
        onCodeScanned(manualCode)
        dismiss()
    }

    @MainActor
    private func resolveCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAccess = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAccess = granted ? .authorized : .denied
        default:
            cameraAccess = .denied
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let context: QRScannerContext
    let cameraPosition: QRScanCameraPosition
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.scanContext = self.context
        controller.cameraPosition = cameraPosition
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.updateCameraPosition(cameraPosition)
        uiViewController.startCaptureIfNeeded()
    }

    static func dismantleUIViewController(_ uiViewController: QRScannerViewController, coordinator: ()) {
        uiViewController.stopCapture()
    }
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onCodeScanned: ((String) -> Void)?
    var scanContext: QRScannerContext = .lobbyPlayer
    var cameraPosition: QRScanCameraPosition = .front

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "dmd.qr.session", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let visionQueue = DispatchQueue(label: "dmd.qr.ocr", qos: .userInitiated)
    private var lastOCRDate = Date.distantPast
    private var hasScanned = false
    private var isSessionConfigured = false
    private var appliedCameraPosition: QRScanCameraPosition?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func startCaptureIfNeeded() {
        sessionQueue.async { [weak self] in
            self?.configureAndStartIfNeeded()
        }
    }

    func stopCapture() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func updateCameraPosition(_ position: QRScanCameraPosition) {
        cameraPosition = position
        guard isSessionConfigured, appliedCameraPosition != position else { return }

        sessionQueue.async { [weak self] in
            self?.reconfigureCameraInput()
        }
    }

    private func configureAndStartIfNeeded() {
        if isSessionConfigured {
            if !session.isRunning {
                session.startRunning()
            }
            return
        }

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
        isSessionConfigured = true
        appliedCameraPosition = cameraPosition

        DispatchQueue.main.sync { [weak self] in
            guard let self else { return }
            if self.previewLayer == nil {
                let preview = AVCaptureVideoPreviewLayer(session: self.session)
                preview.videoGravity = .resizeAspectFill
                preview.frame = self.view.bounds
                self.view.layer.addSublayer(preview)
                self.previewLayer = preview
            }
            self.applyPreviewMirroring()
        }

        session.startRunning()
    }

    private func reconfigureCameraInput() {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        let success = addCameraInput(for: cameraPosition)
        session.commitConfiguration()

        guard success else { return }
        appliedCameraPosition = cameraPosition

        DispatchQueue.main.sync { [weak self] in
            self?.applyPreviewMirroring()
        }

        session.startRunning()
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

    private func applyPreviewMirroring() {
        guard let connection = previewLayer?.connection else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = cameraPosition == .front
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            !hasScanned,
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let value = object.stringValue,
            scanContext.accepts(value)
        else { return }

        finishScan(with: value)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned else { return }
        let now = Date()
        guard now.timeIntervalSince(lastOCRDate) >= 0.45 else { return }
        lastOCRDate = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self, !self.hasScanned else { return }
            let lines = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            guard let code = PaperCodeRecognizer.bestCode(from: lines, context: self.scanContext) else { return }
            DispatchQueue.main.async {
                self.finishScan(with: code)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: cameraPosition.visionOrientation,
            options: [:]
        )
        try? handler.perform([request])
    }

    private func finishScan(with code: String) {
        guard !hasScanned else { return }
        hasScanned = true
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        onCodeScanned?(code)
    }
}

enum PaperCodeRecognizer {
    static func bestCode(from lines: [String], context: QRScannerContext) -> String? {
        var candidates: [String] = []

        for line in lines {
            if let normalized = QRCodeParser.normalizedID(from: line) {
                candidates.append(normalized)
            }
            candidates.append(contentsOf: digitSequences(in: line))
        }

        let unique = Array(Set(candidates))
        let sorted = unique.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs < rhs
        }

        for code in sorted where isValid(code, context: context) {
            return code
        }
        return nil
    }

    private static func digitSequences(in text: String) -> [String] {
        let pattern = /\d{3,5}/
        return text.matches(of: pattern).map(\.output).map(String.init)
    }

    private static func isValid(_ code: String, context: QRScannerContext) -> Bool {
        switch context {
        case .lobbyPlayer:
            return QRLobbyScanParser.matches(code)
        case .passiveGameplay:
            return QRGameplayScanParser.matches(code)
        }
    }
}
