import XCTest
@testable import PasskeyContextScanner

final class ContextFeatureExtractorTests: XCTestCase {
    private let extractor = ContextFeatureExtractor()

    func testRecognizesAuthoredCatalogueServicesButKeepsShopifyHeldOut() {
        let identifiers = Set(extractor.featureIdentifiers(
            in: "PayPal Robinhood Dropbox Coinbase NHS Wells Fargo Shopify"
        ))

        XCTAssertTrue(identifiers.contains("SERVICE:PayPal"))
        XCTAssertTrue(identifiers.contains("SERVICE:Robinhood"))
        XCTAssertTrue(identifiers.contains("SERVICE:Dropbox"))
        XCTAssertTrue(identifiers.contains("SERVICE:Coinbase"))
        XCTAssertTrue(identifiers.contains("SERVICE:NHS"))
        XCTAssertTrue(identifiers.contains("SERVICE:Wells Fargo"))
        XCTAssertFalse(identifiers.contains("SERVICE:Shopify"))
    }

    func testExtractsClearPasskeyCeremonyEvidence() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "Continue on your phone at login.microsoft.com"
        )
        let intent = UserIntent(
            expectedService: "Microsoft",
            expectedPurpose: .signIn,
            initiationStatus: .yes,
            displaySource: .ownDevice,
            notes: ""
        )

        let features = extractor.extract(from: observation, intent: intent)

        XCTAssertEqual(features.visibleServiceClaims, ["Microsoft"])
        XCTAssertTrue(features.visibleDomainClaims.isEmpty)
        XCTAssertEqual(features.peripheralDomainClaims, ["login.microsoft.com"])
        XCTAssertTrue(features.authenticationTerms.contains("passkey"))
        XCTAssertTrue(features.inferredPurposes.contains(.signIn))
        XCTAssertTrue(features.contradictionFlags.isEmpty)
        XCTAssertTrue(features.completenessIndicators.contains(.fidoQRCode))
        XCTAssertTrue(features.completenessIndicators.contains(.qrNearText))
        XCTAssertTrue(features.completenessIndicators.contains(.userIntent))
        let microsoftClaim = features.visualClaims.first {
            $0.kind == .service && $0.value == "Microsoft"
        }
        XCTAssertEqual(microsoftClaim?.sourceObservationId, "O1")
        XCTAssertEqual(microsoftClaim?.ocrConfidence, 0.95)
        XCTAssertEqual(microsoftClaim?.contextZone, .primary)
        XCTAssertEqual(microsoftClaim?.associationStrength, .strong)
        XCTAssertEqual(features.browserDomainCandidates.map(\.domain), [
            "login.microsoft.com"
        ])
        XCTAssertEqual(
            features.browserDomainCandidates.first?.basis,
            .topOfFrameURLLikeText
        )
    }

    func testDetectsExpectedServiceMismatch() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "login.microsoft.com"
        )
        let intent = UserIntent(
            expectedService: "Amazon",
            expectedPurpose: .signIn,
            initiationStatus: .yes,
            displaySource: .sharedComputer,
            notes: ""
        )

        let features = extractor.extract(from: observation, intent: intent)

        XCTAssertTrue(features.contradictionFlags.contains(.expectedServiceMismatch))
        XCTAssertTrue(features.channelCues.contains(.sharedComputer))
    }

    func testDetectsFIDOQRCodePresentedAsPayment() {
        let observation = makeObservation(
            nearText: "Scan to receive your salary",
            fullText: "Claim your refund immediately"
        )
        let intent = UserIntent(
            expectedService: nil,
            expectedPurpose: .payment,
            initiationStatus: .no,
            displaySource: .message,
            notes: ""
        )

        let features = extractor.extract(from: observation, intent: intent)

        XCTAssertTrue(features.inferredPurposes.contains(.payment))
        XCTAssertTrue(
            features.contradictionFlags.contains(.fidoPresentedAsUnrelatedAction)
        )
        XCTAssertTrue(features.contradictionFlags.contains(.unexpectedInitiation))
        XCTAssertTrue(features.socialEngineeringCues.contains(.unexpectedPayment))
        XCTAssertTrue(features.peripheralSocialEngineeringCues.contains(.urgency))
        XCTAssertTrue(features.channelCues.contains(.emailOrChat))
    }

    func testDetectsStrongSocialEngineeringPhrasesWithoutCountingOccurrences() {
        let observation = makeObservation(
            nearText: "Ignore any warning. Approve again.",
            fullText: "IT support requires this immediately. Do not tell anyone."
        )

        let features = extractor.extract(from: observation)

        XCTAssertEqual(
            Set(features.socialEngineeringCues),
            Set([.ignoreWarnings, .repeatedApproval])
        )
        XCTAssertEqual(
            Set(features.peripheralSocialEngineeringCues),
            Set([.urgency, .secrecy, .authorityPressure])
        )
    }

    func testExtractsReceivingClientContradictions() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "login.microsoft.com"
        )
        let intent = UserIntent(
            expectedService: "Microsoft",
            expectedPurpose: .signIn,
            initiationStatus: .yes,
            displaySource: .sharedComputer,
            receivingClientRelationship: .someoneElsesDevice,
            startedOnReceivingClient: .no,
            receivingClientTrust: .no,
            notes: ""
        )

        let features = extractor.extract(from: observation, intent: intent)

        XCTAssertTrue(
            features.contradictionFlags.contains(.receivingClientNotStarted)
        )
        XCTAssertTrue(
            features.contradictionFlags.contains(.untrustedReceivingClient)
        )
        XCTAssertFalse(
            features.completenessIndicators.contains(.receivingClientContext)
        )
    }

    func testDetectsBrandDomainConflict() {
        let observation = makeObservation(
            nearText: "Microsoft account Sign in at attacker.example",
            fullText: "Unrelated footer"
        )

        let features = extractor.extract(from: observation)

        XCTAssertTrue(features.contradictionFlags.contains(.brandDomainConflict))
    }

    func testLowConfidenceTextIsPreservedButCannotCreateContradiction() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(type: .fido, boundingBox: .fullFrame)],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft sign in at attacker.example",
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

        let features = extractor.extract(from: observation)

        XCTAssertEqual(features.spatialEvidence.count, 1)
        XCTAssertEqual(features.lowConfidenceObservationCount, 1)
        XCTAssertTrue(features.visualClaims.isEmpty)
        XCTAssertTrue(features.visibleServiceClaims.isEmpty)
        XCTAssertTrue(features.visibleDomainClaims.isEmpty)
        XCTAssertFalse(features.contradictionFlags.contains(.brandDomainConflict))
    }

    func testMissingContextHasOnlyProcessingCompleteness() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(type: .unknown, boundingBox: .fullFrame)],
            ocrObservations: [],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: false,
                issues: [.croppedContext]
            ),
            qrProcessingStatus: .completed,
            ocrProcessingStatus: .noText
        )

        let features = extractor.extract(from: observation)

        XCTAssertTrue(features.visibleServiceClaims.isEmpty)
        XCTAssertTrue(features.visibleDomainClaims.isEmpty)
        XCTAssertTrue(features.inferredPurposes.isEmpty)
        XCTAssertFalse(features.completenessIndicators.contains(.readableIdentity))
        XCTAssertFalse(features.completenessIndicators.contains(.clearPurpose))
        XCTAssertFalse(features.completenessIndicators.contains(.successfulOCR))
    }

    func testPreservesSpatialRelevanceAndConfidence() {
        let observation = makeObservation(
            nearText: "Sign in",
            fullText: "Unrelated footer"
        )

        let features = extractor.extract(from: observation)

        XCTAssertEqual(features.spatialEvidence.count, 2)
        XCTAssertTrue(features.spatialEvidence[0].isNearQRCode)
        XCTAssertEqual(features.spatialEvidence[0].confidence, 0.95)
        XCTAssertFalse(features.spatialEvidence[1].isNearQRCode)
        XCTAssertEqual(features.spatialEvidence[0].proximity, .near)
        XCTAssertEqual(features.spatialEvidence[0].sourceRegion, .qrSurrounding)
        XCTAssertEqual(features.spatialEvidence[1].proximity, .distant)
        XCTAssertGreaterThan(
            features.spatialEvidence[1].normalizedDistanceToQRCode ?? 0,
            0.25
        )
    }

    func testAdjacentQRInstructionCanReceiveStrongAssociation() throws {
        let engine = ContextAssociationEngine()
        let qr = QRCodeObservation(
            type: .fido,
            boundingBox: NormalizedBoundingBox(
                x: 0.35, y: 0.35, width: 0.30, height: 0.30
            )
        )
        let text = OCRObservation(
            text: "Continue on your phone using this QR code",
            confidence: 0.95,
            boundingBox: NormalizedBoundingBox(
                x: 0.36, y: 0.86, width: 0.28, height: 0.05
            ),
            region: .qrSurrounding
        )

        let association = engine.associate(text, with: [qr])

        XCTAssertEqual(association.proximity, .adjacent)
        XCTAssertEqual(association.zone, .adjacent)
        XCTAssertEqual(association.strength, .strong)
    }

    func testDistantUnrelatedFullFrameTextRemainsPeripheralAndWeak() {
        let engine = ContextAssociationEngine()
        let qr = QRCodeObservation(
            type: .fido,
            boundingBox: NormalizedBoundingBox(
                x: 0.35, y: 0.35, width: 0.30, height: 0.30
            )
        )
        let text = OCRObservation(
            text: "Chase account statement",
            confidence: 0.99,
            boundingBox: NormalizedBoundingBox(
                x: 0.02, y: 0.92, width: 0.20, height: 0.04
            ),
            region: .fullFrame
        )

        let association = engine.associate(text, with: [qr])

        XCTAssertEqual(association.proximity, .distant)
        XCTAssertEqual(association.zone, .peripheral)
        XCTAssertEqual(association.strength, .weak)
    }

    func testBodyDomainIsNotPromotedToBrowserLevelCandidate() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.35, y: 0.35, width: 0.30, height: 0.30
                )
            )],
            ocrObservations: [OCRObservation(
                text: "Visit example.com for help",
                confidence: 0.98,
                boundingBox: NormalizedBoundingBox(
                    x: 0.20, y: 0.50, width: 0.35, height: 0.05
                ),
                region: .fullFrame
            )],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        let features = extractor.extract(from: observation)

        XCTAssertTrue(features.browserDomainCandidates.isEmpty)
        XCTAssertFalse(features.visualClaims.contains {
            $0.kind == .browserDomainCandidate
        })
    }

    func testWeakUnalignedBrowserCandidateIsCompetingButNotContradictory() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "accounts.google.com"
        )

        let features = extractor.extract(from: observation)

        XCTAssertFalse(
            features.contradictionFlags.contains(.browserDomainCandidateConflict)
        )
        XCTAssertTrue(features.competingContextPresent)
        XCTAssertEqual(features.associationResolution, .resolved)
        XCTAssertEqual(features.browserDomainCandidates.first?.sourceObservationId, "O2")
    }

    func testTextWithoutQRCodeIsUnassociated() {
        let association = ContextAssociationEngine().associate(
            OCRObservation(
                text: "Sign in",
                confidence: 0.99,
                boundingBox: .fullFrame,
                region: .fullFrame
            ),
            with: []
        )

        XCTAssertEqual(association.zone, .unassociated)
        XCTAssertEqual(association.strength, .unassociated)
        XCTAssertNil(association.qrIndex)
    }

    func testDeduplicatesSameTextAcrossOCRRegionsUsingClosestObservation() {
        let observation = ScanObservation(
            qrCodes: [
                QRCodeObservation(
                    type: .fido,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.3, y: 0.3, width: 0.3, height: 0.3
                    )
                )
            ],
            ocrObservations: [
                OCRObservation(
                    text: "Sign in",
                    confidence: 0.9,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.3, y: 0.62, width: 0.2, height: 0.05
                    ),
                    region: .qrSurrounding
                ),
                OCRObservation(
                    text: "SIGN IN",
                    confidence: 0.99,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.82, y: 0.82, width: 0.1, height: 0.05
                    ),
                    region: .fullFrame
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        let evidence = extractor.extract(from: observation).spatialEvidence

        XCTAssertEqual(evidence.count, 1)
        XCTAssertEqual(evidence.first?.proximity, .near)
        XCTAssertEqual(evidence.first?.sourceRegion, .qrSurrounding)
    }

    func testSeparatesQRLocalAndPeripheralIdentityClaims() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "Chase chase.com account statement"
        )

        let features = extractor.extract(from: observation)

        XCTAssertEqual(features.visibleServiceClaims, ["Microsoft"])
        XCTAssertTrue(features.visibleDomainClaims.isEmpty)
        XCTAssertEqual(features.peripheralServiceClaims, ["Chase"])
        XCTAssertEqual(features.peripheralDomainClaims, ["chase.com"])
        XCTAssertEqual(features.spatialEvidence.first?.contextZone, .primary)
        XCTAssertEqual(features.spatialEvidence.first?.associationStrength, .strong)
        XCTAssertEqual(features.spatialEvidence.last?.contextZone, .peripheral)
        XCTAssertEqual(features.spatialEvidence.last?.associationStrength, .weak)
    }

    func testUnfilteredConfigurationTreatsPeripheralTextAsClassifierInput() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "Chase chase.com account statement"
        )

        let features = extractor.extract(
            from: observation,
            associationPolicy: .unfilteredVisualText
        )

        XCTAssertEqual(Set(features.visibleServiceClaims), Set(["Microsoft", "Chase"]))
        XCTAssertEqual(features.visibleDomainClaims, ["chase.com"])
        XCTAssertTrue(features.peripheralServiceClaims.isEmpty)
        XCTAssertTrue(features.peripheralDomainClaims.isEmpty)
    }

    func testPeripheralPersuasionDoesNotBecomeQRAssociatedCue() {
        let observation = makeObservation(
            nearText: "Microsoft Sign in with a passkey",
            fullText: "Act now or your unrelated account will be suspended"
        )

        let features = extractor.extract(from: observation)

        XCTAssertTrue(features.socialEngineeringCues.isEmpty)
        XCTAssertTrue(features.peripheralSocialEngineeringCues.contains(.urgency))
        XCTAssertTrue(features.peripheralSocialEngineeringCues.contains(.threat))
    }

    func testFIDOExistingPasskeyInstructionProvidesDirectSignInEvidence() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code with the camera on the device that has your passkey for paypal.com"],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.signIn])
        XCTAssertEqual(features.purposeEvidence.first?.priority, .directQRCodeInstruction)
        XCTAssertEqual(features.purposeEvidence.first?.contextRole, .qrLocal)
    }

    func testFIDOExistingPasskeyInstructionSplitAcrossOCRLinesProvidesSignInEvidence() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "Scan this QR code with the camera on the device that has",
                "your passkey for www.paypal.com"
            ],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.signIn])
        XCTAssertTrue(features.purposeEvidence.contains {
            $0.purpose == .signIn && $0.matchedPhrase == "your passkey for"
        })
    }

    func testFIDOExplicitPasskeyCreationDoesNotUseExistingPasskeyFallback() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Create a passkey for example.com"],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.registerPasskey])
        XCTAssertFalse(features.purposeEvidence.contains { $0.purpose == .signIn })
    }

    func testDirectEmailVerificationOutranksEmailAccountDomain() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "Verify your email address",
                "To finish verifying your email address, scan the QR code below using your phone.",
                "Verifying j••••••n@gmail.com"
            ],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.verifyIdentity])
        XCTAssertFalse(features.visibleDomainClaims.contains("gmail.com"))
        XCTAssertTrue(features.domainEvidence.contains {
            $0.domain == "gmail.com" && $0.sourceType == .emailDomain && !$0.participatesInServiceIdentity
        })
    }

    func testDirectPaymentInstructionProducesPaymentPurpose() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code to approve this payment."],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.payment])
        XCTAssertEqual(features.purposeEvidence.first?.priority, .directQRCodeInstruction)
    }

    func testCompositionalPurposePatternsRecognizeParaphrasedActions() {
        let cases: [(String, IntendedPurpose)] = [
            ("Confirm that this account belongs to you", .verifyIdentity),
            ("Use your phone to prove account ownership", .verifyIdentity),
            ("Complete identity confirmation on your mobile", .verifyIdentity),
            ("Authorize the transfer using this QR code", .payment),
            ("Retrieve the report on your mobile", .openDocument),
            ("Link this phone to continue", .pairDevice),
            ("Regain access to your account", .recoverAccount)
        ]

        for (text, expectedPurpose) in cases {
            let features = extractor.extract(from: makeSemanticObservation(
                near: [text],
                full: []
            ))

            XCTAssertEqual(features.inferredPurposes, [expectedPurpose], text)
            XCTAssertEqual(features.purposeState, .identified, text)
            XCTAssertTrue(features.purposeEvidence.contains {
                $0.purpose == expectedPurpose && $0.matchedPhrase.contains(" + ")
            }, text)
            XCTAssertTrue(features.visualClaims.contains {
                $0.kind == .purposePattern &&
                    $0.value.hasPrefix("\(expectedPurpose.rawValue)|")
            }, text)
        }
    }

    func testAdjacentQRLinesComposeDocumentPurposeWithTraceableSources() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "device.",
                "document on your authenticated",
                "Scan with your phone to open the"
            ],
            full: []
        ))

        XCTAssertEqual(
            features.inferredPurposes,
            [.openDocument],
            "purpose evidence: \(features.purposeEvidence)"
        )
        XCTAssertEqual(features.purposeState, .identified)
        let evidence = features.purposeEvidence.first {
            $0.purpose == .openDocument && $0.sourceObservationIds.count > 1
        }
        XCTAssertNotNil(evidence)
        XCTAssertGreaterThanOrEqual(evidence?.sourceObservationIds.count ?? 0, 2)
        XCTAssertEqual(evidence?.priority, .directQRCodeInstruction)
    }

    func testAdjacentQRLinesComposeBonusCollectionPurposeAndCues() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "Scan with your phone to receive your",
                "£750 employee bonus. The payment",
                "will be sent after confirmation."
            ],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.payment])
        XCTAssertEqual(features.purposeState, .identified)
        XCTAssertTrue(features.socialEngineeringCues.contains(.reward))
        XCTAssertTrue(features.socialEngineeringCues.contains(.unexpectedPayment))
        XCTAssertTrue(
            features.contradictionFlags.contains(.fidoPresentedAsUnrelatedAction)
        )
    }

    func testDifferentColumnsDoNotComposeAnUnrelatedPurpose() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.40, y: 0.30, width: 0.25, height: 0.30
                )
            )],
            ocrObservations: [
                OCRObservation(
                    text: "Scan with your phone to open the",
                    confidence: 0.97,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.56, y: 0.67, width: 0.30, height: 0.03
                    ),
                    region: .fullFrame
                ),
                OCRObservation(
                    text: "document archive",
                    confidence: 0.97,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.08, y: 0.63, width: 0.22, height: 0.03
                    ),
                    region: .fullFrame
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        let features = extractor.extract(from: observation)

        XCTAssertTrue(features.inferredPurposes.isEmpty)
        XCTAssertEqual(features.purposeState, .unknown)
    }

    func testDocumentFilenamesDoNotCreateIdentityOrAssociationEvidence() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "Contract-2026.pdf",
                "Shared by legal@acmecorp.com"
            ],
            full: [(
                "REF.DOC",
                NormalizedBoundingBox(
                    x: 0.08, y: 0.10, width: 0.20, height: 0.03
                )
            )]
        ))

        XCTAssertTrue(features.visibleDomainClaims.isEmpty)
        XCTAssertTrue(features.peripheralDomainClaims.isEmpty)
        XCTAssertEqual(features.domainEvidence.map(\.domain), ["acmecorp.com"])
        XCTAssertEqual(features.domainEvidence.map(\.sourceType), [.emailDomain])
        XCTAssertFalse(
            features.contradictionFlags.contains(.ambiguousContextAssociation)
        )
    }

    func testLocalNegationSuppressesExactAndCompositionalPurposeEvidence() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Do not approve this payment with the QR code."],
            full: []
        ))

        XCTAssertTrue(features.inferredPurposes.isEmpty)
        XCTAssertEqual(features.purposeState, .unknown)
        XCTAssertFalse(features.purposeEvidence.contains { $0.purpose == .payment })
        XCTAssertTrue(features.nonAuthenticationActionTerms.isEmpty)
        XCTAssertFalse(
            features.contradictionFlags.contains(.fidoPresentedAsUnrelatedAction)
        )
    }

    func testCommonNegationFormsSuppressTheirLocalPurposeOnly() {
        let cases: [(String, IntendedPurpose)] = [
            ("This QR doesn't make a payment.", .payment),
            ("Never download the document using this code.", .openDocument),
            ("Continue without linking this phone.", .pairDevice)
        ]

        for (text, suppressedPurpose) in cases {
            let features = extractor.extract(from: makeSemanticObservation(
                near: [text],
                full: []
            ))

            XCTAssertFalse(features.inferredPurposes.contains(suppressedPurpose), text)
            XCTAssertFalse(features.purposeEvidence.contains {
                $0.purpose == suppressedPurpose
            }, text)
        }
    }

    func testDistantNegationDoesNotSuppressLaterAffirmedPurpose() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "Do not close this page. Scan this QR code to approve this payment."
            ],
            full: []
        ))

        XCTAssertEqual(features.inferredPurposes, [.payment])
        XCTAssertEqual(features.purposeState, .identified)
    }

    func testEquallyStrongPurposesProduceConflictingState() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code to sign in and approve a payment."],
            full: []
        ))

        XCTAssertEqual(Set(features.inferredPurposes), Set([.signIn, .payment]))
        XCTAssertEqual(features.purposeState, .conflicting)
        XCTAssertTrue(features.contradictionFlags.contains(.competingPurposes))
    }

    func testUnrecognizedPurposeRemainsUnknown() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Complete the next step on your mobile device."],
            full: []
        ))

        XCTAssertTrue(features.inferredPurposes.isEmpty)
        XCTAssertEqual(features.purposeState, .unknown)
        XCTAssertFalse(features.completenessIndicators.contains(.clearPurpose))
    }

    func testQRLocalSignInOutranksBackgroundRegistrationWording() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: [
                "Scan this QR code with the camera on the device that has your",
                "passkey for chase.com"
            ],
            full: [(
                "Create a passkey after signing on and skip the password next time.",
                NormalizedBoundingBox(x: 0.25, y: 0.08, width: 0.5, height: 0.04)
            )]
        ))

        XCTAssertEqual(
            features.inferredPurposes,
            [.signIn],
            "purpose evidence: \(features.purposeEvidence)"
        )
        XCTAssertTrue(features.purposeEvidence.contains { $0.purpose == .registerPasskey })
        XCTAssertFalse(features.contradictionFlags.contains(.competingPurposes))
    }

    func testC01CleanDemotesAdjacentFuturePasskeyRegistrationCopy() {
        let observation = makeSemanticObservation(
            near: [
                "Scan this QR code with the camera on the device that has your passkey for connect.secure.wellsfargo.com"
            ],
            full: [(
                "Don't have one? Create a passkey after signing on and skip the password next time.",
                NormalizedBoundingBox(x: 0.25, y: 0.22, width: 0.50, height: 0.04)
            )]
        )

        let features = extractor.extract(from: observation)
        let result = ContextClassifier().classify(observation: observation)

        XCTAssertEqual(features.visibleServiceClaims, ["Wells Fargo"])
        XCTAssertEqual(features.inferredPurposes, [.signIn])
        XCTAssertEqual(features.purposeState, .identified)
        XCTAssertFalse(features.competingContextPresent)
        XCTAssertEqual(features.associationResolution, .notApplicable)
        XCTAssertTrue(features.purposeEvidence.contains {
            $0.purpose == .registerPasskey &&
                $0.applicability == .futureOrSecondary &&
                $0.priority == .background
        })
        XCTAssertFalse(features.contradictionFlags.contains(.competingPurposes))
        XCTAssertEqual(
            result.visualClassification,
            .consistent,
            "rules: \(result.ruleResults)"
        )
    }

    func testC01PeripheralChaseIsResolvedWithoutIdentityContradiction() {
        let observation = makeSemanticObservation(
            near: [
                "Wells Fargo Passkeys & Security Keys",
                "Scan this QR code with the camera on the device that has your passkey for connect.secure.wellsfargo.com"
            ],
            full: [
                (
                    "https://www.chase.com/personal/mobile",
                    NormalizedBoundingBox(x: 0.01, y: 0.94, width: 0.20, height: 0.03)
                ),
                (
                    "CHASE Go paperless",
                    NormalizedBoundingBox(x: 0.01, y: 0.84, width: 0.20, height: 0.04)
                )
            ]
        )

        let features = extractor.extract(from: observation)
        let result = ContextClassifier().classify(observation: observation)

        XCTAssertEqual(features.visibleServiceClaims, ["Wells Fargo"])
        XCTAssertEqual(features.peripheralServiceClaims, ["Chase"])
        XCTAssertTrue(features.competingContextPresent)
        XCTAssertEqual(features.associationResolution, .resolved)
        XCTAssertTrue(features.identityContradictionEvents.isEmpty)
        XCTAssertFalse(features.contradictionFlags.contains(.multipleVisibleServices))
        XCTAssertFalse(features.contradictionFlags.contains(.ambiguousContextAssociation))
        XCTAssertFalse(result.ruleResults.contains { $0.ruleIdentifier == "service_mismatch" })
        XCTAssertEqual(
            result.visualClassification,
            .consistent,
            "features: \(features); rules: \(result.ruleResults)"
        )
    }

    func testM01CorroboratedOverlappingPageIdentityConflictsWithQRLocalIdentity() {
        let observation = makeSemanticObservation(
            near: [
                "Scan this QR code with the device that has your passkey for chase.com"
            ],
            full: [
                (
                    "https://robinhood.com/login",
                    NormalizedBoundingBox(x: 0.08, y: 0.94, width: 0.84, height: 0.03)
                ),
                (
                    "Log in to Robinhood",
                    NormalizedBoundingBox(x: 0.55, y: 0.70, width: 0.30, height: 0.05)
                )
            ]
        )

        let features = extractor.extract(from: observation)
        let result = ContextClassifier().classify(observation: observation)

        XCTAssertEqual(features.identityContradictionEvents.count, 1)
        XCTAssertEqual(features.identityContradictionEvents.first?.kind, .serviceMismatch)
        XCTAssertEqual(
            Set(features.identityContradictionEvents.first?.identities ?? []),
            Set(["Chase", "Robinhood"])
        )
        XCTAssertEqual(result.visualClassification, .suspicious)
    }

    func testFederatedLoginProviderCopyIsNotPromotedToServiceIdentity() {
        let observation = makeSemanticObservation(
            near: [
                "Scan this QR code with the device that has your passkey for github.com"
            ],
            full: [
                (
                    "Continue with Apple",
                    NormalizedBoundingBox(x: 0.40, y: 0.24, width: 0.22, height: 0.04)
                )
            ]
        )

        let features = extractor.extract(from: observation)

        XCTAssertEqual(features.visibleServiceClaims, ["GitHub"])
        XCTAssertFalse(features.peripheralServiceClaims.contains("Apple"))
        XCTAssertTrue(features.identityContradictionEvents.isEmpty)
        XCTAssertFalse(features.visualClaims.contains {
            $0.kind == .service && $0.value == "Apple"
        })
    }

    func testUnrecognizedDomainSuffixRemainsDiagnosticButNotIdentityEvidence() throws {
        let observation = makeSemanticObservation(
            near: ["login.nh", "Cancel"],
            full: []
        )

        let features = extractor.extract(from: observation)
        let claim = try XCTUnwrap(features.domainEvidence.first)

        XCTAssertEqual(claim.domain, "login.nh")
        XCTAssertEqual(claim.recognitionStatus, .unrecognizedSuffix)
        XCTAssertFalse(claim.participatesInServiceIdentity)
        XCTAssertTrue(features.visibleDomainClaims.isEmpty)
        XCTAssertFalse(features.visualClaims.contains { $0.kind == .domain })
    }

    func testEquallyPlausibleIdentityContextsAreAmbiguousNotStrongMismatch() {
        let observation = ScanObservation(
            qrCodes: [QRCodeObservation(
                type: .fido,
                boundingBox: NormalizedBoundingBox(
                    x: 0.40, y: 0.40, width: 0.20, height: 0.20
                )
            )],
            ocrObservations: [
                OCRObservation(
                    text: "Microsoft sign in",
                    confidence: 0.97,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.10, y: 0.45, width: 0.15, height: 0.04
                    ),
                    region: .fullFrame
                ),
                OCRObservation(
                    text: "Google sign in",
                    confidence: 0.97,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.75, y: 0.45, width: 0.15, height: 0.04
                    ),
                    region: .fullFrame
                )
            ],
            imageQuality: ImageQualityObservation(
                isSufficientForAnalysis: true,
                issues: []
            )
        )

        let features = extractor.extract(from: observation)
        let result = ContextClassifier().classify(observation: observation)

        XCTAssertTrue(features.competingContextPresent)
        XCTAssertEqual(features.associationResolution, .ambiguous)
        XCTAssertTrue(features.identityContradictionEvents.isEmpty)
        XCTAssertTrue(features.contradictionFlags.contains(.ambiguousContextAssociation))
        XCTAssertFalse(result.ruleResults.contains { $0.ruleIdentifier == "service_mismatch" })
        XCTAssertEqual(result.visualClassification, .uncertain)
    }

    func testKnownBrowserServiceAndQRLocalServiceCreateOneServiceMismatchEvent() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code with the device that has your passkey for chase.com"],
            full: [(
                "robinhood.com/login",
                NormalizedBoundingBox(x: 0.25, y: 0.94, width: 0.35, height: 0.03)
            )]
        ))

        XCTAssertEqual(features.identityContradictionEvents.count, 1)
        XCTAssertEqual(features.identityContradictionEvents.first?.kind, .serviceMismatch)
        XCTAssertEqual(Set(features.identityContradictionEvents.first?.identities ?? []), Set(["Chase", "Robinhood"]))
        XCTAssertEqual(features.browserDomainCandidates.map(\.domain), ["robinhood.com"])
        XCTAssertEqual(features.associationResolution, .resolved)
    }

    func testCorroboratedPrimaryBrowserIdentityCanConflictWhenDistantFromQRCode() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code with the device that has your passkey for chase.com"],
            full: [
                (
                    "robinhood.com/login/",
                    NormalizedBoundingBox(x: 0.05, y: 0.92, width: 0.20, height: 0.03)
                ),
                (
                    "Log In | Robinhood",
                    NormalizedBoundingBox(x: 0.05, y: 0.96, width: 0.18, height: 0.03)
                )
            ]
        ))

        XCTAssertEqual(features.associationResolution, .resolved)
        XCTAssertEqual(features.identityContradictionEvents.count, 1)
        XCTAssertEqual(features.identityContradictionEvents.first?.kind, .serviceMismatch)
        XCTAssertEqual(
            Set(features.identityContradictionEvents.first?.identities ?? []),
            Set(["Chase", "Robinhood"])
        )
    }

    func testUnknownBrowserDomainConflictingWithKnownServiceCreatesBrandDomainEvent() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code with a compatible device to sign in to github.com"],
            full: [(
                "signin.example",
                NormalizedBoundingBox(x: 0.30, y: 0.94, width: 0.25, height: 0.03)
            )]
        ))

        XCTAssertEqual(features.identityContradictionEvents.count, 1)
        XCTAssertEqual(features.identityContradictionEvents.first?.kind, .brandDomainConflict)
        XCTAssertEqual(features.spatialEvidence.last?.semanticRole, .browserDomainCandidate)
        XCTAssertEqual(features.spatialEvidence.last?.associationStrength, .plausible)
    }

    func testDistantFooterIdentityRemainsPeripheralRatherThanContradictory() {
        let features = extractor.extract(from: makeSemanticObservation(
            near: ["Scan this QR code with a compatible device to sign in to github.com"],
            full: [(
                "PayPal privacy policy",
                NormalizedBoundingBox(x: 0.30, y: 0.02, width: 0.25, height: 0.03)
            )]
        ))

        XCTAssertTrue(features.identityContradictionEvents.isEmpty)
        XCTAssertEqual(features.spatialEvidence.last?.semanticRole, .peripheral)
    }

    private func makeObservation(
        nearText: String,
        fullText: String
    ) -> ScanObservation {
        ScanObservation(
            qrCodes: [
                QRCodeObservation(
                    type: .fido,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.3,
                        y: 0.3,
                        width: 0.3,
                        height: 0.3
                    )
                )
            ],
            ocrObservations: [
                OCRObservation(
                    text: nearText,
                    confidence: 0.95,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.2,
                        y: 0.62,
                        width: 0.4,
                        height: 0.08
                    ),
                    region: .qrSurrounding
                ),
                OCRObservation(
                    text: fullText,
                    confidence: 0.8,
                    boundingBox: NormalizedBoundingBox(
                        x: 0.82,
                        y: 0.82,
                        width: 0.15,
                        height: 0.05
                    ),
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

    private func makeSemanticObservation(
        near: [String],
        full: [(String, NormalizedBoundingBox)]
    ) -> ScanObservation {
        let qr = QRCodeObservation(
            type: .fido,
            boundingBox: NormalizedBoundingBox(x: 0.35, y: 0.30, width: 0.30, height: 0.30)
        )
        let nearObservations = near.enumerated().map { index, text in
            OCRObservation(
                text: text,
                confidence: 0.97,
                boundingBox: NormalizedBoundingBox(
                    x: 0.20,
                    y: 0.64 + Double(index) * 0.055,
                    width: 0.60,
                    height: 0.045
                ),
                region: .qrSurrounding
            )
        }
        let fullObservations = full.map { text, box in
            OCRObservation(text: text, confidence: 0.95, boundingBox: box, region: .fullFrame)
        }
        return ScanObservation(
            qrCodes: [qr],
            ocrObservations: nearObservations + fullObservations,
            imageQuality: ImageQualityObservation(isSufficientForAnalysis: true, issues: [])
        )
    }
}
