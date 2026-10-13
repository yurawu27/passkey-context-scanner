import XCTest
import UIKit
@testable import PasskeyContextScanner

final class ImageAnalysisServiceTests: XCTestCase {
    func testQualityAssessorFindsSmallAndEdgeCroppedQRCode() {
        let quality = ImageQualityAssessmentService().assess(
            pixelWidth: 1170,
            pixelHeight: 2532,
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.005, y: 0.4, width: 0.08, height: 0.08
                )
            )],
            ocrObservations: [OCRObservation(
                text: "Sign in with a passkey",
                confidence: 0.95,
                boundingBox: .fullFrame,
                region: .fullFrame
            )],
            ocrStatus: .completed
        )

        XCTAssertFalse(quality.isSufficientForAnalysis)
        XCTAssertTrue(quality.issues.contains(.qrTooSmall))
        XCTAssertTrue(quality.issues.contains(.croppedContext))
    }

    func testQualityAssessorTreatsLowConfidenceOnlyTextAsUnreadable() {
        let quality = ImageQualityAssessmentService().assess(
            pixelWidth: 1170,
            pixelHeight: 2532,
            qrCodes: [],
            ocrObservations: [OCRObservation(
                text: "Possibly incorrect text",
                confidence: 0.2,
                boundingBox: .fullFrame,
                region: .fullFrame
            )],
            ocrStatus: .completed
        )

        XCTAssertFalse(quality.isSufficientForAnalysis)
        XCTAssertEqual(quality.issues, [.unreadableText])
    }

    func testLowResolutionIsReportedWithoutDiscardingUsableEvidence() {
        let quality = ImageQualityAssessmentService().assess(
            pixelWidth: 640,
            pixelHeight: 480,
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.3, y: 0.3, width: 0.3, height: 0.3
                )
            )],
            ocrObservations: [OCRObservation(
                text: "Microsoft sign in with a passkey",
                confidence: 0.95,
                boundingBox: .fullFrame,
                region: .fullFrame
            )],
            ocrStatus: .completed
        )

        XCTAssertTrue(quality.isSufficientForAnalysis)
        XCTAssertEqual(quality.issues, [.lowResolution])
    }

    func testRunsFullFrameAndPaddedQRCodeOCR() async {
        let qrBox = NormalizedBoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let qrService = QRDetectionStub(
            result: .success([QRCodeObservation(type: .fido, boundingBox: qrBox)])
        )
        let ocrService = OCRStub(results: [
            .fullFrame: .success([
                OCRObservation(
                    text: "Microsoft",
                    confidence: 0.9,
                    boundingBox: .fullFrame,
                    region: .fullFrame
                )
            ]),
            .qrSurrounding: .success([
                OCRObservation(
                    text: "Sign in with a passkey",
                    confidence: 0.95,
                    boundingBox: qrBox,
                    region: .qrSurrounding
                )
            ])
        ])
        let service = ImageAnalysisService(
            qrDetectionService: qrService,
            ocrService: ocrService,
            qrRegionPadding: 0.15
        )

        let result = await service.analyse(UIImage())
        let calls = await ocrService.recordedCalls

        XCTAssertEqual(result.qrProcessingStatus, .completed)
        XCTAssertEqual(result.ocrProcessingStatus, .completed)
        XCTAssertEqual(result.qrCount, 1)
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].region, .fullFrame)
        XCTAssertNil(calls[0].regionOfInterest)
        XCTAssertEqual(calls[1].region, .qrSurrounding)
        assertBoundingBox(
            calls[1].regionOfInterest,
            equals: NormalizedBoundingBox(x: 0, y: 0, width: 0.45, height: 0.45)
        )
        XCTAssertNotNil(result.analysisTiming.qrDetectionMilliseconds)
        XCTAssertNotNil(result.analysisTiming.fullFrameOCRMilliseconds)
        XCTAssertNotNil(result.analysisTiming.qrRegionOCRMilliseconds)
        XCTAssertNotNil(result.analysisTiming.imageAnalysisMilliseconds)
        XCTAssertGreaterThanOrEqual(result.analysisTiming.imageAnalysisMilliseconds ?? -1, 0)
    }

    func testPreservesQRCodeResultWhenOCRFails() async {
        let qrService = QRDetectionStub(
            result: .success([
                QRCodeObservation(type: .unknown, boundingBox: .fullFrame)
            ])
        )
        let ocrService = OCRStub(results: [
            .fullFrame: .failure(TestError.expected),
            .qrSurrounding: .failure(TestError.expected)
        ])
        let service = ImageAnalysisService(
            qrDetectionService: qrService,
            ocrService: ocrService
        )

        let result = await service.analyse(UIImage())

        XCTAssertEqual(result.qrCount, 1)
        XCTAssertEqual(result.qrProcessingStatus, .completed)
        XCTAssertEqual(result.ocrProcessingStatus, .failed)
        XCTAssertTrue(result.ocrObservations.isEmpty)
    }

    func testDistinguishesNoTextFromOCRFailure() async {
        let service = ImageAnalysisService(
            qrDetectionService: QRDetectionStub(result: .success([])),
            ocrService: OCRStub(results: [.fullFrame: .success([])])
        )

        let result = await service.analyse(UIImage())

        XCTAssertEqual(result.qrCount, 0)
        XCTAssertEqual(result.qrProcessingStatus, .completed)
        XCTAssertEqual(result.ocrProcessingStatus, .noText)
    }

    func testPaddingIsClampedToImageBounds() {
        let box = NormalizedBoundingBox(x: 0.9, y: 0.85, width: 0.1, height: 0.15)

        assertBoundingBox(
            box.padded(by: 0.2),
            equals: NormalizedBoundingBox(x: 0.7, y: 0.65, width: 0.3, height: 0.35)
        )
    }

    func testFullFrameAndQRCodeOCRCanOverlap() async {
        let ocrService = ConcurrencyOCRStub()
        let service = ImageAnalysisService(
            qrDetectionService: QRDetectionStub(result: .success([
                QRCodeObservation(
                    type: .fido,
                    boundingBox: NormalizedBoundingBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
                )
            ])),
            ocrService: ocrService
        )

        _ = await service.analyse(UIImage())
        let maximumConcurrentRequests = await ocrService.maximumConcurrentRequests

        XCTAssertGreaterThanOrEqual(maximumConcurrentRequests, 2)
    }

    func testConcurrentQRCodeOCRPreservesQRCodeOrder() async {
        let first = NormalizedBoundingBox(x: 0.1, y: 0.1, width: 0.1, height: 0.1)
        let second = NormalizedBoundingBox(x: 0.7, y: 0.7, width: 0.1, height: 0.1)
        let service = ImageAnalysisService(
            qrDetectionService: QRDetectionStub(result: .success([
                QRCodeObservation(type: .fido, boundingBox: first),
                QRCodeObservation(type: .fido, boundingBox: second)
            ])),
            ocrService: RegionOrderOCRStub(),
            qrRegionPadding: 0
        )

        let result = await service.analyse(UIImage())
        let regionalText = result.ocrObservations
            .filter { $0.region == .qrSurrounding }
            .map(\.text)

        XCTAssertEqual(regionalText, ["region-0.1", "region-0.7"])
    }

    private func assertBoundingBox(
        _ actual: NormalizedBoundingBox?,
        equals expected: NormalizedBoundingBox,
        accuracy: Double = 0.000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            return XCTFail("Expected a bounding box.", file: file, line: line)
        }
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
    }
}

