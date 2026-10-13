import Foundation
import CryptoKit

final class EvaluationLogger {
    static let csvHeader = [
        "scanId",
        "testId",
        "baseScenarioID",
        "scenarioVariant",
        "scenarioGroundTruth",
        "datasetSplit",
        "runNumber",
        "captureAttempt",
        "scenarioSecurityType",
        "visualDetectability",
        "captureQualityTruth",
        "groundTruthService",
        "groundTruthPresentedService",
        "groundTruthPurpose",
        "groundTruthPresentedPurpose",
        "groundTruthInitiation",
        "scenarioReceivingClientOwner",
        "scenarioReceivingClientContext",
        "detectableSignalTypes",
        "qrDetected",
        "analysisMode",
        "applicationMode",
        "participantIntroductionCompleted",
        "ocrTextPreview",
        "fullOcrText",
        "visibleDomainClaims",
        "detectedKeywords",
        "purposeState",
        "classification",
        "scanLatencyMilliseconds",
        "qrDetectionMilliseconds",
        "fullFrameOCRMilliseconds",
        "qrRegionOCRMilliseconds",
        "imageAnalysisMilliseconds",
        "classificationMilliseconds",
        "riskScore",
        "evidenceCompleteness",
        "visualEvidenceCompleteness",
        "intentSessionCompleteness",
        "reasons",
        "contradictionReasons",
        "persuasionReasons",
        "missingEvidenceReasons",
        "contextualConcernReasons",
        "preliminaryClassification",
        "visualClassification",
        "visualRiskScore",
        "preliminaryInterventionStyle",
        "preliminaryRecommendedActionIdentifier",
        "clarificationChangedClassification",
        "clarificationChangedRecommendedAction",
        "clarificationPolicy",
        "clarificationQuestions",
        "clarificationAnswers",
        "expectedService",
        "expectedPurpose",
        "initiationStatus",
        "receivingClientRelationship",
        "receivingClientTrust",
        "assessmentDimensions",
        "sessionBindingAssessment",
        "spatialEvidenceSummary",
        "ablationSummary",
        "userFacingHeadline",
        "primaryReasonIdentifier",
        "primaryReason",
        "recommendedActionIdentifier",
        "recommendedAction",
        "interventionStyle",
        "safetyChecks",
        "lightingCondition",
        "angleCondition",
        "distanceCondition",
        "contextType",
        "detectabilityBoundary",
        "notes"
    ]

    static let compactScanHeader = [
        "scanId", "testId", "baseScenarioID", "scenarioVariant",
        "matchedStimulusID", "associationCondition",
        "datasetSplit", "runNumber", "captureAttempt",
        "scenarioSecurityType",
        "visualDetectability", "captureQualityTruth", "groundTruthService",
        "groundTruthPresentedService", "groundTruthPurpose",
        "groundTruthPresentedPurpose", "groundTruthInitiation",
        "scenarioReceivingClientOwner", "scenarioReceivingClientContext",
        "detectableSignalTypes", "analysisMode",
        "displayOS", "displayBrowser", "presentationType", "clutterCondition",
        "captureConditionPreset",
        "cropCondition", "blurCondition",
        "groundTruthPolicySource", "derivedCombinedSecurityTarget",
        "derivedVisualOnlyTarget",
        "qrDetected", "qrProcessingStatus", "ocrProcessingStatus",
        "rawOCRObservationCount", "exportedObservationCount",
        "imageQualitySufficient", "imageQualityIssues",
        "qrCount", "qrType", "visibleServiceClaims", "visibleDomainClaims",
        "detectedPurposes", "purposeState", "detectedCueTypes",
        "peripheralServiceClaims",
        "competingContextPresent", "associationResolution",
        "associationAmbiguous", "preClarificationInterventionClassification",
        "visualClassification", "finalClassification", "visualRiskScore",
        "combinedRiskScore", "strongOverrideFired", "primaryVisualTriggeredRuleId",
        "primaryTriggeredRuleId",
        "visualEvidenceCompleteness", "intentSessionCompleteness",
        "clarificationPolicy", "clarificationQuestionKinds",
        "clarificationAnswerValues", "clarificationAnswerSource",
        "clarificationChangedClassification", "primaryReasonIdentifier",
        "recommendedActionIdentifier", "interventionStyle", "lightingCondition",
        "angleCondition", "distanceCondition", "scanLatencyMilliseconds",
        "qrDetectionMilliseconds", "fullFrameOCRMilliseconds",
        "qrRegionOCRMilliseconds", "imageAnalysisMilliseconds",
        "classificationMilliseconds", "failureStage", "errorCategory",
        "failureAttribution"
    ]

