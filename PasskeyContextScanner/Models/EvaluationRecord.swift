import Foundation

enum AnalysisMode: String, Codable, CaseIterable {
    case staticImage = "STATIC_IMAGE"
    case liveCamera = "LIVE_CAMERA"
}

enum QRDetectionStatus: String, Codable, CaseIterable {
    case detected = "true"
    case notDetected = "false"
    case notAvailable = "not_available"
}

enum EvaluationFailureStage: String, Codable, Equatable {
    case none = "NONE"
    case imageLoading = "IMAGE_LOADING"
    case qrDetection = "QR_DETECTION"
    case ocr = "OCR"
    case classification = "CLASSIFICATION"
    case persistence = "PERSISTENCE"
}

enum EvaluationErrorCategory: String, Codable, Equatable {
    case none = "NONE"
    case permissionDenied = "PERMISSION_DENIED"
    case invalidImage = "INVALID_IMAGE"
    case processingFailed = "PROCESSING_FAILED"
    case cancelled = "CANCELLED"
    case storageFailed = "STORAGE_FAILED"
    case unknown = "UNKNOWN"
}

/// Researcher-assigned explanation for an observed evaluation outcome. Unlike
/// `EvaluationFailureStage`, this does not mean that pipeline execution failed.
enum EvaluationFailureAttribution: String, Codable, CaseIterable, Equatable, Identifiable {
    case none = "NONE"
    case qrDetection = "QR_DETECTION"
    case ocr = "OCR"
    case featureExtraction = "FEATURE_EXTRACTION"
    case contextAssociation = "CONTEXT_ASSOCIATION"
    case classification = "CLASSIFICATION"
    case clarification = "CLARIFICATION"
    case insufficientCapture = "INSUFFICIENT_CAPTURE"
    case inherentlyUndetectable = "INHERENTLY_UNDETECTABLE"

    var id: String { rawValue }
}

enum LightingCondition: String, Codable, CaseIterable, Identifiable {
    case normal
    case lowLight = "low_light"
    case glare
    case unknown

    var id: String { rawValue }
}

enum AngleCondition: String, Codable, CaseIterable, Identifiable {
    case straight
    case slightAngle = "slight_angle"
    case steepAngle = "steep_angle"
    case unknown

    var id: String { rawValue }
}

enum DistanceCondition: String, Codable, CaseIterable, Identifiable {
    case close
    case medium
    case far
    case unknown

    var id: String { rawValue }
}

