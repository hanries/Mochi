import Foundation

enum Config {
    static var usdaAPIKey: String {
        if let key = Bundle.main.infoDictionary?["USDA_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$") { return key }
        return "DEMO_KEY"
    }

    static var anthropicAPIKey: String {
        if let key = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$") { return key }
        return ""
    }
}
