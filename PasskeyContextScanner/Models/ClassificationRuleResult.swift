import Foundation

enum RuleSeverity: String, Codable, Equatable {
    case informational = "INFORMATIONAL"
    case weak = "WEAK"
    case moderate = "MODERATE"
    case strong = "STRONG"
}

enum EvidencePolarity: String, Codable, Equatable {
    case positive = "POSITIVE"
    case negative = "NEGATIVE"
    case limitation = "LIMITATION"
}

/// Describes what a rule result means, independently of its numerical score.
enum EvidenceCategory: String, Codable, CaseIterable, Equatable, Hashable {
    case supporting = "SUPPORTING"
    case contradiction = "CONTRADICTION"
    case persuasion = "PERSUASION"
    case missingEvidence = "MISSING_EVIDENCE"
    case contextualConcern = "CONTEXTUAL_CONCERN"
}

struct ClassificationRuleResult: Codable, Equatable {
    let ruleIdentifier: String
    let severity: RuleSeverity
    let polarity: EvidencePolarity
    let evidenceCategory: EvidenceCategory
    let riskContribution: Int
    let completenessContribution: Int
    let reason: String
    let evidence: [String]
    let triggersSuspiciousOverride: Bool
    let sourceObservationIds: [String]

    init(
        ruleIdentifier: String,
        severity: RuleSeverity,
        polarity: EvidencePolarity,
        evidenceCategory: EvidenceCategory,
        riskContribution: Int,
        completenessContribution: Int,
        reason: String,
        evidence: [String],
        triggersSuspiciousOverride: Bool,
        sourceObservationIds: [String] = []
    ) {
        self.ruleIdentifier = ruleIdentifier
        self.severity = severity
        self.polarity = polarity
        self.evidenceCategory = evidenceCategory
        self.riskContribution = riskContribution
        self.completenessContribution = completenessContribution
        self.reason = reason
        self.evidence = evidence
        self.triggersSuspiciousOverride = triggersSuspiciousOverride
        self.sourceObservationIds = sourceObservationIds
    }

    private enum CodingKeys: String, CodingKey {
        case ruleIdentifier, severity, polarity, evidenceCategory
        case riskContribution, completenessContribution, reason, evidence
        case triggersSuspiciousOverride, sourceObservationIds
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ruleIdentifier = try values.decode(String.self, forKey: .ruleIdentifier)
        severity = try values.decode(RuleSeverity.self, forKey: .severity)
        polarity = try values.decode(EvidencePolarity.self, forKey: .polarity)
        evidenceCategory = try values.decode(EvidenceCategory.self, forKey: .evidenceCategory)
        riskContribution = try values.decode(Int.self, forKey: .riskContribution)
        completenessContribution = try values.decode(Int.self, forKey: .completenessContribution)
        reason = try values.decode(String.self, forKey: .reason)
        evidence = try values.decode([String].self, forKey: .evidence)
        triggersSuspiciousOverride = try values.decode(
            Bool.self,
            forKey: .triggersSuspiciousOverride
        )
        sourceObservationIds = try values.decodeIfPresent(
            [String].self,
            forKey: .sourceObservationIds
        ) ?? []
    }
}
