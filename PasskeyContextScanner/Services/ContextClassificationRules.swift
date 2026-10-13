import Foundation

struct RuleInput {
    let observation: ScanObservation
    let features: VisualContextFeatures
    let intent: UserIntent
    let policy: ClarificationPolicy

    func sourceObservationIds(
        for kinds: Set<VisualClaimKind>,
        includePeripheral: Bool = false
    ) -> [String] {
        var seen = Set<String>()
        return features.visualClaims.filter { claim in
            guard kinds.contains(claim.kind) else { return false }
            return includePeripheral || claim.associationStrength == .strong ||
                claim.associationStrength == .plausible
        }.map(\.sourceObservationId).filter { seen.insert($0).inserted }
    }
}

protocol ContextClassificationRule {
    var identifier: String { get }
    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult]
}

struct IdentityEvidenceRule: ContextClassificationRule {
    let identifier = "identity_evidence"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        var results: [ClassificationRuleResult] = []
        if !input.features.visibleServiceClaims.isEmpty {
            results.append(.positive(
                rule: identifier,
                completeness: 15,
                reason: "A visible service identity claim was detected.",
                evidence: input.features.visibleServiceClaims,
                sourceObservationIds: input.sourceObservationIds(for: [.service])
            ))
        }
        if !input.features.visibleDomainClaims.isEmpty {
            results.append(.positive(
                rule: identifier,
                completeness: 10,
                reason: "One or more visible domain claims were detected.",
                evidence: input.features.visibleDomainClaims,
                sourceObservationIds: input.sourceObservationIds(for: [.domain])
            ))
        }
        return results
    }
}

struct ServiceContradictionRule: ContextClassificationRule {
    let identifier = "service_mismatch"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard let event = input.features.identityContradictionEvents.first(where: {
            $0.kind == .serviceMismatch
        }) else { return [] }
        return [.negative(
            rule: identifier,
            severity: .strong,
            risk: 75,
            reason: "The QR-associated service conflicts with another credible service identity on the page or browser bar.",
            evidence: event.identities + event.domains,
            override: true,
            sourceObservationIds: event.sourceObservationIds
        )]
    }
}

struct BrandDomainConflictRule: ContextClassificationRule {
    let identifier = "brand_domain_conflict"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard let event = input.features.identityContradictionEvents.first(where: {
            $0.kind == .brandDomainConflict
        }) else { return [] }
        return [.negative(
            rule: identifier,
            severity: .strong,
            risk: 70,
            reason: "A credible page or browser-domain candidate conflicts with the QR-associated service identity.",
            evidence: event.identities + event.domains,
            override: true,
            sourceObservationIds: event.sourceObservationIds
        )]
    }
}

struct ExpectedServiceMismatchRule: ContextClassificationRule {
    let identifier = "expected_service_mismatch"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard input.features.contradictionFlags.contains(.expectedServiceMismatch) else {
            return []
        }
        return [.negative(
            rule: identifier,
            severity: .strong,
            risk: 80,
            reason: "The visible service conflicts with the service the user expected.",
            evidence: [
                input.intent.expectedService ?? "User rejected the detected service",
                input.features.visibleServiceClaims.joined(separator: ", ")
            ],
            override: true,
            sourceObservationIds: input.sourceObservationIds(for: [.service, .domain])
        )]
    }
}

struct CeremonyLanguageRule: ContextClassificationRule {
    let identifier = "ceremony_language"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard !input.features.authenticationTerms.isEmpty else { return [] }
        return [.positive(
            rule: identifier,
            completeness: 15,
            reason: "Visible wording describes an authentication ceremony.",
            evidence: input.features.authenticationTerms,
            sourceObservationIds: input.sourceObservationIds(for: [.authentication])
        )]
    }
}

struct ContextAssociationRule: ContextClassificationRule {
    let identifier = "context_association"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard input.features.contradictionFlags.contains(
            .ambiguousContextAssociation
        ) else { return [] }
        return [.negative(
            rule: identifier,
            category: .contextualConcern,
            severity: .moderate,
            risk: 0,
            reason: "Several visible identity contexts are similarly plausible, so the QR association cannot be resolved.",
            evidence: input.features.visibleServiceClaims +
                input.features.visibleDomainClaims +
                input.features.peripheralServiceClaims +
                input.features.peripheralDomainClaims
        )]
    }
}

