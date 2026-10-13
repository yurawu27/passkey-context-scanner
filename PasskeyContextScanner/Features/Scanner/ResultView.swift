import SwiftUI

struct ResultView: View {
    let result: ScanResult
    var applicationMode: ApplicationMode = .participant
    var onRescan: (() -> Void)?
    var onOpenEvaluationTools: (() -> Void)?
    @State private var showsObservations = false
    @State private var showsSafetyChecks = false

    private var presentation: SecurityResultPresentation {
        .make(for: result)
    }

    var body: some View {
        List {
            outcomeIntervention

            Section {
                DisclosureGroup(
                    presentation.checklistTitle,
                    isExpanded: $showsSafetyChecks
                ) {
                    ForEach(presentation.safetyChecks, id: \.self) { check in
                        Label(check, systemImage: "circle.fill")
                            .labelStyle(BulletLabelStyle())
                            .padding(.top, 6)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(check)
                    }
                }
            }

            if !primaryObservations.isEmpty {
                Section {
                    DisclosureGroup("What else we noticed", isExpanded: $showsObservations) {
                        ForEach(primaryObservations, id: \.self) { observation in
                            Label(observation, systemImage: "circle.fill")
                                .labelStyle(BulletLabelStyle())
                                .padding(.top, 6)
                        }
                    }
                }
            }

            Section {
                if applicationMode == .researcher {
                    NavigationLink {
                        AnalysisDetailsView(result: result)
                    } label: {
                        Label("View technical and evaluation details", systemImage: "list.bullet.clipboard")
                    }

                    if let onOpenEvaluationTools {
                        Button(action: onOpenEvaluationTools) {
                            Label("Save or export live evaluation", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                if let onRescan {
                    Button("Scan Again", action: onRescan)
                }
            }
        }
        .navigationTitle("Scan Result")
    }

    @ViewBuilder
    private var outcomeIntervention: some View {
        switch presentation.style {
        case .activeWarning:
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Security warning", systemImage: presentation.systemImage)
                        .font(.headline)
                        .foregroundStyle(.red)

                    Text(presentation.headline)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.primaryReason)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Text(presentation.recommendedAction)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.limitation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation.accessibilitySummary)
            }
            .listRowBackground(Color.red.opacity(0.12))

        case .caution:
            Section("Check before proceeding") {
                Label(presentation.headline, systemImage: presentation.systemImage)
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.primaryReason)

                Text(presentation.recommendedAction)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.limitation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilitySummary)

        case .quiet:
            Section {
                Label(presentation.headline, systemImage: presentation.systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.primaryReason)

                Text(presentation.recommendedAction)
                    .font(.body)

                Text(presentation.limitation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilitySummary)
        }
    }

    private var primaryObservations: [String] {
        let preferred = result.classification == .suspicious
            ? result.observedNegativeEvidence
            : result.reasons
        let observations = preferred.isEmpty ? result.reasons : preferred
        return Array(observations.prefix(3))
    }

}

struct AnalysisDetailsView: View {
    let result: ScanResult

