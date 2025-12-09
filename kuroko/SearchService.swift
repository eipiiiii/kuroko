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
        
        let (data, _) = try await URLSession.shared.data(from: finalURL)
        let decoder = JSONDecoder()
        let response = try decoder.decode(GoogleSearchResponse.self, from: data)
        
        guard let items = response.items, !items.isEmpty else {
            return "No search results found."
        }
        
        let resultString = items.map { item in
            """
            Title: \(item.title)
            Link: \(item.link)
            Snippet: \(item.snippet ?? "No snippet")
            """
        }.joined(separator: "\n\n")
        
        return "Search Results:\n\(resultString)"
    }
}
