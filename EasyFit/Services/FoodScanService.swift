import Foundation
import UIKit

// MARK: - Response shape

struct FoodScanResult: Codable {
    let name:        String
    let servingSize: String
    let calories:    Int
    let protein:     Double
    let carbs:       Double
    let fat:         Double
    let confidence:  Double
}

// MARK: - Protocol

protocol FoodScanServiceProtocol {
    func scan(image: UIImage) async throws -> FoodScanResult
}

// MARK: - Mock

final class MockFoodScanService: FoodScanServiceProtocol {
    func scan(image: UIImage) async throws -> FoodScanResult {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let mocks: [FoodScanResult] = [
            FoodScanResult(name: "Grilled Chicken Breast", servingSize: "200g",    calories: 330, protein: 62, carbs: 0,  fat: 7,  confidence: 0.94),
            FoodScanResult(name: "Avocado Toast",          servingSize: "1 slice", calories: 240, protein: 5,  carbs: 28, fat: 14, confidence: 0.88),
            FoodScanResult(name: "Greek Yogurt",           servingSize: "1 cup",   calories: 150, protein: 20, carbs: 9,  fat: 4,  confidence: 0.91),
            FoodScanResult(name: "Scrambled Eggs",         servingSize: "3 eggs",  calories: 280, protein: 21, carbs: 2,  fat: 20, confidence: 0.96),
            FoodScanResult(name: "Brown Rice Bowl",        servingSize: "350g",    calories: 410, protein: 8,  carbs: 82, fat: 4,  confidence: 0.85),
        ]
        return mocks.randomElement()!
    }
}

// MARK: - Real service

final class FoodScanService: FoodScanServiceProtocol {
    private let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }

    func scan(image: UIImage) async throws -> FoodScanResult {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw ScanError.imageConversionFailed
        }
        let base64 = jpeg.base64EncodedString()

        let prompt = """
        Analyze this food image. Return ONLY raw JSON with no markdown, no backticks, no explanation:
        {"name":"<food name>","servingSize":"<e.g. 1 cup or 200g>","calories":<integer>,"protein":<decimal>,"carbs":<decimal>,"fat":<decimal>,"confidence":<0.0-1.0>}
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 256,
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

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

        do {
            return try JSONDecoder().decode(FoodScanResult.self, from: jsonData)
        } catch {
            print("❌ Decode error: \(error)")
            throw ScanError.parseError
        }
    }
}

// MARK: - Factory

enum ScanServiceFactory {
    static func make() -> any FoodScanServiceProtocol {
        let key = Config.anthropicAPIKey
        if key.isEmpty {
            print("⚠️ FoodScan: No Anthropic key — using mock data")
            return MockFoodScanService()
        }
        print("✅ FoodScan: Using real Anthropic API (key: \(key.prefix(10))...)")
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
