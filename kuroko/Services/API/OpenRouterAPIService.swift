import Foundation

// MARK: - Data Models for OpenRouter API

/// Represents a single model as returned by the OpenRouter /models API.
public struct OpenRouterAPIModel: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let context_length: Int?
}

/// Represents the top-level response from the OpenRouter /models API.
private struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterAPIModel]
}

// MARK: - OpenRouter API Service

/// A service dedicated to non-chat interactions with the OpenRouter API, such as fetching models.
class OpenRouterAPIService {
    
    /// Fetches the list of available models from the OpenRouter API.
    /// - Parameter apiKey: The user's OpenRouter API key.
    /// - Returns: An array of models available from the API.
    /// - Throws: An error if the network request or decoding fails.
    func fetchModels(apiKey: String) async throws -> [OpenRouterAPIModel] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "OpenRouterAPIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing."])
        }
        
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenRouterAPIService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models from OpenRouter."])
        }
        
        let decoder = JSONDecoder()
        let modelsResponse = try decoder.decode(OpenRouterModelsResponse.self, from: data)
        
        // Sort models alphabetically by name
        let sortedModels = modelsResponse.data.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        return sortedModels
    }
}
