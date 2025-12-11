# Kuroko AI Coding Agent Instructions

## Overview

Kuroko is a privacy-focused, multi-provider AI assistant for iOS and macOS built with SwiftUI. It supports Google Gemini and OpenRouter (100+ models), provides secure file system access, and enables advanced tool calling capabilities.

**Key Technologies:**
- SwiftUI (iOS 17+, macOS 14+)
- Swift 5.9+
- GoogleGenerativeAI SDK
- MarkdownUI for rich text rendering
- Security-scoped bookmarks for file access

## Architecture

### Core Structure
```
kuroko/
├── Models/              # Data structures (MessageModels, SessionModels, ToolModels, FileSystemModels)
├── ViewModels/          # UI state management (KurokoViewModel)
├── Services/            # Business logic
│   ├── API/             # GeminiService, OpenRouterService, APIConfigurationService
│   ├── FileSystem/      # FileAccessManager, FileSystemService
│   ├── SearchService.swift
│   └── SessionManager.swift
├── Views/               # Platform-specific UI
│   ├── Shared/          # Cross-platform components
│   ├── iOS/             # iOS-specific views
│   └── macOS/           # macOS-specific views
├── Managers/            # ThemeManager
└── Extensions/          # ColorExtensions, ViewExtensions
```

### Service Architecture
- **APIConfigurationService**: Manages API keys, model selection, and system prompts
- **GeminiService**: Direct Google Gemini API integration with streaming
- **OpenRouterService**: Access to 100+ AI models with tool calling
- **FileAccessManager**: Security-scoped file system access
- **FileSystemService**: File operations within working directory
- **SearchService**: Google Custom Search integration
- **SessionManager**: Conversation persistence and management

## Key Patterns

### 1. Dependency Injection
All services are injected into ViewModels for testability:
```swift
init(
    configService: APIConfigurationService = .shared,
    geminiService: GeminiServiceProtocol = GeminiService(),
    openRouterService: OpenRouterServiceProtocol = OpenRouterService(),
    sessionManager: SessionManager = .shared
)
```

### 2. Observable State Management
Uses `@Observable` for efficient state updates:
```swift
@Observable
class KurokoViewModel {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
    // ...
}
```

### 3. Protocol-Oriented Design
Services implement protocols for flexibility:
```swift
protocol GeminiServiceProtocol {
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void
    ) async throws
}
```

### 4. Security-Scoped Bookmarks
File access uses persistent security-scoped bookmarks:
```swift
// Start access
url.startAccessingSecurityScopedResource()
// Stop access
url.stopAccessingSecurityScopedResource()
```

## Critical Workflows

### Building & Running
1. Open `kuroko.xcodeproj` in Xcode 15+
2. Select development team for signing
3. Configure App Sandbox: User Selected File → Read/Write
4. Build and run on device or simulator

### API Configuration
1. Get Gemini API key: https://makersuite.google.com/app/apikey
2. Get OpenRouter API key: https://openrouter.ai/keys
3. Configure in Settings → API Keys
4. Optional: Set up Google Custom Search for web search

### File System Setup
1. Go to Settings → Files
2. Select working directory
3. Grant access when prompted
4. AI can now read/write files in this directory

## Platform-Specific Considerations

### iOS vs macOS
- **iOS**: Uses `IOSContentView` with navigation stack, keyboard avoidance
- **macOS**: Uses `MacOSContentView` with sidebar, Settings in separate window
- **Shared**: Core logic, models, and some views are platform-agnostic

### UI/UX Flow

#### Main User Journey
1. **Launch**: App opens to ChatView with welcome message
2. **Configuration** (first-time): User sets API keys in Settings → API Keys
3. **File Access** (optional): User selects working directory in Settings → Files
4. **Chat**: User types message → AI responds with streaming text
5. **Tool Usage**: AI may use tools (search, file operations) automatically
6. **Session Management**: Conversations auto-save; users can browse history

