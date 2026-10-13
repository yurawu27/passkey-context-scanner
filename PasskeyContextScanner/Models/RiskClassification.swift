import Foundation

enum RiskClassification: String, Codable, CaseIterable, Equatable, Hashable {
    case consistent = "CONSISTENT"
    case suspicious = "SUSPICIOUS"
    case uncertain = "UNCERTAIN"
}

enum ApplicationMode: String, Codable, CaseIterable, Identifiable {
    case participant
    case researcher

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .participant: return "Participant"
        case .researcher: return "Researcher"
        }
    }
}

enum SecurityResultStyle: String, Codable, Equatable {
    case quiet
    case caution
    case activeWarning
}

/// User-facing intervention copy kept separate from the research classification.
/// This deliberately describes visible evidence without implying verification.
struct SecurityResultPresentation: Equatable {
    let headline: String
    let primaryReasonIdentifier: String
    let primaryReason: String
    let recommendedActionIdentifier: String
    let recommendedAction: String
    let limitation: String
    let checklistTitle: String
    let safetyChecks: [String]
    let systemImage: String
    let style: SecurityResultStyle

    var accessibilitySummary: String {
        let status: String
        switch style {
        case .quiet: status = "Context assessment"
        case .caution: status = "Caution"
        case .activeWarning: status = "Security warning"
        }
        return "\(status). \(headline). \(primaryReason) \(recommendedAction) \(limitation)"
    }

    static func make(for result: ScanResult) -> SecurityResultPresentation {
        let limitation = "This scanner checks visible context only. It cannot verify who controls the receiving session."

        switch result.classification {
        case .consistent:
            let reason = PrimaryReasonSelector().select(from: result)
            let action = recommendedAction(for: reason, classification: .consistent)
            return SecurityResultPresentation(
                headline: "No obvious context conflict found",
                primaryReasonIdentifier: reason.identifier,
                primaryReason: reason.text,
                recommendedActionIdentifier: action.identifier,
                recommendedAction: action.text,
                limitation: limitation,
                checklistTitle: "Before approving",
                safetyChecks: safetyChecks(for: result, restarting: false),
                systemImage: "info.circle.fill",
                style: .quiet
            )
        case .uncertain:
            let reason = PrimaryReasonSelector().select(from: result)
            let action = recommendedAction(for: reason, classification: .uncertain)
            return SecurityResultPresentation(
                headline: "Not enough information",
                primaryReasonIdentifier: reason.identifier,
                primaryReason: reason.text,
                recommendedActionIdentifier: action.identifier,
                recommendedAction: action.text,
                limitation: limitation,
                checklistTitle: "Before approving",
                safetyChecks: safetyChecks(for: result, restarting: false),
                systemImage: "questionmark.diamond.fill",
                style: .caution
            )
        case .suspicious:
            let reason = PrimaryReasonSelector().select(from: result)
            let action = recommendedAction(for: reason, classification: .suspicious)
            return SecurityResultPresentation(
                headline: "Possible misleading sign-in",
                primaryReasonIdentifier: reason.identifier,
                primaryReason: reason.text,
                recommendedActionIdentifier: action.identifier,
                recommendedAction: action.text,
                limitation: limitation,
                checklistTitle: "If you restart the sign-in",
                safetyChecks: safetyChecks(for: result, restarting: true),
                systemImage: "exclamationmark.triangle.fill",
                style: .activeWarning
            )
        }
    }

