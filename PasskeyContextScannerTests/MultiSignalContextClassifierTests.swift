import XCTest
@testable import PasskeyContextScanner

final class MultiSignalContextClassifierTests: XCTestCase {
    private let classifier = ContextClassifier()

    func testClearLegitimatePasskeyContextIsConsistent() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com",
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .consistent)
        XCTAssertLessThan(result.riskScore, 40)
        XCTAssertGreaterThanOrEqual(result.evidenceCompleteness, 60)
        XCTAssertEqual(result.visualEvidenceCompleteness, .sufficient)
        XCTAssertEqual(result.intentSessionCompleteness, .sufficient)
        XCTAssertTrue(result.observedNegativeEvidence.isEmpty)
        XCTAssertTrue(result.limitations.contains { $0.contains("receiving session") })
        XCTAssertEqual(result.sessionBindingAssessment, .notVerifiable)
        XCTAssertEqual(
            result.assessmentDimensions.first { $0.kind == .identity }?.finding,
            .aligned
        )
        XCTAssertEqual(
            result.assessmentDimensions.first { $0.kind == .receivingClient }?.finding,
            .aligned
        )
    }

    func testUnknownReceivingClientPreventsConsistentResult() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com",
            intent: UserIntent(
                expectedService: "Microsoft",
                expectedPurpose: .signIn,
                initiationStatus: .yes,
                displaySource: .ownDevice,
                notes: ""
            )
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "receiving_client_trust" &&
                $0.polarity == .limitation
        })
    }

    func testRequestNotStartedOnReceivingClientIsSuspicious() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com",
            intent: trustedIntent(
                service: "Microsoft",
                purpose: .signIn,
                startedOnReceivingClient: .no
            )
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "receiving_client_trust" &&
                $0.triggersSuspiciousOverride
        })
    }

    func testExplicitlyUntrustedReceivingClientIsSuspicious() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com",
            intent: trustedIntent(
                service: "Microsoft",
                purpose: .signIn,
                receivingClientTrust: .no
            )
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.observedNegativeEvidence.contains {
            $0.contains("do not trust")
        })
    }

    func testLegitimateButMinimalContextIsUncertain() {
        let result = classify(near: "Use your phone", full: "")

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertLessThan(result.evidenceCompleteness, 60)
        XCTAssertNotEqual(result.visualEvidenceCompleteness, .sufficient)
    }

    func testInsufficientMeasuredImageQualityPreventsConsistentResult() {
        let base = makeObservation(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com"
        )
        let observation = ScanObservation(
            qrCodes: base.qrCodes,
            ocrObservations: base.ocrObservations,
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: false,
                issues: [.qrTooSmall]
            ),
            qrProcessingStatus: base.qrProcessingStatus,
            ocrProcessingStatus: base.ocrProcessingStatus,
            analysisTiming: base.analysisTiming
        )

        let result = classifier.classify(
            observation: observation,
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertNotEqual(result.visualEvidenceCompleteness, .sufficient)
        XCTAssertTrue(result.limitations.contains { $0.contains("visual quality") })
    }

    func testClearVisualContextWithoutIntentSeparatesCompletenessFamilies() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com"
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertEqual(result.visualEvidenceCompleteness, .sufficient)
        XCTAssertEqual(result.intentSessionCompleteness, .insufficient)
    }

    func testCompleteIntentDoesNotCompensateForSparseVisualContext() {
        let result = classify(
            near: "Use your phone",
            full: "",
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertEqual(result.visualEvidenceCompleteness, .partial)
        XCTAssertEqual(result.intentSessionCompleteness, .sufficient)
    }

    func testNoReadableContextIsUncertain() {
        let observation = makeObservation(
            near: nil,
            full: nil,
            ocrStatus: .noText
        )

        let result = classifier.classify(observation: observation)

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertTrue(result.limitations.contains { $0.contains("No clear visible service") })
        XCTAssertTrue(result.limitations.contains { $0.contains("No clear purpose") })
        XCTAssertTrue(result.ruleResults.contains {
            $0.evidenceCategory == .missingEvidence
        })
    }

    func testNoQRCodeIsUncertainEvenWithOtherwiseCompleteContext() {
        let base = makeObservation(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com"
        )
        let observation = ScanObservation(
            qrCodes: [],
            ocrObservations: base.ocrObservations,
            imageQuality: base.imageQuality,
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed
        )

        let result = classifier.classify(
            observation: observation,
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .uncertain)
    }

    func testRelatedVisibleDomainsDoNotCreateAConflict() {
        let result = classify(
            near: "Microsoft microsoft.com Sign in with a passkey",
            full: "Continue at login.microsoft.com",
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .consistent)
        XCTAssertTrue(result.ruleResults.contains {
            $0.evidenceCategory == .supporting
        })
        XCTAssertFalse(result.ruleResults.contains {
            $0.ruleIdentifier == "identity_evidence" &&
                $0.polarity == .negative
        })
    }

    func testWrongExpectedServiceIsStrongSuspiciousOverride() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "login.microsoft.com",
            intent: intent(service: "Amazon", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "expected_service_mismatch" &&
                $0.triggersSuspiciousOverride
        })
    }

    func testExpectedDocumentButVisibleSignInIsSuspicious() {
        let result = classify(
            near: "Sign in with a passkey",
            full: "Microsoft login.microsoft.com",
            intent: intent(service: "Microsoft", purpose: .openDocument)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "purpose_mismatch"
        })
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "purpose_mismatch" &&
                $0.polarity == .negative &&
                $0.evidenceCategory == .contradiction
        })
        XCTAssertEqual(
            result.assessmentDimensions.first { $0.kind == .purpose }?.finding,
            .conflicting
        )
    }

    func testFIDOQRCodeDescribedAsSalaryIsSuspiciousWithoutDomainMismatch() {
        let result = classify(
            near: "Scan to receive your salary",
            full: "Claim your refund",
            intent: intent(service: nil, purpose: .payment)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "direct_purpose_mismatch" &&
                $0.triggersSuspiciousOverride
        })
    }

    func testCompositionalPaymentClaimTriggersDirectPurposeMismatch() {
        let result = classify(
            near: "Scan this QR code to authorize the transfer.",
            full: "",
            intent: intent(service: nil, purpose: .signIn)
        )

        XCTAssertEqual(result.visualClassification, .suspicious)
        XCTAssertEqual(result.purposeState, .identified)
        XCTAssertEqual(result.inferredPurposes, [.payment])
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "direct_purpose_mismatch" &&
                $0.triggersSuspiciousOverride
        })
    }

    func testNegatedPaymentClaimDoesNotCreatePurposeContradiction() {
        let result = classify(
            near: "Microsoft sign in with a passkey. Do not approve this payment.",
            full: "login.microsoft.com",
            intent: trustedIntent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.inferredPurposes, [.signIn])
        XCTAssertEqual(result.purposeState, .identified)
        XCTAssertFalse(result.ruleResults.contains {
            $0.ruleIdentifier == "direct_purpose_mismatch"
        })
        XCTAssertFalse(result.ruleResults.contains {
            $0.ruleIdentifier == "purpose_mismatch" && $0.polarity == .negative
        })
    }

    func testUrgencyCombinedWithMissingIdentityIsSuspicious() {
        let result = classify(
            near: "Urgent action required immediately",
            full: "Continue now"
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "urgency_and_coercion"
        })
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "urgency_and_coercion" &&
                $0.evidenceCategory == .persuasion
        })
    }

    func testConflictingBrandAndDomainIsSuspicious() {
        let result = classify(
            near: "Microsoft Sign in with a passkey at attacker.example",
            full: "",
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "brand_domain_conflict" &&
                $0.severity == .strong &&
                $0.sourceObservationIds == ["O1"]
        })
    }

    func testLowConfidenceVisualConflictCannotTriggerSuspiciousOverride() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(type: .fido, boundingBox: .fullFrame)],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft sign in with a passkey at attacker.example",
                    confidence: 0.30,
                    boundingBox: .fullFrame,
                    region: .qrSurrounding
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        let result = classifier.classify(
            observation: observation,
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertFalse(result.ruleResults.contains {
            $0.triggersSuspiciousOverride
        })
        XCTAssertTrue(result.limitations.contains { $0.contains("too uncertain") })
    }

    func testDistantUnrelatedDomainDoesNotTriggerLocalBrandDomainOverride() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.35, y: 0.35, width: 0.3, height: 0.3
                )
            )],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft Sign in with a passkey",
                    confidence: 0.97,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.3, y: 0.67, width: 0.4, height: 0.06
                    ),
                    region: .qrSurrounding
                ),
                OCRObservation(
                    text: "Chase chase.com account statement",
                    confidence: 0.99,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.02, y: 0.02, width: 0.25, height: 0.04
                    ),
                    region: .fullFrame
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        let result = classifier.classify(
            observation: observation,
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .consistent)
        XCTAssertTrue(result.competingContextPresent)
        XCTAssertEqual(result.associationResolution, .resolved)
        XCTAssertFalse(result.ruleResults.contains {
            ["service_mismatch", "brand_domain_conflict"].contains($0.ruleIdentifier) &&
                $0.triggersSuspiciousOverride
        })
        XCTAssertFalse(result.ruleResults.contains {
            $0.ruleIdentifier == "context_association"
        })
    }

    func testUnexpectedInitiationWithUrgencyIsSuspicious() {
        let result = classify(
            near: "Microsoft Sign in with a passkey immediately",
            full: "login.microsoft.com",
            intent: UserIntent(
                expectedService: "Microsoft",
                expectedPurpose: .signIn,
                initiationStatus: .no,
                displaySource: .kiosk,
                notes: ""
            )
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "unexpected_initiation" &&
                $0.triggersSuspiciousOverride
        })
        XCTAssertEqual(
            result.assessmentDimensions.first { $0.kind == .initiation }?.finding,
            .conflicting
        )
        XCTAssertEqual(
            result.assessmentDimensions.first { $0.kind == .socialEngineering }?.finding,
            .concerning
        )
    }

    func testMultipleQRCodesPreventConsistentResult() {
        var observation = makeObservation(
            near: "Microsoft Sign in with a passkey",
            full: "login.microsoft.com"
        )
        observation = ScanObservation(
            qrCodes: observation.qrCodes + [
                QRCodeObservation(
                    type: .url,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.7, y: 0.7, width: 0.2, height: 0.2
                    )
                )
            ],
            ocrObservations: observation.ocrObservations,
            imageQuality: observation.imageQuality,
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .completed
        )

        let result = classifier.classify(
            observation: observation,
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "multiple_qr_codes"
        })
        XCTAssertEqual(
            result.ruleResults.first {
                $0.ruleIdentifier == "multiple_qr_codes"
            }?.riskContribution,
            0
        )
    }

    func testUnusualChannelIsContextualConcernWithoutAttackRiskPoints() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "login.microsoft.com",
            intent: UserIntent(
                expectedService: "Microsoft",
                expectedPurpose: .signIn,
                initiationStatus: .yes,
                displaySource: .message,
                notes: ""
            )
        )

        let channelRule = result.ruleResults.first {
            $0.ruleIdentifier == "channel_risk"
        }
        XCTAssertEqual(channelRule?.evidenceCategory, .contextualConcern)
        XCTAssertEqual(channelRule?.riskContribution, 0)
    }

    func testSomeoneElsesTrustedComputerIsConcernWithoutAttackRiskPoints() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "login.microsoft.com",
            intent: trustedIntent(
                service: "Microsoft",
                purpose: .signIn,
                relationship: .someoneElsesDevice
            )
        )

        let relationshipRule = result.ruleResults.first {
            $0.ruleIdentifier == "receiving_client_trust" &&
                $0.evidenceCategory == .contextualConcern
        }
        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertEqual(relationshipRule?.riskContribution, 0)
    }

    func testOrdinaryUrgencyIsWeakRatherThanStrongEvidence() {
        let result = classify(
            near: "Microsoft Sign in with a passkey. Act now.",
            full: "login.microsoft.com",
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        let persuasionRule = result.ruleResults.first {
            $0.ruleIdentifier == "urgency_and_coercion"
        }
        XCTAssertEqual(persuasionRule?.severity, .weak)
        XCTAssertEqual(persuasionRule?.riskContribution, 15)
        XCTAssertFalse(persuasionRule?.triggersSuspiciousOverride ?? true)
    }

    func testFrozenClassifierConfigurationsAreStableAndOnlyFullUsesIntent() {
        XCTAssertEqual(
            ClassifierConfiguration.evaluationVariants.map(\.id),
            [
                "IDENTITY_DOMAIN_ONLY",
                "MULTI_SIGNAL",
                "MULTI_SIGNAL_SPATIAL",
                "MULTI_SIGNAL_SPATIAL_INTENT"
            ]
        )
        XCTAssertEqual(
            ClassifierConfiguration.evaluationVariants.map(\.usesIntent),
            [false, false, false, true]
        )

        let observation = makeObservation(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com"
        )
        let conflictingIntent = trustedIntent(service: "Google", purpose: .signIn)

        for configuration in ClassifierConfiguration.evaluationVariants.dropLast() {
            let result = classifier.classify(
                observation: observation,
                intent: conflictingIntent,
                configuration: configuration
            )
            XCTAssertFalse(result.ruleResults.contains {
                $0.ruleIdentifier == "expected_service_mismatch"
            })
        }

        let fullResult = classifier.classify(
            observation: observation,
            intent: conflictingIntent,
            configuration: .full
        )
        XCTAssertTrue(fullResult.ruleResults.contains {
            $0.ruleIdentifier == "expected_service_mismatch"
        })
    }

    func testConvincingAttackerSessionIsDocumentedFalseNegative() {
        let result = classify(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com",
            intent: intent(service: "Microsoft", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .consistent)
        XCTAssertTrue(result.limitations.contains {
            $0.contains("who owns the receiving session")
        })
    }

    func testOriginalGoogleFixtureIsConsistentWithCompleteMatchingIntent() {
        let result = classify(
            near: """
            Passkeys
            Use your phone or tablet
            Scan this QR code with the camera on the device that has your passkey for google.com
            """,
            full: "",
            intent: intent(service: "Google", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .consistent)
        XCTAssertTrue(result.observedNegativeEvidence.isEmpty)
    }

    func testThreatCaptionFixtureIsSuspiciousWithSameGoogleDomain() {
        let result = classify(
            near: """
            Passkeys
            Use your phone or tablet
            Your account is currently under threat! Log in to change your security setting for google.com
            """,
            full: "",
            intent: intent(service: "Google", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "urgency_and_coercion" &&
                $0.evidence.contains(SocialEngineeringCue.threat.rawValue)
        })
    }

    func testThreatAndFakeChaseDomainFixtureIsSuspicious() {
        let result = classify(
            near: """
            Passkeys
            Use your phone or tablet
            Your account is currently under threat! Log in to change your security setting for chase.com
            """,
            full: "",
            intent: intent(service: "Google", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "expected_service_mismatch" &&
                $0.triggersSuspiciousOverride
        })
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "urgency_and_coercion"
        })
    }

    func testMissingExpectedServiceAndPurposeCannotReturnConsistent() {
        let result = classify(
            near: """
            Passkeys
            Use your phone or tablet
            Scan this QR code with the camera on the device that has your passkey for google.com
            """,
            full: ""
        )

        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertTrue(result.limitations.contains {
            $0.contains("cannot return CONSISTENT")
        })
    }

    func testClearChromeCeremonyHasConsistentVisualClassificationWithoutIntent() {
        let result = classify(
            near: """
            Passkeys
            Use your phone or tablet
            Scan this QR code with the camera on the device that has your passkey for paypal.com
            """,
            full: ""
        )

        XCTAssertEqual(result.visualClassification, .consistent)
        XCTAssertEqual(result.classification, .uncertain)
        XCTAssertEqual(result.visualEvidenceCompleteness, .sufficient)
    }

    func testBrowserAndQRServiceConflictIsVisuallySuspiciousWithoutIntent() {
        let result = classify(
            near: "Scan this QR code with the device that has your passkey for chase.com",
            full: "robinhood.com/login"
        )

        XCTAssertEqual(result.visualClassification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "service_mismatch" && $0.triggersSuspiciousOverride
        })
    }

    func testRepeatedIdentityEvidenceProducesOneSemanticRiskEvent() {
        let result = classify(
            near: "Chase chase.com chase.com. Scan this QR code to sign in to chase.com",
            full: "Robinhood robinhood.com robinhood.com"
        )

        let mismatchRules = result.ruleResults.filter { $0.ruleIdentifier == "service_mismatch" }
        XCTAssertEqual(mismatchRules.count, 1)
        XCTAssertLessThanOrEqual(result.visualRiskScore, 100)
    }

    func testMissingIdentityLowersVisualCompletenessWithoutAddingRisk() {
        let result = classify(near: "Use your phone to scan this QR code", full: "")

        XCTAssertEqual(result.visualClassification, .uncertain)
        XCTAssertNotEqual(result.visualEvidenceCompleteness, .sufficient)
        XCTAssertEqual(result.visualRiskScore, 0)
    }

    func testParticipantPolicyAllowsLimitedConsistentAfterExactInitiation() {
        let observation = makeObservation(
            near: "Microsoft Sign in with a passkey",
            full: "Continue on your phone at login.microsoft.com"
        )
        let intent = UserIntent(
            expectedService: nil,
            expectedPurpose: nil,
            initiationStatus: .yes,
            displaySource: .unknown,
            startedOnReceivingClient: .yes,
            notes: ""
        )

        let participantResult = classifier.classify(
            observation: observation,
            intent: intent,
            policy: .participant
        )
        let researcherResult = classifier.classify(
            observation: observation,
            intent: intent,
            policy: .researcher
        )

        XCTAssertEqual(participantResult.classification, .consistent)
        XCTAssertEqual(researcherResult.classification, .uncertain)
        XCTAssertEqual(participantResult.visualEvidenceCompleteness, .sufficient)
        XCTAssertEqual(participantResult.intentSessionCompleteness, .partial)
    }

    func testParticipantPolicyRequiresExactInitiation() {
        let result = classifier.classify(
            observation: makeObservation(
                near: "Microsoft Sign in with a passkey",
                full: "Continue on your phone at login.microsoft.com"
            ),
            intent: .skipped,
            policy: .participant
        )

        XCTAssertEqual(result.classification, .uncertain)
    }

    func testBenignLookingChaseReplacementConflictsWithExpectedGoogle() {
        let result = classify(
            near: "Use your phone to sign in with a passkey for chase.com",
            full: "",
            intent: intent(service: "Google", purpose: .signIn)
        )

        XCTAssertEqual(result.classification, .suspicious)
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "expected_service_mismatch"
        })
    }

    func testM08SplitBonusInstructionIsVisuallySuspicious() {
        let result = classifier.classify(
            observation: makeSplitLineObservation([
                "Scan with your phone to receive your",
                "£750 employee bonus. The payment",
                "will be sent after confirmation."
            ])
        )

        XCTAssertEqual(result.visualClassification, .suspicious)
        XCTAssertEqual(result.purposeState, .identified)
        XCTAssertEqual(result.inferredPurposes, [.payment])
        XCTAssertTrue(result.socialEngineeringCues.contains(.reward))
        XCTAssertTrue(result.socialEngineeringCues.contains(.unexpectedPayment))
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "direct_purpose_mismatch" &&
                $0.triggersSuspiciousOverride
        })
    }

    func testM09SplitDocumentInstructionIsVisuallySuspicious() {
        let result = classifier.classify(
            observation: makeSplitLineObservation([
                "Scan with your phone to open the",
                "document on your authenticated",
                "device."
            ])
        )

        XCTAssertEqual(result.visualClassification, .suspicious)
        XCTAssertEqual(result.purposeState, .identified)
        XCTAssertEqual(result.inferredPurposes, [.openDocument])
        let rule = result.ruleResults.first {
            $0.ruleIdentifier == "direct_purpose_mismatch"
        }
        XCTAssertEqual(rule?.riskContribution, 85)
        XCTAssertEqual(Set(rule?.sourceObservationIds ?? []), Set(["O1", "O2", "O3"]))
    }

    func testGenericNearbyControlDoesNotAddSpatialCompleteness() {
        let result = classifier.classify(
            observation: makeObservation(near: "Cancel", full: "")
        )

        XCTAssertFalse(result.ruleResults.contains {
            $0.ruleIdentifier == "spatial_relevance" &&
                $0.polarity == .positive
        })
        XCTAssertTrue(result.ruleResults.contains {
            $0.ruleIdentifier == "spatial_relevance" &&
                $0.polarity == .limitation
        })
        XCTAssertNotEqual(result.visualClassification, .consistent)
    }

    func testAllRequiredRuleFamiliesAreRegistered() {
        let result = classify(
            near: "Microsoft Sign in with a passkey immediately",
            full: "attacker.example",
            intent: UserIntent(
                expectedService: "Amazon",
                expectedPurpose: .openDocument,
                initiationStatus: .no,
                displaySource: .message,
                notes: ""
            )
        )
        let identifiers = Set(result.ruleResults.map(\.ruleIdentifier))

        XCTAssertTrue(identifiers.contains("identity_evidence"))
        XCTAssertTrue(identifiers.contains("brand_domain_conflict"))
        XCTAssertTrue(identifiers.contains("expected_service_mismatch"))
        XCTAssertTrue(identifiers.contains("ceremony_language"))
        XCTAssertTrue(identifiers.contains("purpose_mismatch"))
        XCTAssertTrue(identifiers.contains("urgency_and_coercion"))
        XCTAssertTrue(identifiers.contains("unexpected_initiation"))
        XCTAssertTrue(identifiers.contains("receiving_client_trust"))
        XCTAssertTrue(identifiers.contains("channel_risk"))
        XCTAssertTrue(identifiers.contains("context_completeness"))
        XCTAssertTrue(identifiers.contains("spatial_relevance"))
    }

    private func classify(
        near: String,
        full: String,
        intent: UserIntent = .skipped
    ) -> ScanResult {
        classifier.classify(
            observation: makeObservation(near: near, full: full),
            intent: intent
        )
    }

    private func intent(
        service: String?,
        purpose: IntendedPurpose
    ) -> UserIntent {
        trustedIntent(service: service, purpose: purpose)
    }

    private func trustedIntent(
        service: String?,
        purpose: IntendedPurpose,
        relationship: ReceivingClientRelationship = .ownDevice,
        startedOnReceivingClient: InitiationStatus = .yes,
        receivingClientTrust: ReceivingClientTrustStatus = .yes
    ) -> UserIntent {
        UserIntent(
            expectedService: service,
            expectedPurpose: purpose,
            initiationStatus: .yes,
            displaySource: .ownDevice,
            receivingClientRelationship: relationship,
            startedOnReceivingClient: startedOnReceivingClient,
            receivingClientTrust: receivingClientTrust,
            notes: ""
        )
    }

    private func makeObservation(
        near: String?,
        full: String?,
        ocrStatus: OCRProcessingStatus = .completed
    ) -> ScanObservation {
        var text: [OCRObservation] = []
        if let near {
            text.append(OCRObservation(
                text: near,
                confidence: 0.95,
                boundingBox: .fullFrame,
                region: .qrSurrounding
            ))
        }
        if let full, !full.isEmpty {
            text.append(OCRObservation(
                text: full,
                confidence: 0.9,
                boundingBox: .fullFrame,
                region: .fullFrame
            ))
        }
        return ScanObservation(
            qrCodes: [
                QRCodeObservation(
                    type: .fido,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.3, y: 0.3, width: 0.3, height: 0.3
                    )
                )
            ],
            ocrObservations: text,
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: !text.isEmpty,
                issues: []
            ),
            qrProcessingStatus: .completed,
            ocrProcessingStatus: ocrStatus
        )
    }

    private func makeSplitLineObservation(_ lines: [String]) -> ScanObservation {
        ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.35, y: 0.30, width: 0.30, height: 0.30
                )
            )],
            ocrObservations: lines.enumerated().map { index, text in
                OCRObservation(
                    text: text,
                    confidence: 0.97,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.55,
                        y: 0.69 - Double(index) * 0.04,
                        width: 0.32,
                        height: 0.025
                    ),
                    region: .fullFrame
                )
            },
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )
    }

    func testConsistentPresentationUsesNeutralNonVerificationLanguage() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Google passkey sign in"),
            classification: .consistent,
            riskScore: 0,
            reasons: ["The visible identity and purpose are clearly stated."]
        )

        let presentation = SecurityResultPresentation.make(for: result)
        let userFacingCopy = [
            presentation.headline,
            presentation.primaryReason,
            presentation.recommendedAction
        ].joined(separator: " ").lowercased()

        XCTAssertEqual(presentation.headline, "No obvious context conflict found")
        XCTAssertEqual(presentation.style, .quiet)
        XCTAssertEqual(presentation.systemImage, "info.circle.fill")
        XCTAssertFalse(userFacingCopy.contains("safe"))
        XCTAssertFalse(userFacingCopy.contains("verified"))
    }

    func testUncertainPresentationPrioritisesMissingEvidence() {
        let missingReason = "No visible service identity was found."
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Scan this code"),
            classification: .uncertain,
            riskScore: 10,
            reasons: ["More context is needed."],
            ruleResults: [ClassificationRuleResult(
                ruleIdentifier: "context_completeness",
                severity: .moderate,
                polarity: .limitation,
                evidenceCategory: .missingEvidence,
                riskContribution: 0,
                completenessContribution: 0,
                reason: missingReason,
                evidence: [],
                triggersSuspiciousOverride: false
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(presentation.headline, "Not enough information")
        XCTAssertEqual(
            presentation.primaryReason,
            "The page did not clearly identify the service for this sign-in."
        )
        XCTAssertEqual(presentation.style, .caution)
    }

    func testSuspiciousPresentationUsesActiveWarningAndObservedReason() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Approve now"),
            classification: .suspicious,
            riskScore: 80,
            reasons: ["The context contains conflicting evidence."],
            observedNegativeEvidence: ["You said you did not start this request."]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(presentation.headline, "Possible misleading sign-in")
        XCTAssertEqual(presentation.primaryReason, "You said you did not start this request.")
        XCTAssertEqual(presentation.style, .activeWarning)
        XCTAssertTrue(presentation.recommendedAction.hasPrefix("Do not approve"))
    }

    func testPrimaryReasonPrioritisesUnexpectedInitiationOverServiceMismatch() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Chase passkey"),
            classification: .suspicious,
            riskScore: 100,
            reasons: ["Several warnings were found."],
            ruleResults: [
                negativeRule(
                    identifier: "expected_service_mismatch",
                    reason: "The visible service conflicts with the service the user expected.",
                    evidence: ["Google", "Chase"]
                ),
                negativeRule(
                    identifier: "unexpected_initiation",
                    reason: "The user stated that they did not initiate this action."
                )
            ]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(presentation.primaryReasonIdentifier, "unexpected_initiation")
        XCTAssertEqual(presentation.primaryReason, "You said you did not start this request.")
    }

    func testPrimaryReasonFormatsExpectedServiceConflict() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Chase passkey"),
            classification: .suspicious,
            riskScore: 80,
            reasons: [],
            ruleResults: [negativeRule(
                identifier: "expected_service_mismatch",
                reason: "The visible service conflicts with the service the user expected.",
                evidence: ["Google", "Chase"]
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(presentation.primaryReasonIdentifier, "expected_service_mismatch")
        XCTAssertEqual(presentation.primaryReason, "You expected Google, but the visible page refers to Chase.")
    }

    func testPrimaryReasonPrioritisesUnavailableOCROverOtherMissingEvidence() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: ""),
            classification: .uncertain,
            riskScore: 0,
            reasons: ["More context is needed."],
            ruleResults: [
                missingRule(reason: "No clear visible service identity was found."),
                missingRule(reason: "OCR evidence is incomplete or unavailable.")
            ]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(
            presentation.primaryReason,
            "We couldn’t read enough text around the QR code."
        )
        XCTAssertEqual(presentation.recommendedActionIdentifier, "rescan_full_page")
        XCTAssertEqual(
            presentation.recommendedAction,
            "Scan again with the QR code and its complete sign-in page visible."
        )
    }

    func testMissingServiceUsesConciseReasonAndPhoneCheck() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Use a passkey"),
            classification: .uncertain,
            riskScore: 0,
            reasons: [],
            ruleResults: [missingRule(
                reason: "No clear visible service identity was found."
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(
            presentation.primaryReason,
            "The page did not clearly identify the service for this sign-in."
        )
        XCTAssertEqual(presentation.recommendedActionIdentifier, "check_phone_service")
    }

    func testUnknownReceivingComputerDoesNotExposeClassifierTerminology() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Passkey sign in"),
            classification: .uncertain,
            riskScore: 0,
            reasons: [],
            ruleResults: [ClassificationRuleResult(
                ruleIdentifier: "receiving_client_trust",
                severity: .informational,
                polarity: .limitation,
                evidenceCategory: .missingEvidence,
                riskContribution: 0,
                completenessContribution: 0,
                reason: "The receiving computer, exact request initiation, or trust is unknown, so the scanner cannot return CONSISTENT.",
                evidence: [],
                triggersSuspiciousOverride: false
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(
            presentation.primaryReason,
            "We couldn’t confirm that you started this sign-in on the computer showing the QR code."
        )
        XCTAssertFalse(presentation.primaryReason.contains("CONSISTENT"))
        XCTAssertEqual(presentation.recommendedActionIdentifier, "confirm_exact_computer")
    }

    func testVisualPrimaryReasonIsIndependentFromFinalInterventionReason() {
        let identityRule = ClassificationRuleResult(
            ruleIdentifier: "identity_evidence",
            severity: .informational,
            polarity: .positive,
            evidenceCategory: .supporting,
            riskContribution: 0,
            completenessContribution: 15,
            reason: "A visible service identity claim was detected.",
            evidence: ["Example"],
            triggersSuspiciousOverride: false
        )
        let receivingRule = ClassificationRuleResult(
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
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Example passkey sign in"),
            visualClassification: .consistent,
            classification: .uncertain,
            riskScore: 0,
            reasons: [],
            ruleResults: [identityRule, receivingRule]
        )

        let visualReason = PrimaryReasonSelector().select(
            from: result,
            classification: result.visualClassification
        )
        let finalPresentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(visualReason.identifier, "identity_evidence")
        XCTAssertEqual(finalPresentation.primaryReasonIdentifier, "receiving_client_trust")
    }

    func testCompetingPeripheralContextUsesRescanGuidance() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Microsoft Chase"),
            classification: .uncertain,
            riskScore: 0,
            reasons: [],
            ruleResults: [ClassificationRuleResult(
                ruleIdentifier: "context_association",
                severity: .moderate,
                polarity: .negative,
                evidenceCategory: .contextualConcern,
                riskContribution: 0,
                completenessContribution: 0,
                reason: "Several visible identity contexts were found, but only some are associated with the QR code.",
                evidence: ["Microsoft", "Chase"],
                triggersSuspiciousOverride: false
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(
            presentation.primaryReason,
            "Several visible contexts were captured, and it is unclear which one describes the QR code."
        )
        XCTAssertEqual(presentation.recommendedActionIdentifier, "rescan_qr_context")
    }

    func testUnexpectedInitiationProducesReasonSpecificRecoveryGuidance() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Passkey sign in"),
            classification: .suspicious,
            riskScore: 70,
            reasons: [],
            ruleResults: [negativeRule(
                identifier: "unexpected_initiation",
                reason: "The user stated that they did not initiate this action."
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(presentation.checklistTitle, "If you restart the sign-in")
        XCTAssertEqual(presentation.recommendedActionIdentifier, "restart_self_initiated")
        XCTAssertTrue(presentation.recommendedAction.contains("start the sign-in yourself"))
        XCTAssertTrue(presentation.safetyChecks.contains("Start this exact sign-in yourself."))
        XCTAssertLessThanOrEqual(presentation.safetyChecks.count, 4)
    }

    func testReceivingClientConcernRecommendsTrustedComputer() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Passkey sign in"),
            classification: .suspicious,
            riskScore: 80,
            reasons: [],
            ruleResults: [negativeRule(
                identifier: "receiving_client_trust",
                reason: "The user stated that they do not trust the computer that may receive the session."
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)

        XCTAssertEqual(presentation.recommendedActionIdentifier, "restart_trusted_computer")
        XCTAssertTrue(presentation.recommendedAction.contains("computer you recognise and trust"))
        XCTAssertTrue(presentation.safetyChecks.contains {
            $0.contains("computer you recognise and trust")
        })
    }

    func testAccessibilitySummaryCommunicatesStatusReasonActionAndLimitation() {
        let result = ScanResult(
            visualContext: VisualContext(qrDetected: true, ocrText: "Approve now"),
            classification: .suspicious,
            riskScore: 80,
            reasons: [],
            ruleResults: [negativeRule(
                identifier: "unexpected_initiation",
                reason: "The user stated that they did not initiate this action."
            )]
        )

        let presentation = SecurityResultPresentation.make(for: result)
        let summary = presentation.accessibilitySummary

        XCTAssertTrue(summary.hasPrefix("Security warning."))
        XCTAssertTrue(summary.contains(presentation.primaryReason))
        XCTAssertTrue(summary.contains(presentation.recommendedAction))
        XCTAssertTrue(summary.contains(presentation.limitation))
    }

    private func negativeRule(
        identifier: String,
        reason: String,
        evidence: [String] = []
    ) -> ClassificationRuleResult {
        ClassificationRuleResult(
            ruleIdentifier: identifier,
            severity: .strong,
            polarity: .negative,
            evidenceCategory: .contradiction,
            riskContribution: 70,
            completenessContribution: 0,
            reason: reason,
            evidence: evidence,
            triggersSuspiciousOverride: true
        )
    }

    private func missingRule(reason: String) -> ClassificationRuleResult {
        ClassificationRuleResult(
            ruleIdentifier: "context_completeness",
            severity: .moderate,
            polarity: .limitation,
            evidenceCategory: .missingEvidence,
            riskContribution: 0,
            completenessContribution: 0,
            reason: reason,
            evidence: [],
            triggersSuspiciousOverride: false
        )
    }
}