    static let ruleTraceHeader = [
        "scanId", "testId", "ruleId", "category", "polarity", "severity",
        "riskContribution", "completenessContribution", "overrideFired", "evidence",
        "sourceObservationIds"
    ]

    static let observationHeader = [
        "scanId", "testId", "observationId", "recognizedText",
        "extractedFeatureIdentifiers",
        "boundingBoxX", "boundingBoxY", "boundingBoxWidth", "boundingBoxHeight",
        "associatedQRCodeId", "associatedQRBoxX", "associatedQRBoxY",
        "associatedQRBoxWidth", "associatedQRBoxHeight", "ocrConfidence", "sourceRegion", "proximity",
        "associationZone", "associationRole", "associationStrength", "normalizedQRDistance"
    ]

    static let ablationHeader = [
        "scanId", "testId", "excludedSignalFamily", "baselineClassification",
        "ablatedClassification", "baselineRisk", "ablatedRisk",
        "baselineCompleteness", "ablatedCompleteness", "removedTriggeredRules",
        "baselineConfiguration", "ablatedConfiguration",
        "baselineAssociationPolicy", "ablatedAssociationPolicy"
    ]

    private let previewLimit: Int
    private let diagnosticRecognizedTextLimit = 250
    private let includeFullOcrText: Bool
    private let dateFormatter: ISO8601DateFormatter
    private let fileManager: FileManager
    private let exportDirectory: URL

    init(
        previewLimit: Int = 200,
        includeFullOcrText: Bool = false,
        fileManager: FileManager = .default,
        exportDirectory: URL? = nil
    ) {
        self.previewLimit = previewLimit
        self.includeFullOcrText = includeFullOcrText
        self.fileManager = fileManager
        self.exportDirectory = exportDirectory ?? fileManager.temporaryDirectory

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
    }