struct PurposeMismatchRule: ContextClassificationRule {
    let identifier = "purpose_mismatch"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        var results: [ClassificationRuleResult] = []
        if !input.features.inferredPurposes.isEmpty {
            results.append(.positive(
                rule: identifier,
                completeness: 15,
                reason: "The visible context states a recognizable purpose.",
                evidence: input.features.inferredPurposes.map(\.rawValue),
                sourceObservationIds: input.sourceObservationIds(for: [.purpose])
            ))
        }
        if input.features.contradictionFlags.contains(.expectedPurposeMismatch) {
            results.append(.negative(
                rule: identifier,
                severity: .strong,
                risk: 70,
                reason: "The visible action conflicts with the action the user expected.",
                evidence: [
                    input.intent.expectedPurpose?.rawValue ?? "User rejected the detected purpose",
                    input.features.inferredPurposes.map(\.rawValue).joined(separator: ", ")
                ],
                override: true,
                sourceObservationIds: input.sourceObservationIds(for: [.purpose, .nonAuthenticationAction])
            ))
        }
        if input.features.contradictionFlags.contains(.competingPurposes) {
            results.append(.negative(
                rule: identifier,
                severity: .moderate,
                risk: 25,
                reason: "The display contains competing explanations of what the QR code does.",
                evidence: input.features.inferredPurposes.map(\.rawValue)
            ))
        }
        return results
    }
}

struct DirectPurposeMismatchRule: ContextClassificationRule {
    let identifier = "direct_purpose_mismatch"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard input.observation.qrTypes.contains(.fido),
              let strongest = input.features.purposeEvidence.map(\.priority).max(),
              strongest >= .sameDialogInstruction else { return [] }
        let purposes = input.features.purposeEvidence.filter {
            $0.priority == strongest
        }.map(\.purpose).uniqued()
        let conflicting = purposes.filter {
            $0 != .signIn && $0 != .registerPasskey && $0 != .unsure
        }
        guard !conflicting.isEmpty else { return [] }
        let sourceIDs = input.features.purposeEvidence.filter {
            $0.priority == strongest && conflicting.contains($0.purpose)
        }.flatMap(\.sourceObservationIds).uniqued()
        return [.negative(
            rule: identifier,
            severity: .strong,
            risk: 85,
            reason: "The direct QR instruction presents a FIDO ceremony as a different action.",
            evidence: conflicting.map(\.rawValue),
            override: true,
            sourceObservationIds: sourceIDs
        )]
    }
}

struct UrgencyAndCoercionRule: ContextClassificationRule {
    let identifier = "urgency_and_coercion"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        let cues = input.features.socialEngineeringCues
        guard !cues.isEmpty else { return [] }
        let strongCues: Set<SocialEngineeringCue> = [
            .threat, .ignoreWarnings, .secrecy, .authorityPressure, .repeatedApproval
        ]
        let missingIdentity = input.features.visibleServiceClaims.isEmpty &&
            input.features.visibleDomainClaims.isEmpty
        let isStrong = !strongCues.isDisjoint(with: Set(cues)) ||
            (missingIdentity && cues.contains(.urgency))
        return [.negative(
            rule: identifier,
            category: .persuasion,
            severity: isStrong ? .strong : .weak,
            risk: isStrong ? 60 : 15,
            reason: "The display contains social-engineering or coercive language.",
            evidence: cues.map(\.rawValue),
            override: cues.contains(.ignoreWarnings) ||
                (missingIdentity && cues.contains(.urgency)),
            sourceObservationIds: input.sourceObservationIds(for: [.socialEngineering])
        )]
    }
}

struct UnexpectedInitiationRule: ContextClassificationRule {
    let identifier = "unexpected_initiation"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard input.features.contradictionFlags.contains(.unexpectedInitiation) else {
            return []
        }
        let combinedWithPressure = !input.features.socialEngineeringCues.isEmpty
        return [.negative(
            rule: identifier,
            severity: combinedWithPressure ? .strong : .moderate,
            risk: combinedWithPressure ? 60 : 35,
            reason: "The user stated that they did not initiate this action.",
            evidence: [input.intent.initiationStatus.rawValue],
            override: combinedWithPressure
        )]
    }
}

struct ReceivingClientTrustRule: ContextClassificationRule {
    let identifier = "receiving_client_trust"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        var results: [ClassificationRuleResult] = []

        if input.features.contradictionFlags.contains(.receivingClientNotStarted) {
            results.append(.negative(
                rule: identifier,
                severity: .strong,
                risk: 70,
                reason: "The user did not start this request on the computer that may receive the session.",
                evidence: [input.intent.startedOnReceivingClient.rawValue],
                override: true
            ))
        }

