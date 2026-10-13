import Foundation

enum DomainSourceType: String, Codable, Equatable {
    case urlDomain = "URL_DOMAIN"
    case browserDomainCandidate = "BROWSER_DOMAIN_CANDIDATE"
    case qrLocalDomain = "QR_LOCAL_DOMAIN"
    case emailDomain = "EMAIL_DOMAIN"
    case otherDomain = "OTHER_DOMAIN"
}

struct ExtractedDomainClaim: Codable, Equatable {
    let domain: String
    let sourceType: DomainSourceType
    let recognitionStatus: DomainRecognitionStatus

    var isAuthoritativeIdentityEvidence: Bool {
        recognitionStatus == .authoritative
    }
}

/// Whether the visible token is complete enough to act as identity evidence.
/// Unrecognized suffixes are retained for diagnostics because they may be OCR
/// fragments or cropped hostnames, but they cannot establish a service claim.
enum DomainRecognitionStatus: String, Codable, Equatable {
    case authoritative = "AUTHORITATIVE"
    case unrecognizedSuffix = "UNRECOGNIZED_SUFFIX"
}

struct DomainExtractor {
    private let domainPattern = #"\b(?:https?://)?(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}\b"#
    private let filenameExtensions: Set<String> = [
        "pdf", "doc", "docx", "txt", "zip", "csv", "xls", "xlsx",
        "ppt", "pptx", "png", "jpg", "jpeg"
    ]
    private let recognizedGenericSuffixes: Set<String> = [
        "com", "org", "net", "edu", "gov", "mil", "int",
        "app", "dev", "info", "biz", "name", "online", "site",
        "tech", "cloud", "store", "bank", "example", "test",
        "localhost", "uk"
    ]

    func extractDomains(from text: String) -> [String] {
        var seen = Set<String>()
        return extractDomainClaims(from: text).map(\.domain).filter {
            seen.insert($0).inserted
        }
    }

    func extractDomainClaims(from text: String) -> [ExtractedDomainClaim] {
        guard let regex = try? NSRegularExpression(pattern: domainPattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)

        var claims: [ExtractedDomainClaim] = []
        var seen = Set<String>()

        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else {
                continue
            }

            let raw = String(text[swiftRange])
            let normalized = normalize(raw)
            let sourceType: DomainSourceType
            if swiftRange.lowerBound > text.startIndex,
               text[text.index(before: swiftRange.lowerBound)] == "@" {
                sourceType = .emailDomain
            } else if raw.lowercased().hasPrefix("http://") ||
                        raw.lowercased().hasPrefix("https://") {
                sourceType = .urlDomain
            } else {
                sourceType = .otherDomain
            }
            guard isPlausibleDomain(normalized, sourceType: sourceType) else {
                continue
            }
            let key = "\(sourceType.rawValue)|\(normalized)"
            if !normalized.isEmpty && seen.insert(key).inserted {
                claims.append(ExtractedDomainClaim(
                    domain: normalized,
                    sourceType: sourceType,
                    recognitionStatus: recognitionStatus(
                        for: normalized,
                        sourceType: sourceType
                    )
                ))
            }
        }

        return claims
    }

    private func normalize(_ value: String) -> String {
        var domain = value.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            .lowercased()

        if domain.hasPrefix("http://") {
            domain.removeFirst("http://".count)
        } else if domain.hasPrefix("https://") {
            domain.removeFirst("https://".count)
        }

        if domain.hasPrefix("www.") {
            domain.removeFirst("www.".count)
        }

        return domain
    }

    private func isPlausibleDomain(
        _ value: String,
        sourceType: DomainSourceType
    ) -> Bool {
        let labels = value.split(separator: ".")
        guard let topLevelLabel = labels.last else {
            return false
        }
        if sourceType == .urlDomain || sourceType == .emailDomain || labels.count > 2 {
            return true
        }
        return !filenameExtensions.contains(String(topLevelLabel))
    }

    private func recognitionStatus(
        for value: String,
        sourceType: DomainSourceType
    ) -> DomainRecognitionStatus {
        if sourceType == .urlDomain || sourceType == .emailDomain {
            return .authoritative
        }
        guard let suffix = value.split(separator: ".").last.map(String.init) else {
            return .unrecognizedSuffix
        }
        let countrySuffixes = Set(
            Locale.Region.isoRegions.map { $0.identifier.lowercased() }
        )
        return recognizedGenericSuffixes.contains(suffix) ||
            countrySuffixes.contains(suffix)
            ? .authoritative
            : .unrecognizedSuffix
    }
}
