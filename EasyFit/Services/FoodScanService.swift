import Foundation
import UIKit

// MARK: - Response shape

// One detected food. The AI returns an array of these so a plate with
// several items (eggs + toast + coffee) comes back as distinct rows the
// user can correct individually before saving.
struct FoodScanItem: Codable, Identifiable {
    var id = UUID()
    var name:        String
    var servingSize: String
    var calories:    Int
    var protein:     Double
    var carbs:       Double
    var fat:         Double
    var confidence:  Double

    // id is local-only — never decoded from the API payload.
    enum CodingKeys: String, CodingKey {
        case name, servingSize, calories, protein, carbs, fat, confidence
    }
}

private struct ScanItemsEnvelope: Codable {
    let items: [FoodScanItem]
}

// MARK: - Protocol

protocol FoodScanServiceProtocol {
    func scan(image: UIImage) async throws -> [FoodScanItem]
}

// MARK: - Mock

final class MockFoodScanService: FoodScanServiceProtocol {
    func scan(image: UIImage) async throws -> [FoodScanItem] {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let pool: [FoodScanItem] = [
            FoodScanItem(name: "Grilled Chicken Breast", servingSize: "200g",    calories: 330, protein: 62, carbs: 0,  fat: 7,  confidence: 0.94),
            FoodScanItem(name: "Avocado Toast",          servingSize: "1 slice", calories: 240, protein: 5,  carbs: 28, fat: 14, confidence: 0.88),
            FoodScanItem(name: "Greek Yogurt",           servingSize: "1 cup",   calories: 150, protein: 20, carbs: 9,  fat: 4,  confidence: 0.91),
            FoodScanItem(name: "Scrambled Eggs",         servingSize: "3 eggs",  calories: 280, protein: 21, carbs: 2,  fat: 20, confidence: 0.96),
            FoodScanItem(name: "Brown Rice Bowl",        servingSize: "350g",    calories: 410, protein: 8,  carbs: 82, fat: 4,  confidence: 0.85),
        ]
        // Return 1–3 distinct items so the multi-item UI is exercised.
        let count = Int.random(in: 1...3)
        return Array(pool.shuffled().prefix(count))
    }
}

// MARK: - Real service

final class FoodScanService: FoodScanServiceProtocol {
    private let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }

    func scan(image: UIImage) async throws -> [FoodScanItem] {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw ScanError.imageConversionFailed
        }
        let base64 = jpeg.base64EncodedString()

        let prompt = """
        Analyze this food image. Identify each distinct food or drink as a separate item (up to 6). Return ONLY raw JSON with no markdown, no backticks, no explanation:
        {"items":[{"name":"<food name>","servingSize":"<e.g. 1 cup or 200g>","calories":<integer>,"protein":<decimal>,"carbs":<decimal>,"fat":<decimal>,"confidence":<0.0-1.0>}]}
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64
                    ]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var request: URLRequest
        let proxy = Config.proxyBaseURL
        if !proxy.isEmpty {
            // Proxy injects the Anthropic key server-side; the app ships none.
            let base = proxy.hasSuffix("/") ? String(proxy.dropLast()) : proxy
            request = URLRequest(url: URL(string: "\(base)/scan")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else {
            request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
        }
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("🔍 Anthropic status: \(statusCode)")

        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Anthropic error: \(body)")
            throw ScanError.apiError
        }

        let envelope = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let rawText = envelope.content.first(where: { $0.type == "text" })?.text else {
            print("❌ Empty response from Anthropic")
            throw ScanError.emptyResponse
        }

        print("📦 Raw response: \(rawText)")

        // Strip markdown backticks if Claude wraps the JSON anyway
        let cleaned = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract just the JSON object in case there's surrounding text
        guard let jsonStart = cleaned.firstIndex(of: "{"),
              let jsonEnd   = cleaned.lastIndex(of: "}") else {
            print("❌ No JSON object found in: \(cleaned)")
            throw ScanError.parseError
        }

        let jsonString = String(cleaned[jsonStart...jsonEnd])
        print("✅ Parsed JSON: \(jsonString)")

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ScanError.parseError
        }

        let decoder = JSONDecoder()
        // Prefer the {"items":[...]} envelope; fall back to a single item
        // object if the model ignored the array instruction.
        if let env = try? decoder.decode(ScanItemsEnvelope.self, from: jsonData), !env.items.isEmpty {
            return env.items
        }
        if let single = try? decoder.decode(FoodScanItem.self, from: jsonData) {
            return [single]
        }
        print("❌ Decode error: could not parse items from \(jsonString)")
        throw ScanError.parseError
    }
}

// MARK: - Factory

enum ScanServiceFactory {
    static func make() -> any FoodScanServiceProtocol {
        // Prefer the proxy (no key on device). Else fall back to a direct key.
        if !Config.proxyBaseURL.isEmpty {
            print("✅ FoodScan: using proxy")
            return FoodScanService(apiKey: "")
        }
        let key = Config.anthropicAPIKey
        if key.isEmpty {
            print("⚠️ FoodScan: no proxy or key — using mock data")
            return MockFoodScanService()
        }
        print("✅ FoodScan: using Anthropic directly (key: \(key.prefix(10))...)")
        return FoodScanService(apiKey: key)
    }
}

// MARK: - Supporting types

private struct AnthropicResponse: Codable {
    let content: [ContentBlock]
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

enum ScanError: LocalizedError {
    case imageConversionFailed, apiError, emptyResponse, parseError
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Could not process the image."
        case .apiError:              return "AI service returned an error."
        case .emptyResponse:         return "No response from AI."
        case .parseError:            return "Could not parse nutritional data."
        }
    }
}
