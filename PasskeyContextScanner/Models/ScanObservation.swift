import Foundation

/// A rectangle expressed in Vision's normalized image coordinate space.
///
/// Values are expected to be between zero and one. The origin convention is
/// determined by the service that creates the observation and must be applied
/// consistently when regions are compared.
struct NormalizedBoundingBox: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let fullFrame = NormalizedBoundingBox(
        x: 0,
        y: 0,
        width: 1,
        height: 1
    )
}

enum QRCodeType: String, Codable, CaseIterable, Equatable {
    case fido = "FIDO"
    case url = "URL"
    case other = "OTHER"
    case unknown = "UNKNOWN"
}

/// Privacy-preserving metadata about a detected QR code.
///
/// The decoded payload is deliberately absent so transient FIDO connection
/// material cannot accidentally enter scan results or evaluation exports.
struct QRCodeObservation: Codable, Equatable {
    let type: QRCodeType
    let boundingBox: NormalizedBoundingBox
}

enum OCRRegion: String, Codable, CaseIterable, Equatable {
    case fullFrame = "FULL_FRAME"
    case qrSurrounding = "QR_SURROUNDING"
}

struct OCRObservation: Codable, Equatable {
    let text: String
    let confidence: Float
    let boundingBox: NormalizedBoundingBox
    let region: OCRRegion

    init(
        text: String,
        confidence: Float,
        boundingBox: NormalizedBoundingBox,
        region: OCRRegion
    ) {
        self.text = text
        self.confidence = min(max(confidence, 0), 1)
        self.boundingBox = boundingBox
        self.region = region
    }
}

enum ImageQualityIssue: String, Codable, CaseIterable, Equatable, Hashable {
    case blur = "BLUR"
    case lowContrast = "LOW_CONTRAST"
    case lowResolution = "LOW_RESOLUTION"
    case croppedContext = "CROPPED_CONTEXT"
    case glare = "GLARE"
    case qrTooSmall = "QR_TOO_SMALL"
    case unreadableText = "UNREADABLE_TEXT"
}

struct ImageQualityObservation: Codable, Equatable {
    let isSufficientForAnalysis: Bool
    let issues: [ImageQualityIssue]
}

enum QRProcessingStatus: String, Codable, Equatable {
    case completed = "COMPLETED"
    case failed = "FAILED"
}

enum OCRProcessingStatus: String, Codable, Equatable {
    case completed = "COMPLETED"
    case noText = "NO_TEXT"
    case partialFailure = "PARTIAL_FAILURE"
    case failed = "FAILED"
}

/// Monotonic processing durations used for performance evaluation only.
/// These values never contribute to feature extraction or classification.
struct AnalysisTimingObservation: Codable, Equatable {
    let qrDetectionMilliseconds: Double?
    let fullFrameOCRMilliseconds: Double?
    let qrRegionOCRMilliseconds: Double?
    let imageAnalysisMilliseconds: Double?

    static let unmeasured = AnalysisTimingObservation(
        qrDetectionMilliseconds: nil,
        fullFrameOCRMilliseconds: nil,
        qrRegionOCRMilliseconds: nil,
        imageAnalysisMilliseconds: nil
    )
}

/// Raw, classifier-independent evidence produced by either static or live input.
struct ScanObservation: Codable, Equatable {
    let qrCodes: [QRCodeObservation]
    let ocrObservations: [OCRObservation]
    let imageQuality: ImageQualityObservation
    let qrProcessingStatus: QRProcessingStatus
    let ocrProcessingStatus: OCRProcessingStatus
    let analysisTiming: AnalysisTimingObservation

    init(
        qrCodes: [QRCodeObservation],
        ocrObservations: [OCRObservation],
        imageQuality: ImageQualityObservation,
        qrProcessingStatus: QRProcessingStatus = .completed,
        ocrProcessingStatus: OCRProcessingStatus = .completed,
        analysisTiming: AnalysisTimingObservation = .unmeasured
    ) {
        self.qrCodes = qrCodes
        self.ocrObservations = ocrObservations
        self.imageQuality = imageQuality
        self.qrProcessingStatus = qrProcessingStatus
        self.ocrProcessingStatus = ocrProcessingStatus
        self.analysisTiming = analysisTiming
    }

    var qrDetected: Bool {
        !qrCodes.isEmpty
    }

    var qrCount: Int {
        qrCodes.count
    }

    var qrBoundingBoxes: [NormalizedBoundingBox] {
        qrCodes.map(\.boundingBox)
    }

    var qrTypes: [QRCodeType] {
        qrCodes.map(\.type)
    }

    /// One copy of each recognised line, with QR-near observations preferred.
    var uniqueOCRText: String {
        var seen = Set<String>()
        let ordered = ocrObservations.sorted {
            $0.region.sortPriority < $1.region.sortPriority
        }

        return ordered.compactMap { observation in
            let normalized = observation.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .joined(separator: "\n")
    }
}

private extension OCRRegion {
    var sortPriority: Int {
        switch self {
        case .qrSurrounding: return 0
        case .fullFrame: return 1
        }
    }
}