#### Screen Navigation
```
Launch → ChatView
  |
  |-- Settings (iOS: Sheet, macOS: Separate Window)
  |   |-- Appearance → Theme selection
  |   |-- Model Provider → Gemini/OpenRouter settings
  |   |-- Custom Instructions → System prompt
  |   |-- Search Config → Google Custom Search
  |   |-- File System → Working directory selection
  |   |-- Conversation Save Location → Session storage
  |
  |-- History (iOS: Sheet, macOS: Sidebar)
      |-- List of saved sessions
      |-- Tap to load session
```

#### Tool Usage UI
- **Search Results**: Displayed as formatted Markdown list in chat bubble
- **File Operations**: Results shown as text in chat bubble
- **Streaming**: Progress indicator with "考え中..." text
- **Actions**: Buttons for copy, retry, stop generation

### Theme System
- `ThemeManager` provides color schemes for different themes
- Supports Monochrome, Ocean, Modern AI, Classic Editorial, Japan Tradition
- Colors adapt to light/dark mode automatically

## Tool Calling Framework

### Current Tools
1. **Google Search**: Real-time web search via Google Custom Search
2. **File Operations**: List, read, write, delete files in working directory

### Tool Definition and AI Integration
Tools are defined in `ToolModels.swift` and presented to the AI in the OpenRouter API request:

1. **Tool Schema Definition** (`ToolModels.swift`):
   ```swift
   struct Tool: Codable {
       let type: String // "function"
       let function: FunctionDefinition
   }
   
   struct FunctionDefinition: Codable {
       let name: String
       let description: String
       let parameters: ParameterDefinition
   }
   
   struct ParameterDefinition: Codable {
       let type: String // "object"
       let properties: [String: PropertyDefinition]
       let required: [String]
   }
   ```

2. **AI Prompt Integration** (`OpenRouterService`):
   - Tools are added to the request body under the `tools` key
   - The AI model receives the tool schema and can decide to use tools
   - Example request structure:
   ```json
   {
     "model": "model-id",
     "messages": [...],
     "tools": [
       {
         "type": "function",
         "function": {
           "name": "google_search",
           "description": "Search the web",
           "parameters": {
             "type": "object",
             "properties": {
               "query": {
                 "type": "string",
                 "description": "Search query"
               }
             },
             "required": ["query"]
           }
         }
       }
     ]
   }
   ```

3. **AI Response Parsing** (`OpenRouterService`):
   - AI responds with tool call requests in JSON format
   - Example response:
   ```json
   {
     "role": "assistant",
     "content": null,
     "tool_calls": [
       {
         "id": "call_1",
         "type": "function",
         "function": {
           "name": "google_search",
           "arguments": "{\"query\": \"SwiftUI tutorial\"}"
         }
       }
     ]
   }
   ```
   - The service parses `tool_calls`, executes the corresponding Swift function, and sends the result back to the AI

### Adding New Tools
1. Define tool schema in `ToolModels.swift`
2. Add tool call handling in `OpenRouterService` (parse `tool_calls`)
3. Implement tool execution logic in appropriate service
4. Update system prompt if needed to describe the new tool
5. Ensure tool results are formatted correctly for the API

### File System Access

### Security Model
- Uses App Sandbox with User Selected File permissions
- Security-scoped bookmarks for persistent access
- Path validation prevents directory escape
- Multiple encoding support (UTF-8, UTF-16, ASCII, ISO Latin-1)

### File Operations
- **List**: Directory contents with metadata
- **Read**: Text files with encoding detection
- **Write**: Create/update files
- **Delete**: Remove files

### Data Persistence

#### Session Storage
- **Technology**: `UserDefaults` for metadata, JSON files for session data
- **Location**: User-selected directory via `SessionManager.setSaveDirectory()`
- **Format**: `ChatSession` and `SessionMessage` structs encoded as JSON
- **Security**: Uses security-scoped bookmarks for persistent access

#### File System Access
- **Working Directory**: User-selected via `FileAccessManager.setWorkingDirectory()`
- **Persistence**: Security-scoped bookmarks stored in `UserDefaults`
- **Access**: All file operations restricted to working directory

