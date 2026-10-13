import Foundation

enum ContextAssociationPolicy: String, Codable, Equatable {
    case spatiallyAssociated = "SPATIALLY_ASSOCIATED"
    case unfilteredVisualText = "UNFILTERED_VISUAL_TEXT"
}

struct ClassifierConfiguration: Codable, Equatable, Identifiable {
    let id: String
    let associationPolicy: ContextAssociationPolicy
    let usesIntent: Bool
    let excludedRuleIdentifiers: Set<String>

    static let full = ClassifierConfiguration(
        id: "MULTI_SIGNAL_SPATIAL_INTENT",
        associationPolicy: .spatiallyAssociated,
        usesIntent: true,
        excludedRuleIdentifiers: []
    )

    static let unfilteredVisualText = ClassifierConfiguration(
        id: "MULTI_SIGNAL",
        associationPolicy: .unfilteredVisualText,
        usesIntent: false,
        excludedRuleIdentifiers: intentRuleIdentifiers
    )

    static let identityDomainOnly = ClassifierConfiguration(
        id: "IDENTITY_DOMAIN_ONLY",
        associationPolicy: .unfilteredVisualText,
        usesIntent: false,
        excludedRuleIdentifiers: Set([
            "ceremony_language", "direct_purpose_mismatch",
            "urgency_and_coercion", "channel_risk", "context_completeness",
            "spatial_relevance", "multiple_qr_codes", "context_association"
        ]).union(intentRuleIdentifiers)
    )

    static let multiSignalSpatial = ClassifierConfiguration(
        id: "MULTI_SIGNAL_SPATIAL",
        associationPolicy: .spatiallyAssociated,
        usesIntent: false,
        excludedRuleIdentifiers: intentRuleIdentifiers
    )

    /// Used by the association-family ablation so that only association policy
    /// changes while intent evidence remains fixed.
    static let unfilteredVisualTextWithIntent = ClassifierConfiguration(
        id: "MULTI_SIGNAL_UNFILTERED_INTENT",
        associationPolicy: .unfilteredVisualText,
        usesIntent: true,
        excludedRuleIdentifiers: []
    )

    static let evaluationVariants: [ClassifierConfiguration] = [
        .identityDomainOnly, .unfilteredVisualText, .multiSignalSpatial, .full
    ]

    private static let intentRuleIdentifiers: Set<String> = [
        "expected_service_mismatch", "purpose_mismatch", "unexpected_initiation",
        "receiving_client_trust"
    ]
}

enum SocialEngineeringCue: String, Codable, CaseIterable, Equatable {
    case urgency = "URGENCY"
    case threat = "THREAT"
    case ignoreWarnings = "IGNORE_WARNINGS"
    case secrecy = "SECRECY"
    case reward = "REWARD"
    case unexpectedPayment = "UNEXPECTED_PAYMENT"
    case authorityPressure = "AUTHORITY_PRESSURE"
    case repeatedApproval = "REPEATED_APPROVAL"
}

enum ChannelCue: String, Codable, CaseIterable, Equatable {
    case loginPage = "LOGIN_PAGE"
    case emailOrChat = "EMAIL_OR_CHAT"
    case sharedComputer = "SHARED_COMPUTER"
    case kiosk = "KIOSK"
    case printedPage = "PRINTED_PAGE"
    case unrelatedWebpage = "UNRELATED_WEBPAGE"
    case unknown = "UNKNOWN"
}

enum ContradictionFlag: String, Codable, CaseIterable, Equatable {
    case expectedServiceMismatch = "EXPECTED_SERVICE_MISMATCH"
    case expectedPurposeMismatch = "EXPECTED_PURPOSE_MISMATCH"
    case brandDomainConflict = "BRAND_DOMAIN_CONFLICT"
    case multipleVisibleServices = "MULTIPLE_VISIBLE_SERVICES"
    case competingPurposes = "COMPETING_PURPOSES"
    case fidoPresentedAsUnrelatedAction = "FIDO_PRESENTED_AS_UNRELATED_ACTION"
    case unexpectedInitiation = "UNEXPECTED_INITIATION"
    case receivingClientNotStarted = "RECEIVING_CLIENT_NOT_STARTED"
    case untrustedReceivingClient = "UNTRUSTED_RECEIVING_CLIENT"
    case ambiguousContextAssociation = "AMBIGUOUS_CONTEXT_ASSOCIATION"
    case browserDomainCandidateConflict = "BROWSER_DOMAIN_CANDIDATE_CONFLICT"
}

