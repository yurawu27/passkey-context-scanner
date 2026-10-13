import AVFoundation
import XCTest
@testable import PasskeyContextScanner

final class CameraCaptureServiceTests: XCTestCase {
    func testMapsAllKnownAuthorizationStates() {
        XCTAssertEqual(
            CameraCaptureService.mapAuthorizationStatus(.notDetermined),
            .notDetermined
        )
        XCTAssertEqual(
            CameraCaptureService.mapAuthorizationStatus(.authorized),
            .authorized
        )
        XCTAssertEqual(
            CameraCaptureService.mapAuthorizationStatus(.denied),
            .denied
        )
        XCTAssertEqual(
            CameraCaptureService.mapAuthorizationStatus(.restricted),
            .restricted
        )
    }
}