enum DisplayOS: String, Codable, CaseIterable, Identifiable {
    case iOS = "IOS"
    case macOS = "MACOS"
    case windows = "WINDOWS"
    case linux = "LINUX"
    case chromeOS = "CHROMEOS"
    case other = "OTHER"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum DisplayBrowser: String, Codable, CaseIterable, Identifiable {
    case safari = "SAFARI"
    case chrome = "CHROME"
    case edge = "EDGE"
    case firefox = "FIREFOX"
    case other = "OTHER"
    case notApplicable = "NOT_APPLICABLE"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum PresentationType: String, Codable, CaseIterable, Identifiable {
    case isolatedDialog = "ISOLATED_DIALOG"
    case fullContext = "FULL_CONTEXT"
    case ambiguousContext = "AMBIGUOUS_CONTEXT"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum ClutterCondition: String, Codable, CaseIterable, Identifiable {
    case clean = "CLEAN"
    case minor = "MINOR"
    case competing = "COMPETING"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum AssociationCondition: String, Codable, CaseIterable, Identifiable {
    case clean = "CLEAN"
    case competingIrrelevant = "COMPETING_IRRELEVANT"
    case competingRelevant = "COMPETING_RELEVANT"
    case genuinelyAmbiguous = "GENUINELY_AMBIGUOUS"
    case notAssigned = "NOT_ASSIGNED"

    var id: String { rawValue }
}

enum CropCondition: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case partial = "PARTIAL"
    case severe = "SEVERE"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum BlurCondition: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case mild = "MILD"
    case severe = "SEVERE"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum CaptureConditionPreset: String, Codable, CaseIterable, Identifiable {
    case manual = "MANUAL"
    case baseline = "BASELINE"
    case lowLight = "LOW_LIGHT"
    case glare = "GLARE"
    case slightAngle = "SLIGHT_ANGLE"
    case steepAngle = "STEEP_ANGLE"
    case farDistance = "FAR_DISTANCE"
    case mildBlur = "MILD_BLUR"
    case severeBlur = "SEVERE_BLUR"
    case partialCrop = "PARTIAL_CROP"
    case severeCrop = "SEVERE_CROP"

    var id: String { rawValue }
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum ContextType: String, Codable, CaseIterable, Identifiable {
    case matching
    case mismatching
    case missingContext = "missing_context"
    case ambiguous
    case contextAssociation = "context_association"
    case unknown

    var id: String { rawValue }
}

enum DetectabilityBoundary: String, Codable, CaseIterable, Identifiable {
    case visibleConsistentEvidence = "visible_consistent_evidence"
    case visibleContradiction = "visible_contradiction"
    case visiblePersuasion = "visible_persuasion"
    case insufficientVisualEvidence = "insufficient_visual_evidence"
    case visuallyIndistinguishableSessionAttack = "visually_indistinguishable_session_attack"
    case notAssigned = "not_assigned"

    var id: String { rawValue }
}

enum ScenarioGroundTruth: String, Codable, CaseIterable, Identifiable {
    case consistent = "CONSISTENT"
    case suspicious = "SUSPICIOUS"
    case uncertain = "UNCERTAIN"
    case notAssigned = "NOT_ASSIGNED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .consistent: "Consistent"
        case .suspicious: "Suspicious"
        case .uncertain: "Uncertain"
        case .notAssigned: "Not assigned"
        }
    }

    var classification: RiskClassification? {
        switch self {
        case .consistent: .consistent
        case .suspicious: .suspicious
        case .uncertain: .uncertain
        case .notAssigned: nil
        }
    }
}

enum DatasetSplit: String, Codable, CaseIterable, Identifiable {
    case development = "DEVELOPMENT"
    case pilot = "PILOT"
    case finalEvaluation = "FINAL_EVALUATION"
    case robustness = "ROBUSTNESS"
    case notAssigned = "NOT_ASSIGNED"

    var id: String { rawValue }
}

enum ScenarioSecurityType: String, Codable, CaseIterable, Identifiable {
    case benign = "BENIGN"
    case misleading = "MISLEADING"
    case insufficient = "INSUFFICIENT"
    case notAssigned = "NOT_ASSIGNED"

    var id: String { rawValue }
}

enum VisualDetectability: String, Codable, CaseIterable, Identifiable {
    case clearlyDetectable = "CLEARLY_DETECTABLE"
    case partiallyDetectable = "PARTIALLY_DETECTABLE"
    case insufficientEvidence = "INSUFFICIENT_EVIDENCE"
    case visuallyIndistinguishable = "VISUALLY_INDISTINGUISHABLE"
    case notAssigned = "NOT_ASSIGNED"

    var id: String { rawValue }
}

enum CaptureQualityTruth: String, Codable, CaseIterable, Identifiable {
    case sufficient = "SUFFICIENT"
    case insufficient = "INSUFFICIENT"
    case notAssigned = "NOT_ASSIGNED"

    var id: String { rawValue }
}

enum ScenarioReceivingClientOwner: String, Codable, CaseIterable, Identifiable {
    case user = "USER"
    case trustedOther = "TRUSTED_OTHER"
    case attacker = "ATTACKER"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

/// Describes the receiving-session condition without pretending that a device
/// category (for example, a kiosk) establishes who owns it.
enum ScenarioReceivingClientContext: String, Codable, CaseIterable, Identifiable {
    case intended = "INTENDED"
    case sharedOrPublic = "SHARED_OR_PUBLIC"
    case attackerControlled = "ATTACKER_CONTROLLED"
    case unintendedOrWrongSession = "UNINTENDED_OR_WRONG_SESSION"
    case unintended = "UNINTENDED"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum DetectableSignalType: String, Codable, CaseIterable, Identifiable {
    case consistentIdentity = "CONSISTENT_IDENTITY"
    case identityContradiction = "IDENTITY_CONTRADICTION"
    case purposeContradiction = "PURPOSE_CONTRADICTION"
    case persuasion = "PERSUASION"
    case warningSuppression = "WARNING_SUPPRESSION"
    case unexpectedInitiation = "UNEXPECTED_INITIATION"
    case domainConflict = "DOMAIN_CONFLICT"
    case missingContext = "MISSING_CONTEXT"
    case degradedCapture = "DEGRADED_CAPTURE"

    var id: String { rawValue }
}

struct ScenarioFactualGroundTruth: Codable, Equatable {
    var securityType: ScenarioSecurityType
    var visualDetectability: VisualDetectability
    var captureQuality: CaptureQualityTruth
    var service: String
    var presentedService: String
    var purpose: IntendedPurpose?
    var presentedPurpose: IntendedPurpose?
    var initiated: InitiationStatus
    var receivingClientOwner: ScenarioReceivingClientOwner
    var receivingClientContext: ScenarioReceivingClientContext? = nil
    var detectableSignals: [DetectableSignalType]

    static let notAssigned = ScenarioFactualGroundTruth(
        securityType: .notAssigned,
        visualDetectability: .notAssigned,
        captureQuality: .notAssigned,
        service: "",
        presentedService: "",
        purpose: nil,
        presentedPurpose: nil,
        initiated: .unsure,
        receivingClientOwner: .unknown,
        detectableSignals: []
    )
}

struct EvaluationServiceProfile: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let canonicalServiceName: String
    let controlledDomains: [String]
}

/// A concrete, pre-authored evaluation image specification. Selecting a fixture
/// copies its facts into the record; these values are never inferred from the
/// scanner and are not supplied to visual feature extraction.
struct EvaluationFixture: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let imageFilename: String
    let matchedStimulusID: String
    let baseScenarioID: String
    let expectedService: String
    let presentedService: String
    let expectedPurpose: IntendedPurpose
    let presentedPurpose: IntendedPurpose?
    let securityType: ScenarioSecurityType
    let visualDetectability: VisualDetectability
    let captureQuality: CaptureQualityTruth
    let initiated: InitiationStatus
    let receivingClientOwner: ScenarioReceivingClientOwner
    let receivingClientContext: ScenarioReceivingClientContext
    let displayOS: DisplayOS
    let displayBrowser: DisplayBrowser
    let presentationType: PresentationType
    let associationCondition: AssociationCondition
    let detectableSignals: [DetectableSignalType]

    var scenarioGroundTruth: ScenarioGroundTruth {
        switch securityType {
        case .benign: .consistent
        case .misleading: .suspicious
        case .insufficient: .uncertain
        case .notAssigned: .notAssigned
        }
    }

    var scenarioFactualGroundTruth: ScenarioFactualGroundTruth {
        ScenarioFactualGroundTruth(
            securityType: securityType,
            visualDetectability: visualDetectability,
            captureQuality: captureQuality,
            service: expectedService,
            presentedService: presentedService,
            purpose: expectedPurpose,
            presentedPurpose: presentedPurpose,
            initiated: initiated,
            receivingClientOwner: receivingClientOwner,
            receivingClientContext: receivingClientContext,
            detectableSignals: detectableSignals
        )
    }
}

enum ControlledEvaluationFixtureCatalog {
    static let version = "fixture-catalog-v2"

    static let fixtures: [EvaluationFixture] = [
        f("L01", "Strong QR-local identity baseline", "LEG-EXPLICIT", "PayPal", presentation: .isolatedDialog),
        f("L02", "Fully aligned full-context sign-in", "LEG-EXPLICIT", "Robinhood", browser: .safari),
        f("L03", "Service and dialog domain visible", "LEG-EXPLICIT", "Chase", browser: .safari),
        f("L04", "Domain visible, branding weak", "LEG-EXPLICIT", "PayPal", visual: .partiallyDetectable, presentation: .isolatedDialog),
        f("L05", "Alternative legitimate wording", "LEG-EXPLICIT", "Dropbox"),
        f("L06", "Minimal legitimate context", "LEG-SPARSE", "GitHub", presented: "NONE_VISIBLE", presentedPurpose: nil, visual: .insufficientEvidence, browser: .safari, presentation: .isolatedDialog, signals: [.missingContext]),
        f("L07", "Distant but relevant browser domain", "LEG-EXPLICIT", "Coinbase", browser: .safari),
        f("L08", "Minor irrelevant text", "LEG-EXPLICIT", "GitHub", browser: .edge),
        f("L09", "Benign shared/public-computer context", "CHANNELS", "Robinhood", owner: .trustedOther, clientContext: .sharedOrPublic),
        f("L10", "Held-out service/layout", "LEG-EXPLICIT", "Shopify", browser: .edge),

        f("M01", "Service mismatch: page vs QR-local identity", "ID-CONFLICT", "Chase", presented: "Robinhood", security: .misleading, signals: [.identityContradiction]),
        f("M02", "Service mismatch with different presentation", "ID-CONFLICT", "Google", presented: "NHS", security: .misleading, browser: .safari, signals: [.identityContradiction]),
        f("M03", "Brand/domain conflict between known services", "ID-CONFLICT", "Chase", presented: "Wells Fargo", security: .misleading, browser: .edge, signals: [.identityContradiction, .domainConflict]),
        f("M04", "Brand/domain conflict with unrelated domain", "ID-CONFLICT", "GitHub", security: .misleading, browser: .safari, signals: [.domainConflict]),
        f("M05", "Sign-in presented as verification", "PURPOSE-CONFLICT", "NONE_VISIBLE", presentedPurpose: .verifyIdentity, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction]),
        f("M06", "Sign-in presented as device pairing", "PURPOSE-CONFLICT", "NONE_VISIBLE", presentedPurpose: .pairDevice, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction]),
        f("M07", "Sign-in presented as payment approval", "MIS-NONAUTH", "NONE_VISIBLE", presentedPurpose: .payment, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction]),
        f("M08", "Sign-in presented as salary/reward collection", "MIS-NONAUTH", "NONE_VISIBLE", presentedPurpose: .payment, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction, .persuasion]),
        f("M09", "Sign-in presented as document access", "MIS-NONAUTH", "Acme Corp", presentedPurpose: .openDocument, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction]),
        f("M10", "Warning-suppression instruction", "SOC-PRESSURE", "PayPal", security: .misleading, signals: [.warningSuppression, .persuasion]),
        f("M11", "Account-loss threat/coercion", "SOC-PRESSURE", "GitHub", security: .misleading, signals: [.persuasion]),
        f("M12", "Weak ordinary urgency", "SOC-PRESSURE", "NONE_VISIBLE", security: .misleading, visual: .insufficientEvidence, browser: .safari, signals: [.persuasion]),
        f("M13", "Hidden non-initiation boundary (excluded from visual metrics)", "LIMIT-SESSION", "GitHub", security: .misleading, visual: .visuallyIndistinguishable, initiated: .no, signals: [.unexpectedInitiation]),
        f("M14", "Purpose deception plus coercion", "PURPOSE-CONFLICT", "NONE_VISIBLE", presentedPurpose: .verifyIdentity, security: .misleading, signals: [.purposeContradiction, .persuasion]),

        f("A01", "QR with almost no context", "LEG-SPARSE", "Chase", presented: "NONE_VISIBLE", presentedPurpose: nil, security: .insufficient, visual: .insufficientEvidence, browser: .safari, presentation: .ambiguousContext, signals: [.missingContext]),
        f("A02", "Service identity missing", "LEG-SPARSE", "NHS", presented: "NONE_VISIBLE", security: .insufficient, visual: .partiallyDetectable, browser: .safari, signals: [.missingContext]),
        f("A03", "Authentication purpose missing", "LEG-SPARSE", "Wells Fargo", presentedPurpose: nil, security: .insufficient, visual: .partiallyDetectable, browser: .safari, signals: [.missingContext]),
        f("A04", "Partially cropped authentication context", "CAPTURE-QUALITY", "NHS", presented: "NONE_VISIBLE", presentedPurpose: nil, security: .insufficient, visual: .insufficientEvidence, capture: .insufficient, browser: .safari, presentation: .ambiguousContext, signals: [.missingContext, .degradedCapture]),
        f("A05", "Context present but poorly readable", "CAPTURE-QUALITY", "GitHub", security: .insufficient, visual: .partiallyDetectable, capture: .insufficient, browser: .safari, signals: [.degradedCapture]),
        f("A06", "Multiple QR codes with unclear ownership", "LEG-SPARSE", "Robinhood", presented: "NONE_VISIBLE", presentedPurpose: nil, security: .insufficient, visual: .partiallyDetectable, presentation: .ambiguousContext, association: .genuinelyAmbiguous, signals: [.missingContext]),
        f("A07", "Two plausible service contexts", "LEG-SPARSE", "Google", presented: "MULTIPLE_VISIBLE", security: .insufficient, visual: .partiallyDetectable, presentation: .ambiguousContext, association: .genuinelyAmbiguous, signals: [.missingContext]),

        f("U01", "Coherent sign-in not initiated by user", "LIMIT-SESSION", "GitHub", security: .misleading, visual: .visuallyIndistinguishable, initiated: .no),
        f("U02", "Coherent RP with attacker-controlled receiver", "LIMIT-SESSION", "Wells Fargo", security: .misleading, visual: .visuallyIndistinguishable, owner: .attacker, clientContext: .attackerControlled),
        f("U03", "Relayed genuine CDA QR in coherent presentation", "LIMIT-SESSION", "NHS", security: .misleading, visual: .visuallyIndistinguishable, owner: .attacker, clientContext: .attackerControlled, browser: .edge),
        f("U04", "Correct service but wrong receiving session", "LIMIT-SESSION", "PayPal", security: .misleading, visual: .visuallyIndistinguishable, owner: .unknown, clientContext: .unintendedOrWrongSession),
        f("U05", "Fully coherent unintended-session negative control", "LIMIT-SESSION", "NHS", security: .misleading, visual: .visuallyIndistinguishable, owner: .unknown, clientContext: .unintended, browser: .edge),

        // Additional authored fixtures. The `-f` suffix identifies the image
        // revision only; dataset split remains an independent researcher choice.
        f("L01-f", "Strong QR-local identity baseline", "LEG-EXPLICIT", "Discord", browser: .edge, presentation: .isolatedDialog),
        f("L02-f", "Fully aligned full-context sign-in", "LEG-EXPLICIT", "Coinbase"),
        f("L03-f", "Service visible, browser domain absent", "LEG-EXPLICIT", "Stripe", visual: .partiallyDetectable, browser: .edge),
        f("M01-f", "Expected service conflicts with visible ceremony", "ID-CONFLICT", "Coinbase", presented: "Stripe", security: .misleading, browser: .edge, signals: [.identityContradiction]),
        f("M07-f", "Sign-in presented as payment approval", "MIS-NONAUTH", "NONE_VISIBLE", presentedPurpose: .payment, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction]),
        f("M09-f", "Sign-in presented as document access", "MIS-NONAUTH", "NONE_VISIBLE", presentedPurpose: .openDocument, security: .misleading, os: .other, browser: .other, signals: [.purposeContradiction]),
        f("M12-f", "Weak ordinary urgency", "SOC-PRESSURE", "NONE_VISIBLE", security: .misleading, visual: .insufficientEvidence, signals: [.persuasion]),
        f("M13-f", "Repeated-approval pressure", "SOC-PRESSURE", "Snapchat", security: .misleading, signals: [.persuasion]),
        f("A04-f", "Partially cropped authentication context", "CAPTURE-QUALITY", "Notion", presented: "NONE_VISIBLE", presentedPurpose: nil, security: .insufficient, visual: .insufficientEvidence, capture: .insufficient, browser: .safari, presentation: .ambiguousContext, signals: [.missingContext, .degradedCapture]),
        f("U03-f", "Relayed genuine CDA QR in coherent presentation", "LIMIT-SESSION", "Notion", security: .misleading, visual: .visuallyIndistinguishable, owner: .attacker, clientContext: .attackerControlled, browser: .edge)
    ]

    static var validationProblems: [String] {
        var problems: [String] = []
        let ids = fixtures.map(\.id)
        if fixtures.count != 46 { problems.append("The controlled fixture catalogue must contain 46 fixtures.") }
        if Set(ids).count != ids.count { problems.append("Fixture IDs must be unique.") }
        if fixtures.contains(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            problems.append("Every fixture requires a title.")
        }
        if fixtures.contains(where: { $0.expectedService.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            problems.append("Every fixture requires expected-service truth or an explicit visibility sentinel.")
        }
        let purposeTokens = Set(IntendedPurpose.allCases.map(\.rawValue) + [
            "EMAIL_VERIFICATION", "PAIRING", "BONUS", "DOCUMENT_ACCESS",
            "REWARD_OR_SALARY"
        ])
        if fixtures.contains(where: {
            purposeTokens.contains($0.expectedService) || purposeTokens.contains($0.presentedService)
        }) {
            problems.append("Service fields must not contain purpose/action tokens.")
        }
        return problems
    }

    static func fixture(id: String) -> EvaluationFixture? {
        fixtures.first { $0.id == id }
    }

    private static func f(
        _ id: String,
        _ title: String,
        _ base: String,
        _ expected: String,
        presented: String? = nil,
        purpose: IntendedPurpose = .signIn,
        presentedPurpose: IntendedPurpose? = .signIn,
        security: ScenarioSecurityType = .benign,
        visual: VisualDetectability = .clearlyDetectable,
        capture: CaptureQualityTruth = .sufficient,
        initiated: InitiationStatus = .yes,
        owner: ScenarioReceivingClientOwner = .user,
        clientContext: ScenarioReceivingClientContext = .intended,
        os: DisplayOS = .macOS,
        browser: DisplayBrowser = .chrome,
        presentation: PresentationType = .fullContext,
        association: AssociationCondition = .clean,
        signals: [DetectableSignalType] = [.consistentIdentity]
    ) -> EvaluationFixture {
        EvaluationFixture(
            id: id, title: title, imageFilename: id.lowercased(),
            matchedStimulusID: id, baseScenarioID: base,
            expectedService: expected, presentedService: presented ?? expected,
            expectedPurpose: purpose, presentedPurpose: presentedPurpose,
            securityType: security, visualDetectability: visual,
            captureQuality: capture, initiated: initiated,
            receivingClientOwner: owner, receivingClientContext: clientContext,
            displayOS: os, displayBrowser: browser,
            presentationType: presentation, associationCondition: association,
            detectableSignals: signals
        )
    }
}