    func makeRecord(
        from result: ScanResult,
        labels: EvaluationLabels,
        scenarioProvenance: EvaluationScenarioProvenance = .manual,
        analysisMode: AnalysisMode = .staticImage,
        applicationMode: ApplicationMode = .participant,
        participantIntroductionCompleted: Bool = false,
        scenarioMetadataConfirmed: Bool = false,
        failureStage: EvaluationFailureStage = .none,
        errorCategory: EvaluationErrorCategory = .none,
        qrProcessingStatus: QRProcessingStatus? = nil,
        ocrProcessingStatus: OCRProcessingStatus? = nil,
        ocrObservationCount: Int? = nil,
        intent: UserIntent = .skipped,
        preliminaryResult: ScanResult? = nil,
        preliminaryClassification: RiskClassification? = nil,
        clarificationHistory: [ClarificationEvent] = [],
        clarificationAnswerSource: ClarificationAnswerSource = .manual,
        clarificationPolicy: ClarificationPolicy = .participant,
        ablationComparisons: [AblationComparison] = [],
        qrDetected: QRDetectionStatus = .notAvailable
    ) -> EvaluationRecord {
        let ocrText = result.visualContext.ocrText
        let presentation = SecurityResultPresentation.make(for: result)
        let preliminaryPresentation = preliminaryResult.map {
            SecurityResultPresentation.make(for: $0)
        }
        let visualPrimaryReason = PrimaryReasonSelector().select(
            from: result,
            classification: result.visualClassification
        )
        let primaryVisualTriggeredRuleId: String
        if result.visualClassification == .consistent && result.visualRiskScore == 0 {
            primaryVisualTriggeredRuleId = ""
        } else if visualPrimaryReason.identifier == "classification_fallback" {
            primaryVisualTriggeredRuleId = ""
        } else {
            primaryVisualTriggeredRuleId = visualPrimaryReason.identifier
        }
        let includeDiagnosticOCR = applicationMode == .researcher &&
            scenarioMetadataConfirmed &&
            !scenarioProvenance.catalogVersion.isEmpty

        return EvaluationRecord(
            timestamp: result.timestamp,
            scanId: UUID(),
            testId: labels.testId,
            scenarioCatalogVersion: scenarioProvenance.catalogVersion,
            baseScenarioID: scenarioProvenance.baseScenarioID,
            scenarioVariant: scenarioProvenance.variant,
            matchedStimulusID: labels.matchedStimulusID,
            associationCondition: labels.associationCondition,
            scenarioGroundTruth: labels.scenarioGroundTruth,
            exportSchemaVersion: EvaluationImplementationVersion.exportSchema,
            classifierVersion: EvaluationImplementationVersion.classifier,
            ruleSetVersion: EvaluationImplementationVersion.ruleSet,
            associationModelVersion: EvaluationImplementationVersion.associationModel,
            appVersion: EvaluationImplementationVersion.appVersion,
            gitCommit: EvaluationImplementationVersion.gitCommit,
            gitWorkingTreeDirty: EvaluationImplementationVersion.gitWorkingTreeDirty,
            datasetSplit: labels.datasetSplit,
            runNumber: labels.runNumber,
            captureAttempt: labels.captureAttempt,
            factualGroundTruth: labels.factualGroundTruth,
            serviceCatalogVersion: ControlledEvaluationServiceCatalog.version,
            expectedServiceProfileID: labels.expectedServiceProfileID,
            presentedServiceProfileID: labels.presentedServiceProfileID,
            scenarioMetadataConfirmed: scenarioMetadataConfirmed,
            displayOS: labels.displayOS,
            displayBrowser: labels.displayBrowser,
            presentationType: labels.presentationType,
            clutterCondition: labels.clutterCondition,
            cropCondition: labels.cropCondition,
            blurCondition: labels.blurCondition,
            qrProcessingStatus: qrProcessingStatus,
            ocrProcessingStatus: ocrProcessingStatus,
            ocrObservationCount: ocrObservationCount,
            imageQualitySufficient: result.imageQuality.isSufficientForAnalysis,
            imageQualityIssues: result.imageQuality.issues,
            qrCount: result.qrCount,
            qrTypes: result.qrTypes,
            visibleServiceClaims: result.visibleServiceClaims,
            peripheralServiceClaims: result.peripheralServiceClaims,
            detectedPurposes: result.inferredPurposes.map(\.rawValue),
            purposeState: result.purposeState,
            detectedCueTypes: result.socialEngineeringCues.map(\.rawValue),
            structuredRuleTrace: result.ruleResults,
            structuredSpatialObservations: result.spatialEvidence.map {
                evidence in
                EvaluationSpatialObservation(
                    observationId: evidence.observationId,
                    recognizedText: diagnosticRecognizedText(
                        evidence.text,
                        enabled: includeDiagnosticOCR
                    ),
                    textFingerprint: textFingerprint(evidence.text),
                    extractedFeatureIdentifiers: result.visualClaims
                        .filter { $0.sourceObservationId == evidence.observationId }
                        .map(\.featureIdentifier),
                    boundingBox: evidence.boundingBox,
                    associatedQRCodeID: evidence.associatedQRCodeIndex.map { "Q\($0 + 1)" },
                    associatedQRCodeBoundingBox: evidence.associatedQRCodeBoundingBox,
                    confidence: evidence.confidence,
                    sourceRegion: evidence.sourceRegion,
                    proximity: evidence.proximity,
                    contextZone: evidence.contextZone,
                    associationStrength: evidence.associationStrength,
                    semanticRole: evidence.semanticRole,
                    normalizedDistanceToQRCode: evidence.normalizedDistanceToQRCode
                )
            },
            structuredAblationComparisons: ablationComparisons,
            competingContextPresent: result.competingContextPresent,
            associationResolution: result.associationResolution,
            associationAmbiguous: result.associationResolution == .ambiguous,
            strongOverrideFired: result.ruleResults.contains(where: \.triggersSuspiciousOverride),
            primaryVisualTriggeredRuleId: primaryVisualTriggeredRuleId,
            primaryTriggeredRuleId: presentation.primaryReasonIdentifier == "classification_fallback"
                ? ""
                : presentation.primaryReasonIdentifier,
            clarificationAsked: !clarificationHistory.isEmpty,
            clarificationQuestionKinds: clarificationHistory.map(\.questionKind.rawValue),
            clarificationAnswerValues: clarificationHistory.map(\.answer),
            clarificationAnswerSource: clarificationHistory.isEmpty
                ? ClarificationAnswerSource.none
                : clarificationAnswerSource,
            failureStage: failureStage,
            errorCategory: errorCategory,
            failureAttribution: labels.failureAttribution,
            captureConditionPreset: labels.captureConditionPreset,
            qrDetected: qrDetected,
            analysisMode: analysisMode,
            applicationMode: applicationMode,
            participantIntroductionCompleted: participantIntroductionCompleted,
            ocrTextPreview: preview(from: ocrText),
            fullOcrText: includeFullOcrText ? ocrText : "",
            visibleDomainClaims: result.visualContext.visibleDomainClaims,
            detectedKeywords: result.visualContext.authenticationKeywords,
            visualClassification: result.visualClassification,
            visualRiskScore: result.visualRiskScore,
            classification: result.classification,
            scanLatencyMilliseconds: result.scanLatencyMilliseconds,
            qrDetectionMilliseconds: result.analysisTiming.qrDetectionMilliseconds,
            fullFrameOCRMilliseconds: result.analysisTiming.fullFrameOCRMilliseconds,
            qrRegionOCRMilliseconds: result.analysisTiming.qrRegionOCRMilliseconds,
            imageAnalysisMilliseconds: result.analysisTiming.imageAnalysisMilliseconds,
            classificationMilliseconds: result.classificationMilliseconds,
            riskScore: result.riskScore,
            evidenceCompleteness: result.evidenceCompleteness,
            visualEvidenceCompleteness: result.visualEvidenceCompleteness,
            intentSessionCompleteness: result.intentSessionCompleteness,
            reasons: result.reasons,
            contradictionReasons: reasons(in: .contradiction, from: result),
            persuasionReasons: reasons(in: .persuasion, from: result),
            missingEvidenceReasons: reasons(in: .missingEvidence, from: result),
            contextualConcernReasons: reasons(in: .contextualConcern, from: result),
            preliminaryClassification: preliminaryClassification,
            preliminaryInterventionStyle: preliminaryPresentation?.style,
            preliminaryRecommendedActionIdentifier: preliminaryPresentation?.recommendedActionIdentifier ?? "",
            clarificationChangedClassification: preliminaryClassification.map {
                $0 != result.classification
            } ?? false,
            clarificationChangedRecommendedAction: preliminaryPresentation.map {
                $0.recommendedActionIdentifier != presentation.recommendedActionIdentifier
            } ?? false,
            clarificationPolicy: clarificationPolicy,
            clarificationQuestions: clarificationHistory.map {
                "\($0.questionKind.rawValue): \($0.prompt)"
            },
            clarificationAnswers: clarificationHistory.map {
                "\($0.questionKind.rawValue): \($0.answer)"
            },
            expectedService: intent.expectedService ?? "",
            expectedPurpose: intent.expectedPurpose?.rawValue ?? "",
            initiationStatus: intent.startedOnReceivingClient.rawValue,
            receivingClientRelationship: intent.receivingClientRelationship.rawValue,
            receivingClientTrust: intent.receivingClientTrust.rawValue,
            assessmentDimensions: result.assessmentDimensions.map {
                "\($0.kind.rawValue):\($0.finding.rawValue)"
            },
            sessionBindingAssessment: result.sessionBindingAssessment,
            spatialEvidenceSummary: result.spatialEvidence.map(spatialSummary),
            ablationSummary: ablationComparisons.map(\.exportSummary),
            userFacingHeadline: presentation.headline,
            primaryReasonIdentifier: presentation.primaryReasonIdentifier,
            primaryReason: presentation.primaryReason,
            recommendedActionIdentifier: presentation.recommendedActionIdentifier,
            recommendedAction: presentation.recommendedAction,
            interventionStyle: presentation.style,
            safetyChecks: presentation.safetyChecks,
            lightingCondition: labels.lightingCondition,
            angleCondition: labels.angleCondition,
            distanceCondition: labels.distanceCondition,
            contextType: labels.contextType,
            detectabilityBoundary: labels.detectabilityBoundary,
            notes: labels.notes
        )
    }

