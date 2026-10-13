import PhotosUI
import SwiftUI

struct StaticImageAnalysisView: View {
    let applicationMode: ApplicationMode
    @StateObject private var viewModel: StaticImageAnalysisViewModel
    @State private var analysisTask: Task<Void, Never>?
    @State private var showsEvaluationTools = false
    @State private var confirmsDatasetDeletion = false

    init(
        applicationMode: ApplicationMode = .participant,
        participantIntroductionCompleted: Bool = false
    ) {
        self.applicationMode = applicationMode
        _viewModel = StateObject(wrappedValue: StaticImageAnalysisViewModel(
            clarificationPolicy: applicationMode == .researcher ? .researcher : .participant,
            applicationMode: applicationMode,
            participantIntroductionCompleted: participantIntroductionCompleted
        ))
    }

    var body: some View {
        List {
            Section {
                PhotosPicker(
                    selection: $viewModel.selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Select Screenshot or Photo", systemImage: "photo.badge.plus")
                }

                if viewModel.isProcessing {
                    HStack {
                        ProgressView()
                        Text("Analysing image")
                    }
                }

            }

            if let errorMessage = viewModel.errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let question = viewModel.clarificationQuestion {
                AdaptiveIntentQuestionSection(
                    question: question,
                    progressText: viewModel.clarificationProgressText,
                    answerConfirmation: viewModel.answerConfirmation,
                    answerReceivingComputer: viewModel.answerReceivingComputer,
                    skip: viewModel.finishWithUnknowns
                )
            }

            if let result = viewModel.result {
                Section("Analysis complete") {
                    NavigationLink {
                        ResultView(result: result, applicationMode: applicationMode)
                    } label: {
                        let presentation = SecurityResultPresentation.make(for: result)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(presentation.headline)
                                .font(.headline)
                            Text(presentation.primaryReason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if applicationMode == .researcher {
                    Section("Research evaluation") {
                    Toggle("Show evaluation tools", isOn: $showsEvaluationTools)

                    if showsEvaluationTools {
                        Text("These fields are for controlled dissertation testing, not part of the normal security check.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker(
                            "Evaluation fixture",
                            selection: Binding(
                                get: { viewModel.selectedFixtureID },
                                set: { viewModel.selectFixture(id: $0) }
                            )
                        ) {
                            Text("Manual / exploratory").tag("")
                            Section("Evaluation 1 — Core classification") {
                                ForEach(ControlledEvaluationFixtureCatalog.fixtures) { fixture in
                                    Text("\(fixture.id) — \(fixture.title)").tag(fixture.id)
                                }
                            }
                            Section("Evaluation 2 — Competing context") {
                                ForEach(CompetingContextEvaluationFixtureCatalog.fixtures) { fixture in
                                    Text("\(fixture.id) — \(fixture.title)").tag(fixture.id)
                                }
                            }
                        }

                        if let fixture = viewModel.selectedFixture {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fixture catalogue \(viewModel.selectedFixtureCatalogVersion)")
                                    .font(.caption.weight(.semibold))
                                Text("Image: \(fixture.imageFilename)")
                                    .font(.caption)
                                Text("\(fixture.expectedService) · \(fixture.expectedPurpose.userFacingLabel) · \(fixture.securityType.rawValue)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }

                        TextField("Test ID", text: $viewModel.evaluationLabels.testId)
                            .textInputAutocapitalization(.characters)

                        Picker("Dataset split", selection: $viewModel.evaluationLabels.datasetSplit) {
                            ForEach(DatasetSplit.allCases) { split in
                                Text(split.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .tag(split)
                            }
                        }

                        if viewModel.evaluationLabels.datasetSplit == .finalEvaluation {
                            Label(
                                "Formal runs use clarification answers scripted from factual scenario truth.",
                                systemImage: "checkmark.shield"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        TextField("Run number", text: $viewModel.evaluationLabels.runNumber)
                            .keyboardType(.numberPad)
                        TextField("Capture attempt", text: $viewModel.evaluationLabels.captureAttempt)
                            .keyboardType(.numberPad)

                        TextField(
                            "Matched stimulus ID",
                            text: $viewModel.evaluationLabels.matchedStimulusID
                        )
                        .textInputAutocapitalization(.characters)

                        Picker(
                            "Association condition",
                            selection: $viewModel.evaluationLabels.associationCondition
                        ) {
                            ForEach(AssociationCondition.allCases) { condition in
                                Text(
                                    condition.rawValue
                                        .replacingOccurrences(of: "_", with: " ")
                                        .capitalized
                                ).tag(condition)
                            }
                        }

                        Text("Use the same matched stimulus ID for the clean and competing-context versions of an otherwise identical scene.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker(
                            "Scenario Ground Truth",
                            selection: $viewModel.evaluationLabels.scenarioGroundTruth
                        ) {
                            ForEach(ScenarioGroundTruth.allCases) { groundTruth in
                                Text(groundTruth.displayName).tag(groundTruth)
                            }
                        }
                        .disabled(viewModel.hasPredefinedScenarioMetadata)

                        if viewModel.hasPredefinedScenarioMetadata {
                            Label(
                                "Scenario truth is fixed by the versioned catalogue.",
                                systemImage: "lock.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        DisclosureGroup("Factual scenario truth") {
                            Picker(
                                "Security type",
                                selection: $viewModel.evaluationLabels.factualGroundTruth.securityType
                            ) {
                                ForEach(ScenarioSecurityType.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            Picker(
                                "Visual detectability",
                                selection: $viewModel.evaluationLabels.factualGroundTruth.visualDetectability
                            ) {
                                ForEach(VisualDetectability.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            Picker(
                                "Capture quality truth",
                                selection: $viewModel.evaluationLabels.factualGroundTruth.captureQuality
                            ) {
                                ForEach(CaptureQualityTruth.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            TextField(
                                "Ground-truth service",
                                text: $viewModel.evaluationLabels.factualGroundTruth.service
                            )
                            TextField(
                                "Presented service",
                                text: $viewModel.evaluationLabels.factualGroundTruth.presentedService
                            )
                            Picker(
                                "Ground-truth purpose",
                                selection: Binding(
                                    get: {
                                        viewModel.evaluationLabels.factualGroundTruth.purpose
                                            ?? .unsure
                                    },
                                    set: {
                                        viewModel.evaluationLabels.factualGroundTruth.purpose =
                                            $0 == .unsure ? nil : $0
                                    }
                                )
                            ) {
                                ForEach(IntendedPurpose.allCases) { purpose in
                                    Text(purpose.userFacingLabel).tag(purpose)
                                }
                            }
                            Picker(
                                "Presented purpose",
                                selection: Binding(
                                    get: {
                                        viewModel.evaluationLabels.factualGroundTruth.presentedPurpose
                                            ?? .unsure
                                    },
                                    set: {
                                        viewModel.evaluationLabels.factualGroundTruth.presentedPurpose =
                                            $0 == .unsure ? nil : $0
                                    }
                                )
                            ) {
                                ForEach(IntendedPurpose.allCases) { purpose in
                                    Text(purpose.userFacingLabel).tag(purpose)
                                }
                            }
                            Picker(
                                "Ground-truth initiation",
                                selection: $viewModel.evaluationLabels.factualGroundTruth.initiated
                            ) {
                                ForEach(InitiationStatus.allCases) { value in
                                    Text(value.rawValue.capitalized).tag(value)
                                }
                            }
                            Picker(
                                "Receiving-client owner",
                                selection: $viewModel.evaluationLabels.factualGroundTruth.receivingClientOwner
                            ) {
                                ForEach(ScenarioReceivingClientOwner.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            Picker(
                                "Receiving-session context",
                                selection: Binding(
                                    get: {
                                        viewModel.evaluationLabels.factualGroundTruth.receivingClientContext
                                            ?? .unknown
                                    },
                                    set: {
                                        viewModel.evaluationLabels.factualGroundTruth.receivingClientContext = $0
                                    }
                                )
                            ) {
                                ForEach(ScenarioReceivingClientContext.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            DisclosureGroup("Detectable signal types") {
                                ForEach(DetectableSignalType.allCases) { signal in
                                    Toggle(
                                        signal.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                                        isOn: Binding(
                                            get: {
                                                viewModel.evaluationLabels.factualGroundTruth.detectableSignals.contains(signal)
                                            },
                                            set: { selected in
                                                var signals = viewModel.evaluationLabels.factualGroundTruth.detectableSignals
                                                if selected, !signals.contains(signal) {
                                                    signals.append(signal)
                                                } else if !selected {
                                                    signals.removeAll { $0 == signal }
                                                }
                                                viewModel.evaluationLabels.factualGroundTruth.detectableSignals = signals
                                            }
                                        )
                                    )
                                }
                            }
                        }
                        .disabled(viewModel.hasPredefinedScenarioMetadata)

                        Picker(
                            "Capture condition",
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
                                ForEach(LightingCondition.allCases) { condition in
                                    Text(condition.rawValue).tag(condition)
                                }
                            }

                            Picker("Angle", selection: $viewModel.evaluationLabels.angleCondition) {
                                ForEach(AngleCondition.allCases) { condition in
                                    Text(condition.rawValue).tag(condition)
                                }
                            }

                            Picker("Distance", selection: $viewModel.evaluationLabels.distanceCondition) {
                                ForEach(DistanceCondition.allCases) { condition in
                                    Text(condition.rawValue).tag(condition)
                                }
                            }
                        } else {
                            Text(viewModel.captureConditionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        DisclosureGroup("Display and presentation conditions") {
                            Picker("Display OS", selection: $viewModel.evaluationLabels.displayOS) {
                                ForEach(DisplayOS.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            Picker("Display browser", selection: $viewModel.evaluationLabels.displayBrowser) {
                                ForEach(DisplayBrowser.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            Picker("Presentation", selection: $viewModel.evaluationLabels.presentationType) {
                                ForEach(PresentationType.allCases) { value in
                                    Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .tag(value)
                                }
                            }
                            Picker("Clutter", selection: $viewModel.evaluationLabels.clutterCondition) {
                                ForEach(ClutterCondition.allCases) { value in
                                    Text(value.rawValue.capitalized).tag(value)
                                }
                            }
                            if viewModel.evaluationLabels.captureConditionPreset == .manual {
                                Picker("Crop", selection: $viewModel.evaluationLabels.cropCondition) {
                                    ForEach(CropCondition.allCases) { value in
                                        Text(value.rawValue.capitalized).tag(value)
                                    }
                                }
                                Picker("Blur", selection: $viewModel.evaluationLabels.blurCondition) {
                                    ForEach(BlurCondition.allCases) { value in
                                        Text(value.rawValue.capitalized).tag(value)
                                    }
                                }
                            }
                        }

                        Picker("Context Type", selection: $viewModel.evaluationLabels.contextType) {
                            ForEach(ContextType.allCases) { contextType in
                                Text(contextType.rawValue).tag(contextType)
                            }
                        }
                        .disabled(viewModel.hasPredefinedScenarioMetadata)

                        Picker(
                            "Detectability Boundary",
                            selection: $viewModel.evaluationLabels.detectabilityBoundary
                        ) {
                            ForEach(DetectabilityBoundary.allCases) { boundary in
                                Text(boundary.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .tag(boundary)
                            }
                        }
                        .disabled(viewModel.hasPredefinedScenarioMetadata)

                        TextField("Evaluator notes", text: $viewModel.evaluationLabels.notes, axis: .vertical)
                            .lineLimit(2...5)

                        Picker(
                            "Researcher failure attribution",
                            selection: $viewModel.evaluationLabels.failureAttribution
                        ) {
                            ForEach(EvaluationFailureAttribution.allCases) { attribution in
                                Text(
                                    attribution.rawValue
                                        .replacingOccurrences(of: "_", with: " ")
                                        .capitalized
                                )
                                .tag(attribution)
                            }
                        }
                        .disabled(viewModel.result == nil)
                        Text("Use this after reviewing an incorrect or inconclusive result. It does not indicate that the app failed to run.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if viewModel.shouldShowScenarioConfirmation {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm scenario metadata")
                                    .font(.subheadline.weight(.semibold))
                                ForEach(viewModel.finalScenarioSummary, id: \.self) { line in
                                    Text(line.replacingOccurrences(of: "_", with: " "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                                .disabled(viewModel.scenarioMetadataConfirmed)
                            }
                        }

                        Button {
                            viewModel.runAblationAnalysis()
                        } label: {
                            Label("Run Signal Ablation", systemImage: "slider.horizontal.3")
                        }

                        if !viewModel.ablationComparisons.isEmpty {
                            DisclosureGroup("Signal contribution") {
                                ForEach(viewModel.ablationComparisons) { comparison in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(comparison.family.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.subheadline.weight(.semibold))
                                        Text("Classification: \(comparison.baselineClassification.rawValue) → \(comparison.ablatedClassification.rawValue)")
                                        Text("Risk: \(comparison.baselineRiskScore) → \(comparison.ablatedRiskScore) · Completeness: \(comparison.baselineCompleteness) → \(comparison.ablatedCompleteness)")
                                        if comparison.family == .contextAssociationModel {
                                            Text("Association: \(comparison.baselineAssociationPolicy?.rawValue ?? "") → \(comparison.ablatedAssociationPolicy?.rawValue ?? "")")
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(comparison.removedTriggeredRules.isEmpty
                                                 ? "No rule in this family triggered."
                                                 : "Removed triggered rules: \(comparison.removedTriggeredRules.joined(separator: ", "))")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption)
                                    .padding(.vertical, 3)
                                }
                                Text("Ablation removes named rule families from the same observation. The context-association comparison instead reruns feature extraction with all visible text treated equally. These are sensitivity analyses, not additional security verdicts.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !viewModel.evaluationValidationIssues.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
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
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Evaluation record checks")
                        }

                        Button {
                            viewModel.addCurrentEvaluationRecord()
                        } label: {
                            Label("Add Scan to Dataset", systemImage: "plus.circle")
                        }
                        .disabled(!viewModel.canAddCurrentEvaluationRecord)

                        Button {
                            viewModel.exportEvaluationDataset()
                        } label: {
                            Label(
                                "Create Dataset Export (\(viewModel.evaluationRecords.count))",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(viewModel.evaluationRecords.isEmpty)

                        if viewModel.failureAttemptCount > 0 {
                            Label(
                                "(viewModel.failureAttemptCount) failed analysis attempt(s) retained for robustness reporting and excluded from accuracy metrics.",
                                systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            confirmsDatasetDeletion = true
                        } label: {
                            Label("Delete Saved Dataset", systemImage: "trash")
                        }
                        .disabled(viewModel.evaluationRecords.isEmpty)

                        if let exportURL = viewModel.exportURL {
                            ShareLink(item: exportURL) {
                                Label("Share CSV", systemImage: "doc.badge.arrow.up")
                            }
                        }

                        if !viewModel.normalizedExportURLs.isEmpty {
                            ShareLink(items: viewModel.normalizedExportURLs) {
                                Label("Share Four CSV Tables", systemImage: "doc.on.doc")
                            }
                        }

                        if let exportMessage = viewModel.exportMessage {
                            Text(exportMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.evaluationRecords.isEmpty {
                            EvaluationCoverageSummaryView(
                                summary: viewModel.evaluationCoverageSummary
                            )
                            EvaluationMetricsSummaryView(
                                summary: viewModel.evaluationMetricsSummary
                            )
                            EvaluationMetricsSummaryView(
                                summary: viewModel.visualOnlyEvaluationMetricsSummary
                            )
                            EvaluationAttackCoverageSummaryView(
                                summary: viewModel.attackCoverageSummary
                            )
                        }
                    }
                    }
                }

            } else if !viewModel.isProcessing && viewModel.scanObservation == nil {
                ContentUnavailableView(
                    "No Image Analysed",
                    systemImage: "doc.viewfinder",
                    description: Text("Select a screenshot or photo to run local OCR.")
                )
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Image Analysis")
        .onChange(of: viewModel.selectedItem) { _, _ in
            analysisTask?.cancel()
            analysisTask = Task {
                await viewModel.analyseSelectedImage()
            }
        }
        .onDisappear {
            analysisTask?.cancel()
        }
        .confirmationDialog(
            "Delete all saved evaluation records?",
            isPresented: $confirmsDatasetDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete All Records", role: .destructive) {
                viewModel.deleteAllEvaluationRecords()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Export the CSV first if you need to keep these records.")
        }
    }

}

private struct EvaluationCoverageSummaryView: View {
    let summary: EvaluationCoverageSummary

    var body: some View {
        DisclosureGroup("Scenario coverage") {
            LabeledContent("Catalogue", value: summary.catalogVersion)
            LabeledContent(
                "Required variants",
                value: "\(summary.coveredVariantCount) of \(summary.requiredVariantCount)"
            )
            ProgressView(value: summary.completionFraction ?? 0)
                .accessibilityLabel("Controlled scenario coverage")
                .accessibilityValue("\(summary.coveredVariantCount) of \(summary.requiredVariantCount) variants")

            if summary.excludedRecordCount > 0 {
                Text("\(summary.excludedRecordCount) manual, unknown, or different-catalog record\(summary.excludedRecordCount == 1 ? " is" : "s are") excluded from this coverage summary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(summary.variants) { variant in
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: variant.isCovered ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(variant.isCovered ? .green : .secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(variant.scenarioID) · \(variant.variant.replacingOccurrences(of: "_", with: " ").capitalized)")
                            .font(.subheadline)
                        Text(variant.isCovered ? "\(variant.recordCount) recorded run\(variant.recordCount == 1 ? "" : "s")" : "Missing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Text("Repeated runs increase the count but do not increase variant coverage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EvaluationMetricsSummaryView: View {
    let summary: EvaluationMetricsSummary

    var body: some View {
        DisclosureGroup(title) {
            LabeledContent("Labelled records", value: "\(summary.includedRecordCount)")
            LabeledContent("Excluded (not assigned)", value: "\(summary.excludedRecordCount)")
            LabeledContent(
                "Factual-policy records",
                value: "\(summary.factualPolicyRecordCount)"
            )
            if summary.legacyFallbackRecordCount > 0 {
                LabeledContent(
                    "Legacy-label fallback",
                    value: "\(summary.legacyFallbackRecordCount)"
                )
            }
            LabeledContent("Overall accuracy", value: percentage(summary.accuracy))
            LabeledContent(
                "Suspicious false-negative rate",
                value: percentage(summary.suspiciousFalseNegativeRate)
            )
            LabeledContent(
                "Consistent false-positive rate",
                value: percentage(summary.consistentFalsePositiveRate)
            )

            ForEach(summary.perClass) { metrics in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(metrics.classification.rawValue) (n=\(metrics.support))")
                        .font(.subheadline.weight(.semibold))
                    Text("Precision \(percentage(metrics.precision)) · Recall \(percentage(metrics.recall)) · F1 \(percentage(metrics.f1Score))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Text("Rates are descriptive dataset statistics, not confidence that an individual scan is safe.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch (summary.targetKind, summary.predictionStage) {
        case (.combinedSecurity, .final): "Final combined-security metrics"
        case (.visualOnly, .preliminary): "Preliminary visual-only metrics"
        default: "Dataset metrics"
        }
    }

    private func percentage(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(1)))
    }
}

private struct EvaluationAttackCoverageSummaryView: View {
    let summary: EvaluationAttackCoverageSummary

    var body: some View {
        DisclosureGroup("Visual attack coverage") {
            LabeledContent(
                "Detectable-case sensitivity",
                value: percentage(summary.detectableCaseSensitivity)
            )
            Text("\(summary.detectableSuspiciousCount) of \(summary.detectableMaliciousCount) malicious cases with observable and sufficient visual evidence were flagged SUSPICIOUS.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent(
                "Overall malicious coverage",
                value: percentage(summary.overallAttackCoverage)
            )
            Text("\(summary.overallSuspiciousCount) of \(summary.overallMaliciousCount) malicious cases were visually flagged, including \(summary.visuallyIndistinguishableCount) cases whose hidden session ownership is not observable from pixels.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("These are descriptive dataset rates. Visually indistinguishable attacks are excluded from the ordinary visual confusion matrix but retained in overall coverage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func percentage(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(1)))
    }
}

struct AdaptiveIntentQuestionSection: View {
    let question: AdaptiveIntentQuestion
    let progressText: String
    let answerConfirmation: (InitiationStatus) -> Void
    let answerReceivingComputer: (ReceivingClientRelationship) -> Void
    let skip: () -> Void

    var body: some View {
        Section("One quick check") {
            Text(progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(question.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            switch question {
            case .receivingComputer:
                ForEach(ReceivingClientRelationship.allCases) { relationship in
                    Button(receivingClientLabel(relationship)) {
                        answerReceivingComputer(relationship)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Answers which computer may receive the signed-in session.")
                }
            case .exactInitiation:
                VStack(spacing: 10) {
                    confirmationButton("I started this request", answer: .yes)
                    confirmationButton("I did not start it", answer: .no)
                    confirmationButton("I’m not sure", answer: .unsure)
                }
            case .confirmService, .confirmPurpose:
                ViewThatFits(in: .horizontal) {
                    HStack {
                        confirmationButton("Yes", answer: .yes)
                        confirmationButton("No", answer: .no)
                        confirmationButton("Not sure", answer: .unsure)
                    }

                    VStack(spacing: 10) {
                        confirmationButton("Yes", answer: .yes)
                        confirmationButton("No", answer: .no)
                        confirmationButton("Not sure", answer: .unsure)
                    }
                }
            }

            Button("Show result with unknowns", action: skip)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHint("Skips this question and keeps missing information marked as unknown.")
        }
    }

    private func confirmationButton(
        _ label: String,
        answer: InitiationStatus
    ) -> some View {
        Button(label) { answerConfirmation(answer) }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Answers the security clarification and shows the resulting assessment.")
    }

    private func receivingClientLabel(
        _ relationship: ReceivingClientRelationship
    ) -> String {
        switch relationship {
        case .ownDevice: return "My own computer"
        case .trustedSharedComputer: return "A trusted shared computer"
        case .publicOrKiosk: return "A public computer or kiosk"
        case .someoneElsesDevice: return "Someone else’s computer"
        case .unknown: return "I’m not sure"
        }
    }
}
