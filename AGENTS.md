# Kuroko - AI Agent Development Guide

> **For AI Coding Agents**: This document provides context, conventions, and workflows for contributing to Kuroko, a Swift-based autonomous AI agent application inspired by Cline's architecture.

## 🔄 This Document is Living Documentation

**AGENTS.md自体も改善対象です。** 以下の場合、このドキュメントの更新を検討してください:

### When to Update AGENTS.md

- 新しいアーキテクチャパターンが確立された時
- 頻繁に同じ質問が発生する時
- 開発プロセスが変更された時
- 新しいツール、コンポーネント、規約が追加された時
- トラブルシューティング情報が蓄積された時

### Update Process (CRITICAL)

**AGENTS.mdを変更する前に必須のステップ:**

1. **タスクドキュメントを作成**:
   ```
   .tasks/TASK-XXX-update-agents-md.md
   ```

2. **変更提案をユーザーに提示**:
   ```
   AGENTS.mdの以下のセクションを改良したいと考えています:

   【変更箇所】
   - セクション名: XXX

   【変更理由】
   - 理由1: ...
   - 理由2: ...

   【変更内容（diff形式）】
   ```diff
   - 旧: ...
   + 新: ...
   ```

   この変更を実施してよろしいですか？
   「はい」で承認、「いいえ」で却下、「修正して」で再提案をお願いします。
   ```

3. **ユーザー承認後に実施**:
   - 承認を得た場合のみ変更を適用
   - 変更内容をGitコミットメッセージに記録
   - タスクドキュメントに変更履歴を記載

4. **完了後の確認**:
   ```
   AGENTS.mdを更新しました。
   変更内容:
   - XXXセクションにYYYを追加
   - ZZZの説明を明確化

   .tasks/TASK-XXX-update-agents-md.mdを削除してよろしいですか？
   ```

### Self-Improvement Guidelines

AGENTS.mdを改善する際の原則:

- ✅ **具体的に**: 曖昧な表現を避け、実例を含める
- ✅ **簡潔に**: 冗長な説明を削除し、要点を明確に
- ✅ **構造的に**: セクションの論理的な順序を保つ
- ✅ **実践的に**: 実際の開発で使われる情報を優先
- ❌ **個人的意見を含めない**: 客観的な事実とベストプラクティスのみ
- ❌ **矛盾を作らない**: 既存の他のドキュメントとの整合性を保つ

### Version Control

AGENTS.mdの主要な変更履歴を記録:

| Version | Date | Changes | Approved By |
|---------|------|---------|-------------|
| 1.0.0 | 2025-12-19 | 初版作成 | User |
| 1.1.0 | 2025-12-19 | Living Documentationプロトコル追加 | User |

---

## Quick Reference

### Project Type
- **Language**: Swift 5.9+
- **Platforms**: iOS 17+, macOS 14+
- **Architecture**: MVVM + Protocol-Oriented
- **AI Framework**: Custom autonomous agent with tool-based execution

### Development Commands

