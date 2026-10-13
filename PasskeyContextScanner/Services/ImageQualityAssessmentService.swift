import Foundation

/// Deterministic capture-quality observations available without retaining the
/// source image. It deliberately does not guess blur, glare, or contrast.
struct ImageQualityAssessmentService {
    static let minimumImageDimensionPixels = 720
    static let minimumQRCodeSide = 0.12
    static let frameEdgeTolerance = 0.015

    func assess(
        pixelWidth: Int,
        pixelHeight: Int,
        qrCodes: [QRCodeObservation],
        ocrObservations: [OCRObservation],
        ocrStatus: OCRProcessingStatus
    ) -> ImageQualityObservation {
        var issues: [ImageQualityIssue] = []
        let smallestDimension = min(pixelWidth, pixelHeight)
        if smallestDimension > 0,
           smallestDimension < Self.minimumImageDimensionPixels {
            issues.append(.lowResolution)
        }
        if qrCodes.contains(where: {
            $0.boundingBox.width < Self.minimumQRCodeSide ||
                $0.boundingBox.height < Self.minimumQRCodeSide
        }) {
            issues.append(.qrTooSmall)
        }
        if qrCodes.contains(where: touchesFrameEdge) {
            issues.append(.croppedContext)
        }
        let hasUsableText = ocrObservations.contains {
            $0.confidence >= ContextFeatureExtractor.minimumSemanticOCRConfidence &&
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !hasUsableText || ocrStatus == .failed || ocrStatus == .noText {
            issues.append(.unreadableText)
        }

        let blocking: Set<ImageQualityIssue> = [
            .qrTooSmall, .croppedContext, .unreadableText
        ]
        return ImageQualityObservation(
            isSufficientForAnalysis: Set(issues).isDisjoint(with: blocking),
            issues: issues
        )
    }

    private func touchesFrameEdge(_ qrCode: QRCodeObservation) -> Bool {
        let box = qrCode.boundingBox
        let maximumX = box.x + box.width
        let maximumY = box.y + box.height
        return box.x <= Self.frameEdgeTolerance ||
            box.y <= Self.frameEdgeTolerance ||
            maximumX >= 1 - Self.frameEdgeTolerance ||
            maximumY >= 1 - Self.frameEdgeTolerance
    }
}
