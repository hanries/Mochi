import Foundation

enum Config {
    static var edamamAppId: String {
        if let key = Bundle.main.infoDictionary?["EDAMAM_APP_ID"] as? String,
           !key.isEmpty, !key.hasPrefix("$") { return key }
        return ""
    }

    static var edamamAppKey: String {
        if let key = Bundle.main.infoDictionary?["EDAMAM_APP_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$") { return key }
        return ""
    }

    static var anthropicAPIKey: String {
        if let key = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$") { return key }
        return ""
    }
}
