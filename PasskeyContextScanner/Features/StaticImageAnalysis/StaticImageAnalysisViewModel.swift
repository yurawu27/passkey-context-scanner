import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class StaticImageAnalysisViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published private(set) var result: ScanResult?
    @Published private(set) var scanObservation: ScanObservation?
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    @Published var userIntent = UserIntent.skipped
    @Published private(set) var clarificationQuestion: AdaptiveIntentQuestion?
    @Published private(set) var clarificationHistory: [ClarificationEvent] = []
    @Published private(set) var preliminaryClassification: RiskClassification?
    @Published var evaluationLabels = EvaluationLabels.empty {
        didSet {
            if oldValue != evaluationLabels { scenarioMetadataConfirmed = false }
            cacheCompletedSession()
        }
    }
    @Published private(set) var scenarioMetadataConfirmed = false
    @Published private(set) var selectedControlledScenarioID = ""
    @Published private(set) var selectedControlledVariant = ""
    @Published private(set) var selectedFixtureID = ""
    @Published private(set) var exportURL: URL?
    @Published private(set) var normalizedExportURLs: [URL] = []
    @Published private(set) var exportMessage: String?
    @Published private(set) var evaluationRecords: [EvaluationRecord] = []
    @Published private(set) var ablationComparisons: [AblationComparison] = []
    @Published var clarificationPolicy: ClarificationPolicy = .participant
    let applicationMode: ApplicationMode
    let participantIntroductionCompleted: Bool

    private let imageAnalysisService: ImageAnalysisServing
    private let classifier: ContextClassifier
    private let evaluationLogger: EvaluationLogger
    private let evaluationRecordStore: EvaluationRecordStore
    private var activeAnalysisID: UUID?
    private let intentPlanner = AdaptiveIntentPlanner()
    private let scenarioClarificationScript = ScenarioClarificationScript()
    private var answeredQuestions: Set<AdaptiveIntentQuestionKind> = []
    private var recordedResultIDs: Set<UUID> = []
    private var preliminaryResult: ScanResult?
    private var currentClarificationAnswerSource: ClarificationAnswerSource = .none
    private var analysisFixtureID: String?

    init(
        imageAnalysisService: ImageAnalysisServing = ImageAnalysisService(),
        classifier: ContextClassifier = ContextClassifier(),
        evaluationLogger: EvaluationLogger = EvaluationLogger(),
        evaluationRecordStore: EvaluationRecordStore = EvaluationRecordStore(),
        clarificationPolicy: ClarificationPolicy = .participant,
        applicationMode: ApplicationMode = .participant,
        participantIntroductionCompleted: Bool = false
    ) {
        self.imageAnalysisService = imageAnalysisService
        self.classifier = classifier
        self.evaluationLogger = evaluationLogger
        self.evaluationRecordStore = evaluationRecordStore
        self.clarificationPolicy = clarificationPolicy
        self.applicationMode = applicationMode
        self.participantIntroductionCompleted = participantIntroductionCompleted
        do {
            evaluationRecords = try evaluationRecordStore.load()
        } catch {
            exportMessage = "Saved evaluation records could not be loaded. No stored data was changed."
        }
        restoreCachedSession()
    }

    var clarificationProgressText: String {
        clarificationPolicy == .participant
            ? "One quick check"
            : "Research check \(min(answeredQuestions.count + 1, clarificationPolicy.maximumQuestionCount)) of up to \(clarificationPolicy.maximumQuestionCount)"
    }

    var evaluationMetricsSummary: EvaluationMetricsSummary {
        EvaluationMetricsCalculator().calculate(records: evaluationRecords)
    }

    var visualOnlyEvaluationMetricsSummary: EvaluationMetricsSummary {
        EvaluationMetricsCalculator().calculate(
            records: evaluationRecords,
            targetKind: .visualOnly,
            predictionStage: .preliminary
        )
    }

    var attackCoverageSummary: EvaluationAttackCoverageSummary {
        EvaluationAttackCoverageCalculator().calculate(records: evaluationRecords)
    }

    var evaluationCoverageSummary: EvaluationCoverageSummary {
        EvaluationCoverageCalculator().calculateFixtures(records: evaluationRecords)
    }

    var failureAttemptCount: Int {
        evaluationRecords.filter {
            ($0.failureStage ?? EvaluationFailureStage.none) != EvaluationFailureStage.none
        }.count
    }

    var selectedControlledScenario: ControlledEvaluationScenario? {
        ControlledEvaluationScenarioCatalog.scenarios.first {
            $0.id == selectedControlledScenarioID
        }
    }

    var selectedFixture: EvaluationFixture? {
        ControlledEvaluationFixtureCatalog.fixture(id: selectedFixtureID) ??
            CompetingContextEvaluationFixtureCatalog.fixture(id: selectedFixtureID)
    }

    var hasPredefinedScenarioMetadata: Bool {
        selectedFixture != nil || selectedControlledScenario != nil
    }

    var shouldShowScenarioConfirmation: Bool {
        evaluationLabels.datasetSplit != .notAssigned && hasPredefinedScenarioMetadata
    }

    var selectedFixtureCatalogVersion: String {
        CompetingContextEvaluationFixtureCatalog.fixture(id: selectedFixtureID) == nil
            ? ControlledEvaluationFixtureCatalog.version
            : CompetingContextEvaluationFixtureCatalog.version
    }

    func selectFixture(id: String) {
        let fixtureChanged = id != selectedFixtureID
        selectedFixtureID = id
        guard let fixture = selectedFixture else {
            selectControlledScenario(id: "")
            if fixtureChanged, refreshAnalysisForFixtureChange() {
                exportMessage = "Fixture metadata was cleared. The existing visual analysis was retained."
            }
            return
        }
        selectedControlledScenarioID = fixture.baseScenarioID
        selectedControlledVariant = fixture.id
        evaluationLabels.testId = fixture.id
        evaluationLabels.scenarioGroundTruth = fixture.scenarioGroundTruth
        evaluationLabels.contextType = CompetingContextEvaluationFixtureCatalog.fixture(id: fixture.id) == nil
            ? contextType(for: fixture.securityType)
            : .contextAssociation
        evaluationLabels.detectabilityBoundary = boundary(for: fixture)
        evaluationLabels.factualGroundTruth = fixture.scenarioFactualGroundTruth
        evaluationLabels.expectedServiceProfileID = ""
        evaluationLabels.presentedServiceProfileID = ""
        evaluationLabels.displayOS = fixture.displayOS
        evaluationLabels.displayBrowser = fixture.displayBrowser
        evaluationLabels.presentationType = fixture.presentationType
        evaluationLabels.clutterCondition = fixture.associationCondition == .clean ? .clean : .competing
        evaluationLabels.associationCondition = fixture.associationCondition
        selectCaptureConditionPreset(
            ["A04", "A04-f"].contains(fixture.id) ? .partialCrop :
                fixture.id == "A05" ? .farDistance : .baseline
        )
        evaluationLabels.matchedStimulusID = fixture.matchedStimulusID
        evaluationLabels.runNumber = "1"
        evaluationLabels.captureAttempt = "1"
        evaluationLabels.failureAttribution = .none
        prepareUniqueTestID()
        if fixtureChanged, refreshAnalysisForFixtureChange() {
            exportMessage = "Fixture metadata was updated. The existing visual analysis was retained."
        }
    }

    @discardableResult
    private func refreshAnalysisForFixtureChange() -> Bool {
        let hadAnalysis = result != nil || scanObservation != nil || isProcessing
        activeAnalysisID = nil
        isProcessing = false
        let retainedObservation = scanObservation
        clarificationQuestion = nil
        clarificationHistory = []
        answeredQuestions = []
        ablationComparisons = []
        currentClarificationAnswerSource = .none
        userIntent = .skipped
        exportURL = nil
        normalizedExportURLs = []
        errorMessage = nil

        guard let retainedObservation else {
            result = nil
            scanObservation = nil
            preliminaryClassification = nil
            preliminaryResult = nil
            analysisFixtureID = nil
            StaticAnalysisSessionCache.shared.snapshot = nil
            return hadAnalysis
        }

        let refreshedResult = classifier.classify(
            observation: retainedObservation,
            intent: userIntent,
            policy: clarificationPolicy
        )
        scanObservation = retainedObservation
        preliminaryClassification = refreshedResult.classification
        preliminaryResult = refreshedResult
        result = refreshedResult
        analysisFixtureID = selectedFixtureID
        cacheCompletedSession()
        return hadAnalysis
    }

    func selectCaptureConditionPreset(_ preset: CaptureConditionPreset) {
        evaluationLabels.captureConditionPreset = preset
        guard preset != .manual else { return }

        evaluationLabels.lightingCondition = .normal
        evaluationLabels.angleCondition = .straight
        evaluationLabels.distanceCondition = .medium
        evaluationLabels.blurCondition = .none
        evaluationLabels.cropCondition = .none

        switch preset {
        case .manual, .baseline:
            break
        case .lowLight:
            evaluationLabels.lightingCondition = .lowLight
        case .glare:
            evaluationLabels.lightingCondition = .glare
        case .slightAngle:
            evaluationLabels.angleCondition = .slightAngle
        case .steepAngle:
            evaluationLabels.angleCondition = .steepAngle
        case .farDistance:
            evaluationLabels.distanceCondition = .far
        case .mildBlur:
            evaluationLabels.blurCondition = .mild
        case .severeBlur:
            evaluationLabels.blurCondition = .severe
        case .partialCrop:
            evaluationLabels.cropCondition = .partial
        case .severeCrop:
            evaluationLabels.cropCondition = .severe
        }
        cacheCompletedSession()
    }

    var captureConditionSummary: String {
        "\(evaluationLabels.lightingCondition.rawValue) light · " +
            "\(evaluationLabels.angleCondition.rawValue) · " +
            "\(evaluationLabels.distanceCondition.rawValue) distance · " +
            "blur \(evaluationLabels.blurCondition.rawValue) · " +
            "crop \(evaluationLabels.cropCondition.rawValue)"
    }

    private func contextType(for securityType: ScenarioSecurityType) -> ContextType {
        switch securityType {
        case .benign: .matching
        case .misleading: .mismatching
        case .insufficient: .ambiguous
        case .notAssigned: .unknown
        }
    }

    private func boundary(for fixture: EvaluationFixture) -> DetectabilityBoundary {
        if fixture.visualDetectability == .visuallyIndistinguishable {
            return .visuallyIndistinguishableSessionAttack
        }
        if fixture.securityType == .insufficient ||
            fixture.visualDetectability == .insufficientEvidence {
            return .insufficientVisualEvidence
        }
        if fixture.detectableSignals.contains(.persuasion) { return .visiblePersuasion }
        return fixture.securityType == .misleading
            ? .visibleContradiction
            : .visibleConsistentEvidence
    }

    var evaluationValidationIssues: [EvaluationValidationIssue] {
        EvaluationRecordValidator().validate(
            labels: evaluationLabels,
            selectedScenarioID: selectedControlledScenarioID,
            selectedScenarioVariant: selectedControlledVariant,
            existingTestIDs: Set(evaluationRecords.compactMap {
                ($0.failureStage ?? EvaluationFailureStage.none) == EvaluationFailureStage.none
                    ? $0.testId
                    : nil
            }),
            clarificationHistory: clarificationHistory,
            clarificationAnswerSource: currentClarificationAnswerSource,
            intent: userIntent,
            analysisCompleted: result != nil,
            scenarioMetadataConfirmed: scenarioMetadataConfirmed
        )
    }

    var canAddCurrentEvaluationRecord: Bool {
        result != nil && !evaluationValidationIssues.contains { $0.severity == .error }
    }

    var evaluationScenarioProvenance: EvaluationScenarioProvenance {
        if let fixture = selectedFixture {
            return EvaluationScenarioProvenance(
                catalogVersion: selectedFixtureCatalogVersion,
                baseScenarioID: fixture.baseScenarioID,
                variant: fixture.id
            )
        }
        guard selectedControlledScenario != nil else { return .manual }
        return EvaluationScenarioProvenance(
            catalogVersion: ControlledEvaluationScenarioCatalog.version,
            baseScenarioID: selectedControlledScenarioID,
            variant: selectedControlledVariant
        )
    }

    func selectControlledScenario(id: String) {
        selectedControlledScenarioID = id
        selectedControlledVariant = ""
        guard let scenario = selectedControlledScenario else { return }
        evaluationLabels.testId = scenario.id
        evaluationLabels.scenarioGroundTruth = scenario.groundTruth
        evaluationLabels.contextType = scenario.contextType
        evaluationLabels.detectabilityBoundary = scenario.detectabilityBoundary
        evaluationLabels.factualGroundTruth = scenario.factualGroundTruth
        evaluationLabels.expectedServiceProfileID = ""
        evaluationLabels.presentedServiceProfileID = ""
        evaluationLabels.matchedStimulusID = ""
        evaluationLabels.associationCondition = .notAssigned
        cacheCompletedSession()
    }

    func selectExpectedServiceProfile(_ id: String) {
        guard let profile = ControlledEvaluationServiceCatalog.profile(id: id) else {
            evaluationLabels.expectedServiceProfileID = ""
            evaluationLabels.factualGroundTruth.service = ""
            return
        }
        evaluationLabels.expectedServiceProfileID = profile.id
        evaluationLabels.factualGroundTruth.service = profile.canonicalServiceName
        if selectedControlledScenario?.family == .identityConflict {
            if evaluationLabels.presentedServiceProfileID == profile.id {
                evaluationLabels.presentedServiceProfileID = ""
                evaluationLabels.factualGroundTruth.presentedService = ""
            }
        } else {
            evaluationLabels.presentedServiceProfileID = profile.id
            evaluationLabels.factualGroundTruth.presentedService = profile.canonicalServiceName
        }
        if !selectedControlledVariant.isEmpty { prepareUniqueTestID() }
        prepareMatchedStimulusIDIfNeeded()
        cacheCompletedSession()
    }

    func selectPresentedServiceProfile(_ id: String) {
        guard let profile = ControlledEvaluationServiceCatalog.profile(id: id) else {
            evaluationLabels.presentedServiceProfileID = ""
            evaluationLabels.factualGroundTruth.presentedService = ""
            return
        }
        evaluationLabels.presentedServiceProfileID = profile.id
        evaluationLabels.factualGroundTruth.presentedService = profile.canonicalServiceName
        cacheCompletedSession()
    }

    func selectControlledVariant(_ variant: String) {
        guard selectedControlledScenario?.requiredVariants.contains(variant) == true else {
            selectedControlledVariant = ""
            return
        }
        selectedControlledVariant = variant
        applyVariantFactualTruth(variant)
        let defaults = ControlledEvaluationScenarioCatalog.conditionDefaults(
            scenarioID: selectedControlledScenarioID,
            variant: variant
        )
        evaluationLabels.lightingCondition = defaults.lighting
        evaluationLabels.angleCondition = defaults.angle
        evaluationLabels.distanceCondition = defaults.distance
        evaluationLabels.blurCondition = defaults.blur
        evaluationLabels.cropCondition = defaults.crop
        evaluationLabels.presentationType = defaults.presentation
        evaluationLabels.clutterCondition = defaults.clutter
        evaluationLabels.associationCondition = defaults.association
        if defaults.displayOS != .unknown {
            evaluationLabels.displayOS = defaults.displayOS
        }
        if defaults.displayBrowser != .unknown {
            evaluationLabels.displayBrowser = defaults.displayBrowser
        }
        prepareUniqueTestID()
        prepareMatchedStimulusIDIfNeeded()
        cacheCompletedSession()
    }

    func confirmScenarioMetadata() {
        guard applicationMode == .researcher,
              evaluationLabels.datasetSplit != .notAssigned,
              hasPredefinedScenarioMetadata else { return }
        scenarioMetadataConfirmed = true
        cacheCompletedSession()
    }

    var finalScenarioSummary: [String] {
        let truth = evaluationLabels.factualGroundTruth
        return [
            "\(truth.service.isEmpty ? "Unassigned service" : truth.service) · \(truth.securityType.rawValue) · \(truth.purpose?.rawValue ?? "UNASSIGNED") · initiated \(truth.initiated.rawValue)",
            "Receiving owner \(truth.receivingClientOwner.rawValue) · session \((truth.receivingClientContext ?? .unknown).rawValue)",
            "\(evaluationLabels.displayOS.rawValue) · \(evaluationLabels.displayBrowser.rawValue) · \(evaluationLabels.presentationType.rawValue) · \(evaluationLabels.clutterCondition.rawValue)",
            "\(evaluationLabels.lightingCondition.rawValue) light · \(evaluationLabels.angleCondition.rawValue) · \(evaluationLabels.distanceCondition.rawValue) distance · blur \(evaluationLabels.blurCondition.rawValue) · crop \(evaluationLabels.cropCondition.rawValue)",
            "Matched stimulus \(evaluationLabels.matchedStimulusID.isEmpty ? "UNASSIGNED" : evaluationLabels.matchedStimulusID) · \(evaluationLabels.associationCondition.rawValue)"
        ]
    }

    private func prepareMatchedStimulusIDIfNeeded() {
        let isGeneratedPlaceholder = evaluationLabels.matchedStimulusID ==
            "\(selectedControlledScenarioID)-SERVICE-PAIR"
        guard evaluationLabels.matchedStimulusID.isEmpty || isGeneratedPlaceholder,
              !selectedControlledScenarioID.isEmpty else { return }
        let service = evaluationLabels.expectedServiceProfileID.isEmpty
            ? "SERVICE"
            : evaluationLabels.expectedServiceProfileID
        evaluationLabels.matchedStimulusID = "\(selectedControlledScenarioID)-\(service)-PAIR"
    }

    private func applyVariantFactualTruth(_ variant: String) {
        guard let scenario = selectedControlledScenario else { return }
        var truth = scenario.factualGroundTruth
        truth.service = evaluationLabels.factualGroundTruth.service
        truth.presentedService = evaluationLabels.factualGroundTruth.presentedService
        switch variant {
        case "payment": truth.presentedPurpose = .payment
        case "document": truth.presentedPurpose = .openDocument
        case "wifi": truth.presentedPurpose = .connectWiFi
        case "account_recovery": truth.presentedPurpose = .recoverAccount
        default: break
        }
        evaluationLabels.factualGroundTruth = truth
    }

    func analyseSelectedImage() async {
        guard let selectedItem else {
            return
        }

        let analysisID = UUID()
        activeAnalysisID = analysisID
        analysisFixtureID = selectedFixtureID
        isProcessing = true
        errorMessage = nil
        exportURL = nil
        normalizedExportURLs = []
        exportMessage = nil
        evaluationLabels.failureAttribution = .none
        result = nil
        scanObservation = nil
        clarificationQuestion = nil
        answeredQuestions = []
        clarificationHistory = []
        currentClarificationAnswerSource = .none
        preliminaryClassification = nil
        preliminaryResult = nil
        ablationComparisons = []
        userIntent = .skipped
        defer {
            if activeAnalysisID == analysisID {
                isProcessing = false
            }
        }

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw StaticImageAnalysisError.imageLoadFailed
            }
            try Task.checkCancellation()

            let observation = await imageAnalysisService.analyse(image)
            try Task.checkCancellation()
            guard activeAnalysisID == analysisID else {
                return
            }
            scanObservation = observation

            let preliminary = classifier.classify(
                observation: observation,
                intent: userIntent,
                policy: clarificationPolicy
            )
            preliminaryClassification = preliminary.classification
            preliminaryResult = preliminary
            advanceAfterAnalysis(observation: observation, preliminary: preliminary)
        } catch {
            guard activeAnalysisID == analysisID, !Task.isCancelled else {
                return
            }
            errorMessage = "The selected image could not be analysed."
            recordFailureAttempt(
                stage: .imageLoading,
                category: error is StaticImageAnalysisError ? .invalidImage : .processingFailed
            )
        }
    }

    private func recordFailureAttempt(
        stage: EvaluationFailureStage,
        category: EvaluationErrorCategory
    ) {
        guard applicationMode == .researcher else { return }
        let record = evaluationLogger.makeFailureRecord(
            labels: evaluationLabels,
            scenarioProvenance: evaluationScenarioProvenance,
            applicationMode: applicationMode,
            participantIntroductionCompleted: participantIntroductionCompleted,
            failureStage: stage,
            errorCategory: category
        )
        evaluationRecords.append(record)
        do {
            try evaluationRecordStore.save(evaluationRecords)
            exportMessage = "The failed analysis attempt was saved without image or OCR content."
        } catch {
            evaluationRecords.removeLast()
            exportMessage = "The analysis failed, and its evaluation attempt could not be saved."
        }
    }

    func answerConfirmation(_ answer: InitiationStatus) {
        guard let clarificationQuestion, let observation = scanObservation else { return }
        let effectiveAnswer: InitiationStatus
        if let truth = scenarioControlledTruth {
            effectiveAnswer = scenarioClarificationScript.confirmationAnswer(
                for: clarificationQuestion,
                truth: truth
            )
        } else {
            effectiveAnswer = answer
        }
        clarificationHistory.append(ClarificationEvent(
            questionKind: clarificationQuestion.kind,
            prompt: clarificationQuestion.title,
            answer: effectiveAnswer.rawValue
        ))
        currentClarificationAnswerSource = scenarioControlledTruth == nil
            ? .manual
            : .scenarioControlled
        answeredQuestions.insert(clarificationQuestion.kind)
        switch clarificationQuestion {
        case .confirmService(let service):
            userIntent.visibleServiceMatchesExpectation = effectiveAnswer
            if let truth = scenarioControlledTruth {
                userIntent.expectedService = truth.service
            } else if effectiveAnswer == .yes {
                userIntent.expectedService = service
            }
        case .confirmPurpose(let purpose):
            userIntent.visiblePurposeMatchesExpectation = effectiveAnswer
            if let truth = scenarioControlledTruth {
                userIntent.expectedPurpose = truth.purpose
            } else if effectiveAnswer == .yes {
                userIntent.expectedPurpose = purpose
            }
        case .exactInitiation:
            userIntent.startedOnReceivingClient = effectiveAnswer
            userIntent.initiationStatus = effectiveAnswer
        case .receivingComputer:
            return
        }
        reclassifyAndAdvance(observation)
    }

    func answerReceivingComputer(_ relationship: ReceivingClientRelationship) {
        guard let observation = scanObservation else { return }
        let effectiveRelationship = scenarioControlledTruth.map {
            scenarioClarificationScript.receivingClientRelationship(for: $0)
        } ?? relationship
        clarificationHistory.append(ClarificationEvent(
            questionKind: .receivingComputer,
            prompt: clarificationQuestion?.title ?? "Which computer is showing the QR code?",
            answer: effectiveRelationship.rawValue
        ))
        currentClarificationAnswerSource = scenarioControlledTruth == nil
            ? .manual
            : .scenarioControlled
        answeredQuestions.insert(.receivingComputer)
        userIntent.receivingClientRelationship = effectiveRelationship
        switch effectiveRelationship {
        case .ownDevice:
            userIntent.displaySource = .ownDevice
            userIntent.receivingClientTrust = .yes
        case .trustedSharedComputer:
            userIntent.displaySource = .sharedComputer
            userIntent.receivingClientTrust = .yes
        case .publicOrKiosk:
            userIntent.displaySource = .kiosk
            userIntent.receivingClientTrust = .no
        case .someoneElsesDevice:
            userIntent.displaySource = .sharedComputer
            userIntent.receivingClientTrust = .no
        case .unknown:
            userIntent.receivingClientTrust = .unsure
        }
        reclassifyAndAdvance(observation)
    }

    func finishWithUnknowns() {
        guard let observation = scanObservation else { return }
        clarificationQuestion = nil
        result = classifier.classify(
            observation: observation,
            intent: userIntent,
            policy: clarificationPolicy
        )
        cacheCompletedSession()
    }

    private func advanceAfterAnalysis(observation: ScanObservation, preliminary: ScanResult) {
        guard answeredQuestions.count < clarificationPolicy.maximumQuestionCount else {
            clarificationQuestion = nil
            result = preliminary
            cacheCompletedSession()
            return
        }
        clarificationQuestion = clarificationPolicy == .participant
            ? intentPlanner.nextHighInformationQuestion(
                observation: observation,
                preliminaryResult: preliminary,
                intent: userIntent,
                answeredQuestions: answeredQuestions,
                classifier: classifier,
                classificationPolicy: clarificationPolicy
            )
            : intentPlanner.nextQuestion(
                observation: observation,
                preliminaryResult: preliminary,
                intent: userIntent,
                answeredQuestions: answeredQuestions
            )
        result = clarificationQuestion == nil ? preliminary : nil
        if clarificationQuestion != nil, scenarioControlledTruth != nil {
            applyScenarioControlledAnswer()
        }
        cacheCompletedSession()
    }

    private var scenarioControlledTruth: ScenarioFactualGroundTruth? {
        guard evaluationLabels.datasetSplit == .finalEvaluation,
              selectedFixture != nil || selectedControlledScenario != nil,
              evaluationLabels.factualGroundTruth.securityType != .notAssigned else {
            return nil
        }
        return evaluationLabels.factualGroundTruth
    }

    private func applyScenarioControlledAnswer() {
        guard let question = clarificationQuestion, scenarioControlledTruth != nil else { return }
        switch question {
        case .receivingComputer:
            answerReceivingComputer(.unknown)
        default:
            answerConfirmation(.unsure)
        }
    }

    private func reclassifyAndAdvance(_ observation: ScanObservation) {
        let updated = classifier.classify(
            observation: observation,
            intent: userIntent,
            policy: clarificationPolicy
        )
        advanceAfterAnalysis(observation: observation, preliminary: updated)
    }

    func addCurrentEvaluationRecord() {
        guard let result else { return }
        guard analysisFixtureID == selectedFixtureID else {
            exportMessage = "The selected fixture has changed. Analyse the image again before adding this record."
            return
        }
        let blockingIssues = evaluationValidationIssues.filter { $0.severity == .error }
        guard blockingIssues.isEmpty else {
            exportMessage = blockingIssues.map(\.message).joined(separator: " ")
            return
        }
        guard recordedResultIDs.insert(result.id).inserted else {
            exportMessage = "This scan is already in the dataset."
            return
        }

        let record = evaluationLogger.makeRecord(
            from: result,
            labels: evaluationLabels,
            scenarioProvenance: evaluationScenarioProvenance,
            applicationMode: applicationMode,
            participantIntroductionCompleted: participantIntroductionCompleted,
            scenarioMetadataConfirmed: scenarioMetadataConfirmed,
            qrProcessingStatus: scanObservation?.qrProcessingStatus,
            ocrProcessingStatus: scanObservation?.ocrProcessingStatus,
            ocrObservationCount: scanObservation?.ocrObservations.count,
            intent: userIntent,
            preliminaryResult: preliminaryResult,
            preliminaryClassification: preliminaryClassification,
            clarificationHistory: clarificationHistory,
            clarificationAnswerSource: currentClarificationAnswerSource,
            clarificationPolicy: clarificationPolicy,
            ablationComparisons: ablationComparisons,
            qrDetected: scanObservation?.qrDetected == true ? .detected : .notDetected
        )
        evaluationRecords.append(record)
        do {
            try evaluationRecordStore.save(evaluationRecords)
        } catch {
            evaluationRecords.removeLast()
            recordedResultIDs.remove(result.id)
            exportMessage = "The record could not be saved locally, so it was not added."
            return
        }
        exportURL = nil
        normalizedExportURLs = []
        exportMessage = "Record added. Dataset contains \(evaluationRecords.count) scan\(evaluationRecords.count == 1 ? "" : "s")."
        prepareUniqueTestID()
        cacheCompletedSession()
    }

    func runAblationAnalysis() {
        guard applicationMode == .researcher, let observation = scanObservation else {
            return
        }
        ablationComparisons = ContextAblationAnalyzer().analyze(
            observation: observation,
            intent: userIntent,
            policy: clarificationPolicy,
            classifier: classifier
        )
        cacheCompletedSession()
    }

    func deleteAllEvaluationRecords() {
        do {
            try evaluationRecordStore.clear()
            evaluationRecords = []
            recordedResultIDs = []
            exportURL = nil
            normalizedExportURLs = []
            exportMessage = "All locally saved evaluation records were deleted."
        } catch {
            exportMessage = "The locally saved dataset could not be deleted."
        }
    }

    func exportEvaluationDataset() {
        do {
            normalizedExportURLs = try evaluationLogger.exportNormalizedCSVs(
                records: evaluationRecords
            )
            exportURL = nil
            exportMessage = "Four linked CSV tables with \(evaluationRecords.count) scan\(evaluationRecords.count == 1 ? "" : "s") are ready to share."
        } catch {
            exportURL = nil
            normalizedExportURLs = []
            exportMessage = evaluationRecords.isEmpty
                ? "Add at least one evaluation record before exporting."
                : "The evaluation CSV could not be created."
        }
    }

    private func prepareUniqueTestID() {
        guard !selectedControlledScenarioID.isEmpty,
              !selectedControlledVariant.isEmpty else { return }
        let matchingCount = evaluationRecords.filter {
            $0.baseScenarioID == selectedControlledScenarioID &&
                $0.scenarioVariant == selectedControlledVariant &&
                $0.scenarioCatalogVersion == evaluationScenarioProvenance.catalogVersion
        }.count
        var run = matchingCount + 1
        var candidate = generatedTestID(run: run, capture: 1)
        let existing = Set(evaluationRecords.map { $0.testId.uppercased() })
        while existing.contains(candidate.uppercased()) {
            run += 1
            candidate = generatedTestID(run: run, capture: 1)
        }
        evaluationLabels.runNumber = String(run)
        evaluationLabels.captureAttempt = "1"
        evaluationLabels.testId = candidate
    }

    private func generatedTestID(run: Int, capture: Int) -> String {
        if !selectedFixtureID.isEmpty {
            return "\(selectedFixtureID)-R\(run)-C\(capture)"
        }
        let variant = selectedControlledVariant
            .uppercased()
            .replacingOccurrences(of: "_", with: "-")
        let service = evaluationLabels.expectedServiceProfileID.isEmpty
            ? "UNASSIGNED"
            : evaluationLabels.expectedServiceProfileID
        return "\(selectedControlledScenarioID)-\(service)-\(variant)-R\(run)-C\(capture)"
    }

    private func cacheCompletedSession() {
        guard let result, let scanObservation else { return }
        StaticAnalysisSessionCache.shared.snapshot = StaticAnalysisSessionSnapshot(
            result: result,
            observation: scanObservation,
            userIntent: userIntent,
            preliminaryResult: preliminaryResult,
            preliminaryClassification: preliminaryClassification,
            clarificationHistory: clarificationHistory,
            clarificationAnswerSource: currentClarificationAnswerSource,
            scenarioMetadataConfirmed: scenarioMetadataConfirmed,
            evaluationLabels: evaluationLabels,
            selectedControlledScenarioID: selectedControlledScenarioID,
            selectedControlledVariant: selectedControlledVariant,
            selectedFixtureID: selectedFixtureID,
            analysisFixtureID: analysisFixtureID,
            ablationComparisons: ablationComparisons,
            applicationMode: applicationMode
        )
    }