\`\`\`bash
# Build
xcodebuild -scheme Kuroko -configuration Debug

# Run Tests
xcodebuild test -scheme KurokoTests

# Format Code
swiftformat . --swiftversion 5.9

# Lint
swiftlint lint --strict
\`\`\`

## Before Making Changes

**CRITICAL**: Before modifying any code, you MUST:

1. **Create a task document** in `.tasks/` directory:
   \`\`\`bash
   # Format: TASK-[NUMBER]-[short-description].md
   .tasks/TASK-XXX-feature-name.md
   \`\`\`

2. **Task document must include**:
   - **Goal**: What are you trying to achieve?
   - **Analysis**: Current code state and affected components
   - **Plan**: Step-by-step implementation approach
   - **Risks**: Potential breaking changes or edge cases
   - **Testing**: How will you verify the changes?
   - **Rollback**: How to undo if something goes wrong?

3. **Get user confirmation** before starting implementation

4. **After completion**, ask user:
   > "タスク[TASK-XXX]が完了しました。`.tasks/TASK-XXX-xxx.md`を削除してよろしいですか?"

## Architecture Overview

### Core State Machine

\`\`\`
Idle → AwaitingLLM → ToolProposed → ExecutingTool → AwaitingLLM
                   ↓                              ↓
                Completed ←―――――――――――――――― Failed
\`\`\`

### Key Components

| Component | Responsibility | File Location |
|-----------|---------------|---------------|
| AgentRunner | State machine & orchestration | `src/Agent/AgentRunner.swift` |
| ToolExecutor | Tool invocation & error handling | `src/Tools/ToolExecutor.swift` |
| LLMService | LLM provider abstraction | `src/LLM/LLMService.swift` |
| SessionManager | Conversation persistence | `src/Session/SessionManager.swift` |

## Coding Conventions

### Swift Style

- **Naming**: camelCase for variables, PascalCase for types
- **Access Control**: Explicit `private`, `internal`, `public`
- **Async/Await**: Prefer over completion handlers
- **Error Handling**: Use typed errors with `LocalizedError`

### Tool Development Pattern

\`\`\`swift
// ✅ CORRECT: Comprehensive tool with validation
struct MyTool: Tool {
    let name = "my_tool"
    let description = """
    明確なユースケース: XXXを実行する際に使用
    制約: YYYには対応していない
    """
    
    var parameters: [String: Any] {
        // JSON Schema形式
    }
    
    func execute(input: [String: Any]) async throws -> String {
        // 1. Validate input
        guard let param = input["key"] as? String else {
            throw ToolError.invalidParameters("key is required")
        }
        
        // 2. Execute with error handling
        do {
            let result = try await performOperation(param)
            return result
        } catch {
            throw ToolError.executionFailed(error.localizedDescription)
        }
    }
}
\`\`\`

### State Management

- **ViewModels**: `@MainActor` for UI-bound logic
- **ObservableObject**: Use `@Published` sparingly
- **Concurrency**: Avoid `Task.detached` unless explicitly needed

## Testing Requirements

### Coverage Targets

- **AgentRunner**: 85%+ state transition coverage
- **Tools**: 90%+ including edge cases
- **LLM Integration**: Mock-based testing

### Test Structure

\`\`\`swift
class MyToolTests: XCTestCase {
    // ✅ Test naming: test_[method]_[scenario]_[expectedResult]
    func test_execute_withValidInput_returnsSuccess() async throws {
        // Given
        let tool = MyTool()
        let input = ["key": "value"]
        
        // When
        let result = try await tool.execute(input: input)
        
        // Then
        XCTAssertEqual(result, "expected")
    }
    
    func test_execute_withInvalidInput_throwsError() async {
        // Edge case testing...
    }
}
\`\`\`

## Common Tasks

### Adding a New Tool

1. Create task doc: `.tasks/TASK-XXX-add-YYY-tool.md`
2. Implement `Tool` protocol in `src/Tools/YYYTool.swift`
3. Register in `ToolRegistry.registerDefaultTools()`
4. Add tests in `Tests/Tools/YYYToolTests.swift`
5. Update this AGENTS.md under "Available Tools"

### Modifying State Machine

⚠️ **High Risk**: Requires comprehensive testing

1. Create detailed task doc with state transition diagram
2. Update `AgentState` enum if needed
3. Modify transition logic in `AgentRunner`
4. Add state-specific tests
5. Verify all existing tests pass

## Pull Request Guidelines

### Checklist

- [ ] Task document created and reviewed
- [ ] Code follows Swift style guide
- [ ] Tests added/updated (coverage maintained)
- [ ] No compiler warnings
- [ ] SwiftLint passes
- [ ] Task document deleted after merge (with user permission)

### Commit Message Format

\`\`\`
[TASK-XXX] Brief description

- Detailed change 1
- Detailed change 2

Refs: #issue_number
\`\`\`

## Security & Privacy

- **API Keys**: Use Keychain, never hardcode
- **File Access**: Request permissions before operations
- **User Data**: All conversations stored locally (Privacy-first)

## Performance Benchmarks

| Operation | Target | Measurement |
|-----------|--------|-------------|
| Tool execution start | < 100ms | From approval to first execution |
| LLM first token | < 2s | Streaming response initiation |
| UI update | < 16ms | Main thread processing |

## Project-Specific Context

### Why Act-Only Mode?

Kuroko focuses on autonomous execution (Act mode) without explicit planning phase. This differs from Cline's Plan & Act separation. Rationale:
- Simpler state management
- Faster iteration for short tasks
- LLM handles implicit planning through system prompt

### System Prompt Philosophy

Fixed system prompt enforces:
1. **Completeness**: Gather all info before acting
2. **Efficiency**: Minimize user friction
3. **Safety**: Prefer non-destructive operations
4. **Transparency**: Explain decisions

Do not modify without consulting project maintainer.

## Troubleshooting

### Tool not being selected by LLM
**Cause**: Unclear description or parameter schema
**Fix**: Add concrete examples to `description`, simplify parameters

### State machine stuck in AwaitingApproval
**Cause**: UI not calling `approveToolCall()`
**Fix**: Check `KurokoViewModel.approveCurrentTool()` connection

### Memory leak in streaming
**Cause**: Strong reference cycle in async closures
**Fix**: Use `[weak self]` in LLMService callbacks

## Resources

- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [MVVM in SwiftUI Best Practices](https://developer.apple.com/tutorials/swiftui)
- [LangGraph State Machine Patterns](https://langchain-ai.github.io/langgraph/) (conceptual reference)

---

**Last Updated**: 2025-12-19
**Maintained by**: Project contributors
**Questions?**: Open an issue with `[AGENTS.md]` prefix
