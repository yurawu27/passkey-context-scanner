import Foundation

struct ContextFeatureExtractor {
    /// A deliberately simple calibration boundary for the rule-based prototype.
    /// Observations below this value remain visible in spatial diagnostics but
    /// cannot create identity, purpose, persuasion, or contradiction features.
    static let minimumSemanticOCRConfidence: Float = 0.50

    private struct ServiceProfile {
        let name: String
        let terms: [String]
        let domains: [String]
    }

    private let domainExtractor: DomainExtractor
    private let associationEngine: ContextAssociationEngine

    private let serviceProfiles = [
        ServiceProfile(
            name: "Microsoft",
            terms: ["microsoft", "microsoft account"],
            domains: ["microsoft.com", "live.com", "microsoftonline.com"]
        ),
        ServiceProfile(
            name: "Google",
            terms: ["google", "google account"],
            domains: ["google.com", "google.co.uk"]
        ),
        ServiceProfile(
            name: "GitHub",
            terms: ["github"],
            domains: ["github.com"]
        ),
        ServiceProfile(
            name: "Amazon",
            terms: ["amazon"],
            domains: ["amazon.com", "amazon.co.uk"]
        ),
        ServiceProfile(
            name: "Apple",
            terms: ["apple", "icloud"],
            domains: ["apple.com", "icloud.com"]
        ),
        ServiceProfile(
            name: "Chase",
            terms: ["chase", "jpmorgan chase"],
            domains: ["chase.com"]
        ),
        ServiceProfile(
            name: "PayPal",
            terms: ["paypal"],
            domains: ["paypal.com"]
        ),
        ServiceProfile(
            name: "Robinhood",
            terms: ["robinhood"],
            domains: ["robinhood.com"]
        ),
        ServiceProfile(
            name: "Dropbox",
            terms: ["dropbox"],
            domains: ["dropbox.com"]
        ),
        ServiceProfile(
            name: "Coinbase",
            terms: ["coinbase"],
            domains: ["coinbase.com"]
        ),
        ServiceProfile(
            name: "NHS",
            terms: ["nhs", "nhs login"],
            domains: ["nhs.uk"]
        ),
        ServiceProfile(
            name: "Wells Fargo",
            terms: ["wells fargo"],
            domains: ["wellsfargo.com"]
        )
    ]

    private let authenticationTerms = [
        "sign in", "log in", "login", "passkey", "security key",
        "verify your identity", "continue on your phone", "use another device",
        "authenticate", "authentication"
    ]

    init(
        domainExtractor: DomainExtractor = DomainExtractor(),
        associationEngine: ContextAssociationEngine = ContextAssociationEngine()
    ) {
        self.domainExtractor = domainExtractor
        self.associationEngine = associationEngine
    }

    /// Bounded, privacy-preserving semantic tags for evaluation traceability.
    /// The original OCR string remains in memory and is not returned here.
    func featureIdentifiers(in text: String) -> [String] {
        let normalized = normalize(text)
        var identifiers = detectedServices(in: normalized).map { "SERVICE:\($0)" }
        identifiers += domainExtractor.extractDomainClaims(from: text).compactMap {
            guard $0.isAuthoritativeIdentityEvidence else { return nil }
            return $0.sourceType == .emailDomain
                ? "EMAIL_DOMAIN:\($0.domain)"
                : "DOMAIN:\($0.domain)"
        }
        identifiers += matchedTerms(authenticationTerms, in: normalized).map { "AUTH:\($0)" }
        identifiers += inferredPurposes(in: normalized).map { "PURPOSE:\($0.rawValue)" }
        identifiers += detectedNonAuthenticationTerms(in: normalized).map { "NON_AUTH:\($0)" }
        identifiers += detectedSocialEngineeringCues(in: normalized).map { "SOCIAL:\($0.rawValue)" }
        var seen = Set<String>()
        return identifiers.filter { seen.insert($0).inserted }
    }

