import XCTest
@testable import PasskeyContextScanner

final class EvaluationLoggerTests: XCTestCase {
    func testFixtureCatalogContainsFrozenCorePlanWithUniqueIDs() {
        let fixtures = ControlledEvaluationFixtureCatalog.fixtures

        XCTAssertEqual(fixtures.count, 46)
        XCTAssertEqual(Set(fixtures.map(\.id)).count, 46)
        XCTAssertEqual(fixtures.filter { $0.id.hasPrefix("L") }.count, 13)
        XCTAssertEqual(fixtures.filter { $0.id.hasPrefix("M") }.count, 19)
        XCTAssertEqual(fixtures.filter { $0.id.hasPrefix("A") }.count, 8)
        XCTAssertEqual(fixtures.filter { $0.id.hasPrefix("U") }.count, 6)
        XCTAssertEqual(fixtures.filter { $0.id.hasSuffix("-f") }.count, 10)
        XCTAssertTrue(ControlledEvaluationFixtureCatalog.validationProblems.isEmpty)
    }

    func testCompetingContextCatalogContainsSixCompleteMatchedPairs() throws {
        let fixtures = CompetingContextEvaluationFixtureCatalog.fixtures

        XCTAssertEqual(fixtures.count, 12)
        XCTAssertEqual(Set(fixtures.map(\.id)).count, 12)
        XCTAssertEqual(Set(fixtures.map(\.matchedStimulusID)), Set(["C01", "C02", "C03", "C04", "C05", "C06"]))
        for pairID in ["C01", "C02", "C03", "C04", "C05", "C06"] {
            XCTAssertEqual(fixtures.filter { $0.matchedStimulusID == pairID }.count, 2)
        }
        XCTAssertTrue(CompetingContextEvaluationFixtureCatalog.validationProblems.isEmpty)

        let clean = try XCTUnwrap(CompetingContextEvaluationFixtureCatalog.fixture(id: "C06-0"))
        let competing = try XCTUnwrap(CompetingContextEvaluationFixtureCatalog.fixture(id: "C06-1"))
        XCTAssertEqual(clean.expectedService, "PayPal")
        XCTAssertEqual(competing.expectedService, "PayPal")
        XCTAssertEqual(competing.presentedService, "PayPal")
        XCTAssertEqual(clean.associationCondition, .clean)
        XCTAssertEqual(competing.associationCondition, .competingIrrelevant)
        XCTAssertEqual(competing.expectedPurpose, .signIn)
        XCTAssertEqual(competing.presentedPurpose, .signIn)
        XCTAssertEqual(competing.displayBrowser, .chrome)
    }

    @MainActor
    func testSelectingCompetingContextFixturePopulatesPairMetadataWithoutChoosingSplit() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.evaluationLabels.datasetSplit = .finalEvaluation

        viewModel.selectFixture(id: "C06-1")

