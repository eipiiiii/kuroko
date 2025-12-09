# Kuroko

<div align="center">

**A powerful, privacy-focused AI assistant for iOS and macOS**

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue.svg)](https://www.apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Architecture](#architecture) • [Contributing](#contributing)

</div>

---

## Overview

Kuroko is a native SwiftUI application that brings advanced AI capabilities to your Apple devices. Unlike cloud-dependent alternatives, Kuroko gives you full control over your AI interactions with support for multiple providers, local file system access, and a clean, intuitive interface.

## Features

### 🤖 Multi-Provider AI Support
- **Google Gemini**: Direct integration with Gemini API
- **OpenRouter**: Access to 100+ AI models including GPT-4, Claude, and more
- Seamless provider switching
- Custom system prompts and instructions

### 📁 File System Access
- Read and write files in user-selected directories
- Support for text files, code, Markdown, JSON, and more
- Multiple encoding support (UTF-8, UTF-16, ASCII, ISO Latin-1)
- Hidden file access (`.gitignore`, `.env`, etc.)
- Security-scoped bookmarks for persistent access

### 🔧 Advanced Tool Calling
- **Google Search**: Real-time web search integration
- **File Operations**: List, read, write, and delete files
- **Extensible**: Easy to add custom tools

### 🎨 Beautiful UI
- Native SwiftUI design for iOS and macOS
- Dark mode support
- Multiple themes (Monochrome, Ocean)
- Platform-specific optimizations
- Smooth animations and transitions

### 💬 Smart Chat Features
- Streaming responses
- Message history with session management
- Stop generation mid-stream
- Retry failed messages
- Markdown rendering with syntax highlighting

### 🔒 Privacy & Security
- No telemetry or tracking
- API keys stored locally
- Security-scoped file access
- App Sandbox compliance
- Full control over your data

## Installation

### Requirements
- **iOS**: 17.0 or later
- **macOS**: 14.0 (Sonoma) or later
- Xcode 15.0 or later

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/kuroko.git
cd kuroko
```

2. Open in Xcode:
```bash
open kuroko.xcodeproj
```

3. Configure signing:
   - Select the `kuroko` target
   - Go to `Signing & Capabilities`
   - Select your development team

4. Build and run:
   - Select your target device/simulator
   - Press `Cmd + R`

### App Sandbox Configuration

For file system access to work, ensure the following is enabled:

**Signing & Capabilities → App Sandbox:**
- ✅ User Selected File: **Read/Write**

## Usage

### Initial Setup

1. **Configure API Keys**
   - Open Settings
   - Navigate to API Keys
   - Enter your Gemini or OpenRouter API key
   - Select your preferred provider

2. **Set Up File Access** (Optional)
   - Go to Settings → Files
   - Click "Select Folder"
   - Choose a working directory
   - Grant access when prompted

3. **Customize System Prompt** (Optional)
   - Settings → Instructions
   - Add custom instructions for the AI

### Basic Chat

Simply type your question and press send. The AI will respond with streaming text.

### Using Tools

**Search the web:**
```
What's the latest news about SwiftUI?
```

**File operations:**
```
What files are in my working directory?
Read the README.md file
Create a new file called notes.txt with "Hello World"
```

### Advanced Features

**Stop generation:**
- Click the stop button (🛑) while the AI is responding

**Retry failed messages:**
- Click the retry button (🔄) when an error occurs

**Switch themes:**
- Settings → Appearance → Select theme

## Architecture

Kuroko follows a clean, modular architecture:

```
kuroko/
├── Models/              # Data structures
│   ├── MessageModels.swift
│   ├── SessionModels.swift
│   ├── ToolModels.swift
│   └── FileSystemModels.swift
├── ViewModels/          # UI state management
│   └── KurokoViewModel.swift
├── Services/            # Business logic
│   ├── API/
│   │   ├── APIConfigurationService.swift
│   │   ├── GeminiService.swift
│   │   └── OpenRouterService.swift
│   ├── FileSystem/
│   │   ├── FileAccessManager.swift
│   │   └── FileSystemService.swift
│   ├── SearchService.swift
│   └── SessionManager.swift
├── Views/               # SwiftUI views
│   ├── Shared/
│   ├── iOS/
│   └── macOS/
├── Managers/
│   └── ThemeManager.swift
└── Extensions/
```

### Key Design Principles

- **Dependency Injection**: Services are injected for testability
- **Protocol-Oriented**: Interfaces defined for all services
- **Platform Agnostic**: Shared code with platform-specific UI
- **Observable Pattern**: SwiftUI's `@Observable` for state management

## API Providers

### Google Gemini

Get your API key: https://makersuite.google.com/app/apikey

**Supported Models:**
- gemini-2.0-flash-exp
- gemini-1.5-pro
- gemini-1.5-flash

### OpenRouter

Get your API key: https://openrouter.ai/keys

**Access to 100+ models including:**
- GPT-4, GPT-4 Turbo
- Claude 3 (Opus, Sonnet, Haiku)
- Llama 3, Mistral, and more

## Roadmap

- [ ] PDF file support
- [ ] Image analysis (Vision API)
- [ ] Voice input/output
- [ ] iCloud sync for sessions
- [ ] Custom tool creation
- [ ] Plugin system
- [ ] Shortcuts integration

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Markdown rendering by [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)
- Powered by [Google Gemini](https://deepmind.google/technologies/gemini/) and [OpenRouter](https://openrouter.ai/)

## Support

If you encounter any issues or have questions:
- Open an issue on GitHub
- Check existing issues for solutions

---

<div align="center">
Made with ❤️ using Swift and SwiftUI
</div>