enum CompletenessIndicator: String, Codable, CaseIterable, Equatable {
    case fidoQRCode = "FIDO_QR_CODE"
    case readableIdentity = "READABLE_IDENTITY"
    case visibleDomain = "VISIBLE_DOMAIN"
    case clearPurpose = "CLEAR_PURPOSE"
    case authenticationLanguage = "AUTHENTICATION_LANGUAGE"
    case qrNearText = "QR_NEAR_TEXT"
    case userIntent = "USER_INTENT"
    case receivingClientContext = "RECEIVING_CLIENT_CONTEXT"
    case successfulOCR = "SUCCESSFUL_OCR"
}

enum SpatialProximity: String, Codable, CaseIterable, Equatable {
    case near = "NEAR"
    case adjacent = "ADJACENT"
    case distant = "DISTANT"
    case notAssessable = "NOT_ASSESSABLE"
}

/// A geometric region relative to the closest QR code. This describes where
/// text appears, not whether the text is truthful.
enum ContextZone: String, Codable, CaseIterable, Equatable {
    case primary = "PRIMARY"
    case adjacent = "ADJACENT"
    case peripheral = "PERIPHERAL"
    case unassociated = "UNASSOCIATED"
}

/// A deterministic estimate that visible text describes the QR ceremony.
/// It is not an OCR confidence, authenticity assessment, or probability.
enum AssociationStrength: String, Codable, CaseIterable, Equatable {
    case strong = "STRONG"
    case plausible = "PLAUSIBLE"
    case weak = "WEAK"
    case unassociated = "UNASSOCIATED"
}

/// Whether competing visible identity contexts can be associated with the QR.
/// This is a visual-association result, not an authenticity judgment.
enum AssociationResolution: String, Codable, CaseIterable, Equatable {
    case resolved = "RESOLVED"
    case ambiguous = "AMBIGUOUS"
    case notApplicable = "NOT_APPLICABLE"
}

/// The inferred visual function of an OCR observation. This remains separate
/// from QR-relative distance: a browser bar can be distant but still have a
/// security-relevant role.
enum SemanticContextRole: String, Codable, CaseIterable, Equatable {
    case qrLocal = "QR_LOCAL"
    case dialogContext = "DIALOG_CONTEXT"
    case pageIdentity = "PAGE_IDENTITY"
    case browserDomainCandidate = "BROWSER_DOMAIN_CANDIDATE"
    case peripheral = "PERIPHERAL"
    case unassociated = "UNASSOCIATED"
}

struct SpatialTextEvidence: Codable, Equatable {
    let observationId: String
    let text: String
    let confidence: Float
    let boundingBox: NormalizedBoundingBox
    let associatedQRCodeIndex: Int?
    let associatedQRCodeBoundingBox: NormalizedBoundingBox?
    let sourceRegion: OCRRegion
    let normalizedDistanceToQRCode: Double?
    let proximity: SpatialProximity

    let contextZone: ContextZone
    let associationStrength: AssociationStrength
    let semanticRole: SemanticContextRole

    let isNearQRCode: Bool
}

enum VisualClaimKind: String, Codable, Equatable {
    case service = "SERVICE"
    case domain = "DOMAIN"
    case authentication = "AUTH"
    case purpose = "PURPOSE"
    case purposePattern = "PURPOSE_PATTERN"
    case nonAuthenticationAction = "NON_AUTH"
    case socialEngineering = "SOCIAL"
    case browserDomainCandidate = "BROWSER_DOMAIN_CANDIDATE"
    case emailDomain = "EMAIL_DOMAIN"
}

enum BrowserDomainCandidateBasis: String, Codable, Equatable {
    case topOfFrameURLLikeText = "TOP_OF_FRAME_URL_LIKE_TEXT"
}

/// URL-like OCR near the top of the image. This is visual evidence only and
/// must never be described as an authenticated browser origin.
struct BrowserDomainCandidate: Codable, Equatable, Identifiable {
    let domain: String
    let sourceObservationId: String
    let ocrConfidence: Float
    let boundingBox: NormalizedBoundingBox
    let basis: BrowserDomainCandidateBasis

    var id: String { "\(sourceObservationId)|\(domain)" }
}

enum PurposeEvidencePriority: Int, Codable, Comparable, Equatable {
    case background = 1
    case associatedPageExplanation = 2
    case sameDialogInstruction = 3
    case directQRCodeInstruction = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Whether a purpose phrase describes the action currently attached to the QR,
/// a later/optional action, or unrelated background copy.
enum PurposeEvidenceApplicability: String, Codable, CaseIterable, Equatable {
    case currentAction = "CURRENT_ACTION"
    case futureOrSecondary = "FUTURE_OR_SECONDARY"
    case background = "BACKGROUND"
}

enum PurposeState: String, Codable, CaseIterable, Equatable {
    case identified = "IDENTIFIED"
    case conflicting = "CONFLICTING"
    case unknown = "UNKNOWN"

