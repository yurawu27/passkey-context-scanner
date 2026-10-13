import AVFoundation
import XCTest
import UIKit
@testable import PasskeyContextScanner

@MainActor
final class LiveScannerViewModelTests: XCTestCase {
    func testCaptureUsesSharedAnalysisAndClassifierPipeline() async {
        let camera = CameraCaptureStub()
        let observation = clearPasskeyObservation()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(observation: observation)
        )
        viewModel.userIntent = UserIntent(
            expectedService: "Microsoft",
            expectedPurpose: .signIn,
            initiationStatus: .yes,
            displaySource: .ownDevice,
            receivingClientRelationship: .ownDevice,
            startedOnReceivingClient: .yes,
            receivingClientTrust: .yes,
            notes: ""
        )

        await viewModel.captureAndAnalyze()

        XCTAssertEqual(camera.captureCalls, 1)
        XCTAssertEqual(camera.stopCalls, 1)
        XCTAssertEqual(viewModel.result?.classification, .consistent)
        XCTAssertFalse(viewModel.isAnalyzing)
    }

    func testCaptureStillAnalysesFrameWithoutLiveMetadataDetection() async {
        let camera = CameraCaptureStub()
        camera.detectedQRCodes = []
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            )
        )

        await viewModel.captureAndAnalyze()

        XCTAssertEqual(camera.captureCalls, 1)
        XCTAssertNotNil(viewModel.clarificationQuestion)
    }

    func testScanFirstFlowAsksOnlyAdaptiveClarifications() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            ),
            clarificationPolicy: .researcher
        )

        await viewModel.captureAndAnalyze()

        XCTAssertEqual(viewModel.clarificationQuestion, .exactInitiation)
        XCTAssertNil(viewModel.result)

        viewModel.answerConfirmation(.yes)
        XCTAssertEqual(viewModel.clarificationQuestion, .receivingComputer)

        viewModel.answerReceivingComputer(.ownDevice)
        XCTAssertEqual(viewModel.clarificationQuestion, .confirmService("Microsoft"))

        viewModel.answerConfirmation(.yes)
        XCTAssertEqual(viewModel.clarificationQuestion, .confirmPurpose(.signIn))

        viewModel.answerConfirmation(.yes)
        XCTAssertNil(viewModel.clarificationQuestion)
        XCTAssertEqual(viewModel.result?.classification, .consistent)
    }

    func testNotStartingExactRequestStopsClarificationImmediately() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            ),
            clarificationPolicy: .researcher
        )

        await viewModel.captureAndAnalyze()
        XCTAssertEqual(viewModel.clarificationQuestion, .exactInitiation)

        viewModel.answerConfirmation(.no)

        XCTAssertNil(viewModel.clarificationQuestion)
        XCTAssertEqual(viewModel.result?.classification, .suspicious)
    }

    func testRejectingDetectedServiceProducesSuspiciousResultImmediately() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            ),
            clarificationPolicy: .researcher
        )

        await viewModel.captureAndAnalyze()
        viewModel.answerConfirmation(.yes)
        viewModel.answerReceivingComputer(.ownDevice)
        XCTAssertEqual(viewModel.clarificationQuestion, .confirmService("Microsoft"))
        viewModel.answerConfirmation(.no)

        XCTAssertNil(viewModel.clarificationQuestion)
        XCTAssertEqual(viewModel.result?.classification, .suspicious)
    }

    func testParticipantFlowStopsAfterOneQuestion() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            )
        )

        await viewModel.captureAndAnalyze()
        XCTAssertEqual(viewModel.clarificationQuestion, .exactInitiation)
        viewModel.answerConfirmation(.yes)

        XCTAssertNil(viewModel.clarificationQuestion)
        XCTAssertNotNil(viewModel.result)
        XCTAssertEqual(viewModel.clarificationHistory.count, 1)
        XCTAssertEqual(viewModel.result?.classification, .consistent)
    }

    func testParticipantPlannerSkipsQuestionThatCannotChangeIntervention() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            )
        )

        await viewModel.captureAndAnalyze()

        XCTAssertEqual(viewModel.clarificationQuestion, .exactInitiation)
    }

    func testParticipantPlannerAsksNothingWhenNoAnswerChangesIntervention() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: nonFidoObservation()
            )
        )
        viewModel.userIntent = UserIntent(
            expectedService: "Microsoft",
            expectedPurpose: .signIn,
            initiationStatus: .unsure,
            displaySource: .ownDevice,
            receivingClientRelationship: .ownDevice,
            startedOnReceivingClient: .unsure,
            receivingClientTrust: .yes,
            visibleServiceMatchesExpectation: .yes,
            visiblePurposeMatchesExpectation: .yes,
            notes: ""
        )

        await viewModel.captureAndAnalyze()

        XCTAssertNil(viewModel.clarificationQuestion)
        XCTAssertEqual(viewModel.result?.classification, .uncertain)
    }

    func testResearcherFlowCanContinueAfterUnsureAnswer() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            ),
            clarificationPolicy: .researcher
        )

        await viewModel.captureAndAnalyze()
        viewModel.answerConfirmation(.unsure)

        XCTAssertEqual(viewModel.clarificationQuestion, .receivingComputer)
    }

    func testCaptureIsIgnoredWhenAnotherCaptureIsInProgress() async {
        let camera = CameraCaptureStub()
        camera.isCapturingPhoto = true
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            )
        )

        await viewModel.captureAndAnalyze()

        XCTAssertEqual(camera.captureCalls, 0)
    }

    func testRescanClearsResultAndRestartsCamera() async {
        let camera = CameraCaptureStub()
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(
                observation: clearPasskeyObservation()
            )
        )
        await viewModel.captureAndAnalyze()
        XCTAssertNotNil(viewModel.clarificationQuestion)

        await viewModel.rescan()

        XCTAssertNil(viewModel.result)
        XCTAssertNil(viewModel.clarificationQuestion)
        XCTAssertEqual(camera.startCalls, 1)
    }

    func testResearcherLiveCaptureUsesSharedEvaluationDatasetAndExport() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = temporaryDirectory.appendingPathComponent("records.json")
        let viewModel = LiveScannerViewModel(
            cameraService: CameraCaptureStub(),
            imageAnalysisService: ImageAnalysisStub(observation: clearPasskeyObservation()),
            clarificationPolicy: .researcher,
            applicationMode: .researcher,
            evaluationLogger: EvaluationLogger(exportDirectory: temporaryDirectory),
            evaluationRecordStore: EvaluationRecordStore(fileURL: storeURL)
        )
        viewModel.selectFixture(id: "L01")
        viewModel.evaluationLabels.datasetSplit = .development
        viewModel.selectCaptureConditionPreset(.glare)

        await viewModel.captureAndAnalyze()
        viewModel.finishWithUnknowns()
        viewModel.addCurrentEvaluationRecord()

        let record = try XCTUnwrap(viewModel.evaluationRecords.first)
        XCTAssertEqual(record.analysisMode, .liveCamera)
        XCTAssertEqual(record.captureConditionPreset, .glare)
        XCTAssertEqual(record.lightingCondition, .glare)
        XCTAssertEqual(record.qrProcessingStatus, .completed)
        XCTAssertEqual(record.ocrProcessingStatus, .completed)
        XCTAssertEqual(record.ocrObservationCount, 2)
        XCTAssertEqual(record.scenarioVariant, "L01")

        viewModel.exportEvaluationDataset()

        XCTAssertEqual(viewModel.normalizedExportURLs.count, 4)
        XCTAssertTrue(viewModel.normalizedExportURLs.contains { $0.lastPathComponent == "scans.csv" })
        XCTAssertTrue(viewModel.normalizedExportURLs.contains { $0.lastPathComponent == "observations.csv" })
        XCTAssertTrue(viewModel.normalizedExportURLs.contains { $0.lastPathComponent == "rule-trace.csv" })
    }

    func testFinalAnalysedLiveFrameWithoutQRCodeCanBeLoggedAsDetectionFailure() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let camera = CameraCaptureStub()
        camera.detectedQRCodes = []
        let viewModel = LiveScannerViewModel(
            cameraService: camera,
            imageAnalysisService: ImageAnalysisStub(observation: noQRCodeObservation()),
            clarificationPolicy: .researcher,
            applicationMode: .researcher,
            evaluationLogger: EvaluationLogger(exportDirectory: temporaryDirectory),
            evaluationRecordStore: EvaluationRecordStore(
                fileURL: temporaryDirectory.appendingPathComponent("records.json")
            )
        )
        viewModel.selectFixture(id: "L01")
        viewModel.evaluationLabels.datasetSplit = .finalEvaluation
        viewModel.selectCaptureConditionPreset(.glare)
        viewModel.confirmScenarioMetadata()

        await viewModel.captureAndAnalyze()
        viewModel.finishWithUnknowns()
        XCTAssertTrue(viewModel.canAddCurrentEvaluationRecord)
        viewModel.addCurrentEvaluationRecord()

        let record = try XCTUnwrap(viewModel.evaluationRecords.first)
        XCTAssertEqual(record.failureStage, .qrDetection)
        XCTAssertEqual(record.qrDetected, .notDetected)
        XCTAssertEqual(record.qrProcessingStatus, .completed)
        XCTAssertEqual(record.ocrProcessingStatus, .completed)
        XCTAssertEqual(record.ocrObservationCount, 1)
        XCTAssertEqual(record.visualClassification, .uncertain)
        XCTAssertEqual(record.captureConditionPreset, .glare)
    }

    private func clearPasskeyObservation() -> ScanObservation {
        ScanObservation(
            qrCodes: [
                QRCodeObservation(type: .fido, boundingBox: .fullFrame)
            ],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft Sign in with a passkey",
                    confidence: 0.95,
                    boundingBox: .fullFrame,
                    region: .qrSurrounding
                ),
                OCRObservation(
                    text: "login.microsoft.com",
                    confidence: 0.9,
                    boundingBox: .fullFrame,
                    region: .fullFrame
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            ),
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed
        )
    }

    private func nonFidoObservation() -> ScanObservation {
        ScanObservation(
            qrCodes: [QRCodeObservation(type: .url, boundingBox: .fullFrame)],
            ocrObservations: [],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: false,
                issues: []
            ),
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed
        )
    }

    private func noQRCodeObservation() -> ScanObservation {
        ScanObservation(
            qrCodes: [],
            ocrObservations: [OCRObservation(
                text: "Sign in with a passkey",
                confidence: 0.9,
                boundingBox: .fullFrame,
                region: .fullFrame
            )],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: false,
                issues: [.unreadableText]
            ),
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed
        )
    }
}

@MainActor
private final class CameraCaptureStub: CameraCaptureServing {
    let session = AVCaptureSession()
    var authorizationState: CameraAuthorizationState = .authorized
    var sessionState: CameraSessionState = .running
    var detectedQRCodes = [
        LiveQRCodeDetection(
            type: .fido,
            metadataBoundingBox: .fullFrame
        )
    ]
    var isQRCodeStable = true
    var isCapturingPhoto = false
    var stateChangeHandler: (() -> Void)?
    var captureCalls = 0
    var startCalls = 0
    var stopCalls = 0

    func prepareAndStart() async {
        startCalls += 1
        sessionState = .running
        stateChangeHandler?()
    }

    func capturePhoto() async throws -> UIImage {
        captureCalls += 1
        return UIImage()
    }

    func stop() {
        stopCalls += 1
        sessionState = .stopped
        stateChangeHandler?()
    }
}

private struct ImageAnalysisStub: ImageAnalysisServing {
    let observation: ScanObservation

    func analyse(_ image: UIImage) async -> ScanObservation {
        observation
    }
}
