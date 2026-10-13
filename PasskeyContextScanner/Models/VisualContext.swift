import Foundation

struct VisualContext: Codable, Equatable {
    var qrDetected: Bool
    var ocrText: String
    var visibleDomainClaims: [String]
    var authenticationKeywords: [String]

    init(
        qrDetected: Bool,
        ocrText: String,
        visibleDomainClaims: [String] = [],
        authenticationKeywords: [String] = []
    ) {
        self.qrDetected = qrDetected
        self.ocrText = ocrText
        self.visibleDomainClaims = visibleDomainClaims
        self.authenticationKeywords = authenticationKeywords
    }
}