/// Predefined matched pairs for Evaluation 2. This catalogue remains separate
/// from the core fixture catalogue so its options do not change the 46-fixture
/// coverage denominator used by Evaluation 1.
enum CompetingContextEvaluationFixtureCatalog {
    static let version = "competing-context-catalog-v1"

    static let fixtures: [EvaluationFixture] = [
        f("C01-0", "Clean Wells Fargo baseline", "C01", "c01-0.png", "Wells Fargo", .edge, .clean),
        f("C01-1", "Wells Fargo with peripheral Chase window", "C01", "c01-1.png", "Wells Fargo", .edge, .competingIrrelevant),
        f("C02-0", "Clean GitHub baseline", "C02", "c02-0.png", "GitHub", .edge, .clean),
        f("C02-1", "GitHub with peripheral Microsoft window", "C02", "c02-1.png", "GitHub", .edge, .competingIrrelevant),
        f("C03-0", "Discord baseline with secondary QR", "C03", "c03-0.png", "Discord", .edge, .competingIrrelevant),
        f("C03-1", "Discord with peripheral Amazon window and secondary QR", "C03", "c03-1.png", "Discord", .edge, .competingIrrelevant),
        f("C04-0", "Clean Crypto.com baseline", "C04", "c04-0.png", "Crypto.com", .edge, .clean),
        f("C04-1", "Crypto.com with peripheral Coinbase window", "C04", "c04-1.png", "Crypto.com", .edge, .competingIrrelevant),
        f("C05-0", "Clean Shopify baseline", "C05", "c05-0.png", "Shopify", .edge, .clean),
        f("C05-1", "Shopify with peripheral Facebook window", "C05", "c05-1.png", "Shopify", .edge, .competingIrrelevant),
        f("C06-0", "Clean PayPal baseline", "C06", "c06-0.png", "PayPal", .chrome, .clean),
        f("C06-1", "PayPal with peripheral Venmo payment language", "C06", "c06-1.png", "PayPal", .chrome, .competingIrrelevant)
    ]

    static var validationProblems: [String] {
        var problems: [String] = []
        let ids = fixtures.map(\.id)
        if fixtures.count != 12 { problems.append("The competing-context catalogue must contain 12 fixtures.") }
        if Set(ids).count != ids.count { problems.append("Competing-context fixture IDs must be unique.") }
        if fixtures.contains(where: { $0.expectedService != $0.presentedService }) {
            problems.append("Peripheral competitors must not replace the primary presented service.")
        }
        for pairID in Set(fixtures.map(\.matchedStimulusID)) {
            if fixtures.filter({ $0.matchedStimulusID == pairID }).count != 2 {
                problems.append("Matched pair \(pairID) must contain exactly two fixtures.")
            }
        }
        return problems
    }

    static func fixture(id: String) -> EvaluationFixture? {
        fixtures.first { $0.id == id }
    }

    private static func f(
        _ id: String,
        _ title: String,
        _ pairID: String,
        _ imageFilename: String,
        _ primaryService: String,
        _ browser: DisplayBrowser,
        _ association: AssociationCondition
    ) -> EvaluationFixture {
        EvaluationFixture(
            id: id,
            title: title,
            imageFilename: imageFilename,
            matchedStimulusID: pairID,
            baseScenarioID: "CONTEXT-ASSOCIATION",
            expectedService: primaryService,
            presentedService: primaryService,
            expectedPurpose: .signIn,
            presentedPurpose: .signIn,
            securityType: .benign,
            visualDetectability: .clearlyDetectable,
            captureQuality: .sufficient,
            initiated: .yes,
            receivingClientOwner: .user,
            receivingClientContext: .intended,
            displayOS: .macOS,
            displayBrowser: browser,
            presentationType: .fullContext,
            associationCondition: association,
            detectableSignals: [.consistentIdentity]
        )
    }
}

enum ControlledEvaluationServiceCatalog {
    static let version = "service-catalog-v1"

    static let profiles: [EvaluationServiceProfile] = [
        EvaluationServiceProfile(
            id: "CHASE",
            displayName: "Chase",
            canonicalServiceName: "Chase",
            controlledDomains: ["chase.com"]
        ),
        EvaluationServiceProfile(
            id: "GOOGLE",
            displayName: "Google",
            canonicalServiceName: "Google",
            controlledDomains: ["google.com", "accounts.google.com"]
        ),
        EvaluationServiceProfile(
            id: "MICROSOFT",
            displayName: "Microsoft",
            canonicalServiceName: "Microsoft",
            controlledDomains: ["microsoft.com", "login.microsoftonline.com"]
        ),
        EvaluationServiceProfile(
            id: "GITHUB",
            displayName: "GitHub",
            canonicalServiceName: "GitHub",
            controlledDomains: ["github.com"]
        )
    ]

