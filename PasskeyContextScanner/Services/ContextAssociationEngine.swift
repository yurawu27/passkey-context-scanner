import Foundation

/// Explainable QR-relative association used before semantic security extraction.
/// Geometry remains the primary signal; OCR source, alignment, and explicit
/// QR-instruction wording can strengthen—but never authenticate—the association.
struct ContextAssociationEngine {
    struct Association: Equatable {
        let qrIndex: Int?
        let qrBoundingBox: NormalizedBoundingBox?
        let normalizedDistance: Double?
        let proximity: SpatialProximity
        let zone: ContextZone
        let strength: AssociationStrength
    }

    func associate(
        _ observation: OCRObservation,
        with qrCodes: [QRCodeObservation]
    ) -> Association {
        guard let closest = qrCodes.enumerated().map({ index, qrCode in
            (
                index: index,
                box: qrCode.boundingBox,
                distance: rectangleDistance(observation.boundingBox, qrCode.boundingBox)
            )
        }).min(by: { $0.distance < $1.distance }) else {
            return Association(
                qrIndex: nil,
                qrBoundingBox: nil,
                normalizedDistance: nil,
                proximity: .notAssessable,
                zone: .unassociated,
                strength: .unassociated
            )
        }

        let proximity = proximity(for: closest.distance)
        var score = baseScore(for: proximity)
        if observation.region == .qrSurrounding { score += 1 }
        if isAxisAligned(observation.boundingBox, with: closest.box) { score += 1 }
        if containsQRInstruction(observation.text) { score += 1 }

        return Association(
            qrIndex: closest.index,
            qrBoundingBox: closest.box,
            normalizedDistance: closest.distance,
            proximity: proximity,
            zone: zone(for: proximity),
            strength: strength(for: score, proximity: proximity)
        )
    }

    private func proximity(for distance: Double) -> SpatialProximity {
        if distance <= 0.08 { return .near }
        if distance <= 0.25 { return .adjacent }
        return .distant
    }

    private func zone(for proximity: SpatialProximity) -> ContextZone {
        switch proximity {
        case .near: .primary
        case .adjacent: .adjacent
        case .distant: .peripheral
        case .notAssessable: .unassociated
        }
    }

    private func baseScore(for proximity: SpatialProximity) -> Int {
        switch proximity {
        case .near: 4
        case .adjacent: 2
        case .distant: 1
        case .notAssessable: 0
        }
    }

    private func strength(
        for score: Int,
        proximity: SpatialProximity
    ) -> AssociationStrength {
        // Distant text cannot be strongly associated from lightweight image
        // heuristics alone, even when its wording resembles an instruction.
        if proximity == .distant {
            return score >= 4 ? .plausible : .weak
        }
        if score >= 4 { return .strong }
        if score >= 2 { return .plausible }
        if score == 1 { return .weak }
        return .unassociated
    }

    private func isAxisAligned(
        _ text: NormalizedBoundingBox,
        with qr: NormalizedBoundingBox
    ) -> Bool {
        let tolerance = 0.08
        let textCenterX = text.x + text.width / 2
        let textCenterY = text.y + text.height / 2
        let horizontallyAligned = textCenterX >= qr.x - tolerance &&
            textCenterX <= qr.x + qr.width + tolerance
        let verticallyAligned = textCenterY >= qr.y - tolerance &&
            textCenterY <= qr.y + qr.height + tolerance
        return horizontallyAligned || verticallyAligned
    }

    private func containsQRInstruction(_ text: String) -> Bool {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ).lowercased()
        return [
            "scan this qr", "scan the qr", "qr code", "use your phone",
            "scan with your phone", "continue on your phone",
            "use another device", "passkey",
            "security key"
        ].contains { normalized.contains($0) }
    }

    private func rectangleDistance(
        _ first: NormalizedBoundingBox,
        _ second: NormalizedBoundingBox
    ) -> Double {
        let firstMaxX = first.x + first.width
        let firstMaxY = first.y + first.height
        let secondMaxX = second.x + second.width
        let secondMaxY = second.y + second.height
        let dx = max(second.x - firstMaxX, first.x - secondMaxX, 0)
        let dy = max(second.y - firstMaxY, first.y - secondMaxY, 0)
        return hypot(dx, dy)
    }
}
