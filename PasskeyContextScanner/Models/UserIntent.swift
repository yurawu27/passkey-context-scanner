import Foundation

enum IntendedPurpose: String, Codable, CaseIterable, Identifiable, Equatable {
    case signIn = "SIGN_IN"
    case registerPasskey = "REGISTER_PASSKEY"
    case verifyIdentity = "VERIFY_IDENTITY"
    case pairDevice = "PAIR_DEVICE"
    case recoverAccount = "RECOVER_ACCOUNT"
    case payment = "PAYMENT"
    case openDocument = "OPEN_DOCUMENT"
    case connectWiFi = "CONNECT_WIFI"
    case other = "OTHER"
    case unsure = "UNSURE"

    var id: String { rawValue }
}

enum InitiationStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case yes = "YES"
    case no = "NO"
    case unsure = "UNSURE"

    var id: String { rawValue }
}

enum DisplaySource: String, Codable, CaseIterable, Identifiable, Equatable {
    case ownDevice = "OWN_DEVICE"
    case sharedComputer = "SHARED_COMPUTER"
    case kiosk = "KIOSK"
    case message = "MESSAGE"
    case printedPage = "PRINTED_PAGE"
    case unrelatedWebpage = "UNRELATED_WEBPAGE"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum ReceivingClientRelationship: String, Codable, CaseIterable, Identifiable, Equatable {
    case ownDevice = "OWN_DEVICE"
    case trustedSharedComputer = "TRUSTED_SHARED_COMPUTER"
    case publicOrKiosk = "PUBLIC_OR_KIOSK"
    case someoneElsesDevice = "SOMEONE_ELSES_DEVICE"
    case unknown = "UNKNOWN"

    var id: String { rawValue }
}

enum ReceivingClientTrustStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case yes = "YES"
    case no = "NO"
    case unsure = "UNSURE"

    var id: String { rawValue }
}

struct UserIntent: Codable, Equatable {
    var expectedService: String?
    var expectedPurpose: IntendedPurpose?
    var initiationStatus: InitiationStatus
    var displaySource: DisplaySource
    var receivingClientRelationship: ReceivingClientRelationship
    var startedOnReceivingClient: InitiationStatus
    var receivingClientTrust: ReceivingClientTrustStatus
    var visibleServiceMatchesExpectation: InitiationStatus
    var visiblePurposeMatchesExpectation: InitiationStatus
    var notes: String

    init(
        expectedService: String?,
        expectedPurpose: IntendedPurpose?,
        initiationStatus: InitiationStatus,
        displaySource: DisplaySource,
        receivingClientRelationship: ReceivingClientRelationship = .unknown,
        startedOnReceivingClient: InitiationStatus = .unsure,
        receivingClientTrust: ReceivingClientTrustStatus = .unsure,
        visibleServiceMatchesExpectation: InitiationStatus = .unsure,
        visiblePurposeMatchesExpectation: InitiationStatus = .unsure,
        notes: String
    ) {
        self.expectedService = expectedService
        self.expectedPurpose = expectedPurpose
        self.initiationStatus = initiationStatus
        self.displaySource = displaySource
        self.receivingClientRelationship = receivingClientRelationship
        self.startedOnReceivingClient = startedOnReceivingClient
        self.receivingClientTrust = receivingClientTrust
        self.visibleServiceMatchesExpectation = visibleServiceMatchesExpectation
        self.visiblePurposeMatchesExpectation = visiblePurposeMatchesExpectation
        self.notes = notes
    }

    static let skipped = UserIntent(
        expectedService: nil,
        expectedPurpose: nil,
        initiationStatus: .unsure,
        displaySource: .unknown,
        receivingClientRelationship: .unknown,
        startedOnReceivingClient: .unsure,
        receivingClientTrust: .unsure,
        visibleServiceMatchesExpectation: .unsure,
        visiblePurposeMatchesExpectation: .unsure,
        notes: ""
    )

    var hasDeclaredIntent: Bool {
        let hasService = expectedService?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        return hasService ||
            expectedPurpose != nil ||
            initiationStatus != .unsure ||
            receivingClientRelationship != .unknown ||
            startedOnReceivingClient != .unsure ||
            receivingClientTrust != .unsure
    }

    var hasServiceAndPurposeExpectation: Bool {
        let hasService = expectedService?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let hasPurpose = expectedPurpose != nil && expectedPurpose != .unsure
        let confirmedService = visibleServiceMatchesExpectation == .yes
        let confirmedPurpose = visiblePurposeMatchesExpectation == .yes
        return (hasService || confirmedService) && (hasPurpose || confirmedPurpose)
    }