        if input.features.contradictionFlags.contains(.untrustedReceivingClient) {
            results.append(.negative(
                rule: identifier,
                severity: .strong,
                risk: 80,
                reason: "The user stated that they do not trust the computer that may receive the session.",
                evidence: [input.intent.receivingClientTrust.rawValue],
                override: true
            ))
        }

        switch input.intent.receivingClientRelationship {
        case .someoneElsesDevice:
            results.append(.negative(
                rule: identifier,
                category: .contextualConcern,
                severity: .weak,
                risk: 0,
                reason: "The request may authenticate a computer belonging to someone else.",
                evidence: [input.intent.receivingClientRelationship.rawValue]
            ))
        case .publicOrKiosk:
            results.append(.negative(
                rule: identifier,
                category: .contextualConcern,
                severity: .weak,
                risk: 0,
                reason: "The request may authenticate a public computer or kiosk.",
                evidence: [input.intent.receivingClientRelationship.rawValue]
            ))
        case .ownDevice, .trustedSharedComputer, .unknown:
            break
        }

        if input.intent.hasTrustedReceivingClientContext {
            results.append(.positive(
                rule: identifier,
                completeness: 10,
                reason: "The user identified, initiated, and trusts the computer expected to receive the session.",
                evidence: [
                    input.intent.receivingClientRelationship.rawValue,
                    input.intent.startedOnReceivingClient.rawValue,
                    input.intent.receivingClientTrust.rawValue
                ]
            ))
        } else if results.isEmpty {
            let reason = input.policy == .participant
                ? "Receiving-computer ownership and general trust were not collected in the one-question participant assessment."
                : "The receiving computer, exact request initiation, or trust is unknown, so the scanner cannot return CONSISTENT."
            results.append(.limitation(
                rule: identifier,
                reason: reason,
                evidence: [
                    input.intent.receivingClientRelationship.rawValue,
                    input.intent.startedOnReceivingClient.rawValue,
                    input.intent.receivingClientTrust.rawValue
                ]
            ))
        }

        return results
    }
}

struct ChannelRiskRule: ContextClassificationRule {
    let identifier = "channel_risk"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        let risky: Set<ChannelCue> = [
            .emailOrChat, .kiosk, .printedPage, .unrelatedWebpage
        ]
        let detected = input.features.channelCues.filter { risky.contains($0) }
        guard !detected.isEmpty else { return [] }
        return [.negative(
            rule: identifier,
            category: .contextualConcern,
            severity: .weak,
            risk: 0,
            reason: "The QR code is presented through an unusual or less trusted channel.",
            evidence: detected.map(\.rawValue)
        )]
    }
}

struct ContextCompletenessRule: ContextClassificationRule {
    let identifier = "context_completeness"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        var results: [ClassificationRuleResult] = []
        if input.observation.qrTypes.contains(.fido) {
            results.append(.positive(
                rule: identifier,
                completeness: 15,
                reason: "The detected QR format appears FIDO-related.",
                evidence: [QRCodeType.fido.rawValue]
            ))
        }
        if input.observation.ocrProcessingStatus == .completed {
            results.append(.positive(
                rule: identifier,
                completeness: 5,
                reason: "OCR processing completed.",
                evidence: [OCRProcessingStatus.completed.rawValue]
            ))
        } else {
            results.append(.limitation(
                rule: identifier,
                reason: "OCR evidence is incomplete or unavailable.",
                evidence: [input.observation.ocrProcessingStatus.rawValue]
            ))
        }
        if input.features.lowConfidenceObservationCount > 0 {
            results.append(.limitation(
                rule: identifier,
                reason: "Some OCR text was too uncertain to use for security decisions.",
                evidence: ["\(input.features.lowConfidenceObservationCount) low-confidence observation(s)"]
            ))
        }
        if !input.observation.imageQuality.isSufficientForAnalysis {
            results.append(.limitation(
                rule: identifier,
                reason: "The captured image does not provide sufficient visual quality for a consistent result.",
                evidence: input.observation.imageQuality.issues.map(\.rawValue)
            ))
        }
        if input.intent.hasServiceAndPurposeExpectation {
            results.append(.positive(
                rule: identifier,
                completeness: 10,
                reason: "Expected service and purpose are available for comparison.",
                evidence: [input.intent.expectedService ?? "Purpose or initiation supplied"]
            ))
        } else if input.intent.hasDeclaredIntent {
            results.append(.positive(
                rule: identifier,
                completeness: 5,
                reason: "Partial user intent is available.",
                evidence: [input.intent.expectedService ?? "Purpose or initiation supplied"]
            ))
            let reason = input.policy == .participant
                ? "Expected service and purpose were not collected in the one-question participant assessment."
                : "Both expected service and purpose are required before the scanner can return CONSISTENT."
            results.append(.limitation(
                rule: identifier,
                reason: reason,
                evidence: []
            ))
        } else {
            let reason = input.policy == .participant
                ? "Expected service and purpose were not collected in the one-question participant assessment."
                : "Expected service and purpose were not provided, so the scanner cannot return CONSISTENT."
            results.append(.limitation(
                rule: identifier,
                reason: reason,
                evidence: []
            ))
        }
        if input.features.visibleServiceClaims.isEmpty &&
            input.features.visibleDomainClaims.isEmpty {
            results.append(.limitation(
                rule: identifier,
                reason: "No clear visible service identity was found.",
                evidence: []
            ))
        }
        if input.features.inferredPurposes.isEmpty {
            results.append(.limitation(
                rule: identifier,
                reason: "No clear purpose was found in the visible context.",
                evidence: []
            ))
        }
        return results
    }
}

