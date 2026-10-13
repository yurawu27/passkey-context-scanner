import Foundation
import Combine
import UIKit
@preconcurrency import AVFoundation

enum CameraAuthorizationState: String, Equatable {
    case notDetermined = "NOT_DETERMINED"
    case authorized = "AUTHORIZED"
    case denied = "DENIED"
    case restricted = "RESTRICTED"
}

enum CameraSessionState: Equatable {
    case idle
    case requestingPermission
    case configuring
    case running
    case stopped
    case failed(String)
}

@MainActor
protocol CameraCaptureServing: AnyObject {
    var session: AVCaptureSession { get }
    var authorizationState: CameraAuthorizationState { get }
    var sessionState: CameraSessionState { get }
    var detectedQRCodes: [LiveQRCodeDetection] { get }
    var isQRCodeStable: Bool { get }
    var isCapturingPhoto: Bool { get }
    var stateChangeHandler: (() -> Void)? { get set }

    func prepareAndStart() async
    func capturePhoto() async throws -> UIImage
    func stop()
}

@MainActor
final class CameraCaptureService: NSObject, ObservableObject, CameraCaptureServing {
    let session = AVCaptureSession()

    @Published private(set) var authorizationState: CameraAuthorizationState {
        didSet { stateChangeHandler?() }
    }
    @Published private(set) var sessionState: CameraSessionState = .idle {
        didSet { stateChangeHandler?() }
    }
    @Published private(set) var detectedQRCodes: [LiveQRCodeDetection] = [] {
        didSet { stateChangeHandler?() }
    }
    @Published private(set) var isQRCodeStable = false {
        didSet { stateChangeHandler?() }
    }
    @Published private(set) var isCapturingPhoto = false {
        didSet { stateChangeHandler?() }
    }
    var stateChangeHandler: (() -> Void)?

    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataQueue = DispatchQueue(
        label: "uk.ac.prototype.PasskeyContextScanner.camera-metadata",
        qos: .userInitiated
    )
    private let sessionQueue = DispatchQueue(
        label: "uk.ac.prototype.PasskeyContextScanner.camera-session",
        qos: .userInitiated
    )
    private var isConfigured = false
    private var stabilityTracker = QRCodeStabilityTracker()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    override init() {
        authorizationState = Self.mapAuthorizationStatus(
            AVCaptureDevice.authorizationStatus(for: .video)
        )
        super.init()
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
    }

    func prepareAndStart() async {
        guard sessionState != .running, sessionState != .configuring else {
            return
        }

        authorizationState = Self.mapAuthorizationStatus(
            AVCaptureDevice.authorizationStatus(for: .video)
        )

        if authorizationState == .notDetermined {
            sessionState = .requestingPermission
            let granted = await requestCameraAccess()
            authorizationState = granted ? .authorized : .denied
        }

        guard authorizationState == .authorized else {
            sessionState = .stopped
            return
        }

        sessionState = .configuring
        do {
            if !isConfigured {
                try await configureSession()
                isConfigured = true
            }
            try Task.checkCancellation()
            await startSession()
            guard !Task.isCancelled else {
                stop()
                return
            }
            sessionState = .running
        } catch is CancellationError {
            sessionState = .stopped
        } catch {
            sessionState = .failed(
                (error as? LocalizedError)?.errorDescription ??
                    "The camera could not be started."
            )
        }
    }

    func stop() {
        sessionState = .stopped
        detectedQRCodes = []
        stabilityTracker.reset()
        isQRCodeStable = false
        if let photoContinuation {
            photoContinuation.resume(throwing: CancellationError())
            self.photoContinuation = nil
        }
        isCapturingPhoto = false
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    nonisolated static func mapAuthorizationStatus(
        _ status: AVAuthorizationStatus
    ) -> CameraAuthorizationState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    func capturePhoto() async throws -> UIImage {
        guard sessionState == .running else {
            throw CameraCaptureError.sessionNotRunning
        }
        guard !isCapturingPhoto, photoContinuation == nil else {
            throw CameraCaptureError.captureAlreadyInProgress
        }

        isCapturingPhoto = true
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality

        return try await withCheckedThrowingContinuation { continuation in
            photoContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureSession() async throws {
        let session = session
        let metadataOutput = metadataOutput
        let photoOutput = photoOutput
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    session.beginConfiguration()
                    defer { session.commitConfiguration() }

                    session.sessionPreset = .photo
                    guard let camera = AVCaptureDevice.default(
                        .builtInWideAngleCamera,
                        for: .video,
                        position: .back
                    ) else {
                        throw CameraCaptureError.cameraUnavailable
                    }

                    let input = try AVCaptureDeviceInput(device: camera)
                    guard session.canAddInput(input) else {
                        throw CameraCaptureError.cannotAddCameraInput
                    }
                    guard session.canAddOutput(metadataOutput) else {
                        throw CameraCaptureError.cannotAddMetadataOutput
                    }
                    guard session.canAddOutput(photoOutput) else {
                        throw CameraCaptureError.cannotAddPhotoOutput
                    }

                    session.addInput(input)
                    session.addOutput(metadataOutput)
                    session.addOutput(photoOutput)
                    guard metadataOutput.availableMetadataObjectTypes.contains(.qr) else {
                        session.removeOutput(photoOutput)
                        session.removeOutput(metadataOutput)
                        session.removeInput(input)
                        throw CameraCaptureError.qrMetadataUnavailable
                    }
                    metadataOutput.metadataObjectTypes = [.qr]
                    photoOutput.maxPhotoQualityPrioritization = .quality
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startSession() async {
        let session = session
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }
}

enum CameraCaptureError: LocalizedError {
    case cameraUnavailable
    case cannotAddCameraInput
    case cannotAddMetadataOutput
    case qrMetadataUnavailable
    case cannotAddPhotoOutput
    case sessionNotRunning
    case captureAlreadyInProgress
    case photoDataUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "No rear camera is available on this device."
        case .cannotAddCameraInput:
            return "The rear camera could not be added to the capture session."
        case .cannotAddMetadataOutput:
            return "QR metadata detection could not be added to the capture session."
        case .qrMetadataUnavailable:
            return "QR metadata detection is unavailable on this device."
        case .cannotAddPhotoOutput:
            return "High-quality photo capture could not be added to the session."
        case .sessionNotRunning:
            return "The camera is not ready to capture a frame."
        case .captureAlreadyInProgress:
            return "A frame capture is already in progress."
        case .photoDataUnavailable:
            return "The captured frame could not be decoded."
        }
    }
}

extension CameraCaptureService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let detections = metadataObjects.compactMap {
            $0 as? AVMetadataMachineReadableCodeObject
        }
        .filter { $0.type == .qr }
        .map {
            LiveQRCodeDetection(
                type: QRDetectionService.classifyPayload($0.stringValue),
                metadataBoundingBox: NormalizedBoundingBox(
                    x: $0.bounds.origin.x,
                    y: $0.bounds.origin.y,
                    width: $0.bounds.width,
                    height: $0.bounds.height
                )
            )
        }

        Task { @MainActor [weak self] in
            guard let self, self.sessionState == .running else { return }
            self.stabilityTracker.update(with: detections)
            self.detectedQRCodes = detections
            self.isQRCodeStable = self.stabilityTracker.isStable
        }
    }
}

extension CameraCaptureService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result: Result<UIImage, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(CameraCaptureError.photoDataUnavailable)
        }

        Task { @MainActor [weak self] in
            guard let self, let continuation = self.photoContinuation else {
                return
            }
            self.photoContinuation = nil
            self.isCapturingPhoto = false
            continuation.resume(with: result)
        }
    }
}
