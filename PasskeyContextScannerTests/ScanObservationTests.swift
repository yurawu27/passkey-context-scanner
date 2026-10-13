import XCTest
@testable import PasskeyContextScanner

final class ScanObservationTests: XCTestCase {
    func testDerivesQRCodeSummaryFromObservations() {
        let firstBox = NormalizedBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.3)
        let secondBox = NormalizedBoundingBox(x: 0.6, y: 0.2, width: 0.2, height: 0.2)
        let observation = ScanObservation(
            qrCodes: [
                QRCodeObservation(type: .fido, boundingBox: firstBox),
                QRCodeObservation(type: .url, boundingBox: secondBox)
            ],
            ocrObservations: [],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        XCTAssertTrue(observation.qrDetected)
        XCTAssertEqual(observation.qrCount, 2)
        XCTAssertEqual(observation.qrBoundingBoxes, [firstBox, secondBox])
        XCTAssertEqual(observation.qrTypes, [.fido, .url])
    }

    func testNoQRCodeProducesConsistentEmptySummary() {
        let observation = ScanObservation(
            qrCodes: [],
            ocrObservations: [],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: false,
                issues: [.croppedContext]
            )
        )

        XCTAssertFalse(observation.qrDetected)
        XCTAssertEqual(observation.qrCount, 0)
        XCTAssertTrue(observation.qrBoundingBoxes.isEmpty)
        XCTAssertTrue(observation.qrTypes.isEmpty)
    }

    func testOCRConfidenceIsClampedToUnitRange() {
        let tooHigh = OCRObservation(
            text: "Sign in with a passkey",
            confidence: 1.4,
            boundingBox: .fullFrame,
            region: .fullFrame
        )
        let tooLow = OCRObservation(
            text: "Microsoft",
            confidence: -0.2,
            boundingBox: .fullFrame,
            region: .qrSurrounding
        )

        XCTAssertEqual(tooHigh.confidence, 1)
        XCTAssertEqual(tooLow.confidence, 0)
    }

    func testCodableRoundTripPreservesStructuredEvidence() throws {
        let original = ScanObservation(
            qrCodes: [
                QRCodeObservation(type: .unknown, boundingBox: .fullFrame)
            ],
            ocrObservations: [
                OCRObservation(
                    text: "Continue on your phone",
                    confidence: 0.92,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.2,
                        y: 0.4,
                        width: 0.5,
                        height: 0.1
                    ),
                    region: .qrSurrounding
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: [.glare]
            )
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScanObservation.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testUniqueOCRTextPrefersNearTextAndRemovesDuplicates() {
        let observation = ScanObservation(
            qrCodes: [],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft",
                    confidence: 0.8,
                    boundingBox: .fullFrame,
                    region: .fullFrame
                ),
                OCRObservation(
                    text: "Sign in with a passkey",
                    confidence: 0.9,
                    boundingBox: .fullFrame,
                    region: .qrSurrounding
                ),
                OCRObservation(
                    text: " microsoft ",
                    confidence: 0.95,
                    boundingBox: .fullFrame,
                    region: .qrSurrounding
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        XCTAssertEqual(
            observation.uniqueOCRText,
            "Sign in with a passkey\nmicrosoft"
        )
    }
}