    func makeFailureRecord(
        labels: EvaluationLabels,
        scenarioProvenance: EvaluationScenarioProvenance = .manual,
        analysisMode: AnalysisMode = .staticImage,
        applicationMode: ApplicationMode = .researcher,
        participantIntroductionCompleted: Bool = false,
        failureStage: EvaluationFailureStage,
        errorCategory: EvaluationErrorCategory,
        qrProcessingStatus: QRProcessingStatus? = nil,
        ocrProcessingStatus: OCRProcessingStatus? = nil,
        qrDetected: QRDetectionStatus = .notAvailable
    ) -> EvaluationRecord {
        let placeholder = ScanResult(
            visualContext: VisualContext(
                qrDetected: false,
                ocrText: "",
                visibleDomainClaims: [],
                authenticationKeywords: []
            ),
            classification: .uncertain,
            riskScore: 0,
            evidenceCompleteness: 0,
            reasons: ["Analysis did not produce a classification result."]
        )
        return makeRecord(
            from: placeholder,
            labels: labels,
            scenarioProvenance: scenarioProvenance,
            analysisMode: analysisMode,
            applicationMode: applicationMode,
            participantIntroductionCompleted: participantIntroductionCompleted,
            failureStage: failureStage,
            errorCategory: errorCategory,
            qrProcessingStatus: qrProcessingStatus,
            ocrProcessingStatus: ocrProcessingStatus,
            ocrObservationCount: ocrProcessingStatus == nil ? nil : 0,
            qrDetected: qrDetected
        )
    }

    func csvString(for records: [EvaluationRecord]) -> String {
        let rows = [Self.csvHeader] + records.map(csvFields(for:))
        return rows.map(csvRow(fields:)).joined(separator: "\n") + "\n"
    }