    private static func recommendedAction(
        for reason: SecurityPrimaryReason,
        classification: RiskClassification
    ) -> SecurityRecommendedAction {
        if classification == .consistent {
            return SecurityRecommendedAction(
                identifier: "proceed_with_checks",
                text: "Before approving, confirm the service shown by the phone and that you trust the computer receiving the session."
            )
        }
        if classification == .uncertain {
            switch reason.identifier {
            case "receiving_client_trust":
                return SecurityRecommendedAction(
                    identifier: "confirm_exact_computer",
                    text: "Only continue if this is the computer where you started the exact sign-in."
                )
            case "context_association", "multiple_qr_codes":
                return SecurityRecommendedAction(
                    identifier: "rescan_qr_context",
                    text: "Scan again with only the QR dialog and its instructions clearly framed."
                )
            case "spatial_relevance":
                return SecurityRecommendedAction(
                    identifier: "rescan_full_page",
                    text: "Scan again with the QR code and its complete sign-in page visible."
                )
            case "context_completeness":
                if reason.text.contains("couldn’t read enough text") {
                    return SecurityRecommendedAction(
                        identifier: "rescan_full_page",
                        text: "Scan again with the QR code and its complete sign-in page visible."
                    )
                }
                if reason.text.contains("did not clearly identify the service") {
                    return SecurityRecommendedAction(
                        identifier: "check_phone_service",
                        text: "Before approving, check that your phone shows the service you expected."
                    )
                }
                if reason.text.contains("did not clearly explain") {
                    return SecurityRecommendedAction(
                        identifier: "check_intended_action",
                        text: "Before approving, check that the action on your phone matches what you intended."
                    )
                }
                return SecurityRecommendedAction(
                    identifier: "confirm_initiation",
                    text: "Only continue if you started this exact sign-in yourself."
                )
            default:
                return SecurityRecommendedAction(
                    identifier: "pause_and_confirm_context",
                    text: "Pause and confirm that the service and sign-in request match what you intended."
                )
            }
        }

        switch reason.identifier {
        case "unexpected_initiation":
            return SecurityRecommendedAction(identifier: "restart_self_initiated", text: "Do not approve this request. Close it and start the sign-in yourself from the service you intended to use.")
        case "receiving_client_trust":
            return SecurityRecommendedAction(identifier: "restart_trusted_computer", text: "Do not approve this request. Restart the sign-in on a computer you recognise and trust.")
        case "expected_service_mismatch", "service_mismatch", "brand_domain_conflict",
             "identity_evidence":
            return SecurityRecommendedAction(identifier: "navigate_independently", text: "Do not approve this request. Navigate independently to the service you intended to use and begin again.")
        case "purpose_mismatch", "direct_purpose_mismatch", "unrelated_action":
            return SecurityRecommendedAction(identifier: "restart_intended_action", text: "Do not approve this request. Return to the action you intended and start it again through the service itself.")
        case "urgency_and_coercion":
            return SecurityRecommendedAction(identifier: "contact_trusted_channel", text: "Do not approve under pressure. Close the request and contact the service through a channel you already trust.")
        default:
            return SecurityRecommendedAction(identifier: "restart_trusted_context", text: "Do not approve this request. Close it and start a new sign-in from a website and computer you trust.")
        }
    }

    private static func safetyChecks(
        for result: ScanResult,
        restarting: Bool
    ) -> [String] {
        var checks: [String] = []
        func finding(_ kind: AssessmentDimensionKind) -> DimensionFinding? {
            result.assessmentDimensions.first { $0.kind == kind }?.finding
        }

        if restarting || finding(.initiation) != .aligned {
            checks.append("Start this exact sign-in yourself.")
        }
        checks.append("Check that the phone names the service you expected.")
        if restarting || finding(.receivingClient) != .aligned {
            checks.append("Use a computer you recognise and trust to receive the session.")
        }
        if finding(.purpose) != .aligned {
            checks.append("Confirm that signing in is the action you intended.")
        }

        var seen = Set<String>()
        return Array(checks.filter { seen.insert($0).inserted }.prefix(4))
    }
}

private struct SecurityRecommendedAction {
    let identifier: String
    let text: String
}

struct SecurityPrimaryReason: Equatable {
    let identifier: String
    let text: String
}

/// Selects one explanation using a documented security priority rather than
/// relying on the order in which classifier rules happened to run.
struct PrimaryReasonSelector {
    func select(from result: ScanResult) -> SecurityPrimaryReason {
        select(from: result, classification: result.classification)
    }

    func select(
        from result: ScanResult,
        classification: RiskClassification
    ) -> SecurityPrimaryReason {
        let candidates = result.ruleResults.enumerated().filter { _, rule in
            eligible(rule, for: classification)
        }
        if let selected = candidates.max(by: { lhs, rhs in
            let left = priority(of: lhs.element, for: classification)
            let right = priority(of: rhs.element, for: classification)
            return left == right ? lhs.offset > rhs.offset : left < right
        })?.element {
            return SecurityPrimaryReason(
                identifier: selected.ruleIdentifier,
                text: userFacingText(for: selected)
            )
        }

        let fallback: String
        switch classification {
        case .consistent:
            fallback = result.reasons.first ?? "The visible information did not contain an obvious contradiction."
        case .uncertain:
            fallback = result.reasons.first ?? "The visible context was incomplete or unclear."
        case .suspicious:
            fallback = result.observedNegativeEvidence.first ?? result.reasons.first ?? "The visible context contains a strong contradiction."
        }
        return SecurityPrimaryReason(identifier: "classification_fallback", text: fallback)
    }