        XCTAssertEqual(viewModel.selectedFixture?.id, "C06-1")
        XCTAssertEqual(viewModel.evaluationLabels.matchedStimulusID, "C06")
        XCTAssertEqual(viewModel.evaluationLabels.associationCondition, .competingIrrelevant)
        XCTAssertEqual(viewModel.evaluationLabels.contextType, .contextAssociation)
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.service, "PayPal")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.presentedService, "PayPal")
        XCTAssertEqual(viewModel.evaluationLabels.datasetSplit, .finalEvaluation)
        XCTAssertEqual(
            viewModel.evaluationScenarioProvenance.catalogVersion,
            CompetingContextEvaluationFixtureCatalog.version
        )
    }

    func testFixtureCatalogMatchesCurrentAuthoredServiceTruth() throws {
        let expectedServices = [
            "L01": "PayPal", "L02": "Robinhood", "L03": "Chase",
            "L04": "PayPal", "L05": "Dropbox", "L06": "GitHub",
            "L07": "Coinbase", "L08": "GitHub", "L09": "Robinhood",
            "L10": "Shopify", "M01": "Chase", "M02": "Google",
            "M03": "Chase", "M04": "GitHub", "M05": "NONE_VISIBLE",
            "M06": "NONE_VISIBLE", "M07": "NONE_VISIBLE",
            "M08": "NONE_VISIBLE", "M09": "Acme Corp",
            "M10": "PayPal", "M11": "GitHub", "M12": "NONE_VISIBLE",
            "M13": "GitHub", "M14": "NONE_VISIBLE", "A01": "Chase",
            "A02": "NHS", "A03": "Wells Fargo", "A04": "NHS",
            "A05": "GitHub", "A06": "Robinhood", "A07": "Google",
            "U01": "GitHub", "U02": "Wells Fargo", "U03": "NHS",
            "U04": "PayPal", "U05": "NHS",
            "L01-f": "Discord", "L02-f": "Coinbase", "L03-f": "Stripe",
            "M01-f": "Coinbase", "M07-f": "NONE_VISIBLE",
            "M09-f": "NONE_VISIBLE", "M12-f": "NONE_VISIBLE",
            "M13-f": "Snapchat", "A04-f": "Notion", "U03-f": "Notion"
        ]

        for (id, service) in expectedServices {
            let fixture = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: id))
            XCTAssertEqual(fixture.expectedService, service, "Unexpected expected-service truth for \(id).")
            if ["M05", "M06", "M07", "M08", "M09", "M12", "M14", "M07-f", "M09-f", "M12-f"].contains(id) {
                XCTAssertEqual(
                    fixture.presentedService,
                    service,
                    "Purpose/persuasion fixture \(id) must retain the service actually visible in its image."
                )
            }
        }

        let m08 = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "M08")
        )
        XCTAssertEqual(m08.presentedPurpose, .payment)

        let m12 = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "M12")
        )
        XCTAssertEqual(m12.visualDetectability, .insufficientEvidence)
        let m12Record = makeMetricsRecord(
            groundTruth: m12.scenarioGroundTruth,
            prediction: .uncertain,
            factualTruth: m12.scenarioFactualGroundTruth,
            preliminaryPrediction: .uncertain
        )
        XCTAssertEqual(
            EvaluationGroundTruthPolicy().targets(for: m12Record).visualOnly,
            .uncertain
        )

        let m12Final = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "M12-f")
        )
        XCTAssertEqual(m12Final.visualDetectability, .insufficientEvidence)
        let m12FinalRecord = makeMetricsRecord(
            groundTruth: m12Final.scenarioGroundTruth,
            prediction: .uncertain,
            factualTruth: m12Final.scenarioFactualGroundTruth,
            preliminaryPrediction: .uncertain
        )
        XCTAssertEqual(
            EvaluationGroundTruthPolicy().targets(for: m12FinalRecord).visualOnly,
            .uncertain
        )

        let hiddenInitiation = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "M13")
        )
        let hiddenInitiationRecord = makeMetricsRecord(
            groundTruth: hiddenInitiation.scenarioGroundTruth,
            prediction: .consistent,
            factualTruth: hiddenInitiation.scenarioFactualGroundTruth,
            preliminaryPrediction: .consistent
        )
        XCTAssertNil(
            EvaluationGroundTruthPolicy().targets(for: hiddenInitiationRecord).visualOnly
        )

        let actionTokens = Set([
            "SIGN_IN", "EMAIL_VERIFICATION", "VERIFY_IDENTITY", "PAIRING",
            "PAYMENT", "BONUS", "DOCUMENT_ACCESS", "REWARD_OR_SALARY"
        ])
        for fixture in ControlledEvaluationFixtureCatalog.fixtures {
            XCTAssertFalse(actionTokens.contains(fixture.expectedService))
            XCTAssertFalse(actionTokens.contains(fixture.presentedService))
        }
    }

    func testFixtureCatalogSeparatesCaptureQualityFromMissingVisualEvidence() throws {
        let sparseLegitimate = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "L06")
        )
        XCTAssertEqual(sparseLegitimate.visualDetectability, .insufficientEvidence)
        XCTAssertEqual(sparseLegitimate.captureQuality, .sufficient)

        let sparseContext = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "A01")
        )
        XCTAssertEqual(sparseContext.visualDetectability, .insufficientEvidence)
        XCTAssertEqual(sparseContext.captureQuality, .sufficient)

        let croppedContext = try XCTUnwrap(
            ControlledEvaluationFixtureCatalog.fixture(id: "A04")
        )
        XCTAssertEqual(croppedContext.visualDetectability, .insufficientEvidence)
        XCTAssertEqual(croppedContext.captureQuality, .insufficient)
    }

    func testAddedFixtureMetadataMatchesAuthoredCatalogue() throws {
        let payment = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: "M07-f"))
        XCTAssertEqual(payment.expectedService, "NONE_VISIBLE")
        XCTAssertEqual(payment.presentedService, "NONE_VISIBLE")
        XCTAssertEqual(payment.expectedPurpose, .signIn)
        XCTAssertEqual(payment.presentedPurpose, .payment)

        let unexpected = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: "M13-f"))
        XCTAssertEqual(unexpected.expectedService, "Snapchat")
        XCTAssertEqual(unexpected.baseScenarioID, "SOC-PRESSURE")
        XCTAssertEqual(unexpected.initiated, .yes)
        XCTAssertEqual(unexpected.detectableSignals, [.persuasion])

        let hiddenSession = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: "U03-f"))
        XCTAssertEqual(hiddenSession.expectedService, "Notion")
        XCTAssertEqual(hiddenSession.presentedService, "Notion")
        XCTAssertEqual(hiddenSession.receivingClientOwner, .attacker)
        XCTAssertEqual(hiddenSession.receivingClientContext, .attackerControlled)
        XCTAssertEqual(hiddenSession.visualDetectability, .visuallyIndistinguishable)
    }

    @MainActor
    func testFixtureSuffixDoesNotChooseDatasetSplit() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.evaluationLabels.datasetSplit = .pilot

        viewModel.selectFixture(id: "L01-f")

        XCTAssertEqual(viewModel.evaluationLabels.datasetSplit, .pilot)
    }

    @MainActor
    func testChangingFixtureClearsIntentFromPreviousAnalysis() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.selectFixture(id: "L01-f")
        viewModel.userIntent.expectedService = "Discord"
        viewModel.userIntent.expectedPurpose = .signIn
        viewModel.userIntent.initiationStatus = .yes

        viewModel.selectFixture(id: "L02")

        XCTAssertNil(viewModel.userIntent.expectedService)
        XCTAssertNil(viewModel.userIntent.expectedPurpose)
        XCTAssertEqual(viewModel.userIntent.initiationStatus, .unsure)
    }

    @MainActor
    func testSelectingFixtureAfterAnalysisPreservesVisualObservationAndResult() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(x: 0.35, y: 0.35, width: 0.3, height: 0.3)
            )],
            ocrObservations: [OCRObservation(
                text: "PayPal Sign in with a passkey paypal.com",
                confidence: 0.98,
                boundingBox: NormalizedBoundingBox(x: 0.3, y: 0.67, width: 0.4, height: 0.05),
                region: .qrSurrounding
            )],
            imageQuality: ImageQualityObservation(isSufficientForAnalysis: true, issues: [])
        )
        viewModel.seedCompletedAnalysisForTesting(observation)
        let originalResultID = viewModel.result?.id

        viewModel.selectFixture(id: "C06-0")

        XCTAssertEqual(viewModel.scanObservation, observation)
        XCTAssertNotNil(viewModel.result)
        XCTAssertNotEqual(viewModel.result?.id, originalResultID)
        XCTAssertNil(viewModel.userIntent.expectedService)
        XCTAssertEqual(viewModel.selectedFixture?.id, "C06-0")
    }

    func testFixtureCoverageUsesConcreteFixtureCatalog() {
        let record = makeProvenanceRecord(
            testId: "M02-R1-C1",
            catalogVersion: ControlledEvaluationFixtureCatalog.version,
            scenarioID: "ID-CONFLICT",
            variant: "M02"
        )

        let summary = EvaluationCoverageCalculator().calculateFixtures(records: [record])

        XCTAssertEqual(summary.requiredVariantCount, 46)
        XCTAssertEqual(summary.coveredVariantCount, 1)
        XCTAssertEqual(summary.excludedRecordCount, 0)
        XCTAssertEqual(summary.variants.first { $0.variant == "M02" }?.recordCount, 1)
    }

    @MainActor
    func testFixtureSelectionAppliesControlledCapturePreset() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)

        viewModel.selectFixture(id: "A04")
        XCTAssertEqual(viewModel.evaluationLabels.captureConditionPreset, .partialCrop)
        XCTAssertEqual(viewModel.evaluationLabels.cropCondition, .partial)
        XCTAssertEqual(viewModel.evaluationLabels.blurCondition, BlurCondition.none)
        XCTAssertEqual(viewModel.evaluationLabels.lightingCondition, .normal)

        viewModel.selectFixture(id: "A05")
        XCTAssertEqual(viewModel.evaluationLabels.captureConditionPreset, .farDistance)
        XCTAssertEqual(viewModel.evaluationLabels.distanceCondition, .far)
        XCTAssertEqual(viewModel.evaluationLabels.cropCondition, CropCondition.none)
    }

    @MainActor
    func testCapturePresetResetsOtherPhysicalConditions() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.selectCaptureConditionPreset(.severeBlur)
        viewModel.selectCaptureConditionPreset(.lowLight)

        XCTAssertEqual(viewModel.evaluationLabels.captureConditionPreset, .lowLight)
        XCTAssertEqual(viewModel.evaluationLabels.lightingCondition, .lowLight)
        XCTAssertEqual(viewModel.evaluationLabels.angleCondition, .straight)
        XCTAssertEqual(viewModel.evaluationLabels.distanceCondition, .medium)
        XCTAssertEqual(viewModel.evaluationLabels.blurCondition, BlurCondition.none)
        XCTAssertEqual(viewModel.evaluationLabels.cropCondition, CropCondition.none)
    }

    @MainActor
    func testFixtureSelectionPopulatesArbitraryServiceTruthWithoutServiceProfile() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)

        viewModel.selectFixture(id: "M02")

        XCTAssertEqual(viewModel.selectedFixture?.expectedService, "Google")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.service, "Google")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.presentedService, "NHS")
        XCTAssertEqual(viewModel.evaluationLabels.expectedServiceProfileID, "")
        XCTAssertEqual(viewModel.evaluationLabels.presentedServiceProfileID, "")
        XCTAssertEqual(viewModel.evaluationLabels.displayOS, .macOS)
        XCTAssertEqual(viewModel.evaluationLabels.displayBrowser, .safari)
        XCTAssertEqual(viewModel.evaluationLabels.testId, "M02-R1-C1")
        XCTAssertEqual(
            viewModel.evaluationScenarioProvenance.catalogVersion,
            ControlledEvaluationFixtureCatalog.version
        )
    }

    func testFailureRecordContainsNoImageOCRorClassificationMetrics() {
        var labels = EvaluationLabels.empty
        labels.testId = "FAILED-01"
        let record = EvaluationLogger().makeFailureRecord(
            labels: labels,
            failureStage: .imageLoading,
            errorCategory: .invalidImage
        )

        XCTAssertEqual(record.failureStage, .imageLoading)
        XCTAssertEqual(record.errorCategory, .invalidImage)
        XCTAssertEqual(
            record.failureAttribution,
            EvaluationFailureAttribution.none
        )
        XCTAssertEqual(record.qrDetected, .notAvailable)
        XCTAssertEqual(record.ocrTextPreview, "")
        XCTAssertEqual(record.fullOcrText, "")
        XCTAssertNil(record.scanLatencyMilliseconds)
        XCTAssertTrue(record.structuredRuleTrace?.isEmpty == true)
    }

    func testFailureRecordsAreExcludedFromClassificationMetricsAndCoverage() {
        var labels = completeFinalEvaluationLabels()
        labels.testId = "FAILED-LEG-01"
        let record = EvaluationLogger().makeFailureRecord(
            labels: labels,
            scenarioProvenance: EvaluationScenarioProvenance(
                catalogVersion: ControlledEvaluationScenarioCatalog.version,
                baseScenarioID: "LEG-EXPLICIT",
                variant: "login_page"
            ),
            failureStage: .imageLoading,
            errorCategory: .invalidImage
        )

        let metrics = EvaluationMetricsCalculator().calculate(records: [record])
        let coverage = EvaluationCoverageCalculator().calculate(records: [record])

        XCTAssertEqual(metrics.includedRecordCount, 0)
        XCTAssertEqual(metrics.excludedRecordCount, 1)
        XCTAssertEqual(coverage.coveredVariantCount, 0)
        XCTAssertEqual(coverage.excludedRecordCount, 1)
    }

    func testCSVExportEscapesCommasQuotesAndNewlines() {
        let logger = EvaluationLogger(previewLimit: 80)
        let record = EvaluationRecord(
            timestamp: Date(timeIntervalSince1970: 0),
            scanId: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            testId: "T,001",
            scenarioCatalogVersion: "catalog-test-v1",
            baseScenarioID: "ID-CONFLICT",
            scenarioVariant: "brand_domain",
            matchedStimulusID: "PAIR-GOOGLE-01",
            associationCondition: .competingRelevant,
            scenarioGroundTruth: .suspicious,
            exportSchemaVersion: "2.0-draft",
            classifierVersion: "1.0",
            ruleSetVersion: "1.0",
            associationModelVersion: "1.0",
            appVersion: "1.0",
            gitCommit: "abc123",
            gitWorkingTreeDirty: false,
            datasetSplit: .development,
            runNumber: "1",
            captureAttempt: "1",
            factualGroundTruth: ScenarioFactualGroundTruth(
                securityType: .misleading,
                visualDetectability: .clearlyDetectable,
                captureQuality: .sufficient,
                service: "Google",
                presentedService: "Microsoft",
                purpose: .signIn,
                presentedPurpose: .signIn,
                initiated: .no,
                receivingClientOwner: .attacker,
                detectableSignals: [.identityContradiction]
            ),
            serviceCatalogVersion: "service-test-v1",
            expectedServiceProfileID: "GOOGLE",
            presentedServiceProfileID: "MICROSOFT",
            scenarioMetadataConfirmed: true,
            displayOS: .windows,
            displayBrowser: .chrome,
            presentationType: .fullContext,
            clutterCondition: .competing,
            cropCondition: .partial,
            blurCondition: BlurCondition.none,
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed,
            ocrObservationCount: 2,
            imageQualitySufficient: false,
            imageQualityIssues: [.qrTooSmall],
            qrCount: 1,
            qrTypes: [.fido],
            visibleServiceClaims: ["Microsoft"],
            peripheralServiceClaims: [],
            detectedPurposes: ["SIGN_IN"],
            detectedCueTypes: [],
            structuredRuleTrace: [],
            structuredSpatialObservations: [],
            structuredAblationComparisons: [],
            associationAmbiguous: true,
            strongOverrideFired: true,
            primaryTriggeredRuleId: "expected_service_mismatch",
            clarificationAsked: true,
            clarificationQuestionKinds: ["INITIATION"],
            clarificationAnswerValues: ["NO"],
            clarificationAnswerSource: .scenarioControlled,
            failureStage: EvaluationFailureStage.none,
            errorCategory: EvaluationErrorCategory.none,
            failureAttribution: .contextAssociation,
            captureConditionPreset: .baseline,
            qrDetected: .notAvailable,
            analysisMode: .staticImage,
            applicationMode: .researcher,
            participantIntroductionCompleted: true,
            ocrTextPreview: "Example, \"quoted\"\ntext",
            fullOcrText: "",
            visibleDomainClaims: ["example.com", "login.microsoft.com"],
            detectedKeywords: ["passkey", "sign in"],
            classification: .suspicious,
            scanLatencyMilliseconds: 120.5,
            qrDetectionMilliseconds: 20,
            fullFrameOCRMilliseconds: 80,
            qrRegionOCRMilliseconds: 30,
            imageAnalysisMilliseconds: 118,
            classificationMilliseconds: 2.5,
            riskScore: 85,
            evidenceCompleteness: 70,
            visualEvidenceCompleteness: .sufficient,
            intentSessionCompleteness: .partial,
            reasons: ["Visible page says example.com", "Prompt says \"login.microsoft.com\""],
            contradictionReasons: ["Visible identity conflict"],
            persuasionReasons: ["Urgent approval requested"],
            missingEvidenceReasons: [],
            contextualConcernReasons: [],
            preliminaryClassification: .uncertain,
            preliminaryInterventionStyle: .caution,
            preliminaryRecommendedActionIdentifier: "pause_and_confirm_context",
            clarificationChangedClassification: true,
            clarificationChangedRecommendedAction: true,
            clarificationPolicy: .researcher,
            clarificationQuestions: ["INITIATION: Did you start this request?"],
            clarificationAnswers: ["INITIATION: NO"],
            expectedService: "Microsoft",
            expectedPurpose: IntendedPurpose.signIn.rawValue,
            initiationStatus: InitiationStatus.no.rawValue,
            receivingClientRelationship: ReceivingClientRelationship.unknown.rawValue,
            receivingClientTrust: ReceivingClientTrustStatus.unsure.rawValue,
            assessmentDimensions: ["INITIATION:CONFLICTING"],
            sessionBindingAssessment: .notVerifiable,
            spatialEvidenceSummary: ["NEAR|QR_SURROUNDING|0.020"],
            ablationSummary: ["IDENTITY|SUSPICIOUS->UNCERTAIN"],
            userFacingHeadline: "Possible misleading sign-in",
            primaryReasonIdentifier: "expected_service_mismatch",
            primaryReason: "You expected Microsoft, but the visible page refers to example.com.",
            recommendedActionIdentifier: "navigate_independently",
            recommendedAction: "Do not approve this request.",
            interventionStyle: .activeWarning,
            safetyChecks: ["Start this exact sign-in yourself."],
            lightingCondition: .glare,
            angleCondition: .slightAngle,
            distanceCondition: .medium,
            contextType: .mismatching,
            detectabilityBoundary: .visibleContradiction,
            notes: "contains comma, quote \" and newline\nhere"
        )

        let csv = logger.csvString(for: [record])

        XCTAssertTrue(csv.hasPrefix(EvaluationLogger.csvHeader.map { "\"\($0)\"" }.joined(separator: ",")))
        XCTAssertTrue(csv.contains("\"T,001\""))
        XCTAssertTrue(csv.contains("\"scanId\""))
        XCTAssertTrue(csv.contains("\"scenarioSecurityType\""))
        XCTAssertTrue(csv.contains("\"datasetSplit\""))
        for removedColumn in [
            "timestamp", "scenarioCatalogVersion", "exportSchemaVersion",
            "classifierVersion", "ruleSetVersion", "associationModelVersion", "appVersion"
        ] {
            XCTAssertFalse(csv.contains("\"\(removedColumn)\""))
        }
        XCTAssertTrue(csv.contains("\"ID-CONFLICT\""))
        XCTAssertTrue(csv.contains("\"brand_domain\""))
        XCTAssertTrue(csv.contains("\"ablationSummary\""))
        XCTAssertTrue(csv.contains("\"scenarioGroundTruth\""))
        XCTAssertTrue(csv.contains("\"SUSPICIOUS\""))
        XCTAssertTrue(csv.contains("\"Example, \"\"quoted\"\"\ntext\""))
        XCTAssertTrue(csv.contains("Prompt says \"\"login.microsoft.com\"\""))
        XCTAssertTrue(csv.contains("\"contains comma, quote \"\" and newline\nhere\""))
    }

    func testMakeRecordUsesPreviewAndDoesNotIncludeFullOCRByDefault() {
        let logger = EvaluationLogger(previewLimit: 12)
        let result = ScanResult(
            timestamp: Date(timeIntervalSince1970: 0),
            visualContext: VisualContext(
                qrDetected: true,
                ocrText: "Line one\nLine two with sensitive detail",
                visibleDomainClaims: ["login.microsoft.com"],
                authenticationKeywords: ["passkey"]
            ),
            classification: .consistent,
            riskScore: 20,
            reasons: ["The context appears consistent."],
            analysisTiming: AnalysisTimingObservation(
                qrDetectionMilliseconds: 10,
                fullFrameOCRMilliseconds: 40,
                qrRegionOCRMilliseconds: 20,
                imageAnalysisMilliseconds: 55
            ),
            classificationMilliseconds: 3
        )

        let record = logger.makeRecord(
            from: result,
            labels: EvaluationLabels(
                testId: "T001",
                scenarioGroundTruth: .consistent,
                lightingCondition: .normal,
                angleCondition: .straight,
                distanceCondition: .close,
                contextType: .matching,
                detectabilityBoundary: .notAssigned,
                notes: "baseline"
            )
        )

        XCTAssertEqual(record.ocrTextPreview, "Line one Lin")
        XCTAssertEqual(record.scenarioGroundTruth, .consistent)
        XCTAssertEqual(record.fullOcrText, "")
        XCTAssertEqual(record.qrDetected, .notAvailable)
        XCTAssertEqual(record.analysisMode, .staticImage)
        XCTAssertEqual(record.applicationMode, .participant)
        XCTAssertFalse(record.participantIntroductionCompleted)
        XCTAssertTrue(record.contradictionReasons.isEmpty)
        XCTAssertTrue(record.persuasionReasons.isEmpty)
        XCTAssertTrue(record.missingEvidenceReasons.isEmpty)
        XCTAssertEqual(record.sessionBindingAssessment, .notVerifiable)
        XCTAssertEqual(record.evidenceCompleteness, 0)
        XCTAssertEqual(record.visualEvidenceCompleteness, .notAssessed)
        XCTAssertEqual(record.intentSessionCompleteness, .notAssessed)
        XCTAssertFalse(record.clarificationChangedClassification)
        XCTAssertEqual(record.userFacingHeadline, "No obvious context conflict found")
        XCTAssertEqual(record.recommendedActionIdentifier, "proceed_with_checks")
        XCTAssertEqual(record.clarificationPolicy, .participant)
        XCTAssertEqual(record.scanLatencyMilliseconds, 58)
        XCTAssertEqual(record.qrDetectionMilliseconds, 10)
        XCTAssertEqual(record.fullFrameOCRMilliseconds, 40)
        XCTAssertEqual(record.qrRegionOCRMilliseconds, 20)
        XCTAssertEqual(record.imageAnalysisMilliseconds, 55)
        XCTAssertEqual(record.classificationMilliseconds, 3)
        XCTAssertNotNil(record.scanId)
        XCTAssertEqual(record.exportSchemaVersion, EvaluationImplementationVersion.exportSchema)
        XCTAssertEqual(record.classifierVersion, EvaluationImplementationVersion.classifier)
        XCTAssertEqual(record.ruleSetVersion, EvaluationImplementationVersion.ruleSet)
        XCTAssertEqual(record.purposeState, .unknown)
        XCTAssertEqual(record.datasetSplit, .notAssigned)
        XCTAssertEqual(record.factualGroundTruth, .notAssigned)
        XCTAssertEqual(record.scenarioCatalogVersion, "")
        XCTAssertEqual(record.baseScenarioID, "")
        XCTAssertEqual(record.scenarioVariant, "")
    }

    func testZeroRiskConsistentVisualResultHasNoPrimaryVisualTriggeredRule() {
        let result = ScanResult(
            visualContext: VisualContext(
                qrDetected: true,
                ocrText: "Example passkey sign in",
                visibleDomainClaims: ["example.com"],
                authenticationKeywords: ["passkey", "sign in"]
            ),
            visibleServiceClaims: ["Example"],
            inferredPurposes: [.signIn],
            qrCount: 1,
            qrTypes: [.fido],
            visualClassification: .consistent,
            classification: .uncertain,
            visualRiskScore: 0,
            riskScore: 0,
            reasons: ["The receiving computer is unknown."],
            ruleResults: [
                ClassificationRuleResult(
                    ruleIdentifier: "purpose_mismatch",
                    severity: .informational,
                    polarity: .positive,
                    evidenceCategory: .supporting,
                    riskContribution: 0,
                    completenessContribution: 15,
                    reason: "The visible context states a recognizable purpose.",
                    evidence: ["SIGN_IN"],
                    triggersSuspiciousOverride: false
                ),
                ClassificationRuleResult(
                    ruleIdentifier: "receiving_client_trust",
                    severity: .informational,
                    polarity: .limitation,
                    evidenceCategory: .missingEvidence,
                    riskContribution: 0,
                    completenessContribution: 0,
                    reason: "The receiving computer is unknown.",
                    evidence: [],
                    triggersSuspiciousOverride: false
                )
            ]
        )

        let record = EvaluationLogger().makeRecord(
            from: result,
            labels: .empty
        )

        XCTAssertEqual(record.primaryVisualTriggeredRuleId, "")
        XCTAssertEqual(record.primaryTriggeredRuleId, "receiving_client_trust")
    }

    func testDiagnosticRecognizedTextIsBoundedAndRestrictedToConfirmedResearcherRecords() throws {
        let longText = "person@example.com " + String(repeating: "x", count: 400)
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: longText),
            classification: .uncertain,
            riskScore: 0,
            reasons: ["More context is required."],
            spatialEvidence: [SpatialTextEvidence(
                observationId: "O1",
                text: longText,
                confidence: 0.9,
                boundingBox: NormalizedBoundingBox(x: 0.1, y: 0.1, width: 0.5, height: 0.1),
                associatedQRCodeIndex: 0,
                associatedQRCodeBoundingBox: nil,
                sourceRegion: .fullFrame,
                normalizedDistanceToQRCode: 0.2,
                proximity: .near,
                contextZone: .primary,
                associationStrength: .strong,
                semanticRole: .qrLocal,
                isNearQRCode: true
            )]
        )
        let labels = EvaluationLabels(
            testId: "OCR-EXPORT-01",
            scenarioGroundTruth: .uncertain,
            lightingCondition: .normal,
            angleCondition: .straight,
            distanceCondition: .close,
            contextType: .ambiguous,
            detectabilityBoundary: .insufficientVisualEvidence,
            notes: ""
        )
        let provenance = EvaluationScenarioProvenance(
            catalogVersion: ControlledEvaluationFixtureCatalog.version,
            baseScenarioID: "OCR-EXPORT",
            variant: "A01"
        )
        let logger = EvaluationLogger()

        let confirmedResearcher = logger.makeRecord(
            from: result,
            labels: labels,
            scenarioProvenance: provenance,
            applicationMode: .researcher,
            scenarioMetadataConfirmed: true
        )
        let participant = logger.makeRecord(
            from: result,
            labels: labels,
            scenarioProvenance: provenance,
            applicationMode: .participant,
            scenarioMetadataConfirmed: true
        )
        let unconfirmedResearcher = logger.makeRecord(
            from: result,
            labels: labels,
            scenarioProvenance: provenance,
            applicationMode: .researcher,
            scenarioMetadataConfirmed: false
        )

        let exportedText = try XCTUnwrap(
            confirmedResearcher.structuredSpatialObservations?.first?.recognizedText
        )
        XCTAssertEqual(exportedText.count, 250)
        XCTAssertTrue(exportedText.hasPrefix("[redacted]@example.com"))
        XCTAssertFalse(exportedText.contains("person@example.com"))
        XCTAssertNil(participant.structuredSpatialObservations?.first?.recognizedText)
        XCTAssertNil(unconfirmedResearcher.structuredSpatialObservations?.first?.recognizedText)
    }

    func testMakeRecordPreservesControlledScenarioProvenance() {
        let record = EvaluationLogger().makeRecord(
            from: ScanResult(
                visualContext: VisualContext(qrDetected: true, ocrText: "passkey"),
                classification: .uncertain,
                riskScore: 0,
                reasons: []
            ),
            labels: .empty,
            scenarioProvenance: EvaluationScenarioProvenance(
                catalogVersion: "catalog-v1",
                baseScenarioID: "SOC-PRESSURE",
                variant: "urgency"
            )
        )

        XCTAssertEqual(record.scenarioCatalogVersion, "catalog-v1")
        XCTAssertEqual(record.baseScenarioID, "SOC-PRESSURE")
        XCTAssertEqual(record.scenarioVariant, "urgency")
    }


    func testMakeRecordPreservesClarificationContribution() {
        let logger = EvaluationLogger()
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: ""),
            classification: .suspicious,
            riskScore: 80,
            reasons: ["The user did not initiate the exact request."]
        )
        let history = [ClarificationEvent(
            questionKind: .initiation,
            prompt: "Did you start this exact request?",
            answer: InitiationStatus.no.rawValue
        )]
        let preliminaryResult = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: ""),
            classification: .uncertain,
            riskScore: 0,
            reasons: ["More context is needed."]
        )

        let record = logger.makeRecord(
            from: result,
            labels: .empty,
            intent: UserIntent(
                expectedService: nil,
                expectedPurpose: nil,
                initiationStatus: .no,
                displaySource: .unknown,
                startedOnReceivingClient: .no,
                notes: ""
            ),
            preliminaryResult: preliminaryResult,
            preliminaryClassification: .uncertain,
            clarificationHistory: history,
            clarificationAnswerSource: .scenarioControlled,
            clarificationPolicy: .researcher
        )

        XCTAssertEqual(record.preliminaryClassification, .uncertain)
        XCTAssertTrue(record.clarificationChangedClassification)
        XCTAssertTrue(record.clarificationChangedRecommendedAction)
        XCTAssertEqual(record.preliminaryInterventionStyle, .caution)
        XCTAssertEqual(record.interventionStyle, .activeWarning)
        XCTAssertEqual(record.clarificationPolicy, .researcher)
        XCTAssertEqual(record.clarificationQuestions.count, 1)
        XCTAssertEqual(record.clarificationAnswers, ["INITIATION: NO"])
        XCTAssertEqual(record.clarificationAnswerSource, .scenarioControlled)
        XCTAssertEqual(record.initiationStatus, "NO")
    }

    func testDatasetExportContainsMultipleRecordsAndOneHeader() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let logger = EvaluationLogger(exportDirectory: directory)
        let first = makeMinimalRecord(testId: "T001")
        let second = makeMinimalRecord(testId: "T002")

        let url = try logger.exportCSV(records: [first, second])
        let csv = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(csv.components(separatedBy: "\n").filter { !$0.isEmpty }.count, 3)
        XCTAssertFalse(csv.contains("\"timestamp\""))
        XCTAssertTrue(csv.contains("\"T001\""))
        XCTAssertTrue(csv.contains("\"T002\""))
    }

    func testDatasetExportRejectsEmptyCollection() {
        let logger = EvaluationLogger()

        XCTAssertThrowsError(try logger.exportCSV(records: [])) { error in
            XCTAssertEqual(error as? EvaluationLoggerError, .noRecords)
        }
    }

    func testNormalizedExportCreatesFourLinkedTablesWithControlledRedactedOCR() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let logger = EvaluationLogger(exportDirectory: directory)
        let rule = ClassificationRuleResult(
            ruleIdentifier: "urgency_and_coercion",
            severity: .strong,
            polarity: .negative,
            evidenceCategory: .persuasion,
            riskContribution: 60,
            completenessContribution: 0,
            reason: "Coercive language was detected.",
            evidence: ["THREAT"],
            triggersSuspiciousOverride: true
        )
        let result = ScanResult(
            visualContext: VisualContext(
                qrDetected: true,
                ocrText: "private full OCR transcript",
                visibleDomainClaims: ["example.com"],
                authenticationKeywords: ["passkey"]
            ),
            visibleServiceClaims: ["Example"],
            peripheralServiceClaims: ["Peripheral Example"],
            competingContextPresent: true,
            associationResolution: .resolved,
            inferredPurposes: [.signIn],
            socialEngineeringCues: [.threat],
            qrCount: 1,
            qrTypes: [.fido],
            classification: .suspicious,
            riskScore: 60,
            reasons: ["Coercive language was detected."],
            ruleResults: [rule],
            spatialEvidence: [SpatialTextEvidence(
                observationId: "O1",
                text: "account under threat for person@example.com",
                confidence: 0.95,
                boundingBox: NormalizedBoundingBox(x: 0.2, y: 0.7, width: 0.5, height: 0.08),
                associatedQRCodeIndex: 0,
                associatedQRCodeBoundingBox: NormalizedBoundingBox(x: 0.3, y: 0.3, width: 0.3, height: 0.3),
                sourceRegion: .qrSurrounding,
                normalizedDistanceToQRCode: 0.02,
                proximity: .near,
                contextZone: .primary,
                associationStrength: .strong,
                semanticRole: .qrLocal,
                isNearQRCode: true
            )],
            visualClaims: [VisualClaimEvidence(
                kind: .socialEngineering,
                value: SocialEngineeringCue.threat.rawValue,
                sourceObservationId: "O1",
                ocrConfidence: 0.95,
                contextZone: .primary,
                associationStrength: .strong,
                semanticRole: .qrLocal
            )],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: false,
                issues: [.qrTooSmall]
            )
        )
        let ablation = AblationComparison(
            family: .socialEngineering,
            baselineClassification: .suspicious,
            ablatedClassification: .uncertain,
            baselineRiskScore: 60,
            ablatedRiskScore: 0,
            baselineCompleteness: 30,
            ablatedCompleteness: 30,
            removedTriggeredRules: ["urgency_and_coercion"]
        )
        let record = logger.makeRecord(
            from: result,
            labels: EvaluationLabels(
                testId: "NORMALIZED-01",
                scenarioGroundTruth: .suspicious,
                lightingCondition: .normal,
                angleCondition: .straight,
                distanceCondition: .close,
                displayOS: .windows,
                displayBrowser: .chrome,
                presentationType: .fullContext,
                clutterCondition: .competing,
                cropCondition: .partial,
                contextType: .mismatching,
                detectabilityBoundary: .visiblePersuasion,
                notes: "",
                failureAttribution: .contextAssociation,
                captureConditionPreset: .baseline
            ),
            scenarioProvenance: EvaluationScenarioProvenance(
                catalogVersion: ControlledEvaluationFixtureCatalog.version,
                baseScenarioID: "PERSUASION",
                variant: "M09"
            ),
            applicationMode: .researcher,
            scenarioMetadataConfirmed: true,
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed,
            ocrObservationCount: 1,
            ablationComparisons: [ablation]
        )

        let tables = logger.normalizedCSVStrings(for: [record])
        let urls = try logger.exportNormalizedCSVs(records: [record])

        XCTAssertEqual(record.competingContextPresent, true)
        XCTAssertEqual(record.associationResolution, .resolved)
        XCTAssertEqual(record.associationAmbiguous, false)
        XCTAssertEqual(record.ocrObservationCount, 1)
        XCTAssertEqual(record.structuredSpatialObservations?.count, 1)
        XCTAssertEqual(record.primaryVisualTriggeredRuleId, "urgency_and_coercion")
        XCTAssertEqual(record.primaryTriggeredRuleId, "urgency_and_coercion")
        XCTAssertEqual(Set(tables.keys), Set([
            "scans.csv", "rule-trace.csv", "observations.csv", "ablations.csv"
        ]))
        XCTAssertEqual(Set(urls.map(\.lastPathComponent)), Set(tables.keys))
        XCTAssertTrue(tables["scans.csv"]?.contains("\"NORMALIZED-01\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"displayOS\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"WINDOWS\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"COMPETING\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"qrType\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"FIDO\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"qrProcessingStatus\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"ocrProcessingStatus\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"rawOCRObservationCount\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"exportedObservationCount\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"ocrObservationCount\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"imageQualityIssues\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"QR_TOO_SMALL\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"serviceCatalogVersion\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"gitCommit\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"gitWorkingTreeDirty\"") == true)
        for removedColumn in [
            "timestamp", "scenarioCatalogVersion", "exportSchemaVersion",
            "classifierVersion", "ruleSetVersion", "associationModelVersion", "appVersion"
        ] {
            XCTAssertFalse(tables["scans.csv"]?.contains("\"\(removedColumn)\"") == true)
        }
        XCTAssertFalse(tables["scans.csv"]?.contains("\"expectedServiceProfileID\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"presentedServiceProfileID\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"scenarioMetadataConfirmed\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"clarificationAsked\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"clarificationQuestions\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"clarificationAnswers\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"datasetSplit\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"clarificationPolicy\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"clarificationQuestionKinds\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"clarificationAnswerValues\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"clarificationAnswerSource\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"clarificationChangedClassification\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"associationAmbiguous\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"competingContextPresent\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"associationResolution\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"RESOLVED\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"strongOverrideFired\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"primaryVisualTriggeredRuleId\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"urgency_and_coercion\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"failureStage\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"errorCategory\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"failureAttribution\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"CONTEXT_ASSOCIATION\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"captureConditionPreset\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"scenarioReceivingClientContext\"") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("\"BASELINE\"") == true)
        XCTAssertTrue(tables["rule-trace.csv"]?.contains("\"urgency_and_coercion\"") == true)
        XCTAssertTrue(tables["rule-trace.csv"]?.contains("\"O1\"") == true)
        XCTAssertTrue(tables["rule-trace.csv"]?.contains("\"testId\"") == true)
        XCTAssertTrue(tables["rule-trace.csv"]?.contains("\"NORMALIZED-01\"") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("\"O1\"") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("\"testId\"") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("\"NORMALIZED-01\"") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("SOCIAL:THREAT") == true)
        XCTAssertFalse(tables["observations.csv"]?.contains("textFingerprint") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("recognizedText") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("associationRole") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("QR_LOCAL") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("[redacted]@example.com") == true)
        XCTAssertFalse(tables["observations.csv"]?.contains("person@example.com") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("visualClassification") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("visualRiskScore") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("purposeState") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("IDENTIFIED") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("preClarificationInterventionClassification") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("finalClassification") == true)
        XCTAssertTrue(tables["scans.csv"]?.contains("combinedRiskScore") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"preliminaryClassification\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"classification\"") == true)
        XCTAssertFalse(tables["scans.csv"]?.contains("\"riskScore\"") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("associatedQRCodeId") == true)
        XCTAssertTrue(tables["observations.csv"]?.contains("\"Q1\"") == true)
        XCTAssertTrue(tables["ablations.csv"]?.contains("\"SOCIAL_ENGINEERING\"") == true)
        XCTAssertTrue(tables["ablations.csv"]?.contains("\"testId\"") == true)
        XCTAssertTrue(tables["ablations.csv"]?.contains("\"NORMALIZED-01\"") == true)
        XCTAssertFalse(tables["observations.csv"]?.contains("private full OCR transcript") == true)
        XCTAssertEqual(urls.compactMap { try? String(contentsOf: $0) }.count, 4)
    }

    func testNormalizedExportRejectsEmptyDataset() {
        XCTAssertThrowsError(
            try EvaluationLogger().exportNormalizedCSVs(records: [])
        ) { error in
            XCTAssertEqual(error as? EvaluationLoggerError, .noRecords)
        }
    }

    func testEvaluationRecordStorePersistsAndRestoresVersionedDataset() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("records.json")
        let store = EvaluationRecordStore(fileURL: fileURL)
        let records = [makeMinimalRecord(testId: "PERSIST-01")]

        try store.save(records)

        XCTAssertEqual(try store.load(), records)
        let data = try Data(contentsOf: fileURL)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(
            object["schemaVersion"] as? Int,
            EvaluationDatasetEnvelope.currentSchemaVersion
        )
    }

    func testEvaluationRecordStoreClearDeletesSavedDataset() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("records.json")
        let store = EvaluationRecordStore(fileURL: fileURL)
        try store.save([makeMinimalRecord(testId: "DELETE-01")])

        try store.clear()

        XCTAssertEqual(try store.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testEvaluationRecordStoreRejectsUnknownSchemaVersion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent("records.json")
        let data = try JSONEncoder().encode(EvaluationDatasetEnvelope(
            schemaVersion: 999,
            records: []
        ))
        try data.write(to: fileURL)

        XCTAssertThrowsError(try EvaluationRecordStore(fileURL: fileURL).load()) {
            XCTAssertEqual(
                $0 as? EvaluationRecordStoreError,
                .unsupportedSchemaVersion(999)
            )
        }
    }

    func testEvaluationMetricsBuildsThreeClassConfusionMatrix() {
        let records = [
            makeMetricsRecord(groundTruth: .suspicious, prediction: .suspicious),
            makeMetricsRecord(groundTruth: .suspicious, prediction: .consistent),
            makeMetricsRecord(groundTruth: .consistent, prediction: .consistent),
            makeMetricsRecord(groundTruth: .consistent, prediction: .suspicious),
            makeMetricsRecord(groundTruth: .uncertain, prediction: .uncertain),
            makeMetricsRecord(groundTruth: .notAssigned, prediction: .suspicious)
        ]

        let summary = EvaluationMetricsCalculator().calculate(records: records)

        XCTAssertEqual(summary.includedRecordCount, 5)
        XCTAssertEqual(summary.excludedRecordCount, 1)
        XCTAssertEqual(summary.confusionMatrix.count(actual: .suspicious, predicted: .suspicious), 1)
        XCTAssertEqual(summary.confusionMatrix.count(actual: .suspicious, predicted: .consistent), 1)
        XCTAssertEqual(summary.confusionMatrix.count(actual: .consistent, predicted: .suspicious), 1)
        XCTAssertEqual(summary.confusionMatrix.count(actual: .uncertain, predicted: .uncertain), 1)
        XCTAssertEqual(try! XCTUnwrap(summary.accuracy), 0.6, accuracy: 0.0001)
        XCTAssertEqual(try! XCTUnwrap(summary.suspiciousFalseNegativeRate), 0.5, accuracy: 0.0001)
        XCTAssertEqual(try! XCTUnwrap(summary.consistentFalsePositiveRate), 0.5, accuracy: 0.0001)
    }

    func testEvaluationMetricsReportsPerClassPrecisionRecallAndF1() {
        let records = [
            makeMetricsRecord(groundTruth: .suspicious, prediction: .suspicious),
            makeMetricsRecord(groundTruth: .suspicious, prediction: .uncertain),
            makeMetricsRecord(groundTruth: .consistent, prediction: .suspicious),
            makeMetricsRecord(groundTruth: .uncertain, prediction: .uncertain)
        ]

        let summary = EvaluationMetricsCalculator().calculate(records: records)
        let suspicious = try! XCTUnwrap(summary.perClass.first { $0.classification == .suspicious })

        XCTAssertEqual(suspicious.support, 2)
        XCTAssertEqual(try! XCTUnwrap(suspicious.precision), 0.5, accuracy: 0.0001)
        XCTAssertEqual(try! XCTUnwrap(suspicious.recall), 0.5, accuracy: 0.0001)
        XCTAssertEqual(try! XCTUnwrap(suspicious.f1Score), 0.5, accuracy: 0.0001)
    }

    func testEvaluationMetricsKeepsUndefinedRatesNil() {
        let summary = EvaluationMetricsCalculator().calculate(records: [
            makeMetricsRecord(groundTruth: .notAssigned, prediction: .consistent)
        ])

        XCTAssertEqual(summary.includedRecordCount, 0)
        XCTAssertEqual(summary.excludedRecordCount, 1)
        XCTAssertNil(summary.accuracy)
        XCTAssertNil(summary.suspiciousFalseNegativeRate)
        XCTAssertNil(summary.consistentFalsePositiveRate)
        XCTAssertTrue(summary.perClass.allSatisfy { $0.precision == nil && $0.recall == nil })
    }

    func testFactualPolicyOverridesConflictingLegacyClassForMetrics() {
        let truth = ScenarioFactualGroundTruth(
            securityType: .misleading,
            visualDetectability: .clearlyDetectable,
            captureQuality: .sufficient,
            service: "Google",
            presentedService: "Microsoft",
            purpose: .signIn,
            presentedPurpose: .signIn,
            initiated: .unsure,
            receivingClientOwner: .unknown,
            detectableSignals: [.identityContradiction]
        )
        let record = makeMetricsRecord(
            groundTruth: .consistent,
            prediction: .suspicious,
            factualTruth: truth
        )

        let targets = EvaluationGroundTruthPolicy().targets(for: record)
        let summary = EvaluationMetricsCalculator().calculate(records: [record])

        XCTAssertEqual(targets.source, .factualPolicy)
        XCTAssertEqual(targets.combinedSecurity, .suspicious)
        XCTAssertEqual(summary.factualPolicyRecordCount, 1)
        XCTAssertEqual(summary.legacyFallbackRecordCount, 0)
        XCTAssertEqual(summary.accuracy, 1)
    }

    func testVisuallyIndistinguishableAttackIsExcludedFromVisualConfusionMatrix() {
        var truth = ScenarioFactualGroundTruth.notAssigned
        truth.securityType = .misleading
        truth.visualDetectability = .visuallyIndistinguishable
        truth.captureQuality = .sufficient
        truth.initiated = .no
        truth.receivingClientOwner = .attacker
        let record = makeMetricsRecord(
            groundTruth: .suspicious,
            prediction: .suspicious,
            factualTruth: truth,
            preliminaryPrediction: .uncertain
        )

        let targets = EvaluationGroundTruthPolicy().targets(for: record)
        let combined = EvaluationMetricsCalculator().calculate(records: [record])
        let visual = EvaluationMetricsCalculator().calculate(
            records: [record],
            targetKind: .visualOnly,
            predictionStage: .preliminary
        )

        XCTAssertEqual(targets.combinedSecurity, .suspicious)
        XCTAssertNil(targets.visualOnly)
        XCTAssertEqual(combined.accuracy, 1)
        XCTAssertEqual(visual.includedRecordCount, 0)
        XCTAssertEqual(visual.excludedRecordCount, 1)
    }

    func testAttackCoverageSeparatesDetectableSensitivityFromOverallCoverage() {
        var detectable = ScenarioFactualGroundTruth.notAssigned
        detectable.securityType = .misleading
        detectable.visualDetectability = .clearlyDetectable
        detectable.captureQuality = .sufficient

        var hidden = detectable
        hidden.visualDetectability = .visuallyIndistinguishable

        let records = [
            makeMetricsRecord(
                groundTruth: .suspicious,
                prediction: .suspicious,
                factualTruth: detectable,
                preliminaryPrediction: .suspicious
            ),
            makeMetricsRecord(
                groundTruth: .suspicious,
                prediction: .suspicious,
                factualTruth: hidden,
                preliminaryPrediction: .consistent
            )
        ]

        let summary = EvaluationAttackCoverageCalculator().calculate(records: records)

        XCTAssertEqual(summary.detectableMaliciousCount, 1)
        XCTAssertEqual(summary.detectableSuspiciousCount, 1)
        XCTAssertEqual(summary.detectableCaseSensitivity, 1)
        XCTAssertEqual(summary.overallMaliciousCount, 2)
        XCTAssertEqual(summary.overallSuspiciousCount, 1)
        XCTAssertEqual(summary.overallAttackCoverage, 0.5)
        XCTAssertEqual(summary.visuallyIndistinguishableCount, 1)
    }

    func testControlledScenarioCatalogCoversEveryRequiredFamily() {
        XCTAssertTrue(ControlledEvaluationScenarioCatalog.validationProblems.isEmpty)
        XCTAssertEqual(
            Set(ControlledEvaluationScenarioCatalog.scenarios.map(\.family)),
            Set(EvaluationScenarioFamily.allCases)
        )
    }

    func testControlledScenarioCatalogAssignsIndependentFactualTruth() throws {
        let legitimate = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first {
                $0.family == .legitimateExplicit
            }
        )
        let attackerSession = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first {
                $0.family == .visuallyIndistinguishableAttack
            }
        )

        XCTAssertEqual(legitimate.factualGroundTruth.securityType, .benign)
        XCTAssertEqual(legitimate.factualGroundTruth.initiated, .yes)
        XCTAssertEqual(attackerSession.factualGroundTruth.securityType, .misleading)
        XCTAssertEqual(
            attackerSession.factualGroundTruth.visualDetectability,
            .visuallyIndistinguishable
        )
        XCTAssertEqual(attackerSession.factualGroundTruth.initiated, .no)
        XCTAssertEqual(attackerSession.factualGroundTruth.receivingClientOwner, .attacker)
    }

    func testControlledScenarioConditionDefaultsReflectVariantWithoutInventingPlatform() {
        let blur = ControlledEvaluationScenarioCatalog.conditionDefaults(
            scenarioID: "CAPTURE-QUALITY",
            variant: "blur"
        )
        XCTAssertEqual(blur.blur, .severe)
        XCTAssertEqual(blur.lighting, .normal)
        XCTAssertEqual(blur.displayOS, .unknown)
        XCTAssertEqual(blur.displayBrowser, .unknown)

        let email = ControlledEvaluationScenarioCatalog.conditionDefaults(
            scenarioID: "CHANNELS",
            variant: "email"
        )
        XCTAssertEqual(email.presentation, .ambiguousContext)
        XCTAssertEqual(email.clutter, .competing)
    }

    func testScenarioClarificationScriptUsesPredefinedFacts() {
        var truth = ScenarioFactualGroundTruth.notAssigned
        truth.securityType = .benign
        truth.service = "Chase"
        truth.purpose = .signIn
        truth.initiated = .yes
        truth.receivingClientOwner = .user
        let script = ScenarioClarificationScript()

        XCTAssertEqual(script.confirmationAnswer(for: .confirmService("chase"), truth: truth), .yes)
        XCTAssertEqual(script.confirmationAnswer(for: .confirmService("Google"), truth: truth), .no)
        XCTAssertEqual(script.confirmationAnswer(for: .confirmPurpose(.signIn), truth: truth), .yes)
        XCTAssertEqual(script.confirmationAnswer(for: .confirmPurpose(.payment), truth: truth), .no)
        XCTAssertEqual(script.confirmationAnswer(for: .exactInitiation, truth: truth), .yes)
        XCTAssertEqual(script.receivingClientRelationship(for: truth.receivingClientOwner), .ownDevice)
    }

    func testScenarioClarificationScriptMapsAttackerOwnedClientToUntrustedDevice() {
        let relationship = ScenarioClarificationScript().receivingClientRelationship(
            for: .attacker
        )
        XCTAssertEqual(relationship, .someoneElsesDevice)
    }

    func testUnintendedSessionFixturesDoNotAssertAttackerOwnership() throws {
        let wrongSession = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: "U04"))
        XCTAssertEqual(wrongSession.receivingClientOwner, .unknown)
        XCTAssertEqual(wrongSession.receivingClientContext, .unintendedOrWrongSession)

        let unintended = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: "U05"))
        XCTAssertEqual(unintended.receivingClientOwner, .unknown)
        XCTAssertEqual(unintended.receivingClientContext, .unintended)

        XCTAssertEqual(
            ScenarioClarificationScript().receivingClientRelationship(for: wrongSession.scenarioFactualGroundTruth),
            .unknown
        )
        XCTAssertEqual(
            ScenarioClarificationScript().receivingClientRelationship(for: unintended.scenarioFactualGroundTruth),
            .unknown
        )
    }

    func testExplicitUnintendedSessionContextCompletesTruthWithoutKnownOwner() throws {
        let fixture = try XCTUnwrap(ControlledEvaluationFixtureCatalog.fixture(id: "U04"))
        var labels = completeFinalEvaluationLabels()
        labels.scenarioGroundTruth = .suspicious
        labels.factualGroundTruth = fixture.scenarioFactualGroundTruth

        let issues = EvaluationRecordValidator().validate(
            labels: labels,
            selectedScenarioID: fixture.baseScenarioID,
            selectedScenarioVariant: fixture.id,
            existingTestIDs: [],
            analysisCompleted: true,
            scenarioMetadataConfirmed: true
        )

        XCTAssertFalse(issues.contains { $0.code == .incompleteFactualGroundTruth })
    }

    @MainActor
    func testNonConflictScenarioUsesSameExpectedAndPresentedServiceProfile() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        let scenario = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first {
                $0.family == .legitimateExplicit
            }
        )
        viewModel.selectControlledScenario(id: scenario.id)
        viewModel.selectExpectedServiceProfile("GITHUB")

        XCTAssertEqual(viewModel.evaluationLabels.expectedServiceProfileID, "GITHUB")
        XCTAssertEqual(viewModel.evaluationLabels.presentedServiceProfileID, "GITHUB")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.service, "GitHub")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.presentedService, "GitHub")
    }

    func testVisuallyIndistinguishableAttackRetainsSecurityGroundTruth() throws {
        let scenario = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first {
                $0.family == .visuallyIndistinguishableAttack
            }
        )

        XCTAssertEqual(scenario.groundTruth, .suspicious)
        XCTAssertEqual(
            scenario.detectabilityBoundary,
            .visuallyIndistinguishableSessionAttack
        )
        XCTAssertTrue(scenario.rationale.contains("scanner limitation"))
    }

    @MainActor
    func testSelectingControlledScenarioPopulatesIndependentLabels() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        let scenario = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first {
                $0.family == .identityConflict
            }
        )

        viewModel.evaluationLabels.lightingCondition = .glare
        viewModel.evaluationLabels.angleCondition = .steepAngle
        viewModel.evaluationLabels.notes = "Retain evaluator note"
        viewModel.selectControlledScenario(id: scenario.id)

        XCTAssertEqual(viewModel.selectedControlledScenario, scenario)
        XCTAssertEqual(viewModel.evaluationLabels.testId, scenario.id)
        XCTAssertEqual(viewModel.evaluationLabels.scenarioGroundTruth, scenario.groundTruth)
        XCTAssertEqual(viewModel.evaluationLabels.contextType, scenario.contextType)
        XCTAssertEqual(
            viewModel.evaluationLabels.detectabilityBoundary,
            scenario.detectabilityBoundary
        )
        XCTAssertEqual(viewModel.evaluationLabels.lightingCondition, .glare)
        XCTAssertEqual(viewModel.evaluationLabels.angleCondition, .steepAngle)
        XCTAssertEqual(viewModel.evaluationLabels.notes, "Retain evaluator note")
        XCTAssertEqual(viewModel.evaluationScenarioProvenance.catalogVersion, ControlledEvaluationScenarioCatalog.version)
        XCTAssertEqual(viewModel.evaluationScenarioProvenance.baseScenarioID, scenario.id)
        XCTAssertEqual(viewModel.evaluationScenarioProvenance.variant, "")

        let variant = try XCTUnwrap(scenario.requiredVariants.first)
        viewModel.selectControlledVariant(variant)
        XCTAssertEqual(viewModel.evaluationScenarioProvenance.variant, variant)
        XCTAssertEqual(viewModel.evaluationLabels.runNumber, "1")
        XCTAssertEqual(viewModel.evaluationLabels.captureAttempt, "1")
        XCTAssertTrue(viewModel.evaluationLabels.testId.contains(scenario.id))
        XCTAssertTrue(viewModel.evaluationLabels.testId.contains("R1-C1"))
        XCTAssertEqual(viewModel.evaluationLabels.presentationType, .fullContext)
        XCTAssertEqual(viewModel.evaluationLabels.clutterCondition, .clean)
        XCTAssertEqual(viewModel.evaluationLabels.cropCondition, .none)
        XCTAssertEqual(viewModel.evaluationLabels.blurCondition, .none)
        XCTAssertEqual(viewModel.evaluationLabels.associationCondition, .competingRelevant)

        viewModel.selectExpectedServiceProfile("GOOGLE")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.service, "Google")
        XCTAssertEqual(viewModel.evaluationLabels.presentedServiceProfileID, "")
        viewModel.selectPresentedServiceProfile("MICROSOFT")
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.presentedService, "Microsoft")
        XCTAssertTrue(viewModel.evaluationLabels.testId.contains("GOOGLE"))
        XCTAssertEqual(viewModel.evaluationLabels.matchedStimulusID, "ID-CONFLICT-GOOGLE-PAIR")
    }

    @MainActor
    func testManualScenarioSelectionDoesNotEraseExistingLabels() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.evaluationLabels.testId = "PILOT-01"
        viewModel.evaluationLabels.scenarioGroundTruth = .notAssigned

        viewModel.selectControlledScenario(id: "")

        XCTAssertNil(viewModel.selectedControlledScenario)
        XCTAssertEqual(viewModel.evaluationLabels.testId, "PILOT-01")
        XCTAssertEqual(viewModel.evaluationLabels.scenarioGroundTruth, .notAssigned)
        XCTAssertEqual(viewModel.evaluationScenarioProvenance, .manual)
    }

    func testEvaluationValidatorBlocksMissingAndDuplicateTestIDs() {
        let validator = EvaluationRecordValidator()
        var labels = EvaluationLabels.empty

        var issues = validator.validate(
            labels: labels,
            selectedScenarioID: "",
            existingTestIDs: []
        )
        XCTAssertTrue(issues.contains { $0.code == .missingTestID && $0.severity == .error })

        labels.testId = " run-01 "
        issues = validator.validate(
            labels: labels,
            selectedScenarioID: "",
            existingTestIDs: ["RUN-01"]
        )
        XCTAssertTrue(issues.contains { $0.code == .duplicateTestID && $0.severity == .error })
    }

    func testEvaluationValidatorWarnsWithoutBlockingExploratoryRecords() {
        let issues = EvaluationRecordValidator().validate(
            labels: EvaluationLabels(
                testId: "PILOT-01",
                scenarioGroundTruth: .notAssigned,
                lightingCondition: .unknown,
                angleCondition: .unknown,
                distanceCondition: .unknown,
                contextType: .unknown,
                detectabilityBoundary: .notAssigned,
                notes: ""
            ),
            selectedScenarioID: "",
            existingTestIDs: []
        )

        XCTAssertFalse(issues.contains { $0.severity == .error })
        XCTAssertTrue(issues.contains { $0.code == .groundTruthNotAssigned })
        XCTAssertTrue(issues.contains { $0.code == .unknownCaptureConditions })
        XCTAssertFalse(issues.contains { $0.code == .unknownDisplayConditions })
    }

    func testFinalEvaluationValidationBlocksIncompleteScenarioFactsButNotBuildMetadata() {
        var labels = EvaluationLabels.empty
        labels.testId = "FINAL-01"
        labels.datasetSplit = .finalEvaluation
        labels.runNumber = "1"
        labels.captureAttempt = "1"

        let issues = EvaluationRecordValidator().validate(
            labels: labels,
            selectedScenarioID: "LEG-EXPLICIT",
            selectedScenarioVariant: "login_page",
            existingTestIDs: [],
            analysisCompleted: true
        )

        XCTAssertTrue(issues.contains {
            $0.code == .incompleteFactualGroundTruth && $0.severity == .error
        })
        XCTAssertFalse(issues.contains {
            $0.message.localizedCaseInsensitiveContains("git") ||
                $0.message.localizedCaseInsensitiveContains("app version")
        })
        XCTAssertTrue(issues.contains {
            $0.code == .unknownCaptureConditions && $0.severity == .error
        })
        XCTAssertTrue(issues.contains {
            $0.code == .unknownDisplayConditions && $0.severity == .error
        })
        XCTAssertTrue(issues.contains {
            $0.code == .scenarioMetadataNotConfirmed && $0.severity == .error
        })
        XCTAssertTrue(issues.contains {
            $0.code == .missingMatchedStimulus && $0.severity == .error
        })
        XCTAssertTrue(issues.contains {
            $0.code == .missingAssociationCondition && $0.severity == .error
        })
    }

    func testFinalEvaluationValidationRequiresMetadataConfirmationAfterAnalysis() {
        let issues = EvaluationRecordValidator().validate(
            labels: completeFinalEvaluationLabels(),
            selectedScenarioID: "LEG-CHASE",
            selectedScenarioVariant: "login_page",
            existingTestIDs: [],
            analysisCompleted: true,
            scenarioMetadataConfirmed: false
        )

        XCTAssertTrue(issues.contains {
            $0.code == .scenarioMetadataNotConfirmed && $0.severity == .error
        })
    }

    @MainActor
    func testEditingMetadataResetsScenarioConfirmation() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        let scenario = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first { $0.id == "LEG-EXPLICIT" }
        )
        viewModel.selectControlledScenario(id: scenario.id)
        viewModel.evaluationLabels.datasetSplit = .finalEvaluation
        viewModel.confirmScenarioMetadata()
        XCTAssertTrue(viewModel.scenarioMetadataConfirmed)

        viewModel.evaluationLabels.notes = "Changed after confirmation"

        XCTAssertFalse(viewModel.scenarioMetadataConfirmed)
    }

    @MainActor
    func testResearcherCanConfirmControlledDevelopmentMetadata() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        let scenario = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first { $0.id == "LEG-EXPLICIT" }
        )
        viewModel.selectControlledScenario(id: scenario.id)
        viewModel.evaluationLabels.datasetSplit = .development

        viewModel.confirmScenarioMetadata()

        XCTAssertTrue(viewModel.scenarioMetadataConfirmed)
    }

    @MainActor
    func testCompetingContextFixtureExposesAndAcceptsMetadataConfirmation() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.selectFixture(id: "C01-0")
        viewModel.evaluationLabels.datasetSplit = .finalEvaluation

        XCTAssertNil(viewModel.selectedControlledScenario)
        XCTAssertTrue(viewModel.hasPredefinedScenarioMetadata)
        XCTAssertTrue(viewModel.shouldShowScenarioConfirmation)

        viewModel.confirmScenarioMetadata()

        XCTAssertTrue(viewModel.scenarioMetadataConfirmed)
    }

    @MainActor
    func testUnassignedDatasetCannotConfirmScenarioMetadata() throws {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        let scenario = try XCTUnwrap(
            ControlledEvaluationScenarioCatalog.scenarios.first { $0.id == "LEG-EXPLICIT" }
        )
        viewModel.selectControlledScenario(id: scenario.id)

        viewModel.confirmScenarioMetadata()

        XCTAssertFalse(viewModel.scenarioMetadataConfirmed)
    }

    @MainActor
    func testNonAuthenticationVariantSetsPresentedPurposeWithoutChangingExpectedPurpose() {
        let viewModel = StaticImageAnalysisViewModel(applicationMode: .researcher)
        viewModel.selectControlledScenario(id: "MIS-NONAUTH")
        viewModel.selectControlledVariant("payment")

        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.purpose, .signIn)
        XCTAssertEqual(viewModel.evaluationLabels.factualGroundTruth.presentedPurpose, .payment)
    }

    func testFinalEvaluationValidationRejectsClarificationThatContradictsTruth() {
        let labels = completeFinalEvaluationLabels()
        let history = [ClarificationEvent(
            questionKind: .initiation,
            prompt: "Did you start this request?",
            answer: "NO"
        )]
        var intent = UserIntent.skipped
        intent.initiationStatus = .no
        intent.startedOnReceivingClient = .no

        let issues = EvaluationRecordValidator().validate(
            labels: labels,
            selectedScenarioID: "LEG-CHASE",
            selectedScenarioVariant: "login_page",
            existingTestIDs: [],
            clarificationHistory: history,
            clarificationAnswerSource: .manual,
            intent: intent,
            analysisCompleted: true
        )

        XCTAssertTrue(issues.contains { $0.code == .invalidClarificationProvenance })
        XCTAssertTrue(issues.contains { $0.code == .clarificationTruthMismatch })
    }

    func testCompleteFinalEvaluationMetadataPassesStrictChecks() {
        let labels = completeFinalEvaluationLabels()
        let history = [ClarificationEvent(
            questionKind: .initiation,
            prompt: "Did you start this request?",
            answer: "YES"
        )]
        var intent = UserIntent.skipped
        intent.initiationStatus = .yes
        intent.startedOnReceivingClient = .yes

        let issues = EvaluationRecordValidator().validate(
            labels: labels,
            selectedScenarioID: "LEG-CHASE",
            selectedScenarioVariant: "login_page",
            existingTestIDs: [],
            clarificationHistory: history,
            clarificationAnswerSource: .scenarioControlled,
            intent: intent,
            analysisCompleted: true,
            scenarioMetadataConfirmed: true
        )

        XCTAssertFalse(issues.contains { $0.severity == .error })
    }

    func testEvaluationValidatorRequestsSuffixForControlledBaseID() {
        var labels = EvaluationLabels.empty
        labels.testId = "ID-CONFLICT"
        labels.scenarioGroundTruth = .suspicious
        labels.lightingCondition = .normal
        labels.angleCondition = .straight
        labels.distanceCondition = .close

        let issues = EvaluationRecordValidator().validate(
            labels: labels,
            selectedScenarioID: "ID-CONFLICT",
            selectedScenarioVariant: "brand_domain",
            existingTestIDs: []
        )

        XCTAssertTrue(issues.contains { $0.code == .baseTestIDNeedsRunSuffix })
    }

    func testEvaluationValidatorBlocksControlledRecordWithMissingVariant() {
        var labels = EvaluationLabels.empty
        labels.testId = "ID-CONFLICT-01"

        let issues = EvaluationRecordValidator().validate(
            labels: labels,
            selectedScenarioID: "ID-CONFLICT",
            selectedScenarioVariant: "",
            existingTestIDs: []
        )

        XCTAssertTrue(issues.contains { $0.code == .missingScenarioVariant })
        XCTAssertTrue(issues.contains {
            $0.code == .missingScenarioVariant && $0.severity == .error
        })
    }

    func testCoverageCountsRequiredVariantsAndRepeatedRuns() {
        let matching = makeProvenanceRecord(
            testId: "ID-CONFLICT-01",
            catalogVersion: ControlledEvaluationScenarioCatalog.version,
            scenarioID: "ID-CONFLICT",
            variant: "brand_domain"
        )
        let repeated = makeProvenanceRecord(
            testId: "ID-CONFLICT-02",
            catalogVersion: ControlledEvaluationScenarioCatalog.version,
            scenarioID: "ID-CONFLICT",
            variant: "brand_domain"
        )
        let manual = makeMinimalRecord(testId: "PILOT-01")
        let oldCatalog = makeProvenanceRecord(
            testId: "OLD-01",
            catalogVersion: "old-version",
            scenarioID: "ID-CONFLICT",
            variant: "expected_service"
        )

        let summary = EvaluationCoverageCalculator().calculate(
            records: [matching, repeated, manual, oldCatalog]
        )
        let covered = summary.variants.first {
            $0.scenarioID == "ID-CONFLICT" && $0.variant == "brand_domain"
        }
        let missing = summary.variants.first {
            $0.scenarioID == "ID-CONFLICT" && $0.variant == "expected_service"
        }

        XCTAssertEqual(covered?.recordCount, 2)
        XCTAssertEqual(missing?.recordCount, 0)
        XCTAssertEqual(summary.coveredVariantCount, 1)
        XCTAssertEqual(summary.excludedRecordCount, 2)
        XCTAssertEqual(summary.missingVariantCount, summary.requiredVariantCount - 1)
    }

    func testAblationRemovesOnlySelectedRuleFamily() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(x: 0.3, y: 0.3, width: 0.3, height: 0.3)
            )],
            ocrObservations: [OCRObservation(
                text: "Act now or your account will be suspended",
                confidence: 0.95,
                boundingBox: NormalizedBoundingBox(x: 0.3, y: 0.62, width: 0.4, height: 0.08),
                region: .qrSurrounding
            )],
            imageQuality: ImageQualityObservation(isSufficientForAnalysis: true, issues: []),
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed
        )
        let comparisons = ContextAblationAnalyzer().analyze(
            observation: observation,
            intent: .skipped,
            policy: .researcher
        )
        let persuasion = comparisons.first { $0.family == .socialEngineering }
        let identity = comparisons.first { $0.family == .identity }

        XCTAssertEqual(persuasion?.baselineClassification, .suspicious)
        XCTAssertEqual(persuasion?.ablatedClassification, .uncertain)
        XCTAssertEqual(persuasion?.removedTriggeredRules, ["urgency_and_coercion"])
        XCTAssertEqual(identity?.baselineRiskScore, identity?.ablatedRiskScore)
        XCTAssertEqual(comparisons.count, AblationSignalFamily.allCases.count)
    }

    func testAssociationComparisonChangesFeatureInputRatherThanOnlyRemovingRules() throws {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(x: 0.35, y: 0.35, width: 0.3, height: 0.3)
            )],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft Sign in with a passkey",
                    confidence: 0.98,
                    boundingBox: NormalizedBoundingBox(x: 0.3, y: 0.67, width: 0.4, height: 0.05),
                    region: .qrSurrounding
                ),
                OCRObservation(
                    text: "Chase chase.com account statement",
                    confidence: 0.98,
                    boundingBox: NormalizedBoundingBox(x: 0.02, y: 0.02, width: 0.25, height: 0.04),
                    region: .fullFrame
                )
            ],
            imageQuality: ImageQualityObservation(isSufficientForAnalysis: true, issues: [])
        )

        let comparison = try XCTUnwrap(
            ContextAblationAnalyzer().analyze(
                observation: observation,
                intent: .skipped,
                policy: .researcher
            ).first { $0.family == .contextAssociationModel }
        )

        XCTAssertEqual(comparison.baselineAssociationPolicy, .spatiallyAssociated)
        XCTAssertEqual(comparison.ablatedAssociationPolicy, .unfilteredVisualText)
        XCTAssertNotEqual(comparison.baselineRiskScore, comparison.ablatedRiskScore)
        XCTAssertTrue(comparison.removedTriggeredRules.isEmpty)
    }

    private func makeMinimalRecord(testId: String) -> EvaluationRecord {
        EvaluationLogger().makeRecord(
            from: ScanResult(
                visualContext: VisualContext(qrDetected: true, ocrText: "passkey"),
                classification: .uncertain,
                riskScore: 10,
                reasons: ["More context is needed."]
            ),
            labels: EvaluationLabels(
                testId: testId,
                scenarioGroundTruth: .notAssigned,
                lightingCondition: .normal,
                angleCondition: .straight,
                distanceCondition: .close,
                contextType: .ambiguous,
                detectabilityBoundary: .insufficientVisualEvidence,
                notes: ""
            )
        )
    }

    private func completeFinalEvaluationLabels() -> EvaluationLabels {
        EvaluationLabels(
            testId: "LEG-CHASE-LOGIN-PAGE-R1-C1",
            scenarioGroundTruth: .consistent,
            lightingCondition: .normal,
            angleCondition: .straight,
            distanceCondition: .medium,
            displayOS: .macOS,
            displayBrowser: .safari,
            presentationType: .fullContext,
            clutterCondition: .clean,
            cropCondition: .none,
            blurCondition: .none,
            contextType: .matching,
            detectabilityBoundary: .visibleConsistentEvidence,
            notes: "",
            datasetSplit: .finalEvaluation,
            runNumber: "1",
            captureAttempt: "1",
            factualGroundTruth: ScenarioFactualGroundTruth(
                securityType: .benign,
                visualDetectability: .clearlyDetectable,
                captureQuality: .sufficient,
                service: "Chase",
                presentedService: "Chase",
                purpose: .signIn,
                presentedPurpose: .signIn,
                initiated: .yes,
                receivingClientOwner: .user,
                detectableSignals: [.consistentIdentity]
            ),
            expectedServiceProfileID: "CHASE",
            presentedServiceProfileID: "CHASE",
            matchedStimulusID: "LEG-CHASE-PAIR-01",
            associationCondition: .clean
        )
    }

    private func makeProvenanceRecord(
        testId: String,
        catalogVersion: String,
        scenarioID: String,
        variant: String
    ) -> EvaluationRecord {
        EvaluationLogger().makeRecord(
            from: ScanResult(
                visualContext: VisualContext(qrDetected: true, ocrText: "passkey"),
                classification: .uncertain,
                riskScore: 0,
                reasons: []
            ),
            labels: EvaluationLabels(
                testId: testId,
                scenarioGroundTruth: .uncertain,
                lightingCondition: .normal,
                angleCondition: .straight,
                distanceCondition: .close,
                contextType: .ambiguous,
                detectabilityBoundary: .insufficientVisualEvidence,
                notes: ""
            ),
            scenarioProvenance: EvaluationScenarioProvenance(
                catalogVersion: catalogVersion,
                baseScenarioID: scenarioID,
                variant: variant
            )
        )
    }

    private func makeMetricsRecord(
        groundTruth: ScenarioGroundTruth,
        prediction: RiskClassification,
        factualTruth: ScenarioFactualGroundTruth = .notAssigned,
        preliminaryPrediction: RiskClassification? = nil
    ) -> EvaluationRecord {
        EvaluationLogger().makeRecord(
            from: ScanResult(
                visualContext: VisualContext(qrDetected: true, ocrText: "passkey"),
                visualClassification: preliminaryPrediction ?? prediction,
                classification: prediction,
                riskScore: 0,
                reasons: []
            ),
            labels: EvaluationLabels(
                testId: UUID().uuidString,
                scenarioGroundTruth: groundTruth,
                lightingCondition: .unknown,
                angleCondition: .unknown,
                distanceCondition: .unknown,
                contextType: .unknown,
                detectabilityBoundary: .notAssigned,
                notes: "",
                factualGroundTruth: factualTruth
            ),
            preliminaryClassification: preliminaryPrediction
        )
    }
}