    var body: some View {
        List {
            Section("Research metrics") {
                LabeledContent("Classification", value: result.classification.rawValue)
                LabeledContent("Heuristic risk", value: "\(result.riskScore)/100")
                LabeledContent("Evidence completeness", value: "\(result.evidenceCompleteness)/100")
                LabeledContent(
                    "Visual evidence",
                    value: result.visualEvidenceCompleteness.rawValue
                )
                LabeledContent(
                    "Intent/session evidence",
                    value: result.intentSessionCompleteness.rawValue
                )
                LabeledContent("Purpose state", value: result.purposeState.rawValue)
                LabeledContent(
                    "Competing context",
                    value: result.competingContextPresent ? "Present" : "Not detected"
                )
                LabeledContent(
                    "Association resolution",
                    value: result.associationResolution.rawValue
                )
                if !result.inferredPurposes.isEmpty {
                    LabeledContent(
                        "Detected purposes",
                        value: result.inferredPurposes.map(\.rawValue)
                            .joined(separator: ", ")
                    )
                }
                Text("These values are explainable heuristic measures, not probabilities.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("QR observation") {
                LabeledContent("Detected", value: result.visualContext.qrDetected ? "Yes" : "No")
                LabeledContent("Count", value: "\(result.qrCount)")
                LabeledContent("Types", value: qrTypeSummary)
                LabeledContent(
                    "Capture quality",
                    value: result.imageQuality.isSufficientForAnalysis
                        ? "Usable"
                        : "Insufficient"
                )
                if !result.imageQuality.issues.isEmpty {
                    LabeledContent(
                        "Quality observations",
                        value: result.imageQuality.issues.map(\.rawValue)
                            .joined(separator: ", ")
                    )
                }
            }

            Section("Performance timing") {
                LabeledContent("Scan analysis", value: formattedMilliseconds(result.scanLatencyMilliseconds))
                LabeledContent("Image pipeline", value: formattedMilliseconds(result.analysisTiming.imageAnalysisMilliseconds))
                LabeledContent("QR detection", value: formattedMilliseconds(result.analysisTiming.qrDetectionMilliseconds))
                LabeledContent("Full-frame OCR", value: formattedMilliseconds(result.analysisTiming.fullFrameOCRMilliseconds))
                LabeledContent("QR-region OCR", value: formattedMilliseconds(result.analysisTiming.qrRegionOCRMilliseconds))
                LabeledContent("Classification", value: formattedMilliseconds(result.classificationMilliseconds))
                Text("QR detection and full-frame OCR run concurrently, so stage durations must not be added together. Timings use a monotonic clock and exclude user clarification time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }


            Section("Structured assessment") {
                ForEach(result.assessmentDimensions, id: \.kind) { dimension in
                    DimensionRow(dimension: dimension, showsSummary: true)
                }
            }

            Section("Session binding") {
                LabeledContent(
                    "Receiving-session owner",
                    value: result.sessionBindingAssessment.rawValue
                )
                Text("Neither pixels nor the decoded FIDO QR payload allow this standalone app to authenticate who controls the receiving browser session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !result.spatialEvidence.isEmpty {
                Section("Spatial text evidence") {
                    ForEach(Array(result.spatialEvidence.enumerated()), id: \.offset) { _, evidence in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(evidence.text)
                            LabeledContent("Proximity", value: evidence.proximity.rawValue)
                                .font(.caption)
                            LabeledContent("Context zone", value: evidence.contextZone.rawValue)
                                .font(.caption)
                            LabeledContent("Association", value: evidence.associationStrength.rawValue)
                                .font(.caption)
                            LabeledContent("OCR source", value: evidence.sourceRegion.rawValue)
                                .font(.caption)
                            LabeledContent(
                                "Normalized distance",
                                value: formattedDistance(evidence.normalizedDistanceToQRCode)
                            )
                            .font(.caption)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            valuesSection("Visible domain claims", values: result.visualContext.visibleDomainClaims)
            if !result.browserDomainCandidates.isEmpty {
                Section("Browser-level domain candidates") {
                    ForEach(result.browserDomainCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.domain)
                            Text("Unverified visual candidate · \(candidate.basis.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Image position can suggest browser-level text, but cannot verify browser chrome or page origin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            valuesSection("Authentication terms", values: result.visualContext.authenticationKeywords)
            valuesSection("Positive evidence", values: result.observedPositiveEvidence)
            valuesSection("Negative evidence", values: result.observedNegativeEvidence)
            valuesSection("Limitations", values: result.limitations)
            valuesSection("Suggested checks", values: result.suggestedUserChecks)

            ForEach(EvidenceCategory.allCases, id: \.self) { category in
                let matchingRules = result.ruleResults.filter {
                    $0.evidenceCategory == category
                }
                if !matchingRules.isEmpty {
                    Section(category.displayName) {
                        ForEach(Array(matchingRules.enumerated()), id: \.offset) { _, rule in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.reason)
                                Text(rule.ruleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !result.ruleResults.isEmpty {
                Section("Triggered rules") {
                    ForEach(Array(result.ruleResults.enumerated()), id: \.offset) { _, rule in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(rule.ruleIdentifier)
                                .font(.headline)
                            Text(rule.reason)
                            Text(rule.evidenceCategory.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Risk \(signed(rule.riskContribution)); completeness \(signed(rule.completenessContribution))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Recognised text") {
                Text(result.visualContext.ocrText.isEmpty ? "No OCR text available." : result.visualContext.ocrText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(result.visualContext.ocrText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Analysis Details")
    }

    private var qrTypeSummary: String {
        result.qrTypes.isEmpty
            ? "None"
            : result.qrTypes.map(\.rawValue).joined(separator: ", ")
    }

    @ViewBuilder
    private func valuesSection(_ title: String, values: [String]) -> some View {
        if !values.isEmpty {
            Section(title) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                }
            }
        }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func formattedDistance(_ distance: Double?) -> String {
        guard let distance else { return "Not assessable" }
        return String(format: "%.3f", distance)
    }

    private func formattedMilliseconds(_ milliseconds: Double?) -> String {
        guard let milliseconds else { return "Not measured" }
        return String(format: "%.1f ms", milliseconds)
    }
}

private extension EvidenceCategory {
    var displayName: String {
        switch self {
        case .supporting: return "Supporting evidence"
        case .contradiction: return "Contradictions"
        case .persuasion: return "Persuasion cues"
        case .missingEvidence: return "Missing evidence"
        case .contextualConcern: return "Contextual concerns"
        }
    }
}

private struct DimensionRow: View {
    let dimension: AssessmentDimension
    var showsSummary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(dimension.kind.displayName) {
                Text(findingLabel)
                    .foregroundStyle(findingColor)
            }
            if showsSummary {
                Text(dimension.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !dimension.evidence.isEmpty {
                    Text("Evidence: \(dimension.evidence.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var findingLabel: String {
        dimension.finding.rawValue.replacingOccurrences(of: "_", with: " ")
    }

    private var findingColor: Color {
        switch dimension.finding {
        case .aligned: return .green
        case .conflicting: return .red
        case .concerning, .incomplete: return .orange
        case .notAssessable: return .secondary
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon
                .font(.system(size: 6))
            configuration.title
        }
    }
}
