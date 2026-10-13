import Foundation

struct ContextClassifier {
    private let featureExtractor: ContextFeatureExtractor
    private let rules: [any ContextClassificationRule]

    init(
        featureExtractor: ContextFeatureExtractor = ContextFeatureExtractor(),
        rules: [any ContextClassificationRule] = [
            IdentityEvidenceRule(),
            ServiceContradictionRule(),
            BrandDomainConflictRule(),
            ContextAssociationRule(),
            ExpectedServiceMismatchRule(),
            CeremonyLanguageRule(),
            PurposeMismatchRule(),
            DirectPurposeMismatchRule(),
            UrgencyAndCoercionRule(),
            UnexpectedInitiationRule(),
            ReceivingClientTrustRule(),
            ChannelRiskRule(),
            ContextCompletenessRule(),
            SpatialRelevanceRule(),
            MultipleQRCodeRule()
        ]
    ) {
        self.featureExtractor = featureExtractor
        self.rules = rules
    }

    func classify(
        observation: ScanObservation,
        intent: UserIntent = .skipped,
        policy: ClarificationPolicy = .researcher,
        configuration: ClassifierConfiguration = .full,
        excludingRuleIdentifiers: Set<String> = []
    ) -> ScanResult {
        let classificationStart = DispatchTime.now().uptimeNanoseconds
        let effectiveIntent = configuration.usesIntent ? intent : .skipped
        let excludedRules = excludingRuleIdentifiers.union(
            configuration.excludedRuleIdentifiers
        )
        let features = featureExtractor.extract(
            from: observation,
            intent: effectiveIntent,
            associationPolicy: configuration.associationPolicy
        )
        let visualFeatures = featureExtractor.extract(
            from: observation,
            intent: .skipped,
            associationPolicy: configuration.associationPolicy
        )
        let input = RuleInput(
            observation: observation,
            features: features,
            intent: effectiveIntent,
            policy: policy
        )
        let ruleResults = rules
            .filter { !excludedRules.contains($0.identifier) }
            .flatMap { $0.evaluate(input) }
        let visualInput = RuleInput(
            observation: observation,
            features: visualFeatures,
            intent: .skipped,
            policy: policy
        )
        let visualRuleResults = rules
            .filter { !excludedRules.contains($0.identifier) }
            .flatMap { $0.evaluate(visualInput) }
        let riskScore = cappedSum(ruleResults.map(\.riskContribution))
        let completeness = cappedSum(ruleResults.map(\.completenessContribution))
        let visualRiskScore = cappedSum(visualRuleResults.map(\.riskContribution))
        let visualCompletenessScore = cappedSum(
            visualRuleResults.map(\.completenessContribution)
        )
        let visualCompleteness = visualEvidenceCompleteness(
            observation: observation,
            features: visualFeatures
        )
        let intentCompleteness = intentSessionCompleteness(intent: effectiveIntent)
        let hasOverride = ruleResults.contains(where: \.triggersSuspiciousOverride)
        let hasStrongContradiction = ruleResults.contains {
            $0.polarity == .negative &&
                $0.evidenceCategory == .contradiction &&
                $0.severity == .strong
        }
        let hasNegativeEvidence = ruleResults.contains {
            $0.polarity == .negative
        }
        let visualHasOverride = visualRuleResults.contains(where: \.triggersSuspiciousOverride)
        let visualHasStrongContradiction = visualRuleResults.contains {
            $0.polarity == .negative &&
                $0.evidenceCategory == .contradiction &&
                $0.severity == .strong
        }
        let visualHasNegativeEvidence = visualRuleResults.contains {
            $0.polarity == .negative
        }
        let isFIDO = observation.qrTypes.contains(.fido)
        let exactInitiationConfirmed = effectiveIntent.startedOnReceivingClient == .yes
        let participantRequirementsMet = policy == .participant &&
            exactInitiationConfirmed
        let researcherRequirementsMet = policy == .researcher &&
            effectiveIntent.hasServiceAndPurposeExpectation &&
            effectiveIntent.hasTrustedReceivingClientContext

        let visualClassification: RiskClassification
        if visualHasOverride || visualHasStrongContradiction || visualRiskScore >= 60 {
            visualClassification = .suspicious
        } else if isFIDO,
                  visualCompleteness == .sufficient,
                  visualCompletenessScore >= 60,
                  visualRiskScore < 40,
                  !visualHasNegativeEvidence {
            visualClassification = .consistent
        } else {
            visualClassification = .uncertain
        }

        let classification: RiskClassification
        if hasOverride || hasStrongContradiction || riskScore >= 60 {
            classification = .suspicious
        } else if visualClassification == .consistent,
                  completeness >= 60,
                  riskScore < 40,
                  !hasNegativeEvidence,
                  participantRequirementsMet || researcherRequirementsMet {
            classification = .consistent
        } else {
            classification = .uncertain
        }

        let positive = ruleResults
            .filter { $0.polarity == .positive }
            .map(\.reason)
            .uniqued()
        let negative = ruleResults
            .filter { $0.polarity == .negative }
            .map(\.reason)
            .uniqued()
        var limitations = ruleResults
            .filter { $0.polarity == .limitation }
            .map(\.reason)
            .uniqued()
        limitations.append(
            "Visible analysis cannot verify the actual relying party or who owns the receiving session."
        )
        limitations = limitations.uniqued()

        let reasons = negative.isEmpty ? positive : negative
        let context = VisualContext(
            qrDetected: observation.qrDetected,
            ocrText: observation.uniqueOCRText,
            visibleDomainClaims: features.visibleDomainClaims,
            authenticationKeywords: features.authenticationTerms
        )

        return ScanResult(
            visualContext: context,
            visibleServiceClaims: features.visibleServiceClaims,
            peripheralServiceClaims: features.peripheralServiceClaims,
            competingContextPresent: features.competingContextPresent,
            associationResolution: features.associationResolution,
            inferredPurposes: features.inferredPurposes,
            socialEngineeringCues: features.socialEngineeringCues,
            qrCount: observation.qrCount,
            qrTypes: observation.qrTypes,
            visualClassification: visualClassification,
            classification: classification,
            visualRiskScore: visualRiskScore,
            riskScore: riskScore,
            evidenceCompleteness: completeness,
            visualEvidenceCompleteness: visualCompleteness,
            intentSessionCompleteness: intentCompleteness,
            reasons: reasons.isEmpty
                ? ["The visible evidence is insufficient for a contextual judgment."]
                : reasons,
            observedPositiveEvidence: positive,
            observedNegativeEvidence: negative,
            limitations: limitations,
            suggestedUserChecks: [
                "Confirm that you initiated this sign-in.",
                "Confirm the service name shown by the phone's system prompt.",
                "Confirm that you trust the computer that will receive the session.",
                "Stop if the requested action differs from what you intended."
            ],
            ruleResults: ruleResults,
            assessmentDimensions: makeAssessmentDimensions(
                observation: observation,
                features: features,
                intent: intent
            ),
            sessionBindingAssessment: .notVerifiable,
            spatialEvidence: features.spatialEvidence,
            visualClaims: features.visualClaims,
            browserDomainCandidates: features.browserDomainCandidates,
            analysisTiming: observation.analysisTiming,
            imageQuality: observation.imageQuality,
            classificationMilliseconds: Double(
                DispatchTime.now().uptimeNanoseconds - classificationStart
            ) / 1_000_000
        )
    }