    func extract(
        from observation: ScanObservation,
        intent: UserIntent = .skipped,
        associationPolicy: ContextAssociationPolicy = .spatiallyAssociated
    ) -> VisualContextFeatures {
        let spatialEvidence = makeSpatialEvidence(from: observation)
        let reliableSpatialEvidence = spatialEvidence.filter {
            $0.confidence >= Self.minimumSemanticOCRConfidence
        }
        let isFIDO = observation.qrTypes.contains(.fido)
        let domainEvidence = reliableSpatialEvidence.flatMap {
            makeDomainEvidence(from: $0, associationPolicy: associationPolicy)
        }
        let localTextCompositions = makeLocalTextCompositions(
            from: reliableSpatialEvidence
        )
        let individualPurposeEvidence = reliableSpatialEvidence.flatMap {
            makePurposeEvidence(from: $0, isFIDO: isFIDO)
        }
        let composedPurposeEvidence = localTextCompositions.flatMap {
            makePurposeEvidence(from: $0, isFIDO: isFIDO)
        }
        let purposeEvidence = deduplicatedPurposeEvidence(
            individualPurposeEvidence + composedPurposeEvidence
        )
        let purposes = materialPurposes(from: purposeEvidence)
        let browserDomainCandidates = makeBrowserDomainCandidates(
            from: reliableSpatialEvidence,
            domainEvidence: domainEvidence
        )
        let contextCompetition = makeContextCompetitionAssessment(
            from: reliableSpatialEvidence,
            domainEvidence: domainEvidence,
            associationPolicy: associationPolicy
        )
        let associatedEvidence: [SpatialTextEvidence]
        let peripheralEvidence: [SpatialTextEvidence]
        switch associationPolicy {
        case .spatiallyAssociated:
            associatedEvidence = reliableSpatialEvidence.filter {
                $0.semanticRole == .qrLocal ||
                    $0.semanticRole == .dialogContext
            }
            peripheralEvidence = reliableSpatialEvidence.filter {
                $0.semanticRole == .pageIdentity ||
                    $0.semanticRole == .peripheral ||
                    $0.semanticRole == .browserDomainCandidate
            }
        case .unfilteredVisualText:
            associatedEvidence = reliableSpatialEvidence
            peripheralEvidence = []
        }
        let associatedText = joinedText(from: associatedEvidence)
        let peripheralText = joinedText(from: peripheralEvidence)
        let allText = joinedText(from: reliableSpatialEvidence)
        let normalizedText = normalize(associatedText)
        let normalizedPeripheralText = normalize(peripheralText)
        let primaryDomainEvidence = domainEvidence.filter {
            $0.participatesInServiceIdentity &&
                (associationPolicy == .unfilteredVisualText ||
                 $0.contextRole == .qrLocal || $0.contextRole == .dialogContext)
        }
        let peripheralDomainEvidence = associationPolicy == .spatiallyAssociated
            ? domainEvidence.filter {
                $0.sourceType != .emailDomain &&
                    $0.recognitionStatus == .authoritative &&
                    ($0.contextRole == .pageIdentity ||
                     $0.contextRole == .peripheral ||
                     $0.contextRole == .browserDomainCandidate)
            }
            : []
        let domains = primaryDomainEvidence.map(\.domain).uniqued()
        let services = (
            associatedEvidence.flatMap {
                detectedServiceIdentityClaims(
                    in: normalize($0.text),
                    role: $0.semanticRole
                )
            } +
                domains.compactMap(serviceName(for:))
        ).uniqued()
        let peripheralDomains = peripheralDomainEvidence.map(\.domain).uniqued()
        let peripheralServices = peripheralEvidence.flatMap {
            detectedServiceIdentityClaims(
                in: normalize($0.text),
                role: $0.semanticRole
            )
        }.uniqued()
        let authentication = matchedTerms(authenticationTerms, in: normalizedText)
        let associatedSemanticTexts = associatedEvidence.map(\.text) +
            localTextCompositions.map(\.text)
        let nonAuthenticationTerms = associatedSemanticTexts.flatMap {
            detectedNonAuthenticationTerms(in: normalize($0))
        }.uniqued()
        let socialCues = associatedSemanticTexts.flatMap {
            detectedSocialEngineeringCues(in: normalize($0))
        }.uniqued()
        let peripheralSocialCues = detectedSocialEngineeringCues(
            in: normalizedPeripheralText
        )
        let channels = detectedChannels(in: normalize(allText), intent: intent)
        let identityEvents = makeIdentityContradictionEvents(
            from: reliableSpatialEvidence,
            domainEvidence: domainEvidence,
            associationPolicy: associationPolicy,
            associationResolution: contextCompetition.resolution
        )
        let contradictions = detectedContradictions(
            observation: observation,
            intent: intent,
            services: services,
            domains: domains,
            browserDomainCandidates: browserDomainCandidates,
            identityEvents: identityEvents,
            associationResolution: contextCompetition.resolution,
            purposes: purposes,
            nonAuthenticationTerms: nonAuthenticationTerms
        )
        let completeness = completenessIndicators(
            observation: observation,
            intent: intent,
            services: services,
            domains: domains,
            purposes: purposes,
            authenticationTerms: authentication
        )
        var visualClaims = reliableSpatialEvidence.flatMap { evidence in
            makeVisualClaims(
                from: evidence,
                domainEvidence: domainEvidence,
                purposeEvidence: purposeEvidence
            )
        }
        visualClaims += browserDomainCandidates.map { candidate in
            VisualClaimEvidence(
                kind: .browserDomainCandidate,
                value: candidate.domain,
                sourceObservationId: candidate.sourceObservationId,
                ocrConfidence: candidate.ocrConfidence,
                contextZone: .peripheral,
                associationStrength: .plausible,
                semanticRole: .browserDomainCandidate
            )
        }
        visualClaims += makeComposedSemanticClaims(from: localTextCompositions)
        visualClaims = deduplicatedVisualClaims(visualClaims)

        return VisualContextFeatures(
            visibleServiceClaims: services,
            visibleDomainClaims: domains,
            peripheralServiceClaims: peripheralServices,
            peripheralDomainClaims: peripheralDomains,
            competingContextPresent: contextCompetition.isPresent,
            associationResolution: contextCompetition.resolution,
            authenticationTerms: authentication,
            inferredPurposes: purposes,
            nonAuthenticationActionTerms: nonAuthenticationTerms,
            socialEngineeringCues: socialCues,
            peripheralSocialEngineeringCues: peripheralSocialCues,
            channelCues: channels,
            contradictionFlags: contradictions,
            completenessIndicators: completeness,
            spatialEvidence: spatialEvidence,
            visualClaims: visualClaims,
            browserDomainCandidates: browserDomainCandidates,
            purposeEvidence: purposeEvidence,
            domainEvidence: domainEvidence,
            identityContradictionEvents: identityEvents,
            lowConfidenceObservationCount: spatialEvidence.count - reliableSpatialEvidence.count
        )
    }

    private func joinedText(from evidence: [SpatialTextEvidence]) -> String {
        evidence.map(\.text).joined(separator: "\n")
    }

    private func makeSpatialEvidence(
        from observation: ScanObservation
    ) -> [SpatialTextEvidence] {
        var bestByText: [String: SpatialTextEvidence] = [:]

        for textObservation in observation.ocrObservations {
            let association = associationEngine.associate(
                textObservation,
                with: observation.qrCodes
            )
            let role = semanticRole(
                for: textObservation,
                association: association
            )
            let associationStrength = adjustedAssociationStrength(
                association,
                role: role,
                observation: textObservation
            )
            let evidence = SpatialTextEvidence(
                observationId: "",
                text: textObservation.text,
                confidence: textObservation.confidence,
                boundingBox: textObservation.boundingBox,
                associatedQRCodeIndex: association.qrIndex,
                associatedQRCodeBoundingBox: association.qrBoundingBox,
                sourceRegion: textObservation.region,
                normalizedDistanceToQRCode: association.normalizedDistance,
                proximity: association.proximity,
                contextZone: association.zone,
                associationStrength: associationStrength,
                semanticRole: role,
                isNearQRCode: association.proximity == .near
            )
            let key = normalize(textObservation.text)
            guard !key.isEmpty else { continue }

            if let existing = bestByText[key] {
                let existingDistance = existing.normalizedDistanceToQRCode ?? .infinity
                let newDistance = association.normalizedDistance ?? .infinity
                if newDistance < existingDistance ||
                    (newDistance == existingDistance && evidence.confidence > existing.confidence) {
                    bestByText[key] = evidence
                }
            } else {
                bestByText[key] = evidence
            }
        }

        return bestByText.values.sorted {
            ($0.normalizedDistanceToQRCode ?? .infinity) <
                ($1.normalizedDistanceToQRCode ?? .infinity)
        }.enumerated().map { index, evidence in
            SpatialTextEvidence(
                observationId: "O\(index + 1)",
                text: evidence.text,
                confidence: evidence.confidence,
                boundingBox: evidence.boundingBox,
                associatedQRCodeIndex: evidence.associatedQRCodeIndex,
                associatedQRCodeBoundingBox: evidence.associatedQRCodeBoundingBox,
                sourceRegion: evidence.sourceRegion,
                normalizedDistanceToQRCode: evidence.normalizedDistanceToQRCode,
                proximity: evidence.proximity,
                contextZone: evidence.contextZone,
                associationStrength: evidence.associationStrength,
                semanticRole: evidence.semanticRole,
                isNearQRCode: evidence.isNearQRCode
            )
        }
    }

