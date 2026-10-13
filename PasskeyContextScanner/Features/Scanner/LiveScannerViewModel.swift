import Foundation
import UIKit

@MainActor
final class LiveScannerViewModel: ObservableObject {
    @Published var userIntent = UserIntent.skipped
    @Published private(set) var result: ScanResult?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var clarificationQuestion: AdaptiveIntentQuestion?
    @Published private(set) var clarificationHistory: [ClarificationEvent] = []
    @Published private(set) var preliminaryClassification: RiskClassification?
    @Published var evaluationLabels = EvaluationLabels.empty {
        didSet {
            if oldValue != evaluationLabels { scenarioMetadataConfirmed = false }
        }
    }
    @Published private(set) var scenarioMetadataConfirmed = false
    @Published private(set) var selectedFixtureID = ""
    @Published private(set) var evaluationRecords: [EvaluationRecord] = []
    @Published private(set) var normalizedExportURLs: [URL] = []
    @Published private(set) var exportMessage: String?
    let clarificationPolicy: ClarificationPolicy
    let applicationMode: ApplicationMode

    let cameraService: CameraCaptureServing

    private let imageAnalysisService: ImageAnalysisServing
    private let classifier: ContextClassifier
    private let evaluationLogger: EvaluationLogger
    private let evaluationRecordStore: EvaluationRecordStore
    private let intentPlanner = AdaptiveIntentPlanner()
    private let scenarioClarificationScript = ScenarioClarificationScript()
    private var scanObservation: ScanObservation?
    private var preliminaryResult: ScanResult?
    private var currentClarificationAnswerSource: ClarificationAnswerSource = .none
    private var answeredQuestions: Set<AdaptiveIntentQuestionKind> = []
    private var recordedResultIDs: Set<UUID> = []

    init(
        cameraService: CameraCaptureServing? = nil,
        imageAnalysisService: ImageAnalysisServing = ImageAnalysisService(),
        classifier: ContextClassifier = ContextClassifier(),
        clarificationPolicy: ClarificationPolicy = .participant,
        applicationMode: ApplicationMode = .participant,
        evaluationLogger: EvaluationLogger = EvaluationLogger(),
        evaluationRecordStore: EvaluationRecordStore = EvaluationRecordStore()
    ) {
        let resolvedCameraService = cameraService ?? CameraCaptureService()
        self.cameraService = resolvedCameraService
        self.imageAnalysisService = imageAnalysisService
        self.classifier = classifier
        self.clarificationPolicy = clarificationPolicy
        self.applicationMode = applicationMode
        self.evaluationLogger = evaluationLogger
        self.evaluationRecordStore = evaluationRecordStore
        resolvedCameraService.stateChangeHandler = { [weak self] in
            self?.objectWillChange.send()
        }
        if applicationMode == .researcher {
            do {
                evaluationRecords = try evaluationRecordStore.load()
            } catch {
                exportMessage = "Saved evaluation records could not be loaded. No stored data was changed."
            }
        }
    }

    var canCapture: Bool {
        cameraService.sessionState == .running &&
            !cameraService.isCapturingPhoto &&
            !isAnalyzing
    }

    var clarificationProgressText: String {
        clarificationPolicy == .participant
            ? "One quick check"
            : "Research check \(min(answeredQuestions.count + 1, clarificationPolicy.maximumQuestionCount)) of up to \(clarificationPolicy.maximumQuestionCount)"
    }

    func start() async {
        errorMessage = nil
        await cameraService.prepareAndStart()
    }

    func stop() {
        cameraService.stop()
    }