    func exportCSV(record: EvaluationRecord) throws -> URL {
        try exportCSV(records: [record], fileLabel: record.testId)
    }

    func exportCSV(
        records: [EvaluationRecord],
        fileLabel: String = "dataset"
    ) throws -> URL {
        guard !records.isEmpty else {
            throw EvaluationLoggerError.noRecords
        }
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let label = sanitizedFileComponent(fileLabel.isEmpty ? "untitled" : fileLabel)
        let timestamp = sanitizedFileComponent(dateFormatter.string(from: Date()))
        let fileURL = exportDirectory.appendingPathComponent("passkey-context-\(label)-\(timestamp).csv")
        let csv = csvString(for: records)

        try Data(csv.utf8).write(to: fileURL, options: .atomic)
        return fileURL
    }

    func normalizedCSVStrings(for records: [EvaluationRecord]) -> [String: String] {
        [
            "scans.csv": csvDocument(
                header: Self.compactScanHeader,
                rows: records.map(compactScanFields)
            ),
            "rule-trace.csv": csvDocument(
                header: Self.ruleTraceHeader,
                rows: records.flatMap(ruleTraceFields)
            ),
            "observations.csv": csvDocument(
                header: Self.observationHeader,
                rows: records.flatMap(observationFields)
            ),
            "ablations.csv": csvDocument(
                header: Self.ablationHeader,
                rows: records.flatMap(ablationFields)
            )
        ]
    }