    private func makeVisualClaims(
        from evidence: SpatialTextEvidence,
        domainEvidence: [DomainClaimEvidence],
        purposeEvidence: [PurposeClaimEvidence]
    ) -> [VisualClaimEvidence] {
        var identifiers = featureIdentifiers(in: evidence.text).filter {
            !$0.hasPrefix("SERVICE:") &&
                !$0.hasPrefix("DOMAIN:") && !$0.hasPrefix("EMAIL_DOMAIN:") &&
                !$0.hasPrefix("PURPOSE:")
        }
        identifiers += detectedServiceIdentityClaims(
            in: normalize(evidence.text),
            role: evidence.semanticRole
        ).map { "SERVICE:\($0)" }
        identifiers += domainEvidence.filter {
            $0.sourceObservationId == evidence.observationId &&
                ($0.sourceType == .emailDomain ||
                 $0.participatesInServiceIdentity)
        }.map {
            let kind = $0.sourceType == .emailDomain ? "EMAIL_DOMAIN" : "DOMAIN"
            return "\(kind):\($0.domain)"
        }
        let observationPurposeEvidence = purposeEvidence.filter {
            $0.sourceObservationIds.contains(evidence.observationId)
        }
        identifiers += observationPurposeEvidence.map { "PURPOSE:\($0.purpose.rawValue)" }
        identifiers += observationPurposeEvidence.map {
            "PURPOSE_PATTERN:\($0.purpose.rawValue)|\($0.matchedPhrase)"
        }

        return identifiers.compactMap { identifier in
            guard let separator = identifier.firstIndex(of: ":"),
                  let kind = VisualClaimKind(
                      rawValue: String(identifier[..<separator])
                  ) else { return nil }
            let value = String(identifier[identifier.index(after: separator)...])
            guard !value.isEmpty else { return nil }
            return VisualClaimEvidence(
                kind: kind,
                value: value,
                sourceObservationId: evidence.observationId,
                ocrConfidence: evidence.confidence,
                contextZone: evidence.contextZone,
                associationStrength: evidence.associationStrength,
                semanticRole: evidence.semanticRole
            )
        }
    }

    private func makeBrowserDomainCandidates(
        from evidence: [SpatialTextEvidence],
        domainEvidence: [DomainClaimEvidence]
    ) -> [BrowserDomainCandidate] {
        evidence.flatMap { observation -> [BrowserDomainCandidate] in
            guard observation.semanticRole == .browserDomainCandidate else { return [] }
            return domainEvidence.filter {
                $0.sourceObservationId == observation.observationId &&
                    $0.sourceType == .browserDomainCandidate &&
                    $0.recognitionStatus == .authoritative
            }.map { claim in
                BrowserDomainCandidate(
                    domain: claim.domain,
                    sourceObservationId: observation.observationId,
                    ocrConfidence: observation.confidence,
                    boundingBox: observation.boundingBox,
                    basis: .topOfFrameURLLikeText
                )
            }
        }
    }

    private func semanticRole(
        for observation: OCRObservation,
        association: ContextAssociationEngine.Association
    ) -> SemanticContextRole {
        guard association.qrIndex != nil else { return .unassociated }
        let topEdge = observation.boundingBox.y + observation.boundingBox.height
        let nonEmailDomains = domainExtractor.extractDomainClaims(from: observation.text)
            .filter { $0.sourceType != .emailDomain }
        if observation.region == .fullFrame,
           topEdge >= 0.84,
           !nonEmailDomains.isEmpty {
            return .browserDomainCandidate
        }
        if observation.region == .qrSurrounding {
            return containsDirectQRInstruction(observation.text)
                ? .qrLocal
                : .dialogContext
        }
        if observation.region == .fullFrame, topEdge <= 0.20 {
            return .peripheral
        }
        if association.strength == .strong || association.strength == .plausible {
            return containsDirectQRInstruction(observation.text)
                ? .qrLocal
                : .dialogContext
        }
        let normalized = normalize(observation.text)
        let resemblesPageIdentity = topEdge >= 0.62 && (
            !detectedServices(in: normalized).isEmpty ||
                !nonEmailDomains.isEmpty ||
                !matchedTerms(authenticationTerms, in: normalized).isEmpty
        )
        return resemblesPageIdentity ? .pageIdentity : .peripheral
    }

    /// A URL-like observation at the top of the frame can remain relevant even
    /// when vertically distant from the QR, but only when it is horizontally
    /// aligned with the QR's visual context. This preserves browser-bar
    /// contradictions without promoting a separate window beside the QR.
    private func adjustedAssociationStrength(
        _ association: ContextAssociationEngine.Association,
        role: SemanticContextRole,
        observation: OCRObservation
    ) -> AssociationStrength {
        guard role == .browserDomainCandidate,
              association.strength == .weak,
              let qr = association.qrBoundingBox else {
            return association.strength
        }
        let tolerance = 0.08
        let textCenterX = observation.boundingBox.x + observation.boundingBox.width / 2
        let horizontallyAligned = textCenterX >= qr.x - tolerance &&
            textCenterX <= qr.x + qr.width + tolerance
        return horizontallyAligned ? .plausible : .weak
    }

    private func makeDomainEvidence(
        from evidence: SpatialTextEvidence,
        associationPolicy: ContextAssociationPolicy
    ) -> [DomainClaimEvidence] {
        domainExtractor.extractDomainClaims(from: evidence.text).map { extracted in
            let sourceType: DomainSourceType
            if extracted.sourceType == .emailDomain {
                sourceType = .emailDomain
            } else if evidence.semanticRole == .browserDomainCandidate {
                sourceType = .browserDomainCandidate
            } else if evidence.semanticRole == .qrLocal ||
                        evidence.semanticRole == .dialogContext {
                sourceType = extracted.sourceType == .urlDomain
                    ? .urlDomain
                    : .qrLocalDomain
            } else {
                sourceType = extracted.sourceType
            }
            let participates = extracted.isAuthoritativeIdentityEvidence &&
                sourceType != .emailDomain && (
                associationPolicy == .unfilteredVisualText || (
                    evidence.semanticRole != .peripheral &&
                        evidence.semanticRole != .unassociated
                )
            )
            return DomainClaimEvidence(
                domain: extracted.domain,
                sourceType: sourceType,
                sourceObservationId: evidence.observationId,
                ocrConfidence: evidence.confidence,
                contextRole: evidence.semanticRole,
                recognitionStatus: extracted.recognitionStatus,
                participatesInServiceIdentity: participates
            )
        }
    }

    private func makePurposeEvidence(
        from evidence: SpatialTextEvidence,
        isFIDO: Bool
    ) -> [PurposeClaimEvidence] {
        let matches = purposeMatches(in: evidence.text, isFIDO: isFIDO)

        var seenPurposes = Set<IntendedPurpose>()
        return matches
            .filter { seenPurposes.insert($0.0).inserted }
            .map { purpose, phrase in
                let applicability = purposeApplicability(
                    for: purpose,
                    in: evidence.text,
                    semanticRole: evidence.semanticRole
                )
                return PurposeClaimEvidence(
                    purpose: purpose,
                    matchedPhrase: phrase,
                    sourceObservationId: evidence.observationId,
                    ocrConfidence: evidence.confidence,
                    contextRole: evidence.semanticRole,
                    priority: purposePriority(
                        for: evidence.text,
                        semanticRole: evidence.semanticRole,
                        applicability: applicability
                    ),
                    applicability: applicability
                )
            }
    }

    private struct LocalTextComposition {
        let evidence: [SpatialTextEvidence]

        var text: String { evidence.map(\.text).joined(separator: " ") }
        var sourceObservationIds: [String] { evidence.map(\.observationId) }
        var confidence: Float { evidence.map(\.confidence).min() ?? 0 }
        var contextRole: SemanticContextRole {
            evidence.contains { $0.semanticRole == .qrLocal }
                ? .qrLocal
                : .dialogContext
        }
    }