    var hasTrustedReceivingClientContext: Bool {
        receivingClientRelationship != .unknown &&
            startedOnReceivingClient == .yes &&
            receivingClientTrust == .yes
    }
}

enum AdaptiveIntentQuestion: Equatable {
    case confirmService(String)
    case confirmPurpose(IntendedPurpose)
    case exactInitiation
    case receivingComputer

    var kind: AdaptiveIntentQuestionKind {
        switch self {
        case .confirmService: return .service
        case .confirmPurpose: return .purpose
        case .exactInitiation: return .initiation
        case .receivingComputer: return .receivingComputer
        }
    }

    var title: String {
        switch self {
        case .confirmService(let service):
            return "The visible text mentions \(service). Is that the service you intended to access?"
        case .confirmPurpose(let purpose):
            return "The visible text describes \(purpose.userFacingLabel.lowercased()). Is that what you intended?"
        case .exactInitiation:
            return "Did you personally start this exact request on the computer showing the QR code?"
        case .receivingComputer:
            return "Which computer is showing the QR code?"
        }
    }
}

enum AdaptiveIntentQuestionKind: String, Codable, Hashable {
    case service = "SERVICE"
    case purpose = "PURPOSE"
    case initiation = "INITIATION"
    case receivingComputer = "RECEIVING_COMPUTER"
}

struct ClarificationEvent: Codable, Equatable {
    let questionKind: AdaptiveIntentQuestionKind
    let prompt: String
    let answer: String
}

enum ClarificationAnswerSource: String, Codable, Equatable {
    case none = "NONE"
    case manual = "MANUAL"
    case scenarioControlled = "SCENARIO_CONTROLLED"
}

/// Supplies reproducible intent answers from researcher-authored scenario facts.
/// It does not infer ground truth from OCR or classifier output.
struct ScenarioClarificationScript {
    func confirmationAnswer(
        for question: AdaptiveIntentQuestion,
        truth: ScenarioFactualGroundTruth
    ) -> InitiationStatus {
        switch question {
        case .confirmService(let observedService):
            let expected = normalize(truth.service)
            guard !expected.isEmpty else { return .unsure }
            return normalize(observedService) == expected ? .yes : .no
        case .confirmPurpose(let observedPurpose):
            guard let expected = truth.purpose, expected != .unsure else { return .unsure }
            return observedPurpose == expected ? .yes : .no
        case .exactInitiation:
            return truth.initiated
        case .receivingComputer:
            return .unsure
        }
    }

    func receivingClientRelationship(
        for owner: ScenarioReceivingClientOwner
    ) -> ReceivingClientRelationship {
        switch owner {
        case .user: return .ownDevice
        case .trustedOther: return .trustedSharedComputer
        case .attacker: return .someoneElsesDevice
        case .unknown: return .unknown
        }
    }

