import Foundation

enum Config {
    static var anthropicAPIKey: String {
        value(for: "ANTHROPIC_API_KEY")
    }

    static var edamamAppId: String {
        value(for: "EDAMAM_APP_ID")
    }

    static var edamamAppKey: String {
        value(for: "EDAMAM_APP_KEY")
    }

    /// Base URL of the Cloudflare Worker proxy. When set, the app calls the
    /// proxy (which holds the keys) and ships no API keys of its own.
    static var proxyBaseURL: String {
        value(for: "PROXY_BASE_URL")
    }

    private static func value(for key: String) -> String {
        guard let val = Bundle.main.infoDictionary?[key] as? String,
              !val.isEmpty,
              !val.hasPrefix("$") else {
            return ""
        }
        return val
    }
}