    /// Composes only consecutive OCR lines that belong to the same QR, OCR
    /// region, and visual column. This repairs ordinary Vision line breaks
    /// without joining unrelated text elsewhere in the frame.
    private func makeLocalTextCompositions(
        from evidence: [SpatialTextEvidence]
    ) -> [LocalTextComposition] {
        let eligible = evidence.filter {
            $0.associatedQRCodeIndex != nil &&
                ($0.semanticRole == .qrLocal || $0.semanticRole == .dialogContext)
        }
        let grouped = Dictionary(grouping: eligible) {
            "\($0.associatedQRCodeIndex ?? -1)|\($0.sourceRegion.rawValue)"
        }
        var compositions: [LocalTextComposition] = []

        for key in grouped.keys.sorted() {
            guard let group = grouped[key] else { continue }
            let ordered = group.sorted {
                if $0.boundingBox.y == $1.boundingBox.y {
                    return $0.boundingBox.x < $1.boundingBox.x
                }
                return $0.boundingBox.y > $1.boundingBox.y
            }
            for start in ordered.indices {
                var chain = [ordered[start]]
                var current = ordered[start]
                var currentIndex = start
                while chain.count < 3,
                      let nextIndex = ordered.indices.first(where: {
                          $0 > currentIndex && areComposableLines(current, ordered[$0])
                      }) {
                    let next = ordered[nextIndex]
                    chain.append(next)
                    current = next
                    currentIndex = nextIndex
                    if chain.count >= 2 {
                        compositions.append(LocalTextComposition(evidence: chain))
                    }
                }
            }
        }

        var seen = Set<String>()
        return compositions.filter {
            seen.insert($0.sourceObservationIds.joined(separator: "+")).inserted
        }
    }

    private func areComposableLines(
        _ first: SpatialTextEvidence,
        _ second: SpatialTextEvidence
    ) -> Bool {
        guard first.associatedQRCodeIndex == second.associatedQRCodeIndex,
              first.sourceRegion == second.sourceRegion else { return false }
        let firstBox = first.boundingBox
        let secondBox = second.boundingBox
        let overlap = max(
            0,
            min(firstBox.x + firstBox.width, secondBox.x + secondBox.width) -
                max(firstBox.x, secondBox.x)
        )
        let minimumWidth = max(0.001, min(firstBox.width, secondBox.width))
        guard overlap / minimumWidth >= 0.45 else { return false }

        let verticalGap = max(
            0,
            max(firstBox.y, secondBox.y) -
                min(firstBox.y + firstBox.height, secondBox.y + secondBox.height)
        )
        let maximumGap = max(0.035, max(firstBox.height, secondBox.height) * 1.5)
        return verticalGap <= maximumGap
    }

    private func purposePriority(
        for text: String,
        semanticRole: SemanticContextRole,
        applicability: PurposeEvidenceApplicability
    ) -> PurposeEvidencePriority {
        guard applicability == .currentAction else { return .background }
        if containsDirectQRInstruction(text) {
            return .directQRCodeInstruction
        }
        switch semanticRole {
        case .qrLocal, .dialogContext:
            return .sameDialogInstruction
        case .pageIdentity:
            return .associatedPageExplanation
        case .browserDomainCandidate, .peripheral, .unassociated:
            return .background
        }
    }

    private func purposeApplicability(
        for _: IntendedPurpose,
        in text: String,
        semanticRole: SemanticContextRole
    ) -> PurposeEvidenceApplicability {
        if semanticRole == .browserDomainCandidate ||
            semanticRole == .peripheral || semanticRole == .unassociated {
            return .background
        }

        let normalized = normalize(text)
        let futureOrSecondaryMarkers = [
            "after signing on", "after signing in", "after you sign in",
            "after you log in", "next time", "do not have one",
            "don't have one", "create a passkey later",
            "register a passkey later"
        ]
        if futureOrSecondaryMarkers.contains(where: normalized.contains) {
            return .futureOrSecondary
        }
        return .currentAction
    }

    private func makePurposeEvidence(
        from composition: LocalTextComposition,
        isFIDO: Bool
    ) -> [PurposeClaimEvidence] {
        let matches = purposeMatches(in: composition.text, isFIDO: isFIDO)
        var seenPurposes = Set<IntendedPurpose>()
        return matches.filter {
            seenPurposes.insert($0.0).inserted
        }.map { purpose, phrase in
            let applicability = purposeApplicability(
                for: purpose,
                in: composition.text,
                semanticRole: composition.contextRole
            )
            return PurposeClaimEvidence(
                purpose: purpose,
                matchedPhrase: phrase,
                sourceObservationIds: composition.sourceObservationIds,
                ocrConfidence: composition.confidence,
                contextRole: composition.contextRole,
                priority: purposePriority(
                    for: composition.text,
                    semanticRole: composition.contextRole,
                    applicability: applicability
                ),
                applicability: applicability
            )
        }
    }

    private func deduplicatedPurposeEvidence(
        _ evidence: [PurposeClaimEvidence]
    ) -> [PurposeClaimEvidence] {
        var seen = Set<String>()
        return evidence.filter { seen.insert($0.id).inserted }
    }

    private func makeComposedSemanticClaims(
        from compositions: [LocalTextComposition]
    ) -> [VisualClaimEvidence] {
        compositions.flatMap { composition in
            let cues = detectedSocialEngineeringCues(in: composition.text)
            let actions = detectedNonAuthenticationTerms(in: composition.text)
            return composition.sourceObservationIds.flatMap { sourceID in
                cues.map {
                    VisualClaimEvidence(
                        kind: .socialEngineering,
                        value: $0.rawValue,
                        sourceObservationId: sourceID,
                        ocrConfidence: composition.confidence,
                        contextZone: .adjacent,
                        associationStrength: .plausible,
                        semanticRole: composition.contextRole
                    )
                } + actions.map {
                    VisualClaimEvidence(
                        kind: .nonAuthenticationAction,
                        value: $0,
                        sourceObservationId: sourceID,
                        ocrConfidence: composition.confidence,
                        contextZone: .adjacent,
                        associationStrength: .plausible,
                        semanticRole: composition.contextRole
                    )
                }
            }
        }
    }

    private func deduplicatedVisualClaims(
        _ claims: [VisualClaimEvidence]
    ) -> [VisualClaimEvidence] {
        var seen = Set<String>()
        return claims.filter { seen.insert($0.id).inserted }
    }

    private struct CompositionalPurposePattern {
        let purpose: IntendedPurpose
        let actions: [String]
        let objects: [String]
    }