    func exportNormalizedCSVs(records: [EvaluationRecord]) throws -> [URL] {
        guard !records.isEmpty else { throw EvaluationLoggerError.noRecords }
        let timestamp = sanitizedFileComponent(dateFormatter.string(from: Date()))
        let directory = exportDirectory.appendingPathComponent(
            "passkey-context-dataset-\(timestamp)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return try normalizedCSVStrings(for: records)
            .sorted { $0.key < $1.key }
            .map { filename, contents in
                let url = directory.appendingPathComponent(filename)
                try Data(contents.utf8).write(to: url, options: .atomic)
                return url
            }
    }

    private func exportedPurposeState(for record: EvaluationRecord) -> PurposeState {
        record.purposeState ?? PurposeState.derive(
            from: (record.detectedPurposes ?? []).compactMap(IntendedPurpose.init(rawValue:))
        )
    }

    private func compactScanFields(_ record: EvaluationRecord) -> [String] {
        let truth = record.factualGroundTruth
        let targets = EvaluationGroundTruthPolicy().targets(for: record)
        return [
            scanIdentifier(record), record.testId, record.baseScenarioID, record.scenarioVariant,
            record.matchedStimulusID ?? "", record.associationCondition?.rawValue ?? "",
            record.datasetSplit?.rawValue ?? "",
            record.runNumber ?? "", record.captureAttempt ?? "",
            truth?.securityType.rawValue ?? "", truth?.visualDetectability.rawValue ?? "",
            truth?.captureQuality.rawValue ?? "", truth?.service ?? "",
            truth?.presentedService ?? "", truth?.purpose?.rawValue ?? "",
            truth?.presentedPurpose?.rawValue ?? "", truth?.initiated.rawValue ?? "",
            truth?.receivingClientOwner.rawValue ?? "",
            truth?.receivingClientContext?.rawValue ?? "",
            truth?.detectableSignals.map(\.rawValue).joined(separator: "; ") ?? "",
            record.analysisMode.rawValue, record.displayOS?.rawValue ?? "",
            record.displayBrowser?.rawValue ?? "", record.presentationType?.rawValue ?? "",
            record.clutterCondition?.rawValue ?? "",
            record.captureConditionPreset?.rawValue ?? "",
            record.cropCondition?.rawValue ?? "",
            record.blurCondition?.rawValue ?? "",
            targets.source.rawValue,
            targets.combinedSecurity?.rawValue ?? "",
            targets.visualOnly?.rawValue ?? "", record.qrDetected.rawValue,
            record.qrProcessingStatus?.rawValue ?? "",
            record.ocrProcessingStatus?.rawValue ?? "",
            record.ocrObservationCount.map(String.init) ?? "",
            record.structuredSpatialObservations.map { String($0.count) } ?? "",
            booleanField(record.imageQualitySufficient),
            (record.imageQualityIssues ?? []).map(\.rawValue).joined(separator: "; "),
            record.qrCount.map(String.init) ?? "",
            (record.qrTypes ?? []).map(\.rawValue).joined(separator: "; "),
            (record.visibleServiceClaims ?? []).joined(separator: "; "),
            record.visibleDomainClaims.joined(separator: "; "),
            (record.detectedPurposes ?? []).joined(separator: "; "),
            exportedPurposeState(for: record).rawValue,
            (record.detectedCueTypes ?? []).joined(separator: "; "),
            (record.peripheralServiceClaims ?? []).joined(separator: "; "),
            booleanField(record.competingContextPresent),
            record.associationResolution?.rawValue ?? "",
            booleanField(record.associationAmbiguous),
            record.preliminaryClassification?.rawValue ?? "",
            record.visualClassification?.rawValue ?? "", record.classification.rawValue,
            record.visualRiskScore.map(String.init) ?? "", String(record.riskScore),
            booleanField(record.strongOverrideFired),
            record.primaryVisualTriggeredRuleId ?? "",
            record.primaryTriggeredRuleId ?? "", record.visualEvidenceCompleteness.rawValue,
            record.intentSessionCompleteness.rawValue, record.clarificationPolicy.rawValue,
            (record.clarificationQuestionKinds ?? []).joined(separator: "; "),
            (record.clarificationAnswerValues ?? []).joined(separator: "; "),
            record.clarificationAnswerSource?.rawValue ?? "",
            String(record.clarificationChangedClassification), record.primaryReasonIdentifier,
            record.recommendedActionIdentifier, record.interventionStyle.rawValue,
            record.lightingCondition.rawValue, record.angleCondition.rawValue,
            record.distanceCondition.rawValue, millisecondsField(record.scanLatencyMilliseconds),
            millisecondsField(record.qrDetectionMilliseconds),
            millisecondsField(record.fullFrameOCRMilliseconds),
            millisecondsField(record.qrRegionOCRMilliseconds),
            millisecondsField(record.imageAnalysisMilliseconds),
            millisecondsField(record.classificationMilliseconds),
            record.failureStage?.rawValue ?? "", record.errorCategory?.rawValue ?? "",
            record.failureAttribution?.rawValue ?? ""
        ]
    }

    private func ruleTraceFields(_ record: EvaluationRecord) -> [[String]] {
        (record.structuredRuleTrace ?? []).map { rule in
            [scanIdentifier(record), record.testId,
             rule.ruleIdentifier, rule.evidenceCategory.rawValue,
             rule.polarity.rawValue, rule.severity.rawValue,
             String(rule.riskContribution), String(rule.completenessContribution),
             String(rule.triggersSuspiciousOverride), rule.evidence.joined(separator: "; "),
             sourceObservationIDs(for: rule, in: record).joined(separator: "; ")]
        }
    }

    private func observationFields(_ record: EvaluationRecord) -> [[String]] {
        (record.structuredSpatialObservations ?? []).map { observation in
            [scanIdentifier(record), record.testId, observation.observationId,
             observation.recognizedText ?? "",
             (observation.extractedFeatureIdentifiers ?? []).joined(separator: "; "),
             coordinateField(observation.boundingBox?.x),
             coordinateField(observation.boundingBox?.y),
             coordinateField(observation.boundingBox?.width),
             coordinateField(observation.boundingBox?.height),
             observation.associatedQRCodeID ?? "",
             coordinateField(observation.associatedQRCodeBoundingBox?.x),
             coordinateField(observation.associatedQRCodeBoundingBox?.y),
             coordinateField(observation.associatedQRCodeBoundingBox?.width),
             coordinateField(observation.associatedQRCodeBoundingBox?.height),
             String(format: "%.3f", observation.confidence), observation.sourceRegion.rawValue,
             observation.proximity.rawValue, observation.contextZone.rawValue,
             observation.semanticRole?.rawValue ?? "",
             observation.associationStrength.rawValue,
             observation.normalizedDistanceToQRCode.map { String(format: "%.3f", $0) } ?? ""]
        }
    }

    private func ablationFields(_ record: EvaluationRecord) -> [[String]] {
        (record.structuredAblationComparisons ?? []).map { comparison in
            [scanIdentifier(record), record.testId, comparison.family.rawValue,
             comparison.baselineClassification.rawValue,
             comparison.ablatedClassification.rawValue,
             String(comparison.baselineRiskScore), String(comparison.ablatedRiskScore),
             String(comparison.baselineCompleteness), String(comparison.ablatedCompleteness),
             comparison.removedTriggeredRules.joined(separator: "; "),
             comparison.baselineConfigurationID ?? "",
             comparison.ablatedConfigurationID ?? "",
             comparison.baselineAssociationPolicy?.rawValue ?? "",
             comparison.ablatedAssociationPolicy?.rawValue ?? ""]
        }
    }

    private func scanIdentifier(_ record: EvaluationRecord) -> String {
        record.scanId?.uuidString ?? ""
    }

    private func textFingerprint(_ text: String) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func coordinateField(_ value: Double?) -> String {
        value.map { String(format: "%.4f", $0) } ?? ""
    }

    private func sourceObservationIDs(
        for rule: ClassificationRuleResult,
        in record: EvaluationRecord
    ) -> [String] {
        if !rule.sourceObservationIds.isEmpty {
            return rule.sourceObservationIds
        }
        let observations = record.structuredSpatialObservations ?? []
        let prefixes: [String]
        switch rule.ruleIdentifier {
        case "identity_evidence", "expected_service_mismatch", "service_mismatch",
             "brand_domain_conflict":
            prefixes = ["SERVICE:", "DOMAIN:", "BROWSER_DOMAIN:", "QR_LOCAL_DOMAIN:"]
        case "context_association":
            return observations.filter {
                ($0.extractedFeatureIdentifiers ?? []).contains {
                    $0.hasPrefix("SERVICE:") || $0.hasPrefix("DOMAIN:")
                }
            }.map(\.observationId)
        case "ceremony_language":
            prefixes = ["AUTH:"]
        case "purpose_mismatch", "direct_purpose_mismatch":
            prefixes = ["PURPOSE:", "NON_AUTH:"]
        case "unrelated_action":
            prefixes = ["NON_AUTH:"]
        case "urgency_and_coercion":
            prefixes = ["SOCIAL:"]
        case "spatial_relevance":
            return observations
                .filter { $0.proximity == .near }
                .map(\.observationId)
        case "context_completeness":
            return observations
                .filter { !($0.extractedFeatureIdentifiers ?? []).isEmpty }
                .map(\.observationId)
        default:
            return []
        }
        return observations.filter { observation in
            let isAssociated = observation.associationStrength == .strong ||
                observation.associationStrength == .plausible
            return isAssociated &&
                (observation.extractedFeatureIdentifiers ?? []).contains { identifier in
                    prefixes.contains { identifier.hasPrefix($0) }
                }
        }.map(\.observationId)
    }

    private func csvDocument(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map(csvRow(fields:)).joined(separator: "\n") + "\n"
    }

    private func csvFields(for record: EvaluationRecord) -> [String] {
        [
            record.scanId?.uuidString ?? "",
            record.testId,
            record.baseScenarioID,
            record.scenarioVariant,
            record.scenarioGroundTruth.rawValue,
            record.datasetSplit?.rawValue ?? "",
            record.runNumber ?? "",
            record.captureAttempt ?? "",
            record.factualGroundTruth?.securityType.rawValue ?? "",
            record.factualGroundTruth?.visualDetectability.rawValue ?? "",
            record.factualGroundTruth?.captureQuality.rawValue ?? "",
            record.factualGroundTruth?.service ?? "",
            record.factualGroundTruth?.presentedService ?? "",
            record.factualGroundTruth?.purpose?.rawValue ?? "",
            record.factualGroundTruth?.presentedPurpose?.rawValue ?? "",
            record.factualGroundTruth?.initiated.rawValue ?? "",
            record.factualGroundTruth?.receivingClientOwner.rawValue ?? "",
            record.factualGroundTruth?.receivingClientContext?.rawValue ?? "",
            record.factualGroundTruth?.detectableSignals.map(\.rawValue)
                .joined(separator: "; ") ?? "",
            record.qrDetected.rawValue,
            record.analysisMode.rawValue,
            record.applicationMode.rawValue,
            String(record.participantIntroductionCompleted),
            record.ocrTextPreview,
            record.fullOcrText,
            record.visibleDomainClaims.joined(separator: "; "),
            record.detectedKeywords.joined(separator: "; "),
            exportedPurposeState(for: record).rawValue,
            record.classification.rawValue,
            millisecondsField(record.scanLatencyMilliseconds),
            millisecondsField(record.qrDetectionMilliseconds),
            millisecondsField(record.fullFrameOCRMilliseconds),
            millisecondsField(record.qrRegionOCRMilliseconds),
            millisecondsField(record.imageAnalysisMilliseconds),
            millisecondsField(record.classificationMilliseconds),
            String(record.riskScore),
            String(record.evidenceCompleteness),
            record.visualEvidenceCompleteness.rawValue,
            record.intentSessionCompleteness.rawValue,
            record.reasons.joined(separator: "; "),
            record.contradictionReasons.joined(separator: "; "),
            record.persuasionReasons.joined(separator: "; "),
            record.missingEvidenceReasons.joined(separator: "; "),
            record.contextualConcernReasons.joined(separator: "; "),
            record.preliminaryClassification?.rawValue ?? "",
            record.visualClassification?.rawValue ?? "",
            record.visualRiskScore.map(String.init) ?? "",
            record.preliminaryInterventionStyle?.rawValue ?? "",
            record.preliminaryRecommendedActionIdentifier,
            String(record.clarificationChangedClassification),
            String(record.clarificationChangedRecommendedAction),
            record.clarificationPolicy.rawValue,
            record.clarificationQuestions.joined(separator: "; "),
            record.clarificationAnswers.joined(separator: "; "),
            record.expectedService,
            record.expectedPurpose,
            record.initiationStatus,
            record.receivingClientRelationship,
            record.receivingClientTrust,
            record.assessmentDimensions.joined(separator: "; "),
            record.sessionBindingAssessment.rawValue,
            record.spatialEvidenceSummary.joined(separator: "; "),
            (record.ablationSummary ?? []).joined(separator: "; "),
            record.userFacingHeadline,
            record.primaryReasonIdentifier,
            record.primaryReason,
            record.recommendedActionIdentifier,
            record.recommendedAction,
            record.interventionStyle.rawValue,
            record.safetyChecks.joined(separator: "; "),
            record.lightingCondition.rawValue,
            record.angleCondition.rawValue,
            record.distanceCondition.rawValue,
            record.contextType.rawValue,
            record.detectabilityBoundary.rawValue,
            record.notes
        ]
    }

    private func csvRow(fields: [String]) -> String {
        fields.map(escapeCSVField(_:)).joined(separator: ",")
    }

    private func escapeCSVField(_ field: String) -> String {
        "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func preview(from text: String) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .joined(separator: " ")

        if singleLine.count <= previewLimit {
            return singleLine
        }

        return String(singleLine.prefix(previewLimit))
    }

    private func diagnosticRecognizedText(_ text: String, enabled: Bool) -> String? {
        guard enabled else { return nil }
        let pattern = #"[A-Za-z0-9._%+•-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return String(text.prefix(diagnosticRecognizedTextLimit))
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let redacted = expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "[redacted]@$1"
        )
        return String(redacted.prefix(diagnosticRecognizedTextLimit))
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func reasons(
        in category: EvidenceCategory,
        from result: ScanResult
    ) -> [String] {
        var seen = Set<String>()
        return result.ruleResults
            .filter { $0.evidenceCategory == category }
            .map(\.reason)
            .filter { seen.insert($0).inserted }
    }

    private func spatialSummary(_ evidence: SpatialTextEvidence) -> String {
        let distance = evidence.normalizedDistanceToQRCode.map {
            String(format: "%.3f", $0)
        } ?? "n/a"
        return [
            evidence.proximity.rawValue,
            evidence.contextZone.rawValue,
            evidence.associationStrength.rawValue,
            evidence.sourceRegion.rawValue,
            distance
        ].joined(separator: "|")
    }

    private func millisecondsField(_ value: Double?) -> String {
        value.map { String(format: "%.3f", $0) } ?? ""
    }

    private func booleanField(_ value: Bool?) -> String {
        value.map(String.init) ?? ""
    }
}

enum EvaluationLoggerError: Error, Equatable {
    case noRecords
}

struct EvaluationDatasetEnvelope: Codable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let records: [EvaluationRecord]

