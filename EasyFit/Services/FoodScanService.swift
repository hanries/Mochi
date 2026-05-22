import SwiftUI
import UIKit

// MARK: - Response shape

struct FoodScanResult: Codable {
    let name: String
    let servingSize: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let confidence: Double
}

// MARK: - Protocol — swap real ↔ mock without touching any view

protocol FoodScanServiceProtocol {
    func scan(image: UIImage) async throws -> FoodScanResult
}

// MARK: - Mock (no API key needed)

final class MockFoodScanService: FoodScanServiceProtocol {
    func scan(image: UIImage) async throws -> FoodScanResult {
        // Simulate network delay so the loading state is visible
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let mocks: [FoodScanResult] = [
            FoodScanResult(name: "Grilled Chicken Breast", servingSize: "200g", calories: 330, protein: 62, carbs: 0,  fat: 7,  confidence: 0.94),
            FoodScanResult(name: "Avocado Toast",          servingSize: "1 slice", calories: 240, protein: 5,  carbs: 28, fat: 14, confidence: 0.88),
            FoodScanResult(name: "Greek Yogurt",           servingSize: "1 cup",   calories: 150, protein: 20, carbs: 9,  fat: 4,  confidence: 0.91),
            FoodScanResult(name: "Scrambled Eggs",         servingSize: "3 eggs",  calories: 280, protein: 21, carbs: 2,  fat: 20, confidence: 0.96),
            FoodScanResult(name: "Brown Rice Bowl",        servingSize: "350g",    calories: 410, protein: 8,  carbs: 82, fat: 4,  confidence: 0.85),
        ]
        return mocks.randomElement()!
    }
}

// MARK: - Real service (requires API key)

final class FoodScanService: FoodScanServiceProtocol {
    private let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }

    func scan(image: UIImage) async throws -> FoodScanResult {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw ScanError.imageConversionFailed
        }
        let base64 = jpeg.base64EncodedString()

        let prompt = """
        Analyze this food image and return ONLY a JSON object (no markdown, no explanation) with these fields:
        {
          "name": "<dish or food item name>",
          "servingSize": "<estimated serving, e.g. '1 cup' or '200g'>",
          "calories": <integer>,
          "protein": <grams as decimal>,
          "carbs": <grams as decimal>,
          "fat": <grams as decimal>,
          "confidence": <0.0 to 1.0>
        }
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-5",
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
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ScanError.apiError
        }

        let envelope = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = envelope.content.first(where: { $0.type == "text" })?.text else {
            throw ScanError.emptyResponse
        }
        guard let jsonData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw ScanError.parseError
        }
        return try JSONDecoder().decode(FoodScanResult.self, from: jsonData)
    }
}

// MARK: - Shared accessor — flip `useMock` when you get your API key

enum ScanServiceFactory {
    static let useMock = true   // ← set false to use real API

    static func make() -> any FoodScanServiceProtocol {
        useMock
            ? MockFoodScanService()
            : FoodScanService(apiKey: "YOUR_API_KEY")
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