    /// Converts only facts that answer the device-relationship question. An
    /// unintended session may still be on the user's own computer, so U04/U05
    /// deliberately remain unknown instead of being labelled attacker-owned.
    func receivingClientRelationship(
        for truth: ScenarioFactualGroundTruth
    ) -> ReceivingClientRelationship {
        switch truth.receivingClientContext {
        case .unintendedOrWrongSession, .unintended:
            return .unknown
        default:
            return receivingClientRelationship(for: truth.receivingClientOwner)
        }
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

enum ClarificationPolicy: String, Codable, Equatable {
    case participant
    case researcher

    var maximumQuestionCount: Int {
        switch self {
        case .participant: return 1
        case .researcher: return 4
        }
    }
}

extension IntendedPurpose {
    var userFacingLabel: String {
        switch self {
        case .signIn: return "Sign in"
        case .registerPasskey: return "Create a passkey"
        case .verifyIdentity: return "Verify identity"
        case .pairDevice: return "Add or pair a device"
        case .recoverAccount: return "Recover an account"
        case .payment: return "Make or receive a payment"
        case .openDocument: return "Open a document"
        case .connectWiFi: return "Connect to Wi-Fi"
        case .other: return "Another action"
        case .unsure: return "An unclear action"
        }
    }
}

struct AdaptiveIntentPlanner {
    private let featureExtractor = ContextFeatureExtractor()

    func nextQuestion(
        observation: ScanObservation,
        preliminaryResult: ScanResult,
        intent: UserIntent,
        answeredQuestions: Set<AdaptiveIntentQuestionKind> = []
    ) -> AdaptiveIntentQuestion? {
        candidateQuestions(
            observation: observation,
            preliminaryResult: preliminaryResult,
            intent: intent,
            answeredQuestions: answeredQuestions
        ).first
    }

    func nextHighInformationQuestion(
        observation: ScanObservation,
        preliminaryResult: ScanResult,
        intent: UserIntent,
        answeredQuestions: Set<AdaptiveIntentQuestionKind> = [],
        classifier: ContextClassifier,
        classificationPolicy: ClarificationPolicy = .participant
    ) -> AdaptiveIntentQuestion? {
        let baseline = interventionSignature(for: preliminaryResult)
        return candidateQuestions(
            observation: observation,
            preliminaryResult: preliminaryResult,
            intent: intent,
            answeredQuestions: answeredQuestions
        ).first { question in
            hypotheticalIntents(for: question, basedOn: intent).contains { hypotheticalIntent in
                let hypotheticalResult = classifier.classify(
                    observation: observation,
                    intent: hypotheticalIntent,
                    policy: classificationPolicy
                )
                return interventionSignature(for: hypotheticalResult) != baseline
            }
        }
    }

    private func candidateQuestions(
        observation: ScanObservation,
        preliminaryResult: ScanResult,
        intent: UserIntent,
        answeredQuestions: Set<AdaptiveIntentQuestionKind>
    ) -> [AdaptiveIntentQuestion] {
        guard preliminaryResult.classification != .suspicious else { return [] }
        guard observation.qrTypes.contains(.fido) else { return [] }
        let features = featureExtractor.extract(from: observation, intent: intent)
        var questions: [AdaptiveIntentQuestion] = []

        if !answeredQuestions.contains(.initiation),
           intent.startedOnReceivingClient == .unsure {
            questions.append(.exactInitiation)
        }
        if !answeredQuestions.contains(.receivingComputer),
           intent.receivingClientRelationship == .unknown {
            questions.append(.receivingComputer)
        }
        if !answeredQuestions.contains(.service),
           intent.visibleServiceMatchesExpectation == .unsure,
           intent.expectedService == nil,
           features.visibleServiceClaims.count == 1,
           let service = features.visibleServiceClaims.first {
            questions.append(.confirmService(service))
        }
        if !answeredQuestions.contains(.purpose),
           intent.visiblePurposeMatchesExpectation == .unsure,
           intent.expectedPurpose == nil,
           features.inferredPurposes.count == 1,
           let purpose = features.inferredPurposes.first {
            questions.append(.confirmPurpose(purpose))
        }
        return questions
    }

    private func hypotheticalIntents(
        for question: AdaptiveIntentQuestion,
        basedOn intent: UserIntent
    ) -> [UserIntent] {
        switch question {
        case .exactInitiation:
            return [InitiationStatus.yes, .no, .unsure].map { answer in
                var updated = intent
                updated.initiationStatus = answer
                updated.startedOnReceivingClient = answer
                return updated
            }
        case .receivingComputer:
            return ReceivingClientRelationship.allCases.map { relationship in
                var updated = intent
                updated.receivingClientRelationship = relationship
                switch relationship {
                case .ownDevice:
                    updated.displaySource = .ownDevice
                    updated.receivingClientTrust = .yes
                case .trustedSharedComputer:
                    updated.displaySource = .sharedComputer
                    updated.receivingClientTrust = .yes
                case .publicOrKiosk:
                    updated.displaySource = .kiosk
                    updated.receivingClientTrust = .no
                case .someoneElsesDevice:
                    updated.displaySource = .sharedComputer
                    updated.receivingClientTrust = .no
                case .unknown:
                    updated.receivingClientTrust = .unsure
                }
                return updated
            }
        case .confirmService(let service):
            return [InitiationStatus.yes, .no, .unsure].map { answer in
                var updated = intent
                updated.visibleServiceMatchesExpectation = answer
                if answer == .yes { updated.expectedService = service }
                return updated
            }
        case .confirmPurpose(let purpose):
            return [InitiationStatus.yes, .no, .unsure].map { answer in
                var updated = intent
                updated.visiblePurposeMatchesExpectation = answer
                if answer == .yes { updated.expectedPurpose = purpose }
                return updated
            }
        }
    }

    private func interventionSignature(for result: ScanResult) -> InterventionSignature {
        let presentation = SecurityResultPresentation.make(for: result)
        return InterventionSignature(
            classification: result.classification,
            style: presentation.style,
            recommendedAction: presentation.recommendedAction
        )
    }
}

private struct InterventionSignature: Equatable {
    let classification: RiskClassification
    let style: SecurityResultStyle
    let recommendedAction: String
}
