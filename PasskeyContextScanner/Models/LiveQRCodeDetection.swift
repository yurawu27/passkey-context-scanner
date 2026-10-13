import Foundation

/// Privacy-preserving live metadata used only for preview and stability.
///
/// The bounding box uses AVFoundation's normalized metadata-output coordinate
/// space. The decoded payload is deliberately not retained.
struct LiveQRCodeDetection: Equatable {
    let type: QRCodeType
    let metadataBoundingBox: NormalizedBoundingBox
}

struct QRCodeStabilityTracker {
    let requiredConsecutiveObservations: Int
    let minimumIntersectionOverUnion: Double

    private(set) var consecutiveStableObservations = 0
    private var previousDetections: [LiveQRCodeDetection] = []

    init(
        requiredConsecutiveObservations: Int = 3,
        minimumIntersectionOverUnion: Double = 0.7
    ) {
        self.requiredConsecutiveObservations = max(
            requiredConsecutiveObservations,
            1
        )
        self.minimumIntersectionOverUnion = min(
            max(minimumIntersectionOverUnion, 0),
            1
        )
    }

    var isStable: Bool {
        consecutiveStableObservations >= requiredConsecutiveObservations
    }

    mutating func update(with detections: [LiveQRCodeDetection]) {
        let current = sorted(detections)
        let previous = sorted(previousDetections)

        guard !current.isEmpty,
              current.count == previous.count,
              zip(current, previous).allSatisfy({
                  $0.type == $1.type &&
                      intersectionOverUnion(
                          $0.metadataBoundingBox,
                          $1.metadataBoundingBox
                      ) >= minimumIntersectionOverUnion
              }) else {
            consecutiveStableObservations = current.isEmpty ? 0 : 1
            previousDetections = current
            return
        }

        consecutiveStableObservations += 1
        previousDetections = current
    }

    mutating func reset() {
        consecutiveStableObservations = 0
        previousDetections = []
    }

    private func sorted(
        _ detections: [LiveQRCodeDetection]
    ) -> [LiveQRCodeDetection] {
        detections.sorted {
            if $0.metadataBoundingBox.x == $1.metadataBoundingBox.x {
                return $0.metadataBoundingBox.y < $1.metadataBoundingBox.y
            }
            return $0.metadataBoundingBox.x < $1.metadataBoundingBox.x
        }
    }

    private func intersectionOverUnion(
        _ first: NormalizedBoundingBox,
        _ second: NormalizedBoundingBox
    ) -> Double {
        let intersectionWidth = max(
            0,
            min(first.x + first.width, second.x + second.width) -
                max(first.x, second.x)
        )
        let intersectionHeight = max(
            0,
            min(first.y + first.height, second.y + second.height) -
                max(first.y, second.y)
        )
        let intersection = intersectionWidth * intersectionHeight
        let union = first.width * first.height +
            second.width * second.height -
            intersection
        return union > 0 ? intersection / union : 0
    }
}