    static func profile(id: String) -> EvaluationServiceProfile? {
        profiles.first { $0.id == id }
    }
}

enum EvaluationImplementationVersion {
    static let exportSchema = "2.28-draft"
    static let classifier = "1.5"
    static let ruleSet = "1.8"
    static let associationModel = "2.3"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "development"
    }

    static var gitCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "GIT_COMMIT") as? String
            ?? "not_recorded"
    }

    static var gitWorkingTreeDirty: Bool? {
        Bundle.main.object(forInfoDictionaryKey: "GIT_WORKING_TREE_DIRTY") as? Bool
    }
}

enum EvaluationScenarioFamily: String, Codable, CaseIterable, Identifiable {
    case legitimateExplicit = "LEGITIMATE_EXPLICIT"
    case legitimateSparse = "LEGITIMATE_SPARSE"
    case misleadingExplanation = "MISLEADING_EXPLANATION"
    case socialEngineering = "SOCIAL_ENGINEERING"
    case identityConflict = "IDENTITY_CONFLICT"
    case purposeConflict = "PURPOSE_CONFLICT"
    case presentationChannel = "PRESENTATION_CHANNEL"
    case degradedCapture = "DEGRADED_CAPTURE"
    case visuallyIndistinguishableAttack = "VISUALLY_INDISTINGUISHABLE_ATTACK"

    var id: String { rawValue }
}

/// A versioned, image-independent definition of a controlled evaluation case.
/// Ground truth is assigned by the study design, never inferred from scanner output.
struct ControlledEvaluationScenario: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let family: EvaluationScenarioFamily
    let groundTruth: ScenarioGroundTruth
    let contextType: ContextType
    let detectabilityBoundary: DetectabilityBoundary
    let requiredVariants: [String]
    let rationale: String
    let factualGroundTruth: ScenarioFactualGroundTruth
}

struct EvaluationConditionDefaults: Equatable {
    var lighting: LightingCondition = .normal
    var angle: AngleCondition = .straight
    var distance: DistanceCondition = .medium
    var blur: BlurCondition = .none
    var crop: CropCondition = .none
    var presentation: PresentationType = .fullContext
    var clutter: ClutterCondition = .clean
    var association: AssociationCondition = .clean
    var displayOS: DisplayOS = .unknown
    var displayBrowser: DisplayBrowser = .unknown
}

enum ControlledEvaluationScenarioCatalog {
    static let version = "scenario-catalog-v1"

    static let scenarios: [ControlledEvaluationScenario] = [
        scenario("LEG-EXPLICIT", "Explicit legitimate passkey ceremony", .legitimateExplicit, .consistent, .matching, .visibleConsistentEvidence, ["login_page"]),
        scenario("LEG-SPARSE", "Legitimate ceremony with sparse context", .legitimateSparse, .uncertain, .missingContext, .insufficientVisualEvidence, ["minimal_text", "cropped_context"]),
        scenario("MIS-NONAUTH", "FIDO QR described as a non-authentication action", .misleadingExplanation, .suspicious, .mismatching, .visibleContradiction, ["payment", "document", "wifi"]),
        scenario("SOC-PRESSURE", "Urgency or coercion around the ceremony", .socialEngineering, .suspicious, .mismatching, .visiblePersuasion, ["urgency", "threat", "authority_pressure"]),
        scenario("ID-CONFLICT", "Conflicting visible service or domain", .identityConflict, .suspicious, .mismatching, .visibleContradiction, ["brand_domain", "expected_service"]),
        scenario("PURPOSE-CONFLICT", "Expected purpose conflicts with sign-in", .purposeConflict, .suspicious, .mismatching, .visibleContradiction, ["payment", "document", "account_recovery"]),
        scenario("CHANNELS", "Ceremony shown through alternative channels", .presentationChannel, .uncertain, .ambiguous, .insufficientVisualEvidence, ["email", "chat", "kiosk", "shared_computer", "unrelated_page"]),
        scenario("CAPTURE-QUALITY", "Ceremony under degraded capture conditions", .degradedCapture, .uncertain, .ambiguous, .insufficientVisualEvidence, ["blur", "distance", "crop", "angle", "glare", "low_light"]),
        scenario("LIMIT-SESSION", "Convincing attacker-controlled receiving session", .visuallyIndistinguishableAttack, .suspicious, .matching, .visuallyIndistinguishableSessionAttack, ["attacker_session"])
    ]

    static var validationProblems: [String] {
        var problems: [String] = []
        let ids = scenarios.map(\.id)
        if Set(ids).count != ids.count { problems.append("Scenario IDs must be unique.") }
        let presentFamilies = Set(scenarios.map(\.family))
        let missingFamilies = Set(EvaluationScenarioFamily.allCases).subtracting(presentFamilies)
        if !missingFamilies.isEmpty {
            problems.append("Missing scenario families: \(missingFamilies.map(\.rawValue).sorted().joined(separator: ", ")).")
        }
        if scenarios.contains(where: { $0.groundTruth == .notAssigned }) {
            problems.append("Controlled scenarios require an assigned ground-truth label.")
        }
        if scenarios.contains(where: { $0.requiredVariants.isEmpty }) {
            problems.append("Every scenario requires at least one controlled variant.")
        }
        return problems
    }

    static func conditionDefaults(
        scenarioID: String,
        variant: String
    ) -> EvaluationConditionDefaults {
        var values = EvaluationConditionDefaults()
        let scenario = scenarios.first { $0.id == scenarioID }

        switch (scenario?.family, variant) {
        case (.legitimateSparse, "minimal_text"):
            values.presentation = .isolatedDialog
        case (.legitimateSparse, "cropped_context"):
            values.presentation = .ambiguousContext
            values.crop = .partial
        case (.presentationChannel, "email"),
             (.presentationChannel, "chat"),
             (.presentationChannel, "unrelated_page"):
            values.presentation = .ambiguousContext
            values.clutter = .competing
            values.association = .competingIrrelevant
        case (.identityConflict, "brand_domain"):
            values.association = .competingRelevant
        case (.degradedCapture, "blur"):
            values.blur = .severe
        case (.degradedCapture, "distance"):
            values.distance = .far
        case (.degradedCapture, "crop"):
            values.crop = .severe
            values.presentation = .ambiguousContext
        case (.degradedCapture, "angle"):
            values.angle = .steepAngle
        case (.degradedCapture, "glare"):
            values.lighting = .glare
        case (.degradedCapture, "low_light"):
            values.lighting = .lowLight
        default:
            break
        }

        let tokens = Set(variant.uppercased().split { $0 == "_" || $0 == "-" }.map(String.init))
        if tokens.contains("WINDOWS") || tokens.contains("WIN") { values.displayOS = .windows }
        if tokens.contains("MACOS") || tokens.contains("MAC") { values.displayOS = .macOS }
        if tokens.contains("IOS") { values.displayOS = .iOS }
        if tokens.contains("LINUX") { values.displayOS = .linux }
        if tokens.contains("CHROMEOS") { values.displayOS = .chromeOS }
        if tokens.contains("CHROME") { values.displayBrowser = .chrome }
        if tokens.contains("SAFARI") { values.displayBrowser = .safari }
        if tokens.contains("EDGE") { values.displayBrowser = .edge }
        if tokens.contains("FIREFOX") { values.displayBrowser = .firefox }
        return values
    }

    private static func scenario(
        _ id: String,
        _ title: String,
        _ family: EvaluationScenarioFamily,
        _ groundTruth: ScenarioGroundTruth,
        _ contextType: ContextType,
        _ boundary: DetectabilityBoundary,
        _ variants: [String]
    ) -> ControlledEvaluationScenario {
        ControlledEvaluationScenario(
            id: id,
            title: title,
            family: family,
            groundTruth: groundTruth,
            contextType: contextType,
            detectabilityBoundary: boundary,
            requiredVariants: variants,
            rationale: family == .visuallyIndistinguishableAttack
                ? "Measures a known scanner limitation; the expected scanner output may differ from ground truth."
                : "Measures visible evidence in the \(family.rawValue.lowercased()) family.",
            factualGroundTruth: factualTruth(for: family)
        )
    }

