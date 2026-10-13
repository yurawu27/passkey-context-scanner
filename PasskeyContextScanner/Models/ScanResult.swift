import Foundation

enum AssessmentDimensionKind: String, Codable, CaseIterable, Equatable {
    case identity = "IDENTITY"
    case purpose = "PURPOSE"
    case ceremony = "CEREMONY"
    case initiation = "INITIATION"
    case receivingClient = "RECEIVING_CLIENT"
    case socialEngineering = "SOCIAL_ENGINEERING"
    case presentationChannel = "PRESENTATION_CHANNEL"
    case evidenceQuality = "EVIDENCE_QUALITY"

    var displayName: String {
        switch self {
        case .identity: return "Identity claims"
        case .purpose: return "Purpose"
        case .ceremony: return "Authentication ceremony"
        case .initiation: return "Request initiation"
        case .receivingClient: return "Receiving computer"
        case .socialEngineering: return "Persuasion cues"
        case .presentationChannel: return "Presentation channel"
        case .evidenceQuality: return "Evidence quality"
        }
    }
}

enum DimensionFinding: String, Codable, Equatable {
    case aligned = "ALIGNED"
    case conflicting = "CONFLICTING"
    case incomplete = "INCOMPLETE"
    case concerning = "CONCERNING"
    case notAssessable = "NOT_ASSESSABLE"
}

struct AssessmentDimension: Codable, Equatable {
    let kind: AssessmentDimensionKind
    let finding: DimensionFinding
    let summary: String
    let evidence: [String]
}

enum SessionBindingAssessment: String, Codable, Equatable {
    case notVerifiable = "NOT_VERIFIABLE"
}

enum EvidenceCompletenessLevel: String, Codable, CaseIterable, Equatable {
    case sufficient = "SUFFICIENT"
    case partial = "PARTIAL"
    case insufficient = "INSUFFICIENT"
    case notAssessed = "NOT_ASSESSED"
}

struct ScanResult: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let visualContext: VisualContext
    let visibleServiceClaims: [String]
    let peripheralServiceClaims: [String]
    let competingContextPresent: Bool
    let associationResolution: AssociationResolution
    let inferredPurposes: [IntendedPurpose]
    let socialEngineeringCues: [SocialEngineeringCue]
    let qrCount: Int
    let qrTypes: [QRCodeType]
    let visualClassification: RiskClassification
    let classification: RiskClassification
    let visualRiskScore: Int
    let riskScore: Int
    let evidenceCompleteness: Int
    let visualEvidenceCompleteness: EvidenceCompletenessLevel
    let intentSessionCompleteness: EvidenceCompletenessLevel
    let reasons: [String]
    let observedPositiveEvidence: [String]
    let observedNegativeEvidence: [String]
    let limitations: [String]
    let suggestedUserChecks: [String]
    let ruleResults: [ClassificationRuleResult]
    let assessmentDimensions: [AssessmentDimension]
    let sessionBindingAssessment: SessionBindingAssessment
    let spatialEvidence: [SpatialTextEvidence]
    let visualClaims: [VisualClaimEvidence]
    let browserDomainCandidates: [BrowserDomainCandidate]
    let analysisTiming: AnalysisTimingObservation
    let imageQuality: ImageQualityObservation
    let classificationMilliseconds: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        visualContext: VisualContext,
        visibleServiceClaims: [String] = [],
        peripheralServiceClaims: [String] = [],
        competingContextPresent: Bool = false,
        associationResolution: AssociationResolution = .notApplicable,
        inferredPurposes: [IntendedPurpose] = [],
        socialEngineeringCues: [SocialEngineeringCue] = [],
        qrCount: Int = 0,
        qrTypes: [QRCodeType] = [],
        visualClassification: RiskClassification? = nil,
        classification: RiskClassification,
        visualRiskScore: Int? = nil,
        riskScore: Int,
        evidenceCompleteness: Int = 0,
        visualEvidenceCompleteness: EvidenceCompletenessLevel = .notAssessed,
        intentSessionCompleteness: EvidenceCompletenessLevel = .notAssessed,
        reasons: [String],
        observedPositiveEvidence: [String] = [],
        observedNegativeEvidence: [String] = [],
        limitations: [String] = [],
        suggestedUserChecks: [String] = [],
        ruleResults: [ClassificationRuleResult] = [],
        assessmentDimensions: [AssessmentDimension] = [],
        sessionBindingAssessment: SessionBindingAssessment = .notVerifiable,
        spatialEvidence: [SpatialTextEvidence] = [],
        visualClaims: [VisualClaimEvidence] = [],
        browserDomainCandidates: [BrowserDomainCandidate] = [],
        analysisTiming: AnalysisTimingObservation = .unmeasured,
        imageQuality: ImageQualityObservation = ImageQualityObservation(
            isSufficientForAnalysis: true,
            issues: []
        ),
        classificationMilliseconds: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.visualContext = visualContext
        self.visibleServiceClaims = visibleServiceClaims
        self.peripheralServiceClaims = peripheralServiceClaims
        self.competingContextPresent = competingContextPresent
        self.associationResolution = associationResolution
        self.inferredPurposes = inferredPurposes
        self.socialEngineeringCues = socialEngineeringCues
        self.qrCount = max(qrCount, 0)
        self.qrTypes = qrTypes
        self.visualClassification = visualClassification ?? classification
        self.classification = classification
        self.visualRiskScore = min(max(visualRiskScore ?? riskScore, 0), 100)
        self.riskScore = min(max(riskScore, 0), 100)
        self.evidenceCompleteness = min(max(evidenceCompleteness, 0), 100)
        self.visualEvidenceCompleteness = visualEvidenceCompleteness
        self.intentSessionCompleteness = intentSessionCompleteness
        self.reasons = reasons
        self.observedPositiveEvidence = observedPositiveEvidence
        self.observedNegativeEvidence = observedNegativeEvidence
        self.limitations = limitations
        self.suggestedUserChecks = suggestedUserChecks
        self.ruleResults = ruleResults
        self.assessmentDimensions = assessmentDimensions
        self.sessionBindingAssessment = sessionBindingAssessment
        self.spatialEvidence = spatialEvidence
        self.visualClaims = visualClaims
        self.browserDomainCandidates = browserDomainCandidates
        self.analysisTiming = analysisTiming
        self.imageQuality = imageQuality
        self.classificationMilliseconds = classificationMilliseconds
    }

    var scanLatencyMilliseconds: Double? {
        guard let imageAnalysisMilliseconds = analysisTiming.imageAnalysisMilliseconds else {
            return nil
        }
        return imageAnalysisMilliseconds + (classificationMilliseconds ?? 0)
    }

    var purposeState: PurposeState {
        PurposeState.derive(from: inferredPurposes)
    }
}

extension ScanResult {
    static let placeholder = ScanResult(
        visualContext: VisualContext(
            qrDetected: true,
            ocrText: "No scan has been analysed yet.",
            visibleDomainClaims: [],
            authenticationKeywords: []
        ),
        classification: .uncertain,
        riskScore: 50,
        reasons: ["The prototype has not analysed a QR context yet."]
    )
}