    func captureAndAnalyze() async {
        guard canCapture else { return }

        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            let image = try await cameraService.capturePhoto()
            try Task.checkCancellation()
            cameraService.stop()

            let observation = await imageAnalysisService.analyse(image)
            try Task.checkCancellation()
            scanObservation = observation
            let preliminary = classifier.classify(
                observation: observation,
                intent: userIntent,
                policy: clarificationPolicy
            )
            preliminaryResult = preliminary
            preliminaryClassification = preliminary.classification
            advanceAfterAnalysis(observation: observation, preliminary: preliminary)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ??
                "The captured frame could not be analysed."
        }
    }

    func rescan() async {
        result = nil
        scanObservation = nil
        clarificationQuestion = nil
        answeredQuestions = []
        clarificationHistory = []
        preliminaryClassification = nil
        preliminaryResult = nil
        currentClarificationAnswerSource = .none
        userIntent = .skipped
        errorMessage = nil
        await cameraService.prepareAndStart()
    }

    func clearResult() {
        result = nil
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
            userIntent.expectedService = scenarioControlledTruth?.service ??
                (effectiveAnswer == .yes ? service : nil)
        case .confirmPurpose(let purpose):
            userIntent.visiblePurposeMatchesExpectation = effectiveAnswer
            userIntent.expectedPurpose = scenarioControlledTruth?.purpose ??
                (effectiveAnswer == .yes ? purpose : nil)
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
    }

    private func advanceAfterAnalysis(observation: ScanObservation, preliminary: ScanResult) {
        guard answeredQuestions.count < clarificationPolicy.maximumQuestionCount else {
            clarificationQuestion = nil
            result = preliminary
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
    }

    private func reclassifyAndAdvance(_ observation: ScanObservation) {
        let updated = classifier.classify(
            observation: observation,
            intent: userIntent,
            policy: clarificationPolicy
        )
        advanceAfterAnalysis(observation: observation, preliminary: updated)
    }

    var selectedFixture: EvaluationFixture? {
        ControlledEvaluationFixtureCatalog.fixture(id: selectedFixtureID) ??
            CompetingContextEvaluationFixtureCatalog.fixture(id: selectedFixtureID)
    }

    private var selectedFixtureCatalogVersion: String {
        CompetingContextEvaluationFixtureCatalog.fixture(id: selectedFixtureID) == nil
            ? ControlledEvaluationFixtureCatalog.version
            : CompetingContextEvaluationFixtureCatalog.version
    }

    var evaluationScenarioProvenance: EvaluationScenarioProvenance {
        guard let fixture = selectedFixture else { return .manual }
        return EvaluationScenarioProvenance(
            catalogVersion: selectedFixtureCatalogVersion,
            baseScenarioID: fixture.baseScenarioID,
            variant: fixture.id
        )
    }

    func selectFixture(id: String) {
        selectedFixtureID = id
        guard let fixture = selectedFixture else {
            evaluationLabels = .empty
            exportMessage = "Fixture metadata cleared."
            return
        }
        evaluationLabels.testId = fixture.id
        evaluationLabels.scenarioGroundTruth = fixture.scenarioGroundTruth
        evaluationLabels.contextType = contextType(for: fixture.securityType)
        evaluationLabels.detectabilityBoundary = boundary(for: fixture)
        evaluationLabels.factualGroundTruth = fixture.scenarioFactualGroundTruth
        evaluationLabels.expectedServiceProfileID = ""
        evaluationLabels.presentedServiceProfileID = ""
        evaluationLabels.displayOS = fixture.displayOS
        evaluationLabels.displayBrowser = fixture.displayBrowser
        evaluationLabels.presentationType = fixture.presentationType
        evaluationLabels.clutterCondition = fixture.associationCondition == .clean
            ? .clean
            : .competing
        evaluationLabels.associationCondition = fixture.associationCondition
        evaluationLabels.matchedStimulusID = fixture.matchedStimulusID
        evaluationLabels.runNumber = "1"
        evaluationLabels.captureAttempt = "1"
        evaluationLabels.failureAttribution = .none
        selectCaptureConditionPreset(.baseline)
        prepareUniqueTestID()
        exportMessage = nil
    }

    func selectCaptureConditionPreset(_ preset: CaptureConditionPreset) {
        evaluationLabels.captureConditionPreset = preset
        guard preset != .manual else {
            prepareUniqueTestID()
            return
        }
        evaluationLabels.lightingCondition = .normal
        evaluationLabels.angleCondition = .straight
        evaluationLabels.distanceCondition = .medium
        evaluationLabels.blurCondition = .none
        evaluationLabels.cropCondition = .none
        switch preset {
        case .manual, .baseline: break
        case .lowLight: evaluationLabels.lightingCondition = .lowLight
        case .glare: evaluationLabels.lightingCondition = .glare
        case .slightAngle: evaluationLabels.angleCondition = .slightAngle
        case .steepAngle: evaluationLabels.angleCondition = .steepAngle
        case .farDistance: evaluationLabels.distanceCondition = .far
        case .mildBlur: evaluationLabels.blurCondition = .mild
        case .severeBlur: evaluationLabels.blurCondition = .severe
        case .partialCrop: evaluationLabels.cropCondition = .partial
        case .severeCrop: evaluationLabels.cropCondition = .severe
        }
        prepareUniqueTestID()
    }

    var captureConditionSummary: String {
        "\(evaluationLabels.lightingCondition.rawValue) light · " +
            "\(evaluationLabels.angleCondition.rawValue) · " +
            "\(evaluationLabels.distanceCondition.rawValue) distance · " +
            "blur \(evaluationLabels.blurCondition.rawValue) · " +
            "crop \(evaluationLabels.cropCondition.rawValue)"
    }

    func confirmScenarioMetadata() {
        guard applicationMode == .researcher,
              evaluationLabels.datasetSplit != .notAssigned,
              selectedFixture != nil else { return }
        scenarioMetadataConfirmed = true
    }

    var evaluationValidationIssues: [EvaluationValidationIssue] {
        EvaluationRecordValidator().validate(
            labels: evaluationLabels,
            selectedScenarioID: selectedFixture?.baseScenarioID ?? "",
            selectedScenarioVariant: selectedFixtureID,
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

    func addCurrentEvaluationRecord() {
        guard let result, let observation = scanObservation else { return }
        let blocking = evaluationValidationIssues.filter { $0.severity == .error }
        guard blocking.isEmpty else {
            exportMessage = blocking.map(\.message).joined(separator: " ")
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
            analysisMode: .liveCamera,
            applicationMode: applicationMode,
            scenarioMetadataConfirmed: scenarioMetadataConfirmed,
            failureStage: observation.qrDetected ? .none : .qrDetection,
            errorCategory: .none,
            qrProcessingStatus: observation.qrProcessingStatus,
            ocrProcessingStatus: observation.ocrProcessingStatus,
            ocrObservationCount: observation.ocrObservations.count,
            intent: userIntent,
            preliminaryResult: preliminaryResult,
            preliminaryClassification: preliminaryClassification,
            clarificationHistory: clarificationHistory,
            clarificationAnswerSource: currentClarificationAnswerSource,
            clarificationPolicy: clarificationPolicy,
            qrDetected: observation.qrDetected ? .detected : .notDetected
        )
        appendAndPersist(record, resultID: result.id)
    }

    func exportEvaluationDataset() {
        do {
            normalizedExportURLs = try evaluationLogger.exportNormalizedCSVs(
                records: evaluationRecords
            )
            exportMessage = "Four linked CSV tables with \(evaluationRecords.count) scan\(evaluationRecords.count == 1 ? "" : "s") are ready to share."
        } catch {
            normalizedExportURLs = []
            exportMessage = evaluationRecords.isEmpty
                ? "Add at least one evaluation record before exporting."
                : "The evaluation CSV could not be created."
        }
    }

    func deleteAllEvaluationRecords() {
        do {
            try evaluationRecordStore.clear()
            evaluationRecords = []
            recordedResultIDs = []
            normalizedExportURLs = []
            exportMessage = "All locally saved evaluation records were deleted."
        } catch {
            exportMessage = "The locally saved dataset could not be deleted."
        }
    }

    private var scenarioControlledTruth: ScenarioFactualGroundTruth? {
        guard evaluationLabels.datasetSplit == .finalEvaluation,
              selectedFixture != nil,
              evaluationLabels.factualGroundTruth.securityType != .notAssigned else {
            return nil
        }
        return evaluationLabels.factualGroundTruth
    }

    private func applyScenarioControlledAnswer() {
        guard let question = clarificationQuestion else { return }
        switch question {
        case .receivingComputer: answerReceivingComputer(.unknown)
        default: answerConfirmation(.unsure)
        }
    }

    private func appendAndPersist(_ record: EvaluationRecord, resultID: UUID? = nil) {
        evaluationRecords.append(record)
        do {
            try evaluationRecordStore.save(evaluationRecords)
        } catch {
            evaluationRecords.removeLast()
            if let resultID { recordedResultIDs.remove(resultID) }
            exportMessage = "The record could not be saved locally, so it was not added."
            return
        }
        normalizedExportURLs = []
        exportMessage = "Record added. Dataset contains \(evaluationRecords.count) scan\(evaluationRecords.count == 1 ? "" : "s")."
        prepareUniqueTestID()
    }

    private func prepareUniqueTestID() {
        guard let fixture = selectedFixture else { return }
        let matchingCount = evaluationRecords.filter {
            $0.scenarioVariant == fixture.id &&
                $0.captureConditionPreset == evaluationLabels.captureConditionPreset
        }.count
        var run = matchingCount + 1
        let existing = Set(evaluationRecords.map { $0.testId.uppercased() })
        var candidate = generatedTestID(fixtureID: fixture.id, run: run)
        while existing.contains(candidate.uppercased()) {
            run += 1
            candidate = generatedTestID(fixtureID: fixture.id, run: run)
        }
        evaluationLabels.runNumber = String(run)
        evaluationLabels.captureAttempt = "1"
        evaluationLabels.testId = candidate
    }

    private func generatedTestID(fixtureID: String, run: Int) -> String {
        "\(fixtureID)-\(evaluationLabels.captureConditionPreset.rawValue)-R\(run)-C1"
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
}