    private static func factualTruth(
        for family: EvaluationScenarioFamily
    ) -> ScenarioFactualGroundTruth {
        switch family {
        case .legitimateExplicit:
            ScenarioFactualGroundTruth(
                securityType: .benign,
                visualDetectability: .clearlyDetectable,
                captureQuality: .sufficient,
                service: "",
                presentedService: "",
                purpose: .signIn,
                presentedPurpose: .signIn,
                initiated: .yes,
                receivingClientOwner: .user,
                detectableSignals: [.consistentIdentity]
            )
        case .legitimateSparse:
            ScenarioFactualGroundTruth(
                securityType: .insufficient,
                visualDetectability: .partiallyDetectable,
                captureQuality: .sufficient,
                service: "",
                presentedService: "",
                purpose: .signIn,
                presentedPurpose: nil,
                initiated: .yes,
                receivingClientOwner: .user,
                detectableSignals: [.missingContext]
            )
        case .degradedCapture:
            ScenarioFactualGroundTruth(
                securityType: .insufficient,
                visualDetectability: .partiallyDetectable,
                captureQuality: .insufficient,
                service: "",
                presentedService: "",
                purpose: .signIn,
                presentedPurpose: .signIn,
                initiated: .yes,
                receivingClientOwner: .user,
                detectableSignals: [.degradedCapture]
            )
        case .visuallyIndistinguishableAttack:
            ScenarioFactualGroundTruth(
                securityType: .misleading,
                visualDetectability: .visuallyIndistinguishable,
                captureQuality: .sufficient,
                service: "",
                presentedService: "",
                purpose: .signIn,
                presentedPurpose: .signIn,
                initiated: .no,
                receivingClientOwner: .attacker,
                detectableSignals: [.unexpectedInitiation]
            )
        case .identityConflict:
            misleadingTruth(signals: [.identityContradiction, .domainConflict])
        case .purposeConflict, .misleadingExplanation:
            misleadingTruth(signals: [.purposeContradiction])
        case .socialEngineering:
            misleadingTruth(signals: [.persuasion])
        case .presentationChannel:
            ScenarioFactualGroundTruth(
                securityType: .insufficient,
                visualDetectability: .partiallyDetectable,
                captureQuality: .sufficient,
                service: "",
                presentedService: "",
                purpose: .signIn,
                presentedPurpose: .signIn,
                initiated: .yes,
                receivingClientOwner: .user,
                detectableSignals: []
            )
        }
    }

    private static func misleadingTruth(
        signals: [DetectableSignalType]
    ) -> ScenarioFactualGroundTruth {
        ScenarioFactualGroundTruth(
            securityType: .misleading,
            visualDetectability: .clearlyDetectable,
            captureQuality: .sufficient,
            service: "",
            presentedService: "",
            purpose: .signIn,
            presentedPurpose: nil,
            initiated: .no,
            receivingClientOwner: .attacker,
            detectableSignals: signals
        )
    }
}

struct EvaluationLabels: Codable, Equatable {
    var testId: String
    var scenarioGroundTruth: ScenarioGroundTruth
    var lightingCondition: LightingCondition
    var angleCondition: AngleCondition
    var distanceCondition: DistanceCondition
    var displayOS: DisplayOS = .unknown
    var displayBrowser: DisplayBrowser = .unknown
    var presentationType: PresentationType = .unknown
    var clutterCondition: ClutterCondition = .unknown
    var cropCondition: CropCondition = .unknown
    var blurCondition: BlurCondition = .unknown
    var contextType: ContextType
    var detectabilityBoundary: DetectabilityBoundary
    var notes: String
    var datasetSplit: DatasetSplit = .notAssigned
    var runNumber: String = ""
    var captureAttempt: String = ""
    var factualGroundTruth: ScenarioFactualGroundTruth = .notAssigned
    var expectedServiceProfileID: String = ""
    var presentedServiceProfileID: String = ""
    var matchedStimulusID: String = ""
    var associationCondition: AssociationCondition = .notAssigned
    var failureAttribution: EvaluationFailureAttribution = .none
    var captureConditionPreset: CaptureConditionPreset = .manual

    static let empty = EvaluationLabels(
        testId: "",
        scenarioGroundTruth: .notAssigned,
        lightingCondition: .unknown,
        angleCondition: .unknown,
        distanceCondition: .unknown,
        contextType: .unknown,
        detectabilityBoundary: .notAssigned,
        notes: ""
    )
}

struct EvaluationScenarioProvenance: Codable, Equatable {
    let catalogVersion: String
    let baseScenarioID: String
    let variant: String

    static let manual = EvaluationScenarioProvenance(
        catalogVersion: "",
        baseScenarioID: "",
        variant: ""
    )
}

struct EvaluationSpatialObservation: Codable, Equatable, Identifiable {
    let observationId: String
    var recognizedText: String? = nil
    let textFingerprint: String?
    let extractedFeatureIdentifiers: [String]?
    let boundingBox: NormalizedBoundingBox?
    let associatedQRCodeID: String?
    let associatedQRCodeBoundingBox: NormalizedBoundingBox?
    let confidence: Float
    let sourceRegion: OCRRegion
    let proximity: SpatialProximity
    let contextZone: ContextZone
    let associationStrength: AssociationStrength
    var semanticRole: SemanticContextRole? = nil
    let normalizedDistanceToQRCode: Double?

    var id: String { observationId }
}

enum EvaluationValidationSeverity: String, Codable, Equatable {
    case warning
    case error
}

enum EvaluationValidationIssueCode: String, Codable, Equatable {
    case missingTestID
    case duplicateTestID
    case baseTestIDNeedsRunSuffix
    case groundTruthNotAssigned
    case unknownCaptureConditions
    case unknownDisplayConditions
    case missingScenarioVariant
    case missingDatasetSplit
    case missingRunMetadata
    case factualGroundTruthNotAssigned
    case missingControlledScenario
    case incompleteFactualGroundTruth
    case invalidRunMetadata
    case invalidClarificationProvenance
    case clarificationTruthMismatch
    case groundTruthPolicyMismatch
    case invalidServiceProfile
    case scenarioMetadataNotConfirmed
    case missingMatchedStimulus
    case missingAssociationCondition
}

struct EvaluationValidationIssue: Codable, Equatable, Identifiable {
    let code: EvaluationValidationIssueCode
    let severity: EvaluationValidationSeverity
    let message: String

    var id: String { code.rawValue }
}