    private func purposeMatches(
        in text: String,
        isFIDO: Bool
    ) -> [(IntendedPurpose, String)] {
        let normalized = canonicalPurposeText(text)
        var matches: [(IntendedPurpose, String)] = []
        func collect(_ purpose: IntendedPurpose, _ phrases: [String]) {
            for phrase in phrases where containsAffirmedPhrase(phrase, in: normalized) {
                matches.append((purpose, phrase))
            }
        }

        collect(.registerPasskey, [
            "create a passkey", "register a passkey", "set up a passkey"
        ])
        collect(.recoverAccount, [
            "recover your account", "account recovery", "reset your account"
        ])
        collect(.pairDevice, [
            "pair a device", "pair your device", "add a device",
            "connect a device", "connect your mobile device"
        ])
        collect(.verifyIdentity, [
            "verify your identity", "identity verification",
            "verify your email address", "verifying your email address",
            "email address will be verified", "scan to verify your email"
        ])
        collect(.signIn, ["sign in", "log in", "login", "authenticate"])
        if isFIDO {
            collect(.signIn, [
                "use your passkey", "has your passkey for", "your passkey for"
            ])
            if !matches.contains(where: { $0.0 == .registerPasskey }) {
                // Vision commonly separates "your" from "passkey for <domain>"
                // at a line boundary. A detected FIDO QR constrains this
                // otherwise broad fragment to the existing-passkey ceremony.
                collect(.signIn, ["passkey for"])
            }
        }
        collect(.payment, [
            "make a payment", "receive a payment", "receive your salary",
            "claim your refund", "scan to pay", "approve this payment",
            "payment confirmation"
        ])
        collect(.openDocument, [
            "open the document", "view the document", "download the document",
            "access the document", "document access"
        ])
        collect(.connectWiFi, [
            "connect to wi-fi", "connect to wifi", "join the wi-fi", "join the wifi"
        ])

        // Hostname labels such as `connect.secure.example.com` are identity
        // evidence, not action verbs. Remove extracted domain strings before
        // action/object composition so `connect` + `device` cannot invent a
        // PAIR_DEVICE purpose.
        let compositionalText = domainExtractor.extractDomainClaims(from: text)
            .reduce(normalized) { partial, claim in
                partial.replacingOccurrences(of: claim.domain, with: " ")
            }
        matches += compositionalPurposeMatches(in: compositionalText)
        var seenPurposes = Set<IntendedPurpose>()
        return matches.filter { seenPurposes.insert($0.0).inserted }
    }

    private func compositionalPurposeMatches(
        in normalizedText: String
    ) -> [(IntendedPurpose, String)] {
        let patterns = [
            CompositionalPurposePattern(
                purpose: .verifyIdentity,
                actions: [
                    "verify", "verifying", "verification", "confirm", "confirming",
                    "confirmed", "confirmation", "prove", "proven", "proof",
                    "validate", "validated", "validation"
                ],
                objects: ["identity", "email", "account", "ownership"]
            ),
            CompositionalPurposePattern(
                purpose: .payment,
                actions: [
                    "pay", "paid", "approve", "approved", "authorize", "authorized",
                    "authorise", "authorised", "authorizing", "authorising", "send",
                    "sent", "sending", "receive", "received", "receiving", "claim",
                    "claimed", "claiming", "collect", "collected", "collecting",
                    "redeem", "redeemed", "redeeming"
                ],
                objects: [
                    "payment", "money", "transfer", "refund", "funds", "salary",
                    "bonus", "reward", "prize", "£", "$", "€"
                ]
            ),
            CompositionalPurposePattern(
                purpose: .openDocument,
                actions: [
                    "open", "opened", "opening", "view", "viewed", "viewing",
                    "access", "accessed", "accessing", "retrieve", "retrieved",
                    "retrieving", "download", "downloaded", "downloading"
                ],
                objects: ["document", "file", "invoice", "pdf", "report"]
            ),
            CompositionalPurposePattern(
                purpose: .pairDevice,
                actions: [
                    "pair", "paired", "pairing", "connect", "connected", "connecting",
                    "link", "linked", "linking", "add", "added", "adding"
                ],
                objects: ["device", "phone", "computer", "tablet"]
            ),
            CompositionalPurposePattern(
                purpose: .recoverAccount,
                actions: [
                    "recover", "recovered", "recovering", "regain", "regained",
                    "regaining", "restore", "restored", "restoring", "reset",
                    "resetting"
                ],
                objects: ["account", "access"]
            )
        ]
        let tokens = purposeTokens(normalizedText)
        var matches: [(IntendedPurpose, String)] = []

        for pattern in patterns {
            outerLoop: for (actionIndex, action) in tokens.enumerated()
            where pattern.actions.contains(action) {
                for (objectIndex, object) in tokens.enumerated()
                where pattern.objects.contains(object) &&
                    abs(objectIndex - actionIndex) <= 8 {
                    guard !isLocallyNegated(
                        actionIndex: actionIndex,
                        objectIndex: objectIndex,
                        tokens: tokens
                    ) else { continue }
                    matches.append((pattern.purpose, "\(action) + \(object)"))
                    break outerLoop
                }
            }
        }
        return matches
    }

