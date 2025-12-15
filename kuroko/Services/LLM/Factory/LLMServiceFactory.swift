import Foundation

/// A factory for creating `LLMService` instances.
/// This factory is responsible for instantiating the correct service implementation
/// based on the provider specified in the `LLMModel`.
public class LLMServiceFactory {
    
    /// Creates and returns an `LLMService` for a given provider.
    ///
    /// This is the single point of control for creating provider-specific services.
    /// When a new provider is added, this factory is the only place that needs
    /// to be updated to instantiate its service.
    ///
    /// - Parameter provider: The `LLMProvider` for which to create the service.
    /// - Returns: An instance of a class conforming to `LLMService`.
    /// - Throws: `FactoryError.unsupportedProvider` if the provider is not supported.
    public static func createService(for provider: LLMProvider) throws -> LLMService {
        switch provider {
        case .openRouter:
            // All dependencies for the service are resolved here.
            // For now, they use the default singletons.
            return OpenRouterLLMService(
                configService: .shared,
                toolRegistry: .shared
            )
        // Future providers would be added here, e.g.:
        // case .openAI:
        //     return OpenAILLMService()
        }
    }
}

// MARK: - Factory Errors

enum FactoryError: LocalizedError {
    case unsupportedProvider(LLMProvider)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let provider):
            return "The provider '\(provider.rawValue)' is not currently supported."
        }
    }
}