    static func derive(from purposes: [IntendedPurpose]) -> PurposeState {
        let distinctPurposes = Set(purposes)
        if distinctPurposes.isEmpty { return .unknown }
        return distinctPurposes.count == 1 ? .identified : .conflicting
    }
}

struct PurposeClaimEvidence: Codable, Equatable, Identifiable {
    let purpose: IntendedPurpose
    let matchedPhrase: String
    let sourceObservationIds: [String]
    let ocrConfidence: Float
    let contextRole: SemanticContextRole
    let priority: PurposeEvidencePriority
    let applicability: PurposeEvidenceApplicability

    var sourceObservationId: String { sourceObservationIds.first ?? "" }

    var id: String {
        "\(sourceObservationIds.joined(separator: "+"))|\(purpose.rawValue)|\(matchedPhrase)"
    }

    init(
        purpose: IntendedPurpose,
        matchedPhrase: String,
        sourceObservationId: String,
        ocrConfidence: Float,
        contextRole: SemanticContextRole,
        priority: PurposeEvidencePriority,
        applicability: PurposeEvidenceApplicability = .currentAction
    ) {
        self.init(
            purpose: purpose,
            matchedPhrase: matchedPhrase,
            sourceObservationIds: [sourceObservationId],
            ocrConfidence: ocrConfidence,
            contextRole: contextRole,
            priority: priority,
            applicability: applicability
        )
    }

    init(
        purpose: IntendedPurpose,
        matchedPhrase: String,
        sourceObservationIds: [String],
        ocrConfidence: Float,
        contextRole: SemanticContextRole,
        priority: PurposeEvidencePriority,
        applicability: PurposeEvidenceApplicability = .currentAction
    ) {
        self.purpose = purpose
        self.matchedPhrase = matchedPhrase
        self.sourceObservationIds = sourceObservationIds
        self.ocrConfidence = ocrConfidence
        self.contextRole = contextRole
        self.priority = priority
        self.applicability = applicability
    }
}

struct DomainClaimEvidence: Codable, Equatable, Identifiable {
    let domain: String
    let sourceType: DomainSourceType
    let sourceObservationId: String
    let ocrConfidence: Float
    let contextRole: SemanticContextRole
    let recognitionStatus: DomainRecognitionStatus
    let participatesInServiceIdentity: Bool

    var id: String { "\(sourceObservationId)|\(sourceType.rawValue)|\(domain)" }
}

enum IdentityContradictionKind: String, Codable, Equatable {
    case serviceMismatch = "SERVICE_MISMATCH"
    case brandDomainConflict = "BRAND_DOMAIN_CONFLICT"
}

/// One semantic conflict regardless of how many repeated OCR tokens support it.
struct IdentityContradictionEvent: Codable, Equatable, Identifiable {
    let kind: IdentityContradictionKind
    let identities: [String]
    let domains: [String]
    let sourceObservationIds: [String]

    var id: String {
        "\(kind.rawValue)|\(identities.sorted().joined(separator: "+"))|\(domains.sorted().joined(separator: "+"))"
    }
}

/// A semantic claim tied to the exact OCR observation that produced it.
/// This is scanner evidence, never scenario ground truth.
struct VisualClaimEvidence: Codable, Equatable, Identifiable {
    let kind: VisualClaimKind
    let value: String
    let sourceObservationId: String
    let ocrConfidence: Float
    let contextZone: ContextZone
    let associationStrength: AssociationStrength
    let semanticRole: SemanticContextRole

    var id: String { "\(sourceObservationId)|\(kind.rawValue)|\(value)" }
    var featureIdentifier: String { "\(kind.rawValue):\(value)" }
}

struct VisualContextFeatures: Codable, Equatable {
    let visibleServiceClaims: [String]
    let visibleDomainClaims: [String]
    let peripheralServiceClaims: [String]
    let peripheralDomainClaims: [String]
    let competingContextPresent: Bool
    let associationResolution: AssociationResolution
    let authenticationTerms: [String]
    let inferredPurposes: [IntendedPurpose]
    let nonAuthenticationActionTerms: [String]
    let socialEngineeringCues: [SocialEngineeringCue]
    let peripheralSocialEngineeringCues: [SocialEngineeringCue]
    let channelCues: [ChannelCue]
    let contradictionFlags: [ContradictionFlag]
    let completenessIndicators: [CompletenessIndicator]
    let spatialEvidence: [SpatialTextEvidence]
    let visualClaims: [VisualClaimEvidence]
    let browserDomainCandidates: [BrowserDomainCandidate]
    let purposeEvidence: [PurposeClaimEvidence]
    let domainEvidence: [DomainClaimEvidence]
    let identityContradictionEvents: [IdentityContradictionEvent]
    /// OCR lines retained for diagnostics but excluded from semantic security
    /// decisions because their recognition confidence is below the documented
    /// threshold.
    let lowConfidenceObservationCount: Int

    var purposeState: PurposeState {
        PurposeState.derive(from: inferredPurposes)
    }
}