struct SpatialRelevanceRule: ContextClassificationRule {
    let identifier = "spatial_relevance"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        let materialKinds: Set<VisualClaimKind> = [
            .service, .domain, .authentication, .purpose, .purposePattern,
            .nonAuthenticationAction, .socialEngineering
        ]
        let materialSourceIDs = Set(input.features.visualClaims.filter {
            materialKinds.contains($0.kind) &&
                ($0.associationStrength == .strong ||
                 $0.associationStrength == .plausible)
        }.map(\.sourceObservationId))
        let nearText = input.features.spatialEvidence
            .filter {
                $0.proximity == .near &&
                    materialSourceIDs.contains($0.observationId)
            }
            .map { "\($0.text) [distance: \(formatDistance($0.normalizedDistanceToQRCode))]" }
        guard !nearText.isEmpty else {
            return [.limitation(
                rule: identifier,
                reason: "No security-relevant identity, purpose, or authentication instruction was found close to the QR code.",
                evidence: []
            )]
        }
        return [.positive(
            rule: identifier,
            completeness: 15,
            reason: "Security-relevant instructions were found close to the QR code.",
            evidence: nearText
        )]
    }

    private func formatDistance(_ distance: Double?) -> String {
        guard let distance else { return "n/a" }
        return String(format: "%.3f", distance)
    }
}

struct MultipleQRCodeRule: ContextClassificationRule {
    let identifier = "multiple_qr_codes"

    func evaluate(_ input: RuleInput) -> [ClassificationRuleResult] {
        guard input.observation.qrCount > 1 else { return [] }
        return [.negative(
            rule: identifier,
            category: .contextualConcern,
            severity: .moderate,
            risk: 0,
            reason: "Several QR codes create competing contexts.",
            evidence: ["QR count: \(input.observation.qrCount)"]
        )]
    }
}

private extension ClassificationRuleResult {
    static func positive(
        rule: String,
        completeness: Int,
        reason: String,
        evidence: [String],
        sourceObservationIds: [String] = []
    ) -> Self {
        Self(
            ruleIdentifier: rule,
            severity: .informational,
            polarity: .positive,
            evidenceCategory: .supporting,
            riskContribution: 0,
            completenessContribution: completeness,
            reason: reason,
            evidence: evidence,
            triggersSuspiciousOverride: false,
            sourceObservationIds: sourceObservationIds
        )
    }

    static func negative(
        rule: String,
        category: EvidenceCategory = .contradiction,
        severity: RuleSeverity,
        risk: Int,
        reason: String,
        evidence: [String],
        override: Bool = false,
        sourceObservationIds: [String] = []
    ) -> Self {
        Self(
            ruleIdentifier: rule,
            severity: severity,
            polarity: .negative,
            evidenceCategory: category,
            riskContribution: risk,
            completenessContribution: 0,
            reason: reason,
            evidence: evidence,
            triggersSuspiciousOverride: override,
            sourceObservationIds: sourceObservationIds
        )
    }

    static func limitation(
        rule: String,
        reason: String,
        evidence: [String]
    ) -> Self {
        Self(
            ruleIdentifier: rule,
            severity: .informational,
            polarity: .limitation,
            evidenceCategory: .missingEvidence,
            riskContribution: 0,
            completenessContribution: 0,
            reason: reason,
            evidence: evidence,
            triggersSuspiciousOverride: false
        )
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
