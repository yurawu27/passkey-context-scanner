import XCTest
import CoreImage
import UIKit
@testable import PasskeyContextScanner

final class QRDetectionServiceTests: XCTestCase {
    func testClassifiesFIDOCaseInsensitively() {
        XCTAssertEqual(QRDetectionService.classifyPayload("FIDO:/example"), .fido)
        XCTAssertEqual(QRDetectionService.classifyPayload("fido:/example"), .fido)
    }

    func testClassifiesHTTPURLs() {
        XCTAssertEqual(
            QRDetectionService.classifyPayload("https://login.example.com/path"),
            .url
        )
        XCTAssertEqual(QRDetectionService.classifyPayload("http://example.com"), .url)
    }

    func testDoesNotTreatArbitrarySchemesOrTextAsWebURLs() {
        XCTAssertEqual(QRDetectionService.classifyPayload("mailto:user@example.com"), .other)
        XCTAssertEqual(QRDetectionService.classifyPayload("example.com"), .other)
        XCTAssertEqual(QRDetectionService.classifyPayload("pair this device"), .other)
    }

    func testMissingPayloadIsUnknown() {
        XCTAssertEqual(QRDetectionService.classifyPayload(nil), .unknown)
    }

    func testDetectsGeneratedFIDOQRCodeWithoutRetainingPayload() async throws {
        let payload = "FIDO:/dissertation-test-material"
        let data = try XCTUnwrap(payload.data(using: .utf8))
        let filter = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let output = try XCTUnwrap(filter.outputImage?.transformed(
            by: CGAffineTransform(scaleX: 12, y: 12)
        ))
        let cgImage = try XCTUnwrap(
            CIContext().createCGImage(output, from: output.extent)
        )

        let observations: [QRCodeObservation]
        do {
            observations = try await QRDetectionService().detectQRCodes(
                in: UIImage(cgImage: cgImage)
            )
        } catch {
            #if targetEnvironment(simulator)
            let visionError = error as NSError
            if visionError.domain == "com.apple.Vision", visionError.code == 9 {
                throw XCTSkip(
                    "The simulator could not create a Vision inference context; verify QR detection on a physical device."
                )
            }
            #endif
            throw error
        }

        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations.first?.type, .fido)
    }
}