struct EvaluationRecordValidator {
    func validate(
        labels: EvaluationLabels,
        selectedScenarioID: String,
        selectedScenarioVariant: String = "",
        existingTestIDs: Set<String>,
        clarificationHistory: [ClarificationEvent] = [],
        clarificationAnswerSource: ClarificationAnswerSource = .none,
        intent: UserIntent = .skipped,
        analysisCompleted: Bool = false,
        scenarioMetadataConfirmed: Bool = false
    ) -> [EvaluationValidationIssue] {
        var issues: [EvaluationValidationIssue] = []
        let isFinal = labels.datasetSplit == .finalEvaluation
        let controlledSeverity: EvaluationValidationSeverity = isFinal ? .error : .warning
        let testID = labels.testId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExistingIDs = Set(existingTestIDs.map(normalizeID))

        if testID.isEmpty {
            issues.append(issue(.missingTestID, .error, "Enter a unique test ID before adding this scan."))
        } else if normalizedExistingIDs.contains(normalizeID(testID)) {
            issues.append(issue(.duplicateTestID, .error, "This test ID already exists in the current dataset."))
        }

        if !selectedScenarioID.isEmpty,
           normalizeID(testID) == normalizeID(selectedScenarioID) {
            issues.append(issue(
                .baseTestIDNeedsRunSuffix,
                .warning,
                "Add a variant or run suffix to the catalogue's base test ID."
            ))
        }
        if !selectedScenarioID.isEmpty && selectedScenarioVariant.isEmpty {
            issues.append(issue(
                .missingScenarioVariant,
                .error,
                "Select the controlled scenario variant represented by this scan."
            ))
        }
        if !selectedScenarioID.isEmpty && labels.datasetSplit == .notAssigned {
            issues.append(issue(
                .missingDatasetSplit,
                .warning,
                "Assign a dataset split before collecting a controlled record."
            ))
        }
        if isFinal && selectedScenarioID.isEmpty {
            issues.append(issue(
                .missingControlledScenario,
                .error,
                "Final evaluation requires a predefined controlled scenario."
            ))
        }
        if isFinal && labels.matchedStimulusID.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            issues.append(issue(
                .missingMatchedStimulus,
                .error,
                "Final evaluation requires a matched stimulus ID for paired comparisons."
            ))
        }
        if isFinal && labels.associationCondition == .notAssigned {
            issues.append(issue(
                .missingAssociationCondition,
                .error,
                "Assign the context-association condition represented by this stimulus."
            ))
        }
        if !selectedScenarioID.isEmpty &&
            (labels.runNumber.trimmingCharacters(in: .whitespaces).isEmpty ||
             labels.captureAttempt.trimmingCharacters(in: .whitespaces).isEmpty) {
            issues.append(issue(
                .missingRunMetadata,
                controlledSeverity,
                "Record both run number and capture attempt for controlled evaluation."
            ))
        }
        if isFinal && (!isPositiveInteger(labels.runNumber) ||
                       !isPositiveInteger(labels.captureAttempt)) {
            issues.append(issue(
                .invalidRunMetadata,
                .error,
                "Final-evaluation run number and capture attempt must be positive integers."
            ))
        }
        if !selectedScenarioID.isEmpty &&
            labels.factualGroundTruth.securityType == .notAssigned {
            issues.append(issue(
                .factualGroundTruthNotAssigned,
                controlledSeverity,
                "Assign factual scenario security truth before final evaluation."
            ))
        }
        if isFinal && !hasCompleteFactualTruth(labels.factualGroundTruth) {
            issues.append(issue(
                .incompleteFactualGroundTruth,
                .error,
                "Final evaluation requires service, purpose, initiation, receiving-client ownership or session-context truth, visual detectability, and capture-quality truth."
            ))
        }
        if labels.scenarioGroundTruth == .notAssigned {
            issues.append(issue(
                .groundTruthNotAssigned,
                controlledSeverity,
                "NOT_ASSIGNED records are retained but excluded from classification metrics."
            ))
        }
        if isFinal,
           let expectedClass = combinedTarget(for: labels.factualGroundTruth),
           labels.scenarioGroundTruth.classification != expectedClass {
            issues.append(issue(
                .groundTruthPolicyMismatch,
                .error,
                "Legacy scenario label conflicts with the target derived from factual truth."
            ))
        }
        if labels.lightingCondition == .unknown ||
            labels.angleCondition == .unknown ||
            labels.distanceCondition == .unknown {
            issues.append(issue(
                .unknownCaptureConditions,
                controlledSeverity,
                "Record lighting, angle, and distance for controlled evaluation runs."
            ))
        }
        if !selectedScenarioID.isEmpty &&
            (labels.displayOS == .unknown ||
             labels.displayBrowser == .unknown ||
             labels.presentationType == .unknown ||
             labels.clutterCondition == .unknown ||
             labels.cropCondition == .unknown ||
             labels.blurCondition == .unknown) {
            issues.append(issue(
                .unknownDisplayConditions,
                controlledSeverity,
                "Record display OS, browser, presentation, clutter, crop, and blur for controlled evaluation runs."
            ))
        }
        if isFinal && analysisCompleted {
            if !scenarioMetadataConfirmed {
                issues.append(issue(
                    .scenarioMetadataNotConfirmed,
                    .error,
                    "Confirm that the final scenario summary matches the physical test setup."
                ))
            }
            if !clarificationHistory.isEmpty && clarificationAnswerSource != .scenarioControlled {
                issues.append(issue(
                    .invalidClarificationProvenance,
                    .error,
                    "Final-evaluation clarification must come from the controlled scenario script."
                ))
            }
            if clarificationContradictsTruth(
                history: clarificationHistory,
                intent: intent,
                truth: labels.factualGroundTruth
            ) {
                issues.append(issue(
                    .clarificationTruthMismatch,
                    .error,
                    "Recorded clarification conflicts with predefined factual scenario truth."
                ))
            }
        }
        return issues
    }

    private func hasCompleteFactualTruth(_ truth: ScenarioFactualGroundTruth) -> Bool {
        let hasReceivingClientTruth = truth.receivingClientOwner != .unknown ||
            (truth.receivingClientContext != nil && truth.receivingClientContext != .unknown)
        return truth.securityType != .notAssigned &&
            !truth.service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            truth.purpose != nil && truth.purpose != .unsure &&
            truth.initiated != .unsure &&
            hasReceivingClientTruth &&
            truth.visualDetectability != .notAssigned &&
            truth.captureQuality != .notAssigned
    }

    private func clarificationContradictsTruth(
        history: [ClarificationEvent],
        intent: UserIntent,
        truth: ScenarioFactualGroundTruth
    ) -> Bool {
        let kinds = Set(history.map(\.questionKind))
        if let initiationEvent = history.last(where: { $0.questionKind == .initiation }),
           initiationEvent.answer != truth.initiated.rawValue {
            return true
        }
        if let receivingEvent = history.last(where: { $0.questionKind == .receivingComputer }) {
            let expected = ScenarioClarificationScript().receivingClientRelationship(for: truth)
            if receivingEvent.answer != expected.rawValue { return true }
        }
        if kinds.contains(.service), normalizeID(intent.expectedService ?? "") != normalizeID(truth.service) {
            return true
        }
        if kinds.contains(.purpose), intent.expectedPurpose != truth.purpose {
            return true
        }
        if kinds.contains(.initiation),
           (intent.initiationStatus != truth.initiated ||
            intent.startedOnReceivingClient != truth.initiated) {
            return true
        }
        if kinds.contains(.receivingComputer) {
            let expected = ScenarioClarificationScript().receivingClientRelationship(for: truth)
            if intent.receivingClientRelationship != expected { return true }
        }
        return false
    }

    private func combinedTarget(
        for truth: ScenarioFactualGroundTruth
    ) -> RiskClassification? {
        switch truth.securityType {
        case .benign: return .consistent
        case .misleading: return .suspicious
        case .insufficient: return .uncertain
        case .notAssigned: return nil
        }
    }

    private func isPositiveInteger(_ value: String) -> Bool {
        guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return number > 0
    }

    private func normalizeID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func issue(
        _ code: EvaluationValidationIssueCode,
        _ severity: EvaluationValidationSeverity,
        _ message: String
    ) -> EvaluationValidationIssue {
        EvaluationValidationIssue(code: code, severity: severity, message: message)
    }
}

struct EvaluationRecord: Codable, Equatable {
    let timestamp: Date
    let scanId: UUID?
    let testId: String
    let scenarioCatalogVersion: String
    let baseScenarioID: String
    let scenarioVariant: String
    let matchedStimulusID: String?
    let associationCondition: AssociationCondition?
    let scenarioGroundTruth: ScenarioGroundTruth
    let exportSchemaVersion: String?
    let classifierVersion: String?
    let ruleSetVersion: String?
    let associationModelVersion: String?
    let appVersion: String?
    let gitCommit: String?
    let gitWorkingTreeDirty: Bool?
    let datasetSplit: DatasetSplit?
    let runNumber: String?
    let captureAttempt: String?
    let factualGroundTruth: ScenarioFactualGroundTruth?
    let serviceCatalogVersion: String?
    let expectedServiceProfileID: String?
    let presentedServiceProfileID: String?
    let scenarioMetadataConfirmed: Bool?
    let displayOS: DisplayOS?
    let displayBrowser: DisplayBrowser?
    let presentationType: PresentationType?
    let clutterCondition: ClutterCondition?
    let cropCondition: CropCondition?
    let blurCondition: BlurCondition?
    let qrProcessingStatus: QRProcessingStatus?
    let ocrProcessingStatus: OCRProcessingStatus?
    let ocrObservationCount: Int?
    let imageQualitySufficient: Bool?
    let imageQualityIssues: [ImageQualityIssue]?
    let qrCount: Int?
    let qrTypes: [QRCodeType]?
    let visibleServiceClaims: [String]?
    let peripheralServiceClaims: [String]?
    let detectedPurposes: [String]?
    var purposeState: PurposeState? = nil
    let detectedCueTypes: [String]?
    let structuredRuleTrace: [ClassificationRuleResult]?
    let structuredSpatialObservations: [EvaluationSpatialObservation]?
    let structuredAblationComparisons: [AblationComparison]?
    var competingContextPresent: Bool? = nil
    var associationResolution: AssociationResolution? = nil
    let associationAmbiguous: Bool?
    let strongOverrideFired: Bool?
    var primaryVisualTriggeredRuleId: String? = nil
    let primaryTriggeredRuleId: String?
    let clarificationAsked: Bool?
    let clarificationQuestionKinds: [String]?
    let clarificationAnswerValues: [String]?
    let clarificationAnswerSource: ClarificationAnswerSource?
    let failureStage: EvaluationFailureStage?
    let errorCategory: EvaluationErrorCategory?
    let failureAttribution: EvaluationFailureAttribution?
    let captureConditionPreset: CaptureConditionPreset?
    let qrDetected: QRDetectionStatus
    let analysisMode: AnalysisMode
    let applicationMode: ApplicationMode
    let participantIntroductionCompleted: Bool
    let ocrTextPreview: String
    let fullOcrText: String
    let visibleDomainClaims: [String]
    let detectedKeywords: [String]
    var visualClassification: RiskClassification? = nil
    var visualRiskScore: Int? = nil
    let classification: RiskClassification
    let scanLatencyMilliseconds: Double?
    let qrDetectionMilliseconds: Double?
    let fullFrameOCRMilliseconds: Double?
    let qrRegionOCRMilliseconds: Double?
    let imageAnalysisMilliseconds: Double?
    let classificationMilliseconds: Double?
    let riskScore: Int
    let evidenceCompleteness: Int
    let visualEvidenceCompleteness: EvidenceCompletenessLevel
    let intentSessionCompleteness: EvidenceCompletenessLevel
    let reasons: [String]
    let contradictionReasons: [String]
    let persuasionReasons: [String]
    let missingEvidenceReasons: [String]
    let contextualConcernReasons: [String]
    let preliminaryClassification: RiskClassification?
    let preliminaryInterventionStyle: SecurityResultStyle?
    let preliminaryRecommendedActionIdentifier: String
    let clarificationChangedClassification: Bool
    let clarificationChangedRecommendedAction: Bool
    let clarificationPolicy: ClarificationPolicy
    let clarificationQuestions: [String]
    let clarificationAnswers: [String]
    let expectedService: String
    let expectedPurpose: String
    let initiationStatus: String
    let receivingClientRelationship: String
    let receivingClientTrust: String
    let assessmentDimensions: [String]
    let sessionBindingAssessment: SessionBindingAssessment
    let spatialEvidenceSummary: [String]
    /// Optional for backwards compatibility with locally persisted records
    /// created before ablation analysis was introduced.
    let ablationSummary: [String]?
    let userFacingHeadline: String
    let primaryReasonIdentifier: String
    let primaryReason: String
    let recommendedActionIdentifier: String
    let recommendedAction: String
    let interventionStyle: SecurityResultStyle
    let safetyChecks: [String]
    let lightingCondition: LightingCondition
    let angleCondition: AngleCondition
    let distanceCondition: DistanceCondition
    let contextType: ContextType
    let detectabilityBoundary: DetectabilityBoundary
    let notes: String
}

