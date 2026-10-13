import ImageIO
import UIKit
@preconcurrency import Vision

protocol QRDetectionServing {
    func detectQRCodes(in image: UIImage) async throws -> [QRCodeObservation]
}

final class QRDetectionService: QRDetectionServing {
    func detectQRCodes(in image: UIImage) async throws -> [QRCodeObservation] {
        guard let cgImage = image.cgImage else {
            throw QRDetectionServiceError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let continuationGate = QRDetectionContinuationGate()
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuationGate.runOnce {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                let barcodes = request.results as? [VNBarcodeObservation] ?? []
                let observations = barcodes.map { barcode in
                    QRCodeObservation(
                        type: Self.classifyPayload(barcode.payloadStringValue),
                        boundingBox: NormalizedBoundingBox(
                            x: barcode.boundingBox.origin.x,
                            y: barcode.boundingBox.origin.y,
                            width: barcode.boundingBox.width,
                            height: barcode.boundingBox.height
                        )
                    )
                }

                // The payload is inspected only to derive the format. It is not
                // returned, logged, or retained by the observation model.
                continuationGate.runOnce {
                    continuation.resume(returning: observations)
                }
            }

            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: Self.cgOrientation(for: image.imageOrientation),
                options: [:]
            )

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuationGate.runOnce {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    static func classifyPayload(_ payload: String?) -> QRCodeType {
        guard let payload else {
            return .unknown
        }

        if payload.uppercased().hasPrefix("FIDO:") {
            return .fido
        }

        if let components = URLComponents(string: payload),
           let scheme = components.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           components.host != nil {
            return .url
        }

        return .other
    }

    private static func cgOrientation(
        for imageOrientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

/// Vision can report a request error through the completion handler and also
/// throw from `perform`. A checked continuation must be resumed exactly once.
private final class QRDetectionContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    func runOnce(_ action: () -> Void) {
        lock.lock()
        guard !hasResumed else {
            lock.unlock()
            return
        }
        hasResumed = true
        lock.unlock()
        action()
    }
}

enum QRDetectionServiceError: Error {
    case invalidImage
}
