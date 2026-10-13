import ImageIO
import UIKit
@preconcurrency import Vision

protocol OCRServing {
    func recognizeObservations(
        in image: UIImage,
        region: OCRRegion,
        regionOfInterest: NormalizedBoundingBox?
    ) async throws -> [OCRObservation]
}

final class OCRService: OCRServing {
    func recognizeObservations(
        in image: UIImage,
        region: OCRRegion = .fullFrame,
        regionOfInterest: NormalizedBoundingBox? = nil
    ) async throws -> [OCRObservation] {
        guard let cgImage = image.cgImage else {
            throw OCRServiceError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognized = observations.compactMap { observation -> OCRObservation? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return OCRObservation(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: NormalizedBoundingBox(
                            x: observation.boundingBox.origin.x,
                            y: observation.boundingBox.origin.y,
                            width: observation.boundingBox.width,
                            height: observation.boundingBox.height
                        ),
                        region: region
                    )
                }

                continuation.resume(returning: recognized)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-GB", "en-US"]
            if let regionOfInterest {
                request.regionOfInterest = CGRect(
                    x: regionOfInterest.x,
                    y: regionOfInterest.y,
                    width: regionOfInterest.width,
                    height: regionOfInterest.height
                )
            }

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation),
                options: [:]
            )

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func recognizeText(in image: UIImage) async throws -> String {
        try await recognizeObservations(
            in: image,
            region: .fullFrame,
            regionOfInterest: nil
        )
            .map(\.text)
            .joined(separator: "\n")
    }
}

enum OCRServiceError: Error {
    case invalidImage
}

private extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