    private func eligible(
        _ rule: ClassificationRuleResult,
        for classification: RiskClassification
    ) -> Bool {
        switch classification {
        case .consistent:
            return rule.evidenceCategory == .supporting
        case .uncertain:
            return rule.evidenceCategory == .missingEvidence ||
                rule.evidenceCategory == .contextualConcern
        case .suspicious:
            return rule.polarity == .negative
        }
    }

    private func priority(
        of rule: ClassificationRuleResult,
        for classification: RiskClassification
    ) -> Int {
        if classification == .uncertain {
            return missingEvidencePriority(rule)
        }

        switch rule.ruleIdentifier {
        case "unexpected_initiation": return 100
        case "receiving_client_trust":
            if rule.reason.contains("did not start") { return 95 }
            if rule.reason.contains("do not trust") { return 90 }
            return 85
        case "expected_service_mismatch": return 80
        case "service_mismatch": return 78
        case "brand_domain_conflict": return 76
        case "purpose_mismatch", "direct_purpose_mismatch": return 70
        case "unrelated_action": return 60
        case "urgency_and_coercion": return 50
        case "identity_evidence": return 40
        case "multiple_qr_codes": return 30
        case "channel_risk": return 20
        default: return rule.severity == .strong ? 15 : 10
        }
    }

    private func missingEvidencePriority(_ rule: ClassificationRuleResult) -> Int {
        if rule.reason.contains("OCR evidence") { return 100 }
        if rule.ruleIdentifier == "receiving_client_trust" { return 95 }
        if rule.reason.contains("service identity") { return 90 }
        if rule.ruleIdentifier == "context_association" { return 85 }
        if rule.ruleIdentifier == "multiple_qr_codes" { return 85 }
        if rule.reason.contains("No clear purpose") { return 80 }
        if rule.ruleIdentifier == "spatial_relevance" { return 70 }
        if rule.reason.contains("Expected service and purpose") ||
            rule.reason.contains("Both expected service and purpose") { return 60 }
        return 10
    }

    private func userFacingText(for rule: ClassificationRuleResult) -> String {
        switch rule.ruleIdentifier {
        case "unexpected_initiation":
            return "You said you did not start this request."
        case "receiving_client_trust":
            if rule.reason.contains("did not start") {
                return "You said you did not start this request on the computer showing the QR code."
            }
            if rule.reason.contains("do not trust") {
                return "You said you do not trust the computer that may receive the signed-in session."
            }
            return "We couldn’t confirm that you started this sign-in on the computer showing the QR code."
        case "expected_service_mismatch":
            guard rule.evidence.count >= 2 else { return rule.reason }
            return "You expected \(rule.evidence[0]), but the visible page refers to \(rule.evidence[1])."
        case "service_mismatch":
            return "The service named beside the QR code conflicts with the service shown by the surrounding page."
        case "brand_domain_conflict":
            return "A visible page identity conflicts with a domain-like claim shown elsewhere on the screen."
        case "purpose_mismatch":
            guard rule.evidence.count >= 2 else { return rule.reason }
            return "The visible action does not match the action you expected."
        case "direct_purpose_mismatch":
            return "The instructions describe the QR code as a different action rather than a passkey sign-in."
        case "unrelated_action":
            return "This passkey sign-in is presented as an unrelated action."
        case "urgency_and_coercion":
            return "The page uses pressure or persuasion that may encourage a rushed approval."
        case "identity_evidence":
            return rule.reason
        case "context_association":
            return "Several visible contexts were captured, and it is unclear which one describes the QR code."
        case "multiple_qr_codes":
            return "More than one QR code is visible, so the intended sign-in is unclear."
        case "spatial_relevance":
            return "We couldn’t associate enough readable instructions with the QR code."
        case "context_completeness":
            if rule.reason.contains("OCR evidence") {
                return "We couldn’t read enough text around the QR code."
            }
            if rule.reason.contains("service identity") {
                return "The page did not clearly identify the service for this sign-in."
            }
            if rule.reason.contains("No clear purpose") {
                return "The page did not clearly explain what scanning this QR code would do."
            }
            if rule.reason.contains("Expected service and purpose") ||
                rule.reason.contains("Both expected service and purpose") {
                return "We don’t have enough information about the sign-in you intended."
            }
            return "The visible sign-in context was incomplete."
        default:
            return rule.reason
        }
    }
}