    private func makeAssessmentDimensions(
        observation: ScanObservation,
        features: VisualContextFeatures,
        intent: UserIntent
    ) -> [AssessmentDimension] {
        [
            identityDimension(features: features),
            purposeDimension(features: features),
            ceremonyDimension(observation: observation, features: features),
            initiationDimension(intent: intent),
            receivingClientDimension(intent: intent),
            socialEngineeringDimension(features: features),
            channelDimension(features: features),
            evidenceQualityDimension(observation: observation)
        ]
    }

    private func visualEvidenceCompleteness(
        observation: ScanObservation,
        features: VisualContextFeatures
    ) -> EvidenceCompletenessLevel {
        let materialKinds: Set<VisualClaimKind> = [
            .service, .domain, .authentication, .purpose, .purposePattern,
            .nonAuthenticationAction, .socialEngineering
        ]
        let hasAssociatedMaterialEvidence = features.visualClaims.contains {
            materialKinds.contains($0.kind) &&
                ($0.associationStrength == .strong ||
                 $0.associationStrength == .plausible)
        }
        let criteria = [
            observation.qrTypes.contains(.fido),
            observation.imageQuality.isSufficientForAnalysis,
            observation.ocrProcessingStatus == .completed,
            !features.visibleServiceClaims.isEmpty ||
                !features.visibleDomainClaims.isEmpty,
            !features.inferredPurposes.isEmpty,
            !features.authenticationTerms.isEmpty,
            hasAssociatedMaterialEvidence
        ]
        let present = criteria.filter { $0 }.count
        if present == criteria.count { return .sufficient }
        if present >= 3 { return .partial }
        return .insufficient
    }

