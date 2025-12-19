import Foundation

struct GoogleSearchResponse: Codable {
    let items: [GoogleSearchResult]?
}

struct GoogleSearchResult: Codable {
    let title: String
    let link: String
    let snippet: String?
}

class SearchService {
    static let shared = SearchService()
    
    private init() {}
    
    func performSearch(query: String, apiKey: String, engineId: String) async throws -> String {
        guard let url = URL(string: "https://www.googleapis.com/customsearch/v1") else {
            throw URLError(.badURL)
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: engineId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: "5") // Limit to 5 results
        ]

        guard let finalURL = components.url else {
            throw URLError(.badURL)
        }

        // Create URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0 // 10 second timeout
        configuration.timeoutIntervalForResource = 10.0
        let session = URLSession(configuration: configuration)

        let (data, httpResponse) = try await session.data(from: finalURL)

        // Check HTTP status
        if let httpResponse = httpResponse as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                if httpResponse.statusCode == 403 {
                    throw NSError(domain: "GoogleSearch", code: 403, userInfo: [NSLocalizedDescriptionKey: "Google Search API access denied. Check your API key and search engine ID."])
                } else if httpResponse.statusCode == 429 {
                    throw NSError(domain: "GoogleSearch", code: 429, userInfo: [NSLocalizedDescriptionKey: "Google Search API quota exceeded."])
                } else {
                    throw NSError(domain: "GoogleSearch", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Search API returned status \(httpResponse.statusCode)"])
                }
            }
        }
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(GoogleSearchResponse.self, from: data)
        
        guard let items = searchResponse.items, !items.isEmpty else {
            return "No search results found."
        }
        
        // Format as structured Markdown list
        var resultString = "🔍 **Search Results:**\n\n"
        
        for (index, item) in items.enumerated() {
            let number = index + 1
            let title = item.title
            let snippet = item.snippet ?? "No description available"
            let link = item.link
            
            resultString += "\(number). **\(title)**"
            if !snippet.isEmpty {
                resultString += " - \(snippet)"
            }
            resultString += "  \n   Source: [\(extractDomain(from: link))](\(link))\n\n"
        }
        
        return resultString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        // Remove 'www.' prefix if present
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