private struct QRDetectionStub: QRDetectionServing {
    let result: Result<[QRCodeObservation], Error>

    func detectQRCodes(in image: UIImage) async throws -> [QRCodeObservation] {
        try result.get()
    }
}

private actor OCRStub: OCRServing {
    struct Call: Equatable {
        let region: OCRRegion
        let regionOfInterest: NormalizedBoundingBox?
    }

    let results: [OCRRegion: Result<[OCRObservation], Error>]
    private(set) var recordedCalls: [Call] = []

    init(results: [OCRRegion: Result<[OCRObservation], Error>]) {
        self.results = results
    }

    func recognizeObservations(
        in image: UIImage,
        region: OCRRegion,
        regionOfInterest: NormalizedBoundingBox?
    ) async throws -> [OCRObservation] {
        recordedCalls.append(Call(region: region, regionOfInterest: regionOfInterest))
        return try results[region, default: .success([])].get()
    }
}

private actor ConcurrencyOCRStub: OCRServing {
    private var activeRequests = 0
    private(set) var maximumConcurrentRequests = 0

    func recognizeObservations(
        in image: UIImage,
        region: OCRRegion,
        regionOfInterest: NormalizedBoundingBox?
    ) async throws -> [OCRObservation] {
        activeRequests += 1
        maximumConcurrentRequests = max(maximumConcurrentRequests, activeRequests)
        defer { activeRequests -= 1 }
        try await Task.sleep(nanoseconds: 20_000_000)
        return []
    }
}

private actor RegionOrderOCRStub: OCRServing {
    func recognizeObservations(
        in image: UIImage,
        region: OCRRegion,
        regionOfInterest: NormalizedBoundingBox?
    ) async throws -> [OCRObservation] {
        guard region == .qrSurrounding, let regionOfInterest else { return [] }
        let isFirst = regionOfInterest.x < 0.5
        try await Task.sleep(nanoseconds: isFirst ? 20_000_000 : 1_000_000)
        return [OCRObservation(
            text: String(format: "region-%.1f", regionOfInterest.x),
            confidence: 1,
            boundingBox: regionOfInterest,
            region: .qrSurrounding
        )]
    }
}

private enum TestError: Error {
    case expected
}
