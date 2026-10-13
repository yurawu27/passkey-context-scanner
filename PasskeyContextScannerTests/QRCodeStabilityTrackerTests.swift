import XCTest
@testable import PasskeyContextScanner

final class QRCodeStabilityTrackerTests: XCTestCase {
    func testBecomesStableAfterRequiredMatchingObservations() {
        var tracker = QRCodeStabilityTracker(
            requiredConsecutiveObservations: 3,
            minimumIntersectionOverUnion: 0.7
        )
        let detection = makeDetection(x: 0.2, y: 0.3)

        tracker.update(with: [detection])
        XCTAssertFalse(tracker.isStable)
        tracker.update(with: [makeDetection(x: 0.205, y: 0.305)])
        XCTAssertFalse(tracker.isStable)
        tracker.update(with: [makeDetection(x: 0.21, y: 0.31)])

        XCTAssertTrue(tracker.isStable)
        XCTAssertEqual(tracker.consecutiveStableObservations, 3)
    }

    func testLargeMovementRestartsStabilityCount() {
        var tracker = QRCodeStabilityTracker()
        tracker.update(with: [makeDetection(x: 0.1, y: 0.1)])
        tracker.update(with: [makeDetection(x: 0.1, y: 0.1)])

        tracker.update(with: [makeDetection(x: 0.7, y: 0.7)])

        XCTAssertFalse(tracker.isStable)
        XCTAssertEqual(tracker.consecutiveStableObservations, 1)
    }

    func testMissingQRCodeResetsTracker() {
        var tracker = QRCodeStabilityTracker(
            requiredConsecutiveObservations: 2
        )
        tracker.update(with: [makeDetection(x: 0.2, y: 0.2)])
        tracker.update(with: [makeDetection(x: 0.2, y: 0.2)])
        XCTAssertTrue(tracker.isStable)

        tracker.update(with: [])

        XCTAssertFalse(tracker.isStable)
        XCTAssertEqual(tracker.consecutiveStableObservations, 0)
    }

    func testDetectionOrderingDoesNotBreakMultipleQRCodeStability() {
        var tracker = QRCodeStabilityTracker(
            requiredConsecutiveObservations: 2
        )
        let left = makeDetection(x: 0.1, y: 0.2, type: .fido)
        let right = makeDetection(x: 0.7, y: 0.2, type: .url)

        tracker.update(with: [left, right])
        tracker.update(with: [right, left])

        XCTAssertTrue(tracker.isStable)
    }

    func testTypeChangeRestartsStabilityCount() {
        var tracker = QRCodeStabilityTracker(
            requiredConsecutiveObservations: 2
        )
        tracker.update(with: [makeDetection(x: 0.2, y: 0.2, type: .unknown)])
        tracker.update(with: [makeDetection(x: 0.2, y: 0.2, type: .fido)])

        XCTAssertFalse(tracker.isStable)
        XCTAssertEqual(tracker.consecutiveStableObservations, 1)
    }

    private func makeDetection(
        x: Double,
        y: Double,
        type: QRCodeType = .fido
    ) -> LiveQRCodeDetection {
        LiveQRCodeDetection(
            type: type,
            metadataBoundingBox: NormalizedBoundingBox(
                x: x,
                y: y,
                width: 0.2,
                height: 0.2
            )
        )
    }
}
