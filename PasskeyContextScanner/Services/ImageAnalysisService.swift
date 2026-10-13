import UIKit

protocol ImageAnalysisServing {
    func analyse(_ image: UIImage) async -> ScanObservation
}

struct ImageAnalysisService: ImageAnalysisServing {
    private let qrDetectionService: QRDetectionServing
    private let ocrService: OCRServing
    private let qrRegionPadding: Double
    private let imageQualityService: ImageQualityAssessmentService
    private let monotonicNow: () -> UInt64

    init(
        qrDetectionService: QRDetectionServing = QRDetectionService(),
        ocrService: OCRServing = OCRService(),
        imageQualityService: ImageQualityAssessmentService = ImageQualityAssessmentService(),
        qrRegionPadding: Double = 0.15,
        monotonicNow: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }
    ) {
        self.qrDetectionService = qrDetectionService
        self.ocrService = ocrService
        self.imageQualityService = imageQualityService
        self.qrRegionPadding = max(0, qrRegionPadding)
        self.monotonicNow = monotonicNow
    }

    func analyse(_ image: UIImage) async -> ScanObservation {
        let analysisStart = monotonicNow()
        async let qrAttempt = timedQRCodes(in: image)
        async let fullFrameAttempt = timedOCR(
            in: image,
            region: .fullFrame,
            regionOfInterest: nil
        )

        let qrTimedResult = await qrAttempt
        let qrResult = qrTimedResult.result
        let qrCodes = qrResult.value ?? []
        async let qrRegionAttempts = timedQRCodeOCR(in: image, qrCodes: qrCodes)
        let (fullFrameTimedResult, timedRegionResults) = await (
            fullFrameAttempt,
            qrRegionAttempts
        )
        let fullFrameResult = fullFrameTimedResult.result
        var ocrObservations = fullFrameResult.value ?? []
        var qrRegionFailed = false
        var qrRegionOCRMilliseconds = 0.0

        for timedResult in timedRegionResults {
            let result = timedResult.result
            qrRegionOCRMilliseconds += timedResult.milliseconds
            if let observations = result.value {
                ocrObservations.append(contentsOf: observations)
            } else {
                qrRegionFailed = true
            }
        }

        let ocrStatus = makeOCRStatus(
            fullFrameFailed: fullFrameResult.value == nil,
            qrRegionFailed: qrRegionFailed,
            observations: ocrObservations
        )

        let pixelDimensions = pixelDimensions(of: image)
        return ScanObservation(
            qrCodes: qrCodes,
            ocrObservations: ocrObservations,
            imageQuality: imageQualityService.assess(
                pixelWidth: pixelDimensions.width,
                pixelHeight: pixelDimensions.height,
                qrCodes: qrCodes,
                ocrObservations: ocrObservations,
                ocrStatus: ocrStatus
            ),
            qrProcessingStatus: qrResult.value == nil ? .failed : .completed,
            ocrProcessingStatus: ocrStatus,
            analysisTiming: AnalysisTimingObservation(
                qrDetectionMilliseconds: qrTimedResult.milliseconds,
                fullFrameOCRMilliseconds: fullFrameTimedResult.milliseconds,
                qrRegionOCRMilliseconds: qrCodes.isEmpty ? nil : qrRegionOCRMilliseconds,
                imageAnalysisMilliseconds: milliseconds(since: analysisStart)
            )
        )
    }

    private func pixelDimensions(of image: UIImage) -> (width: Int, height: Int) {
        if let cgImage = image.cgImage {
            return (cgImage.width, cgImage.height)
        }
        return (
            Int((image.size.width * image.scale).rounded()),
            Int((image.size.height * image.scale).rounded())
        )
    }

    private func timedQRCodeOCR(
        in image: UIImage,
        qrCodes: [QRCodeObservation]
    ) async -> [TimedResult<[OCRObservation]>] {
        await withTaskGroup(
            of: IndexedTimedOCRResult.self,
            returning: [TimedResult<[OCRObservation]>].self
        ) { group in
            for (index, qrCode) in qrCodes.enumerated() {
                group.addTask {
                    IndexedTimedOCRResult(
                        index: index,
                        timedResult: await timedOCR(
                            in: image,
                            region: .qrSurrounding,
                            regionOfInterest: qrCode.boundingBox.padded(by: qrRegionPadding)
                        )
                    )
                }
            }

            var indexedResults: [IndexedTimedOCRResult] = []
            for await result in group {
                indexedResults.append(result)
            }
            return indexedResults
                .sorted { $0.index < $1.index }
                .map(\.timedResult)
        }
    }

    private func timedQRCodes(in image: UIImage) async -> TimedResult<[QRCodeObservation]> {
        let start = monotonicNow()
        return TimedResult(
            result: await attemptQRCodes(in: image),
            milliseconds: milliseconds(since: start)
        )
    }

    private func timedOCR(
        in image: UIImage,
        region: OCRRegion,
        regionOfInterest: NormalizedBoundingBox?
    ) async -> TimedResult<[OCRObservation]> {
        let start = monotonicNow()
        return TimedResult(
            result: await attemptOCR(
                in: image,
                region: region,
                regionOfInterest: regionOfInterest
            ),
            milliseconds: milliseconds(since: start)
        )
    }

    private func milliseconds(since start: UInt64) -> Double {
        let end = monotonicNow()
        guard end >= start else { return 0 }
        return Double(end - start) / 1_000_000
    }

    private func attemptQRCodes(
        in image: UIImage
    ) async -> Result<[QRCodeObservation], Error> {
        do {
            return .success(try await qrDetectionService.detectQRCodes(in: image))
        } catch {
            return .failure(error)
        }
    }

    private func attemptOCR(
        in image: UIImage,
        region: OCRRegion,
        regionOfInterest: NormalizedBoundingBox?
    ) async -> Result<[OCRObservation], Error> {
        do {
            return .success(
                try await ocrService.recognizeObservations(
                    in: image,
                    region: region,
                    regionOfInterest: regionOfInterest
                )
            )
        } catch {
            return .failure(error)
        }
    }

    private func makeOCRStatus(
        fullFrameFailed: Bool,
        qrRegionFailed: Bool,
        observations: [OCRObservation]
    ) -> OCRProcessingStatus {
        if fullFrameFailed && observations.isEmpty {
            return .failed
        }
        if fullFrameFailed || qrRegionFailed {
            return .partialFailure
        }
        return observations.isEmpty ? .noText : .completed
    }
}

private struct TimedResult<Success> {
    let result: Result<Success, Error>
    let milliseconds: Double
}

private struct IndexedTimedOCRResult {
    let index: Int
    let timedResult: TimedResult<[OCRObservation]>
}

private extension Result {
    var value: Success? {
        try? get()
    }
}

extension NormalizedBoundingBox {
    func padded(by amount: Double) -> NormalizedBoundingBox {
        let minimumX = max(0, x - amount)
        let minimumY = max(0, y - amount)
        let maximumX = min(1, x + width + amount)
        let maximumY = min(1, y + height + amount)

        return NormalizedBoundingBox(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }
}
