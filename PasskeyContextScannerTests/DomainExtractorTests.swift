import XCTest
@testable import PasskeyContextScanner

final class DomainExtractorTests: XCTestCase {
    func testExtractsDomainsFromPlainTextAndURLs() {
        let extractor = DomainExtractor()

        let domains = extractor.extractDomains(
            from: "Open example.com, then sign in at https://login.microsoft.com."
        )

        XCTAssertEqual(domains, ["example.com", "login.microsoft.com"])
    }

    func testNormalizesCaseAndRemovesWwwPrefix() {
        let extractor = DomainExtractor()

        let domains = extractor.extractDomains(from: "Visit HTTPS://WWW.Example.COM for details.")

        XCTAssertEqual(domains, ["example.com"])
    }

    func testRemovesDuplicateDomainsPreservingFirstSeenOrder() {
        let extractor = DomainExtractor()

        let domains = extractor.extractDomains(from: "github.com login.github.com github.com")

        XCTAssertEqual(domains, ["github.com", "login.github.com"])
    }

    func testReturnsEmptyArrayWhenNoDomainExists() {
        let extractor = DomainExtractor()

        let domains = extractor.extractDomains(from: "Sign in with your passkey")

        XCTAssertTrue(domains.isEmpty)
    }

    func testClassifiesEmailAddressDomainSeparatelyFromURLClaims() {
        let claims = DomainExtractor().extractDomainClaims(
            from: "Verify j••••••n@gmail.com at https://login.example.com"
        )

        XCTAssertEqual(claims.map(\.domain), ["gmail.com", "login.example.com"])
        XCTAssertEqual(claims.map(\.sourceType), [.emailDomain, .urlDomain])
    }

    func testRejectsFilenameAndReferenceTokensAsDomainClaims() {
        let claims = DomainExtractor().extractDomainClaims(
            from: "Contract-2026.pdf REF.DOC archive.zip notes.txt"
        )

        XCTAssertTrue(claims.isEmpty)
    }

    func testExtractsHostnameButNotFilenameFromURL() {
        let claims = DomainExtractor().extractDomainClaims(
            from: "Open https://files.example.com/contracts/Contract-2026.pdf and https://archive.zip"
        )

        XCTAssertEqual(claims.map(\.domain), ["files.example.com", "archive.zip"])
        XCTAssertEqual(claims.map(\.sourceType), [.urlDomain, .urlDomain])
    }

    func testKeepsEmailDomainWhileRejectingNearbyFilename() {
        let claims = DomainExtractor().extractDomainClaims(
            from: "Contract-2026.pdf was shared by legal@acmecorp.com"
        )

        XCTAssertEqual(claims.map(\.domain), ["acmecorp.com"])
        XCTAssertEqual(claims.map(\.sourceType), [.emailDomain])
    }

    func testRetainsUnrecognizedSuffixAsNonAuthoritativeDiagnosticEvidence() throws {
        let claim = try XCTUnwrap(
            DomainExtractor().extractDomainClaims(from: "login.nh").first
        )

        XCTAssertEqual(claim.domain, "login.nh")
        XCTAssertEqual(claim.sourceType, .otherDomain)
        XCTAssertEqual(claim.recognitionStatus, .unrecognizedSuffix)
        XCTAssertFalse(claim.isAuthoritativeIdentityEvidence)
    }

    func testRecognizesCountryCodeAndReservedEvaluationSuffixes() {
        let claims = DomainExtractor().extractDomainClaims(
            from: "login.nhs.uk signin.example"
        )

        XCTAssertEqual(claims.map(\.domain), ["login.nhs.uk", "signin.example"])
        XCTAssertTrue(claims.allSatisfy(\.isAuthoritativeIdentityEvidence))
    }
}