    private func intentSessionCompleteness(
        intent: UserIntent
    ) -> EvidenceCompletenessLevel {
        let initiationKnown = intent.startedOnReceivingClient != .unsure ||
            intent.initiationStatus != .unsure
        let criteria = [
            intent.expectedService?.isEmpty == false,
            intent.expectedPurpose != nil && intent.expectedPurpose != .unsure,
            initiationKnown,
            intent.receivingClientRelationship != .unknown,
            intent.receivingClientTrust != .unsure
        ]
        let present = criteria.filter { $0 }.count
        if present == criteria.count { return .sufficient }
        if present > 0 { return .partial }
        return .insufficient
    }

    private func identityDimension(
        features: VisualContextFeatures
    ) -> AssessmentDimension {
        let conflicts: Set<ContradictionFlag> = [
            .expectedServiceMismatch, .brandDomainConflict,
            .multipleVisibleServices
        ]
        if features.contradictionFlags.contains(where: conflicts.contains) {
            return dimension(
                .identity,
                .conflicting,
                "Visible service or domain claims conflict.",
                features.visibleServiceClaims + features.visibleDomainClaims
            )
        }
        let evidence = features.visibleServiceClaims + features.visibleDomainClaims
        return evidence.isEmpty
            ? dimension(.identity, .incomplete, "No clear visible service identity was found.")
            : dimension(.identity, .aligned, "The visible identity claims do not conflict with the supplied expectation.", evidence)
    }

    private func purposeDimension(
        features: VisualContextFeatures
    ) -> AssessmentDimension {
        let hasConflict = features.contradictionFlags.contains(.expectedPurposeMismatch) ||
            features.contradictionFlags.contains(.competingPurposes) ||
            features.contradictionFlags.contains(.fidoPresentedAsUnrelatedAction)
        let evidence = features.inferredPurposes.map(\.userFacingLabel) +
            features.nonAuthenticationActionTerms
        if hasConflict {
            return dimension(.purpose, .conflicting, "The claimed action conflicts with the authentication ceremony or user expectation.", evidence)
        }
        return evidence.isEmpty
            ? dimension(.purpose, .incomplete, "The visible purpose is unclear.")
            : dimension(.purpose, .aligned, "A recognizable purpose is visible and no purpose conflict was found.", evidence)
    }

    private func ceremonyDimension(
        observation: ScanObservation,
        features: VisualContextFeatures
    ) -> AssessmentDimension {
        if features.contradictionFlags.contains(.fidoPresentedAsUnrelatedAction) {
            return dimension(.ceremony, .conflicting, "A FIDO QR code is presented as an unrelated action.", features.nonAuthenticationActionTerms)
        }
        guard observation.qrTypes.contains(.fido) else {
            return dimension(.ceremony, .notAssessable, "No FIDO-related QR code was identified.")
        }
        return features.authenticationTerms.isEmpty
            ? dimension(.ceremony, .incomplete, "The FIDO QR code lacks clear authentication wording.")
            : dimension(.ceremony, .aligned, "The visible wording describes an authentication ceremony.", features.authenticationTerms)
    }