#### API Configuration
- **Storage**: `UserDefaults` with keys like `apiKey`, `openRouterApiKey`
- **Security**: Keys stored locally only, no network transmission

## Error Handling

### Common Issues
- **API Key Errors**: Check Settings → API Keys
- **File Access**: Ensure directory selected and permissions granted
- **Network**: Verify internet connection for API calls
- **Streaming**: Responses are chunked for performance

### Debugging
- Check console logs for detailed error messages
- Verify API keys are valid
- Ensure App Sandbox permissions are configured
- Test file access with simple operations first

## Testing

### Unit Tests
- Located in `kurokoTests/`
- Test services in isolation
- Mock dependencies for predictable testing

### UI Tests
- Located in `kurokoUITests/`
- Test user workflows
- Verify platform-specific behavior

## Performance Considerations

### Streaming Responses
- Uses `AsyncStream` for real-time updates
- Chunks processed incrementally
- Memory efficient for long conversations

### File Operations
- Asynchronous operations prevent UI blocking
- Path validation for security
- Encoding detection for compatibility

## Contributing Guidelines

### Code Style
- Use Swift naming conventions
- Prefer `@Observable` over `@StateObject` for shared state
- Follow existing architecture patterns
- Document new features in README.md

### Feature Development
1. Fork the repository
2. Create feature branch
3. Implement with tests
4. Update documentation
5. Submit pull request

### Breaking Changes
- Consider migration path for users
- Update version in project settings

## Security Notes

### Data Privacy
- No telemetry or tracking
- API keys stored locally only
- User controls all data access
- Security-scoped bookmarks for file access

### App Sandbox
- Required for App Store distribution
- Configure in Signing & Capabilities
- User Selected File → Read/Write enabled

## Deployment

### App Store Requirements
- iOS 17.0+ / macOS 14.0+
- App Sandbox enabled
- Privacy manifest configured
- API keys managed by users

### Build Configuration
- Swift 5.9+
- Xcode 15.0+
- iOS Deployment Target: 17.0
- macOS Deployment Target: 14.0

## Troubleshooting

### Common Build Issues
- **Missing Dependencies**: Ensure Swift packages are resolved
- **Signing Errors**: Configure development team
- **Sandbox Issues**: Enable User Selected File permissions

### Runtime Issues
- **API Errors**: Verify keys and network connectivity
- **File Access**: Check directory selection and permissions
- **Performance**: Monitor memory usage with large files

## Resources

- **README.md**: User-facing documentation
- **ANALYSIS.md**: Technical architecture analysis
- **GoogleGenerativeAI**: https://github.com/google/generative-ai-swift
- **MarkdownUI**: https://github.com/gonzalezreal/MarkdownUI
- **OpenRouter**: https://openrouter.ai/docs

### Localization (i18n)

#### Current Status
- Primary language: Japanese
- String Catalogs: Enabled (`GENERATE_INFOPLIST_FILE = YES`)
- Future-ready for internationalization

#### Adding New Languages
1. **Create String Catalog**:
   - Go to File → New → String Catalog
   - Name: `Localizable.stringsdict`
   - Add to project target

2. **Add Localized Strings**:
   ```swift
   // In views
   Text("Hello") // Will be localized
   Text(String(localized: "Hello")) // Explicit localization
   ```

3. **Supported Languages** (to be added):
   - English (en)
   - Japanese (ja)
   - Additional languages as needed

4. **Localization Guidelines**:
   - Use `NSLocalizedString` or String Catalogs
   - Avoid hardcoded strings in UI
   - Consider text expansion (up to 30% longer)
   - Test with different locales
   - Use `Locale.current` for date/number formatting

5. **Testing Localization**:
   - Test in Simulator with different languages
   - Verify text truncation doesn't break UI
   - Check RTL (Right-to-Left) support if needed

---

**Note**: This project is actively maintained. Always check the latest code for the most current patterns and practices.