    init(
        schemaVersion: Int = EvaluationDatasetEnvelope.currentSchemaVersion,
        records: [EvaluationRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.records = records
    }
}

enum EvaluationRecordStoreError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

final class EvaluationRecordStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.fileURL = directory
                .appendingPathComponent("PasskeyContextScanner", isDirectory: true)
                .appendingPathComponent("evaluation-records.json")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate.bitPattern)
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let bitPattern = try? container.decode(UInt64.self),
               bitPattern > 10_000_000_000 {
                return Date(
                    timeIntervalSinceReferenceDate: TimeInterval(bitPattern: bitPattern)
                )
            }
            // Compatibility with schema-2 pilot files written before the
            // bit-exact representation was introduced.
            return Date(timeIntervalSince1970: try container.decode(Double.self))
        }
        self.decoder = decoder
    }

    func load() throws -> [EvaluationRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let schemaVersion = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["schemaVersion"] as? Int
        let selectedDecoder: JSONDecoder
        if schemaVersion == 1 {
            let legacyDecoder = JSONDecoder()
            legacyDecoder.dateDecodingStrategy = .iso8601
            selectedDecoder = legacyDecoder
        } else {
            selectedDecoder = decoder
        }
        let envelope = try selectedDecoder.decode(EvaluationDatasetEnvelope.self, from: data)
        guard envelope.schemaVersion == EvaluationDatasetEnvelope.currentSchemaVersion ||
                envelope.schemaVersion == 1 else {
            throw EvaluationRecordStoreError.unsupportedSchemaVersion(
                envelope.schemaVersion
            )
        }
        return envelope.records
    }

    func save(_ records: [EvaluationRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(EvaluationDatasetEnvelope(records: records))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}