    private func containsAffirmedPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: canonicalPurposeText(phrase))
        let pattern = #"(?<![\p{L}\p{N}])"# + escaped + #"(?![\p{L}\p{N}])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let nsText = text as NSString
        let matches = expression.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )
        return matches.contains { match in
            let prefix = nsText.substring(to: match.range.location)
            return !purposeTokens(prefix).suffix(3).contains(where: isNegationToken)
        }
    }

    private func isLocallyNegated(
        actionIndex: Int,
        objectIndex: Int,
        tokens: [String]
    ) -> Bool {
        let start = max(0, min(actionIndex, objectIndex) - 3)
        let end = max(actionIndex, objectIndex)
        return tokens[start...end].contains(where: isNegationToken)
    }

    private func isNegationToken(_ token: String) -> Bool {
        ["not", "no", "never", "without", "cannot"].contains(token)
    }

    private func purposeTokens(_ text: String) -> [String] {
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "£$€")
        )
        return canonicalPurposeText(text)
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
    }

    private func canonicalPurposeText(_ text: String) -> String {
        normalize(text)
            .replacingOccurrences(of: "doesn’t", with: "does not")
            .replacingOccurrences(of: "doesn't", with: "does not")
            .replacingOccurrences(of: "isn’t", with: "is not")
            .replacingOccurrences(of: "isn't", with: "is not")
            .replacingOccurrences(of: "aren’t", with: "are not")
            .replacingOccurrences(of: "aren't", with: "are not")
            .replacingOccurrences(of: "can’t", with: "cannot")
            .replacingOccurrences(of: "can't", with: "cannot")
            .replacingOccurrences(of: "won’t", with: "will not")
            .replacingOccurrences(of: "won't", with: "will not")
    }

    private func materialPurposes(
        from evidence: [PurposeClaimEvidence]
    ) -> [IntendedPurpose] {
        let eligible = evidence.filter { $0.priority != .background }
        guard let strongest = eligible.map(\.priority).max() else { return [] }
        return eligible.filter { $0.priority == strongest }.map(\.purpose).uniqued()
    }

    private struct ServiceEvidence {
        let service: String
        let sourceObservationId: String
        let role: SemanticContextRole
        let strength: AssociationStrength
    }

    private struct IdentityContextEvidence {
        let identity: String
        let sourceObservationId: String
        let role: SemanticContextRole
        let strength: AssociationStrength
    }

    private struct ContextCompetitionAssessment {
        let isPresent: Bool
        let resolution: AssociationResolution
    }

    private func makeContextCompetitionAssessment(
        from evidence: [SpatialTextEvidence],
        domainEvidence: [DomainClaimEvidence],
        associationPolicy: ContextAssociationPolicy
    ) -> ContextCompetitionAssessment {
        let evidenceByID = Dictionary(uniqueKeysWithValues: evidence.map {
            ($0.observationId, $0)
        })
        var claims: [IdentityContextEvidence] = []

        for item in evidence where item.semanticRole != .unassociated {
            for service in detectedServiceIdentityClaims(
                in: normalize(item.text),
                role: item.semanticRole
            ) {
                claims.append(IdentityContextEvidence(
                    identity: "SERVICE:\(service)",
                    sourceObservationId: item.observationId,
                    role: item.semanticRole,
                    strength: item.associationStrength
                ))
            }
        }
        for domain in domainEvidence where domain.participatesInServiceIdentity {
            guard let source = evidenceByID[domain.sourceObservationId] else { continue }
            let identity = serviceName(for: domain.domain).map { "SERVICE:\($0)" }
                ?? "DOMAIN:\(domain.domain)"
            claims.append(IdentityContextEvidence(
                identity: identity,
                sourceObservationId: source.observationId,
                role: source.semanticRole,
                strength: source.associationStrength
            ))
        }

        if associationPolicy == .spatiallyAssociated {
            claims = claims.filter { $0.strength != .unassociated }
        }
        let identities = claims.map(\.identity).uniqued()
        guard identities.count > 1 else {
            return ContextCompetitionAssessment(
                isPresent: false,
                resolution: .notApplicable
            )
        }

        let strongIdentities = Set(claims.filter {
            $0.strength == .strong
        }.map(\.identity))
        let plausibleIdentities = Set(claims.filter {
            $0.strength == .plausible
        }.map(\.identity))
        let isAmbiguous = strongIdentities.isEmpty && plausibleIdentities.count > 1
        return ContextCompetitionAssessment(
            isPresent: true,
            resolution: isAmbiguous ? .ambiguous : .resolved
        )
    }

    private func makeIdentityContradictionEvents(
        from evidence: [SpatialTextEvidence],
        domainEvidence: [DomainClaimEvidence],
        associationPolicy: ContextAssociationPolicy,
        associationResolution: AssociationResolution
    ) -> [IdentityContradictionEvent] {
        // Two equally plausible contexts support UNCERTAIN association rather
        // than a strong contradiction. A strong contradiction requires a
        // defensible primary association.
        guard associationResolution != .ambiguous else { return [] }

        let evidenceByID = Dictionary(uniqueKeysWithValues: evidence.map {
            ($0.observationId, $0)
        })
        var services: [ServiceEvidence] = []
        for item in evidence {
            let direct = detectedServiceIdentityClaims(
                in: normalize(item.text),
                role: item.semanticRole
            )
            let mapped = domainEvidence.filter {
                $0.sourceObservationId == item.observationId &&
                    $0.participatesInServiceIdentity
            }.compactMap { serviceName(for: $0.domain) }
            for service in (direct + mapped).uniqued() {
                services.append(ServiceEvidence(
                    service: service,
                    sourceObservationId: item.observationId,
                    role: item.semanticRole,
                    strength: item.associationStrength
                ))
            }
        }

        let localRoles: Set<SemanticContextRole> = [.qrLocal, .dialogContext]
        var contextualRoles: Set<SemanticContextRole> = [
            .pageIdentity, .browserDomainCandidate
        ]
        if associationPolicy == .unfilteredVisualText {
            contextualRoles.formUnion([.peripheral, .unassociated])
        }
        let corroboratedContextualServices = corroboratedPageContextServices(
            from: services,
            evidenceByID: evidenceByID,
            domainEvidence: domainEvidence,
            contextualRoles: contextualRoles
        )
        let eligibleServices = services.filter {
            isEligibleIdentityEvidence(
                role: $0.role,
                strength: $0.strength,
                associationPolicy: associationPolicy
            ) || (
                associationPolicy == .spatiallyAssociated &&
                    contextualRoles.contains($0.role) &&
                    corroboratedContextualServices.contains($0.service) &&
                    $0.strength != .unassociated
            )
        }
        let local = eligibleServices.filter { localRoles.contains($0.role) }
        let contextual = eligibleServices.filter { contextualRoles.contains($0.role) }
        let localNames = local.map(\.service).uniqued()
        let contextualNames = contextual.map(\.service).uniqued()
        let conflictingContextual = contextualNames.filter { !localNames.contains($0) }

        if localNames.count > 1 || (!localNames.isEmpty && !conflictingContextual.isEmpty) {
            let identities = (localNames + conflictingContextual).uniqued()
            let involved = eligibleServices.filter { identities.contains($0.service) }
            let sources = involved.map(\.sourceObservationId).uniqued()
            let domains = domainEvidence.filter {
                sources.contains($0.sourceObservationId) && $0.participatesInServiceIdentity
            }.map(\.domain).uniqued()
            return [IdentityContradictionEvent(
                kind: .serviceMismatch,
                identities: identities,
                domains: domains,
                sourceObservationIds: sources
            )]
        }

        guard !localNames.isEmpty else { return [] }
        let localSources = Set(local.map(\.sourceObservationId))
        let localDomains = domainEvidence.filter {
            localSources.contains($0.sourceObservationId) &&
                $0.participatesInServiceIdentity
        }
        let contextualDomains = domainEvidence.filter {
            contextualRoles.contains($0.contextRole) &&
                $0.participatesInServiceIdentity &&
                evidenceByID[$0.sourceObservationId].map {
                    isEligibleIdentityEvidence(
                        role: $0.semanticRole,
                        strength: $0.associationStrength,
                        associationPolicy: associationPolicy
                    )
                } == true
        }
        let conflictingDomains = (localDomains + contextualDomains).filter { claim in
            localNames.allSatisfy { service in
                guard let profile = serviceProfiles.first(where: { $0.name == service }) else {
                    return false
                }
                return profile.domains.allSatisfy {
                    !domainsAreRelated($0, claim.domain)
                }
            }
        }
        guard !conflictingDomains.isEmpty else { return [] }
        return [IdentityContradictionEvent(
            kind: .brandDomainConflict,
            identities: localNames,
            domains: conflictingDomains.map(\.domain).uniqued(),
            sourceObservationIds: (
                local.map(\.sourceObservationId) +
                    conflictingDomains.map(\.sourceObservationId)
            ).uniqued()
        )]
    }

    private func isEligibleIdentityEvidence(
        role: SemanticContextRole,
        strength: AssociationStrength,
        associationPolicy: ContextAssociationPolicy
    ) -> Bool {
        if associationPolicy == .unfilteredVisualText {
            return strength != .unassociated
        }
        let eligibleRoles: Set<SemanticContextRole> = [
            .qrLocal, .dialogContext, .pageIdentity, .browserDomainCandidate
        ]
        return eligibleRoles.contains(role) &&
            (strength == .strong || strength == .plausible)
    }

    /// Weak page evidence can still belong to the QR's page when the same
    /// service is corroborated. Spatial overlap remains the normal path; a
    /// single browser-domain/page-identity pair may also establish the page
    /// identity when browser chrome is distant from a centred QR dialog.
    private func corroboratedPageContextServices(
        from services: [ServiceEvidence],
        evidenceByID: [String: SpatialTextEvidence],
        domainEvidence: [DomainClaimEvidence],
        contextualRoles: Set<SemanticContextRole>
    ) -> Set<String> {
        let contextual = services.filter {
            contextualRoles.contains($0.role) && $0.strength != .unassociated
        }
        let grouped = Dictionary(grouping: contextual, by: \.service)

        return Set(grouped.compactMap { service, claims in
            let sourceIDs = Set(claims.map(\.sourceObservationId))
            let overlapsQRContext = sourceIDs.contains { sourceID in
                guard let item = evidenceByID[sourceID] else { return false }
                return horizontallyOverlapsQRCodeContext(item)
            }
            let separatelyCorroborated = sourceIDs.count >= 2
            let browserClaims = claims.filter { $0.role == .browserDomainCandidate }
            let pageClaims = claims.filter { $0.role == .pageIdentity }
            let browserChromeCorroborated = browserClaims.contains { browserClaim in
                guard let browserEvidence = evidenceByID[browserClaim.sourceObservationId]
                else { return false }
                let browserMidY = browserEvidence.boundingBox.y + browserEvidence.boundingBox.height / 2
                return pageClaims.contains { pageClaim in
                    guard let pageEvidence = evidenceByID[pageClaim.sourceObservationId]
                    else { return false }
                    let pageMidY = pageEvidence.boundingBox.y + pageEvidence.boundingBox.height / 2
                    return abs(browserMidY - pageMidY) <= 0.075
                }
            }
            let textAndDomainCorroborated = sourceIDs.contains { sourceID in
                guard let item = evidenceByID[sourceID] else { return false }
                let hasDirectName = detectedServiceIdentityClaims(
                    in: normalize(item.text),
                    role: item.semanticRole
                ).contains(service)
                let hasMatchingDomain = domainEvidence.contains { domain in
                    domain.sourceObservationId == sourceID &&
                        domain.recognitionStatus == .authoritative &&
                        serviceName(for: domain.domain) == service
                }
                return hasDirectName && hasMatchingDomain
            }
            let soleCorroboratedBrowserContext = grouped.count == 1 &&
                browserChromeCorroborated
            return (overlapsQRContext &&
                    (separatelyCorroborated || textAndDomainCorroborated)) ||
                soleCorroboratedBrowserContext
                ? service
                : nil
        })
    }

    private func horizontallyOverlapsQRCodeContext(
        _ evidence: SpatialTextEvidence
    ) -> Bool {
        guard let qr = evidence.associatedQRCodeBoundingBox else { return false }
        let left = max(evidence.boundingBox.x, qr.x)
        let right = min(
            evidence.boundingBox.x + evidence.boundingBox.width,
            qr.x + qr.width
        )
        return right - left >= 0.02
    }

    private func serviceName(for domain: String) -> String? {
        serviceProfiles.first { profile in
            profile.domains.contains { domainsAreRelated(domain, $0) }
        }?.name
    }

    private func containsDirectQRInstruction(_ text: String) -> Bool {
        let normalized = normalize(text)
        let scanLanguage = [
            "scan this qr", "scan the qr", "scan this code", "qr code",
            "scan with your phone", "use your phone", "use your phone or tablet"
        ].contains { normalized.contains($0) }
        return scanLanguage
    }

    private func detectedServices(in text: String) -> [String] {
        serviceProfiles.compactMap { profile in
            profile.terms.contains(where: { containsPhrase($0, in: text) })
                ? profile.name
                : nil
        }
    }

    /// A federated-login button names an authentication provider, not
    /// necessarily the service receiving the passkey session. Preserve the OCR
    /// text, but do not promote that provider to relying-party identity unless
    /// it is stated in the direct QR instruction.
    private func detectedServiceIdentityClaims(
        in text: String,
        role: SemanticContextRole
    ) -> [String] {
        detectedServices(in: text).filter { service in
            guard role != .qrLocal else { return true }
            let normalizedService = normalize(service)
            let providerPhrases = [
                "continue with \(normalizedService)",
                "sign in with \(normalizedService)",
                "log in with \(normalizedService)",
                "login with \(normalizedService)",
                "use \(normalizedService) to continue"
            ]
            return !providerPhrases.contains { containsPhrase($0, in: text) }
        }
    }

    private func inferredPurposes(in text: String) -> [IntendedPurpose] {
        purposeMatches(in: text, isFIDO: false).map(\.0)
    }

    private func detectedNonAuthenticationTerms(in text: String) -> [String] {
        var terms = [
            "make a payment", "receive a payment", "receive your salary",
            "claim your refund", "scan to pay", "open the document",
            "view the document", "download the document", "connect to wi-fi",
            "connect to wifi", "join the wi-fi", "join the wifi", "claim your prize",
            "receive your bonus", "claim your bonus", "collect your bonus",
            "claim your reward", "collect your reward"
        ].filter { containsAffirmedPhrase($0, in: canonicalPurposeText(text)) }
        let unrelatedPurposes: Set<IntendedPurpose> = [
            .payment, .openDocument, .connectWiFi, .pairDevice,
            .recoverAccount, .verifyIdentity
        ]
        terms += compositionalPurposeMatches(
            in: canonicalPurposeText(text)
        ).filter {
            unrelatedPurposes.contains($0.0)
        }.map(\.1)
        return terms.uniqued()
    }

    private func detectedSocialEngineeringCues(
        in text: String
    ) -> [SocialEngineeringCue] {
        let normalized = canonicalPurposeText(text)
        var cues: [SocialEngineeringCue] = []
        add(.urgency, ifAny: [
            "act now", "immediately", "within 24 hours", "urgent action",
            "time is running out"
        ], in: text, to: &cues)
        add(.threat, ifAny: [
            "account will be suspended", "account will be deleted",
            "access will be blocked", "account is currently under threat",
            "account is under threat", "account under threat",
            "security breach detected", "account has been compromised"
        ], in: text, to: &cues)
        if containsPhrase("account", in: text),
           containsPhrase("threat", in: text),
           !cues.contains(.threat) {
            cues.append(.threat)
        }
        add(.ignoreWarnings, ifAny: [
            "ignore the warning", "ignore any warning",
            "ignore the service name", "disregard the warning"
        ], in: text, to: &cues)
        add(.secrecy, ifAny: [
            "do not tell anyone", "keep this secret", "keep this confidential"
        ], in: text, to: &cues)
        add(.reward, ifAny: [
            "claim your prize", "claim your reward", "collect your reward",
            "claim your bonus", "collect your bonus", "you have won",
            "bonus is ready", "reward is ready"
        ], in: text, to: &cues)
        add(.unexpectedPayment, ifAny: [
            "receive your salary", "unexpected refund", "claim your refund",
            "receive your bonus", "claim your bonus", "collect your bonus"
        ], in: text, to: &cues)
        let hasPaymentPattern = compositionalPurposeMatches(
            in: normalized
        ).contains { $0.0 == .payment }
        if hasPaymentPattern,
           ["bonus", "reward", "prize"].contains(where: {
               containsPhrase($0, in: normalized)
           }),
           !cues.contains(.reward) {
            cues.append(.reward)
        }
        if hasPaymentPattern,
           ["bonus", "reward", "salary", "refund"].contains(where: {
               containsPhrase($0, in: normalized)
           }),
           !cues.contains(.unexpectedPayment) {
            cues.append(.unexpectedPayment)
        }
        add(.authorityPressure, ifAny: [
            "it support requires", "your manager requires",
            "administrator requires", "security team requires"
        ], in: text, to: &cues)
        add(.repeatedApproval, ifAny: [
            "approve again", "keep approving", "approve every prompt"
        ], in: text, to: &cues)
        return cues
    }

    private func detectedChannels(
        in text: String,
        intent: UserIntent
    ) -> [ChannelCue] {
        var channels: [ChannelCue] = []
        add(.loginPage, ifAny: ["sign in to your account", "login page"], in: text, to: &channels)
        add(.emailOrChat, ifAny: ["from:", "subject:", "sent:", "reply to"], in: text, to: &channels)

        let declared: ChannelCue?
        switch intent.displaySource {
        case .sharedComputer: declared = .sharedComputer
        case .kiosk: declared = .kiosk
        case .message: declared = .emailOrChat
        case .printedPage: declared = .printedPage
        case .unrelatedWebpage: declared = .unrelatedWebpage
        case .ownDevice: declared = nil
        case .unknown: declared = .unknown
        }
        if let declared, !channels.contains(declared) {
            channels.append(declared)
        }
        return channels
    }

    private func detectedContradictions(
        observation: ScanObservation,
        intent: UserIntent,
        services: [String],
        domains: [String],
        browserDomainCandidates: [BrowserDomainCandidate],
        identityEvents: [IdentityContradictionEvent],
        associationResolution: AssociationResolution,
        purposes: [IntendedPurpose],
        nonAuthenticationTerms: [String]
    ) -> [ContradictionFlag] {
        var flags: [ContradictionFlag] = []

        if intent.visibleServiceMatchesExpectation == .no {
            flags.append(.expectedServiceMismatch)
        } else if let expected = normalizedExpectedService(intent.expectedService),
           !services.isEmpty,
           !isExpectedServiceVisible(
               expected,
               services: services,
               domains: domains
           ) {
            flags.append(.expectedServiceMismatch)
        }
        if intent.visiblePurposeMatchesExpectation == .no {
            flags.append(.expectedPurposeMismatch)
        } else if let expectedPurpose = intent.expectedPurpose,
           expectedPurpose != .unsure,
           !purposes.isEmpty,
           !purposes.contains(expectedPurpose) {
            flags.append(.expectedPurposeMismatch)
        }
        if identityEvents.contains(where: { $0.kind == .serviceMismatch }) {
            flags.append(.multipleVisibleServices)
        }
        if purposes.count > 1 {
            flags.append(.competingPurposes)
        }
        if identityEvents.contains(where: { $0.kind == .brandDomainConflict }) {
            flags.append(.brandDomainConflict)
        }
        if identityEvents.contains(where: { event in
            event.sourceObservationIds.contains { id in
                browserDomainCandidates.contains { $0.sourceObservationId == id }
            }
        }) {
            flags.append(.browserDomainCandidateConflict)
        }
        if associationResolution == .ambiguous {
            flags.append(.ambiguousContextAssociation)
        }
        if observation.qrTypes.contains(.fido), !nonAuthenticationTerms.isEmpty {
            flags.append(.fidoPresentedAsUnrelatedAction)
        }
        if intent.initiationStatus == .no {
            flags.append(.unexpectedInitiation)
        }
        if intent.startedOnReceivingClient == .no {
            flags.append(.receivingClientNotStarted)
        }
        if intent.receivingClientTrust == .no {
            flags.append(.untrustedReceivingClient)
        }
        return flags
    }

    private func completenessIndicators(
        observation: ScanObservation,
        intent: UserIntent,
        services: [String],
        domains: [String],
        purposes: [IntendedPurpose],
        authenticationTerms: [String]
    ) -> [CompletenessIndicator] {
        var indicators: [CompletenessIndicator] = []
        if observation.qrTypes.contains(.fido) { indicators.append(.fidoQRCode) }
        if !services.isEmpty { indicators.append(.readableIdentity) }
        if !domains.isEmpty { indicators.append(.visibleDomain) }
        if !purposes.isEmpty { indicators.append(.clearPurpose) }
        if !authenticationTerms.isEmpty { indicators.append(.authenticationLanguage) }
        if observation.ocrObservations.contains(where: { $0.region == .qrSurrounding }) {
            indicators.append(.qrNearText)
        }
        if intent.hasDeclaredIntent { indicators.append(.userIntent) }
        if intent.hasTrustedReceivingClientContext {
            indicators.append(.receivingClientContext)
        }
        if observation.ocrProcessingStatus == .completed {
            indicators.append(.successfulOCR)
        }
        return indicators
    }

    private func hasBrandDomainConflict(
        services: [String],
        domains: [String]
    ) -> Bool {
        guard !services.isEmpty, !domains.isEmpty else { return false }
        return services.contains { service in
            guard let profile = serviceProfiles.first(where: { $0.name == service }) else {
                return false
            }
            return !domains.contains { visibleDomain in
                profile.domains.contains { knownDomain in
                    domainsAreRelated(visibleDomain, knownDomain)
                }
            }
        }
    }

    private func domainsAreRelated(_ first: String, _ second: String) -> Bool {
        first == second || first.hasSuffix(".\(second)") || second.hasSuffix(".\(first)")
    }

    private func normalizedExpectedService(_ service: String?) -> String? {
        guard let normalized = service.map(normalize), !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    private func isExpectedServiceVisible(
        _ expected: String,
        services: [String],
        domains: [String]
    ) -> Bool {
        if services.contains(where: { normalize($0) == expected }) {
            return true
        }

        return serviceProfiles.contains { profile in
            let profileIsExpected = profile.terms.contains {
                normalize($0) == expected
            } || profile.domains.contains {
                domainsAreRelated(expected, $0)
            }
            guard profileIsExpected, services.contains(profile.name) else {
                return false
            }
            return domains.isEmpty || domains.contains { visibleDomain in
                profile.domains.contains {
                    domainsAreRelated(visibleDomain, $0)
                }
            }
        }
    }

    private func matchedTerms(_ terms: [String], in text: String) -> [String] {
        terms.filter { containsPhrase($0, in: text) }
    }

    private func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: normalize(phrase))
        let pattern = #"(?<![\p{L}\p{N}])"# + escaped + #"(?![\p{L}\p{N}])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add<T: Equatable>(
        _ value: T,
        ifAny terms: [String],
        in text: String,
        to values: inout [T]
    ) {
        if terms.contains(where: { containsPhrase($0, in: text) }),
           !values.contains(value) {
            values.append(value)
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