    private func initiationDimension(intent: UserIntent) -> AssessmentDimension {
        let status = intent.startedOnReceivingClient != .unsure
            ? intent.startedOnReceivingClient
            : intent.initiationStatus
        switch status {
        case .yes:
            return dimension(.initiation, .aligned, "The user reports starting this exact request.")
        case .no:
            return dimension(.initiation, .conflicting, "The user reports not starting this exact request.")
        case .unsure:
            return dimension(.initiation, .incomplete, "It is unknown whether the user started this exact request.")
        }
    }

    private func receivingClientDimension(intent: UserIntent) -> AssessmentDimension {
        if intent.receivingClientTrust == .no ||
            intent.receivingClientRelationship == .someoneElsesDevice ||
            intent.receivingClientRelationship == .publicOrKiosk {
            return dimension(.receivingClient, .concerning, "The receiving computer is untrusted, public, or controlled by someone else.")
        }
        if intent.hasTrustedReceivingClientContext {
            return dimension(.receivingClient, .aligned, "The user reports identifying, trusting, and starting the request on the receiving computer.")
        }
        return dimension(.receivingClient, .incomplete, "The receiving computer's trust context is incomplete.")
    }

    private func socialEngineeringDimension(
        features: VisualContextFeatures
    ) -> AssessmentDimension {
        features.socialEngineeringCues.isEmpty
            ? dimension(.socialEngineering, .aligned, "No recognized persuasion cue was observed.")
            : dimension(
                .socialEngineering,
                .concerning,
                "The visible text contains urgency, coercion, reward, or warning-suppression cues.",
                features.socialEngineeringCues.map(\.rawValue)
            )
    }

    private func channelDimension(
        features: VisualContextFeatures
    ) -> AssessmentDimension {
        let concerning = features.channelCues.filter { $0 != .loginPage && $0 != .unknown }
        if !concerning.isEmpty {
            return dimension(.presentationChannel, .concerning, "The QR code is presented through an unusual or higher-risk channel.", concerning.map(\.rawValue))
        }
        if features.channelCues.contains(.loginPage) {
            return dimension(.presentationChannel, .aligned, "The visible context resembles a login page.", [ChannelCue.loginPage.rawValue])
        }
        return dimension(.presentationChannel, .notAssessable, "The presentation channel could not be established.")
    }

    private func evidenceQualityDimension(
        observation: ScanObservation
    ) -> AssessmentDimension {
        guard observation.imageQuality.isSufficientForAnalysis,
              observation.ocrProcessingStatus == .completed,
              !observation.ocrObservations.isEmpty else {
            return dimension(.evidenceQuality, .incomplete, "Image or OCR evidence is incomplete.", observation.imageQuality.issues.map(\.rawValue))
        }
        if !observation.imageQuality.issues.isEmpty {
            return dimension(
                .evidenceQuality,
                .concerning,
                "The capture has quality limitations, although usable evidence was extracted.",
                observation.imageQuality.issues.map(\.rawValue)
            )
        }
        return dimension(.evidenceQuality, .aligned, "The captured image and OCR output were sufficient for contextual analysis.")
    }

    private func dimension(
        _ kind: AssessmentDimensionKind,
        _ finding: DimensionFinding,
        _ summary: String,
        _ evidence: [String] = []
    ) -> AssessmentDimension {
        AssessmentDimension(
            kind: kind,
            finding: finding,
            summary: summary,
            evidence: evidence
        )
    }

    private func cappedSum(_ values: [Int]) -> Int {
        min(max(values.reduce(0, +), 0), 100)
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