#if DEBUG
    /// Seeds a completed visual analysis for state-transition regression tests.
    /// Production analysis continues to enter through `analyseSelectedImage()`.
    func seedCompletedAnalysisForTesting(_ observation: ScanObservation) {
        scanObservation = observation
        let classified = classifier.classify(
            observation: observation,
            intent: userIntent,
            policy: clarificationPolicy
        )
        preliminaryResult = classified
        preliminaryClassification = classified.classification
        result = classified
        analysisFixtureID = selectedFixtureID
        cacheCompletedSession()
    }
#endif

    private func restoreCachedSession() {
        guard let snapshot = StaticAnalysisSessionCache.shared.snapshot,
              snapshot.applicationMode == applicationMode else { return }
        result = snapshot.result
        scanObservation = snapshot.observation
        userIntent = snapshot.userIntent
        preliminaryResult = snapshot.preliminaryResult
        preliminaryClassification = snapshot.preliminaryClassification
        clarificationHistory = snapshot.clarificationHistory
        currentClarificationAnswerSource = snapshot.clarificationAnswerSource
        answeredQuestions = Set(snapshot.clarificationHistory.map(\.questionKind))
        selectedControlledScenarioID = snapshot.selectedControlledScenarioID
        selectedControlledVariant = snapshot.selectedControlledVariant
        selectedFixtureID = snapshot.selectedFixtureID
        analysisFixtureID = snapshot.analysisFixtureID
        ablationComparisons = snapshot.ablationComparisons
        evaluationLabels = snapshot.evaluationLabels
        scenarioMetadataConfirmed = snapshot.scenarioMetadataConfirmed
    }
}

private struct StaticAnalysisSessionSnapshot {
    let result: ScanResult
    let observation: ScanObservation
    let userIntent: UserIntent
    let preliminaryResult: ScanResult?
    let preliminaryClassification: RiskClassification?
    let clarificationHistory: [ClarificationEvent]
    let clarificationAnswerSource: ClarificationAnswerSource
    let scenarioMetadataConfirmed: Bool
    let evaluationLabels: EvaluationLabels
    let selectedControlledScenarioID: String
    let selectedControlledVariant: String
    let selectedFixtureID: String
    let analysisFixtureID: String?
    let ablationComparisons: [AblationComparison]
    let applicationMode: ApplicationMode
}

@MainActor
private final class StaticAnalysisSessionCache {
    static let shared = StaticAnalysisSessionCache()
    var snapshot: StaticAnalysisSessionSnapshot?
}

private enum StaticImageAnalysisError: Error {
    case imageLoadFailed
}