enum EvaluationTargetSource: String, Codable, Equatable {
    case factualPolicy = "FACTUAL_POLICY"
    case legacyThreeClass = "LEGACY_THREE_CLASS"
    case unavailable = "UNAVAILABLE"
}

enum EvaluationTargetKind: String, Codable, Equatable {
    case combinedSecurity = "COMBINED_SECURITY"
    case visualOnly = "VISUAL_ONLY"
}

enum EvaluationPredictionStage: String, Codable, Equatable {
    case final = "FINAL"
    case preliminary = "PRELIMINARY"
}

struct DerivedEvaluationTargets: Equatable {
    let combinedSecurity: RiskClassification?
    let visualOnly: RiskClassification?
    let source: EvaluationTargetSource
}

/// Converts independently authored scenario facts into evaluation targets.
/// This policy never reads classifier output, scores, or triggered rules.
struct EvaluationGroundTruthPolicy {
    func targets(for record: EvaluationRecord) -> DerivedEvaluationTargets {
        if let truth = record.factualGroundTruth,
           truth.securityType != .notAssigned {
            return DerivedEvaluationTargets(
                combinedSecurity: combinedTarget(for: truth),
                visualOnly: visualTarget(for: truth),
                source: .factualPolicy
            )
        }
        if let legacy = record.scenarioGroundTruth.classification {
            return DerivedEvaluationTargets(
                combinedSecurity: legacy,
                visualOnly: legacy,
                source: .legacyThreeClass
            )
        }
        return DerivedEvaluationTargets(
            combinedSecurity: nil,
            visualOnly: nil,
            source: .unavailable
        )
    }

    private func combinedTarget(
        for truth: ScenarioFactualGroundTruth
    ) -> RiskClassification? {
        switch truth.securityType {
        case .benign: .consistent
        case .misleading: .suspicious
        case .insufficient: .uncertain
        case .notAssigned: nil
        }
    }

    private func visualTarget(
        for truth: ScenarioFactualGroundTruth
    ) -> RiskClassification? {
        guard truth.captureQuality == .sufficient else { return .uncertain }
        switch truth.securityType {
        case .benign:
            switch truth.visualDetectability {
            case .clearlyDetectable, .partiallyDetectable: return .consistent
            case .insufficientEvidence: return .uncertain
            case .visuallyIndistinguishable, .notAssigned: return nil
            }
        case .insufficient:
            return .uncertain
        case .misleading:
            switch truth.visualDetectability {
            case .clearlyDetectable, .partiallyDetectable: return .suspicious
            case .insufficientEvidence: return .uncertain
            case .visuallyIndistinguishable, .notAssigned: return nil
            }
        case .notAssigned:
            return nil
        }
    }
}

struct EvaluationVariantCoverage: Equatable, Identifiable {
    let scenarioID: String
    let scenarioTitle: String
    let variant: String
    let recordCount: Int

    var id: String { "\(scenarioID)|\(variant)" }
    var isCovered: Bool { recordCount > 0 }
}

struct EvaluationCoverageSummary: Equatable {
    let catalogVersion: String
    let variants: [EvaluationVariantCoverage]
    let excludedRecordCount: Int

    var requiredVariantCount: Int { variants.count }
    var coveredVariantCount: Int { variants.filter(\.isCovered).count }
    var missingVariantCount: Int { requiredVariantCount - coveredVariantCount }
    var completionFraction: Double? {
        guard requiredVariantCount > 0 else { return nil }
        return Double(coveredVariantCount) / Double(requiredVariantCount)
    }
}

struct EvaluationCoverageCalculator {
    func calculateFixtures(
        records: [EvaluationRecord],
        catalogVersion: String = ControlledEvaluationFixtureCatalog.version,
        fixtures: [EvaluationFixture] = ControlledEvaluationFixtureCatalog.fixtures
    ) -> EvaluationCoverageSummary {
        let fixtureKeys = Set(fixtures.map { "\($0.baseScenarioID)|\($0.id)" })
        let currentRecords = records.filter { record in
            (record.failureStage ?? EvaluationFailureStage.none) == EvaluationFailureStage.none &&
                record.scenarioCatalogVersion == catalogVersion &&
                fixtureKeys.contains("\(record.baseScenarioID)|\(record.scenarioVariant)")
        }
        let variants = fixtures.map { fixture in
            EvaluationVariantCoverage(
                scenarioID: fixture.baseScenarioID,
                scenarioTitle: "\(fixture.id) — \(fixture.title)",
                variant: fixture.id,
                recordCount: currentRecords.filter {
                    $0.baseScenarioID == fixture.baseScenarioID &&
                        $0.scenarioVariant == fixture.id
                }.count
            )
        }
        return EvaluationCoverageSummary(
            catalogVersion: catalogVersion,
            variants: variants,
            excludedRecordCount: records.count - currentRecords.count
        )
    }

    func calculate(
        records: [EvaluationRecord],
        catalogVersion: String = ControlledEvaluationScenarioCatalog.version,
        scenarios: [ControlledEvaluationScenario] = ControlledEvaluationScenarioCatalog.scenarios
    ) -> EvaluationCoverageSummary {
        let currentRecords = records.filter { record in
            guard (record.failureStage ?? EvaluationFailureStage.none) == EvaluationFailureStage.none,
                  record.scenarioCatalogVersion == catalogVersion,
                  let scenario = scenarios.first(where: {
                      $0.id == record.baseScenarioID
                  }) else { return false }
            return scenario.requiredVariants.contains(record.scenarioVariant)
        }
        let variants = scenarios.flatMap { scenario in
            scenario.requiredVariants.map { variant in
                EvaluationVariantCoverage(
                    scenarioID: scenario.id,
                    scenarioTitle: scenario.title,
                    variant: variant,
                    recordCount: currentRecords.filter {
                        $0.baseScenarioID == scenario.id && $0.scenarioVariant == variant
                    }.count
                )
            }
        }
        return EvaluationCoverageSummary(
            catalogVersion: catalogVersion,
            variants: variants,
            excludedRecordCount: records.count - currentRecords.count
        )
    }
}

enum AblationSignalFamily: String, Codable, CaseIterable, Identifiable {
    case identity = "IDENTITY"
    case ceremonyAndPurpose = "CEREMONY_AND_PURPOSE"
    case socialEngineering = "SOCIAL_ENGINEERING"
    case userAndReceivingClient = "USER_AND_RECEIVING_CLIENT"
    case presentationChannel = "PRESENTATION_CHANNEL"
    case spatialAndCompetingContext = "SPATIAL_AND_COMPETING_CONTEXT"
    case contextAssociationModel = "CONTEXT_ASSOCIATION_MODEL"

    var id: String { rawValue }

    var ruleIdentifiers: Set<String> {
        switch self {
        case .identity: [
            "identity_evidence", "service_mismatch", "brand_domain_conflict",
            "expected_service_mismatch"
        ]
        case .ceremonyAndPurpose: [
            "ceremony_language", "purpose_mismatch", "direct_purpose_mismatch"
        ]
        case .socialEngineering: ["urgency_and_coercion"]
        case .userAndReceivingClient: ["unexpected_initiation", "receiving_client_trust"]
        case .presentationChannel: ["channel_risk"]
        case .spatialAndCompetingContext: ["context_association", "spatial_relevance", "multiple_qr_codes"]
        case .contextAssociationModel: []
        }
    }
}

struct AblationComparison: Codable, Equatable, Identifiable {
    let family: AblationSignalFamily
    let baselineClassification: RiskClassification
    let ablatedClassification: RiskClassification
    let baselineRiskScore: Int
    let ablatedRiskScore: Int
    let baselineCompleteness: Int
    let ablatedCompleteness: Int
    let removedTriggeredRules: [String]
    var baselineConfigurationID: String? = nil
    var ablatedConfigurationID: String? = nil
    var baselineAssociationPolicy: ContextAssociationPolicy? = nil
    var ablatedAssociationPolicy: ContextAssociationPolicy? = nil

