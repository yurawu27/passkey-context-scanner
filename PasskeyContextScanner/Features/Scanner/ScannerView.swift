import SwiftUI
import UIKit

struct ScannerView: View {
    let applicationMode: ApplicationMode
    @StateObject private var viewModel: LiveScannerViewModel
    @State private var showsEvaluationTools = false

    init(applicationMode: ApplicationMode = .participant) {
        self.applicationMode = applicationMode
        _viewModel = StateObject(wrappedValue: LiveScannerViewModel(
            clarificationPolicy: applicationMode == .researcher ? .researcher : .participant,
            applicationMode: applicationMode
        ))
    }

    var body: some View {
        Group {
            switch viewModel.cameraService.authorizationState {
            case .denied, .restricted:
                permissionUnavailableView
            case .notDetermined, .authorized:
                cameraContent
            }
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if applicationMode == .researcher {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsEvaluationTools = true
                    } label: {
                        Label("Evaluation setup", systemImage: "clipboard")
                    }
                }
            }
        }
        .sheet(isPresented: clarificationPresentedBinding) {
            clarificationSheet
        }
        .sheet(isPresented: $showsEvaluationTools) {
            NavigationStack {
                LiveEvaluationToolsView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.start()
        }
        .onDisappear {
            if viewModel.result == nil {
                viewModel.stop()
            }
        }
        .navigationDestination(isPresented: resultPresentedBinding) {
            if let result = viewModel.result {
                ResultView(
                    result: result,
                    applicationMode: applicationMode,
                    onRescan: {
                        Task {
                            await viewModel.rescan()
                        }
                    },
                    onOpenEvaluationTools: applicationMode == .researcher
                        ? { showsEvaluationTools = true }
                        : nil
                )
            }
        }
    }

    private var cameraContent: some View {
        ZStack {
            CameraPreview(
                session: viewModel.cameraService.session,
                detections: viewModel.cameraService.detectedQRCodes,
                isStable: viewModel.cameraService.isQRCodeStable
            )
            .ignoresSafeArea(edges: .bottom)

            VStack {
                Text("Keep the full display and its surrounding instructions visible.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()

                Spacer()

                stateOverlay
                    .padding()

                captureControls
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.cameraService.sessionState {
        case .idle, .requestingPermission, .configuring:
            HStack {
                ProgressView()
                Text(statusText)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: Capsule())
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task {
                        await viewModel.start()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .running:
            Text(detectionStatusText)
                .font(.footnote)
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())
        case .stopped:
            EmptyView()
        }
    }

    private var captureControls: some View {
        VStack(spacing: 8) {
            if viewModel.isAnalyzing {
                ProgressView("Capturing and analysing one frame")
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                Button {
                    Task {
                        await viewModel.captureAndAnalyze()
                    }
                } label: {
                    Label("Capture and Analyse", systemImage: "camera.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canCapture)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var permissionUnavailableView: some View {
        ContentUnavailableView {
            Label("Camera Access Required", systemImage: "camera.fill")
        } description: {
            Text("Allow camera access to scan a nearby display. Images are processed locally and are not retained by default.")
        } actions: {
            if viewModel.cameraService.authorizationState == .denied {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var statusText: String {
        switch viewModel.cameraService.sessionState {
        case .requestingPermission:
            return "Requesting camera access"
        case .configuring:
            return "Preparing camera"
        default:
            return "Starting camera"
        }
    }

    private var detectionStatusText: String {
        if viewModel.cameraService.detectedQRCodes.isEmpty {
            return "No live QR detected yet. Include the full context; you may still capture this attempt."
        }
        if viewModel.cameraService.isQRCodeStable {
            return viewModel.cameraService.detectedQRCodes.count == 1
                ? "QR code stable"
                : "\(viewModel.cameraService.detectedQRCodes.count) QR codes stable"
        }
        return "Hold steady, or capture now if the full context is visible."
    }

    private var clarificationSheet: some View {
        NavigationStack {
            List {
                if let question = viewModel.clarificationQuestion {
                    AdaptiveIntentQuestionSection(
                        question: question,
                        progressText: viewModel.clarificationProgressText,
                        answerConfirmation: viewModel.answerConfirmation,
                        answerReceivingComputer: viewModel.answerReceivingComputer,
                        skip: viewModel.finishWithUnknowns
                    )
                }
            }
            .navigationTitle("Before you continue")
            .interactiveDismissDisabled()
        }
    }

    private var clarificationPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.clarificationQuestion != nil },
            set: { if !$0 { viewModel.finishWithUnknowns() } }
        )
    }

    private var resultPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.result != nil },
            set: {
                if !$0 {
                    viewModel.clearResult()
                }
            }
        )
    }

}

private struct LiveEvaluationToolsView: View {
    @ObservedObject var viewModel: LiveScannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDatasetDeletion = false

    var body: some View {
        List {
            Section {
                Text("Use this panel for controlled live-camera runs. Select the fixture and physical capture condition before scanning, then return here to save the result.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker(
                    "Evaluation fixture",
                    selection: Binding(
                        get: { viewModel.selectedFixtureID },
                        set: { viewModel.selectFixture(id: $0) }
                    )
                ) {
                    Text("Select a fixture").tag("")
                    Section("Core fixtures") {
                        ForEach(ControlledEvaluationFixtureCatalog.fixtures) { fixture in
                            Text("\(fixture.id) — \(fixture.title)").tag(fixture.id)
                        }
                    }
                    Section("Competing-context fixtures") {
                        ForEach(CompetingContextEvaluationFixtureCatalog.fixtures) { fixture in
                            Text("\(fixture.id) — \(fixture.title)").tag(fixture.id)
                        }
                    }
                }

                if let fixture = viewModel.selectedFixture {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fixture.id)
                            .font(.subheadline.weight(.semibold))
                        Text(fixture.title)
                        Text("Expected: \(fixture.expectedService) · \(fixture.expectedPurpose.userFacingLabel)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Picker("Dataset split", selection: $viewModel.evaluationLabels.datasetSplit) {
                    ForEach(DatasetSplit.allCases) { split in
                        Text(displayName(split.rawValue)).tag(split)
                    }
                }

                TextField("Test ID", text: $viewModel.evaluationLabels.testId)
                    .textInputAutocapitalization(.characters)
                TextField("Run number", text: $viewModel.evaluationLabels.runNumber)
                    .keyboardType(.numberPad)
                TextField("Capture attempt", text: $viewModel.evaluationLabels.captureAttempt)
                    .keyboardType(.numberPad)
            } header: {
                Text("Scenario")
            }

            Section("Physical capture condition") {
                Picker(
                    "Preset",
                    selection: Binding(
                        get: { viewModel.evaluationLabels.captureConditionPreset },
                        set: { viewModel.selectCaptureConditionPreset($0) }
                    )
                ) {
                    ForEach(CaptureConditionPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                if viewModel.evaluationLabels.captureConditionPreset == .manual {
                    Picker("Lighting", selection: $viewModel.evaluationLabels.lightingCondition) {
                        ForEach(LightingCondition.allCases) { value in
                            Text(displayName(value.rawValue)).tag(value)
                        }
                    }
                    Picker("Angle", selection: $viewModel.evaluationLabels.angleCondition) {
                        ForEach(AngleCondition.allCases) { value in
                            Text(displayName(value.rawValue)).tag(value)
                        }
                    }
                    Picker("Distance", selection: $viewModel.evaluationLabels.distanceCondition) {
                        ForEach(DistanceCondition.allCases) { value in
                            Text(displayName(value.rawValue)).tag(value)
                        }
                    }
                    Picker("Blur", selection: $viewModel.evaluationLabels.blurCondition) {
                        ForEach(BlurCondition.allCases) { value in
                            Text(displayName(value.rawValue)).tag(value)
                        }
                    }
                    Picker("Crop", selection: $viewModel.evaluationLabels.cropCondition) {
                        ForEach(CropCondition.allCases) { value in
                            Text(displayName(value.rawValue)).tag(value)
                        }
                    }
                } else {
                    Text(viewModel.captureConditionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Evaluator notes", text: $viewModel.evaluationLabels.notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Scenario confirmation") {
                if let fixture = viewModel.selectedFixture {
                    LabeledContent("Fixture", value: fixture.id)
                    LabeledContent("Split", value: displayName(viewModel.evaluationLabels.datasetSplit.rawValue))
                    LabeledContent("Capture", value: viewModel.evaluationLabels.captureConditionPreset.displayName)
                    LabeledContent("Conditions", value: viewModel.captureConditionSummary)
                }

                Button {
                    viewModel.confirmScenarioMetadata()
                } label: {
                    Label(
                        viewModel.scenarioMetadataConfirmed
                            ? "Scenario Confirmed"
                            : "Confirm This Physical Setup",
                        systemImage: viewModel.scenarioMetadataConfirmed
                            ? "checkmark.seal.fill"
                            : "checkmark.seal"
                    )
                }
                .disabled(
                    viewModel.selectedFixture == nil ||
                    viewModel.evaluationLabels.datasetSplit == .notAssigned ||
                    viewModel.scenarioMetadataConfirmed
                )
            }

            Section("Record this attempt") {
                if viewModel.result != nil {
                    Button {
                        viewModel.addCurrentEvaluationRecord()
                    } label: {
                        Label("Add Scan to Dataset", systemImage: "plus.circle")
                    }
                    .disabled(!viewModel.canAddCurrentEvaluationRecord)
                } else {
                    Text("Capture the frame from the scanner first. Capture remains available when the preview cannot detect a QR code, so the high-resolution frame can still run through QR detection, OCR, quality assessment, and classification before this attempt is saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.evaluationValidationIssues.isEmpty {
                    ForEach(viewModel.evaluationValidationIssues) { issue in
                        Label(
                            issue.message,
                            systemImage: issue.severity == .error
                                ? "xmark.octagon.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }
                }
            }

            Section("Saved dataset") {
                LabeledContent("Records", value: "\(viewModel.evaluationRecords.count)")

                Button {
                    viewModel.exportEvaluationDataset()
                } label: {
                    Label("Create Four CSV Tables", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.evaluationRecords.isEmpty)

                if !viewModel.normalizedExportURLs.isEmpty {
                    ShareLink(items: viewModel.normalizedExportURLs) {
                        Label("Share Four CSV Tables", systemImage: "doc.on.doc")
                    }
                }

                Button(role: .destructive) {
                    confirmsDatasetDeletion = true
                } label: {
                    Label("Delete Saved Dataset", systemImage: "trash")
                }
                .disabled(viewModel.evaluationRecords.isEmpty)

                if let message = viewModel.exportMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Live Evaluation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .confirmationDialog(
            "Delete all saved evaluation records?",
            isPresented: $confirmsDatasetDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Dataset", role: .destructive) {
                viewModel.deleteAllEvaluationRecords()
            }
        } message: {
            Text("This removes the shared local evaluation dataset used by static and live analysis.")
        }
    }

    private func displayName(_ rawValue: String) -> String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