    var id: String { family.rawValue }
    var changedClassification: Bool { baselineClassification != ablatedClassification }
    var exportSummary: String {
        [family.rawValue,
         "\(baselineClassification.rawValue)->\(ablatedClassification.rawValue)",
         "risk:\(baselineRiskScore)->\(ablatedRiskScore)",
         "completeness:\(baselineCompleteness)->\(ablatedCompleteness)",
         "rules:\(removedTriggeredRules.joined(separator: "+"))"]
            .joined(separator: "|")
    }
}

struct ContextAblationAnalyzer {
    func analyze(
        observation: ScanObservation,
        intent: UserIntent,
        policy: ClarificationPolicy,
        classifier: ContextClassifier = ContextClassifier()
    ) -> [AblationComparison] {
        let baseline = classifier.classify(
            observation: observation,
            intent: intent,
            policy: policy,
            configuration: .full
        )
        return AblationSignalFamily.allCases.map { family in
            let ablatedConfiguration: ClassifierConfiguration = family == .contextAssociationModel
                ? .unfilteredVisualTextWithIntent
                : .full
            let ablated = classifier.classify(
                observation: observation,
                intent: intent,
                policy: policy,
                configuration: ablatedConfiguration,
                excludingRuleIdentifiers: family.ruleIdentifiers
            )
            var seen = Set<String>()
            let removed = baseline.ruleResults.map(\.ruleIdentifier).filter {
                family.ruleIdentifiers.contains($0) && seen.insert($0).inserted
            }
            return AblationComparison(
                family: family,
                baselineClassification: baseline.classification,
                ablatedClassification: ablated.classification,
                baselineRiskScore: baseline.riskScore,
                ablatedRiskScore: ablated.riskScore,
                baselineCompleteness: baseline.evidenceCompleteness,
                ablatedCompleteness: ablated.evidenceCompleteness,
                removedTriggeredRules: removed,
                baselineConfigurationID: ClassifierConfiguration.full.id,
                ablatedConfigurationID: ablatedConfiguration.id,
                baselineAssociationPolicy: ClassifierConfiguration.full.associationPolicy,
                ablatedAssociationPolicy: ablatedConfiguration.associationPolicy
            )
        }
    }
}

struct EvaluationConfusionMatrix: Equatable {
    private var cells: [RiskClassification: [RiskClassification: Int]] = [:]

    mutating func increment(actual: RiskClassification, predicted: RiskClassification) {
        cells[actual, default: [:]][predicted, default: 0] += 1
    }

    func count(actual: RiskClassification, predicted: RiskClassification) -> Int {
        cells[actual]?[predicted] ?? 0
    }

    func actualTotal(for classification: RiskClassification) -> Int {
        RiskClassification.allCases.reduce(0) {
            $0 + count(actual: classification, predicted: $1)
        }
    }

    func predictedTotal(for classification: RiskClassification) -> Int {
        RiskClassification.allCases.reduce(0) {
            $0 + count(actual: $1, predicted: classification)
        }
    }
}

struct EvaluationClassMetrics: Equatable, Identifiable {
    let classification: RiskClassification
    let support: Int
    let precision: Double?
    let recall: Double?
    let f1Score: Double?

    var id: RiskClassification { classification }
}

struct EvaluationMetricsSummary: Equatable {
    let targetKind: EvaluationTargetKind
    let predictionStage: EvaluationPredictionStage
    let includedRecordCount: Int
    let excludedRecordCount: Int
    let factualPolicyRecordCount: Int
    let legacyFallbackRecordCount: Int
    let confusionMatrix: EvaluationConfusionMatrix
    let perClass: [EvaluationClassMetrics]
    let accuracy: Double?
    let suspiciousFalseNegativeRate: Double?
    let consistentFalsePositiveRate: Double?
}

/// Describes the visual scanner's attack coverage without pretending that
/// hidden receiving-session ownership is a pixel-observable classification
/// target. These are dataset-level descriptive rates, not probabilities.
struct EvaluationAttackCoverageSummary: Equatable {
    let detectableMaliciousCount: Int
    let detectableSuspiciousCount: Int
    let detectableCaseSensitivity: Double?
    let overallMaliciousCount: Int
    let overallSuspiciousCount: Int
    let overallAttackCoverage: Double?
    let visuallyIndistinguishableCount: Int
}

struct EvaluationAttackCoverageCalculator {
    func calculate(records: [EvaluationRecord]) -> EvaluationAttackCoverageSummary {
        let malicious = records.filter { record in
            (record.failureStage ?? EvaluationFailureStage.none) ==
                EvaluationFailureStage.none &&
                record.factualGroundTruth?.securityType == .misleading
        }
        let visuallySuspicious: (EvaluationRecord) -> Bool = { record in
            (record.visualClassification ?? record.preliminaryClassification) == .suspicious
        }
        let detectable = malicious.filter { record in
            guard let truth = record.factualGroundTruth,
                  truth.captureQuality == .sufficient else { return false }
            return truth.visualDetectability == .clearlyDetectable ||
                truth.visualDetectability == .partiallyDetectable
        }
        let hiddenCount = malicious.filter {
            $0.factualGroundTruth?.visualDetectability == .visuallyIndistinguishable
        }.count
        let detectableSuspicious = detectable.filter(visuallySuspicious).count
        let overallSuspicious = malicious.filter(visuallySuspicious).count

        return EvaluationAttackCoverageSummary(
            detectableMaliciousCount: detectable.count,
            detectableSuspiciousCount: detectableSuspicious,
            detectableCaseSensitivity: ratio(
                detectableSuspicious,
                detectable.count
            ),
            overallMaliciousCount: malicious.count,
            overallSuspiciousCount: overallSuspicious,
            overallAttackCoverage: ratio(overallSuspicious, malicious.count),
            visuallyIndistinguishableCount: hiddenCount
        )
    }

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double? {
        guard denominator > 0 else { return nil }
        return Double(numerator) / Double(denominator)
    }
}

struct EvaluationMetricsCalculator {
    func calculate(
        records: [EvaluationRecord],
        targetKind: EvaluationTargetKind = .combinedSecurity,
        predictionStage: EvaluationPredictionStage = .final
    ) -> EvaluationMetricsSummary {
        var matrix = EvaluationConfusionMatrix()
        var includedCount = 0
        var factualCount = 0
        var legacyCount = 0
        let policy = EvaluationGroundTruthPolicy()

        for record in records {
            guard (record.failureStage ?? EvaluationFailureStage.none) == EvaluationFailureStage.none else {
                continue
            }
            let targets = policy.targets(for: record)
            let actual = targetKind == .combinedSecurity
                ? targets.combinedSecurity
                : targets.visualOnly
            let predicted: RiskClassification?
            if targetKind == .visualOnly {
                predicted = record.visualClassification ?? record.preliminaryClassification
            } else {
                predicted = predictionStage == .final
                    ? record.classification
                    : record.preliminaryClassification
            }
            guard let actual, let predicted else { continue }
            matrix.increment(actual: actual, predicted: predicted)
            includedCount += 1
            if targets.source == .factualPolicy { factualCount += 1 }
            if targets.source == .legacyThreeClass { legacyCount += 1 }
        }

        let perClass = RiskClassification.allCases.map { classification in
            classMetrics(for: classification, matrix: matrix)
        }
        let correct = RiskClassification.allCases.reduce(0) {
            $0 + matrix.count(actual: $1, predicted: $1)
        }
        let suspiciousTotal = matrix.actualTotal(for: .suspicious)
        let suspiciousDetected = matrix.count(actual: .suspicious, predicted: .suspicious)
        let consistentTotal = matrix.actualTotal(for: .consistent)
        let consistentFlaggedSuspicious = matrix.count(actual: .consistent, predicted: .suspicious)

        return EvaluationMetricsSummary(
            targetKind: targetKind,
            predictionStage: predictionStage,
            includedRecordCount: includedCount,
            excludedRecordCount: records.count - includedCount,
            factualPolicyRecordCount: factualCount,
            legacyFallbackRecordCount: legacyCount,
            confusionMatrix: matrix,
            perClass: perClass,
            accuracy: ratio(correct, includedCount),
            suspiciousFalseNegativeRate: ratio(
                suspiciousTotal - suspiciousDetected,
                suspiciousTotal
            ),
            consistentFalsePositiveRate: ratio(
                consistentFlaggedSuspicious,
                consistentTotal
            )
        )
    }

    private func classMetrics(
        for classification: RiskClassification,
        matrix: EvaluationConfusionMatrix
    ) -> EvaluationClassMetrics {
        let truePositive = matrix.count(actual: classification, predicted: classification)
        let predictedTotal = matrix.predictedTotal(for: classification)
        let actualTotal = matrix.actualTotal(for: classification)
        let precision = ratio(truePositive, predictedTotal)
        let recall = ratio(truePositive, actualTotal)
        let f1Score: Double?
        if let precision, let recall {
            f1Score = precision + recall == 0
                ? 0
                : 2 * precision * recall / (precision + recall)
        } else {
            f1Score = nil
        }

        return EvaluationClassMetrics(
            classification: classification,
            support: actualTotal,
            precision: precision,
            recall: recall,
            f1Score: f1Score
        )
    }

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double? {
        guard denominator > 0 else { return nil }
        return Double(numerator) / Double(denominator)
    }
}
