# Kurokoプロジェクト アーキテクチャ概要

## プロジェクト概要

Kurokoは、AIエージェントを活用したSwiftUIベースのチャットアプリケーションです。ClineスタイルのPlan-Actアーキテクチャを実装し、ユーザーのクエリに対して自律的にツールを実行してタスクを達成します。

## アーキテクチャ原則

### 1. **Separation of Concerns (関心の分離)**
- **UI Layer**: ユーザーインターフェースとプレゼンテーションロジック
- **Business Logic Layer**: エージェント実行とツール管理
- **Data Layer**: データ構造と永続化

### 2. **Dependency Inversion (依存性逆転)**
- Protocolベースの設計により、高レベルモジュールが低レベルモジュールに依存しない
- 依存性注入により、テスト容易性とモジュール化を実現

### 3. **Single Responsibility (単一責任の原則)**
- 各クラスは一つの責任のみを負う
- AgentRunner: エージェント状態管理
- KurokoViewModel: UI状態管理
- 各Service: 特定の機能提供

## 主要アーキテクチャパターン

### MVVM (Model-View-ViewModel)

```
View (SwiftUI) ←→ ViewModel (Observable) ←→ Services/Models
```

- **View**: SwiftUIコンポーネント、UI描画とユーザー操作の処理
- **ViewModel**: UI状態管理、ビジネスロジックとの連携
- **Model**: データ構造、ビジネスルール

#### KurokoにおけるMVVM実装
- `KurokoViewModel`: メインのViewModel、チャット状態とエージェント制御
- `@Observable`: Swift 5.9+の新しいObservationフレームワークを使用
- 双方向データバインディング: ViewとViewModel間の自動同期

### Plan-Act Architecture

```
User Request → Planning Phase → Plan Approval → Execution Phase → Reflection
```

#### Planning Phase
1. **Task Analysis**: ユーザー要求の分析
2. **Plan Generation**: LLMを使用した実行計画の作成
3. **Risk Assessment**: 計画のリスク評価

#### Execution Phase
1. **Step-by-Step Execution**: 計画に基づく順次実行
2. **Tool Invocation**: 必要に応じたツール実行
3. **State Management**: 実行状態の追跡

#### Reflection Phase
1. **Execution Review**: 実行結果の分析
2. **Learning**: 次回実行のための知見蓄積

### State Machine Pattern

AgentRunnerは複雑なエージェント状態遷移を管理：

```
idle → planning → awaitingPlanApproval → executingPlan → awaitingLLM → toolProposed → awaitingApproval → executingTool → reflecting → completed
```

## コンポーネント詳細

### 1. UI Layer

#### Views
- **ChatView**: メインのチャットインターフェース
- **MessageBubble**: 個別のメッセージ表示
- **InputArea**: ユーザー入力とコントロール
- **ToolResultView**: ツール実行結果の表示

#### ViewModels
- **KurokoViewModel**: チャット状態管理とエージェント制御
  - メッセージ履歴管理
  - エージェント状態監視
  - ユーザー操作の処理

### 2. Agent Core

#### AgentRunner
エージェント実行の中心コントローラー：

```swift
class AgentRunner {
    private var state: AgentState = .idle
    private let llmService: LLMService
    private let toolExecutor: ToolExecutor
    // ... 状態遷移と実行制御
}
```

**責務**:
- エージェント状態管理
- LLMとの通信
- ツール実行のオーケストレーション
- タスク計画と実行

#### AgentState
エージェントの状態を表現する列挙型：

```swift
enum AgentState {
    case idle
    case planning(TaskPlan?)
    case awaitingPlanApproval(TaskPlan)
    case executingPlan(TaskPlan, currentStep: Int)
    case awaitingLLM
    case toolProposed(ToolCallProposal)
    case awaitingApproval(ToolCallProposal)
    case executingTool(ToolCallProposal)
    case reflecting(ExecutionResult)
    case completed
    case failed(String)
}
```

### 3. Service Layer

#### LLM Services
言語モデルとの通信を抽象化：

**LLMService Protocol**:
```swift
protocol LLMService {
    var provider: LLMProvider { get }
    func sendMessage(message: String, history: [ChatMessage], config: LLMConfig, onChunk: @escaping (String) -> Void, onToolCall: @escaping (ToolCall) -> Void) async throws
}
```

**実装クラス**:
- `OpenRouterLLMService`: OpenRouter APIを使用
- `UnsupportedLLMService`: フォールバック実装

#### Tool Services
外部ツールの実行を管理：

**Tool Protocol**:
```swift
protocol Tool {
    var name: String { get }
    var description: String { get }
    var parameters: [String: Any] { get }
    var isEnabled: Bool { get set }
    var autoApproval: Bool { get set }
    func execute(arguments: [String: Any]) async throws -> String
}
```

**実装ツール**:
- `FileSystemTools`: ファイル操作
- `AppleCalendarTool`: カレンダー操作
- `AppleRemindersTool`: リマインダー操作
- `GoogleSearchTool`: ウェブ検索

#### Configuration Services
アプリケーション設定の管理：

- **KurokoConfigurationService**: シングルトン設定管理
- **AgentConfig**: エージェント実行設定
- **LLMConfig**: 言語モデル設定

#### Session Management
チャットセッションの永続化：

- **SessionManager**: セッションCRUD操作
- **ChatSession**: セッションデータ構造
- **SessionMessage**: 永続化可能なメッセージ形式

### 4. Data Layer

#### Models
データ構造とDTOs：

- **AgentModels**: エージェント関連データ構造
- **SessionModels**: セッション関連データ構造
- **FileSystemModels**: ファイルシステム関連データ構造

#### Key Data Structures

**ChatMessage**:
```swift
struct ChatMessage {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date
    let isStreaming: Bool
    let toolCallId: String?
}
```

**ToolCallProposal**:
```swift
struct ToolCallProposal {
    let type: String
    let toolId: String
    let requiresApproval: Bool
    let input: [String: Any]
    let reason: String
    let nextStepAfterTool: String
}
```

## データフロー

### 通常の対話フロー

1. **User Input** → `ChatView` → `KurokoViewModel.sendMessage()`
2. **Agent Initialization** → `AgentRunner.startWithHistory()`
3. **LLM Communication** → `LLMService.sendMessage()`
4. **Response Processing** → `AgentRunner.callLLM()` → UI更新
5. **Tool Execution** (必要な場合) → `ToolExecutor.executeToolCall()`
6. **Result Integration** → LLMに結果を返却
7. **Final Response** → UI更新

### ツール実行フロー

1. **LLM Response** → Tool Call検出 → `ToolCallProposal`作成
2. **Approval Check** → 自動承認 or ユーザー承認待ち
3. **Tool Execution** → `Tool.execute()` → 結果取得
4. **Result Integration** → 結果をLLMに返却
5. **Continue Processing** → 次のLLM呼び出し

## 設計上の決定とトレードオフ

### Protocol-Oriented Design
**利点**:
- テスト容易性の向上（Protocol Mocking）
- 実装の柔軟性（複数のProvider対応）
- Swiftの特性を活かした設計

**トレードオフ**:
- Protocol定義の複雑さ増加
- 実装クラスでのボイラープレートコード

### Observable ViewModel
**利点**:
- Swift 5.9+の新しいAPI使用
- 明示的なPublishedプロパティ不要
- パフォーマンスの向上

**トレードオフ**:
- iOS 17+ / macOS 14+ 必須
- 既存コードの移行コスト

### State Machine for Agent Control
**利点**:
- 複雑な状態遷移の明確化
- エラー状態の適切な処理
- デバッグの容易さ

**トレードオフ**:
- 状態数の増加による複雑さ
- 状態遷移ロジックのテスト難易度

## セキュリティ考慮事項

### API Key Management
- LLM APIキーの安全な保存
- 設定ファイルからの読み込み
- 環境変数での管理

### Tool Execution Safety
- ファイルシステムアクセス権限の確認
- 外部API呼び出しの検証
- ユーザー承認制の導入

### Data Persistence
- チャット履歴の暗号化保存
- 機密情報の適切な処理
- セッション管理の安全性

## パフォーマンス最適化

### UI Responsiveness
- 非同期処理の適切な使用
- ストリーミング応答の実装
- バックグラウンド処理の活用

### Memory Management
- 大規模データの適切な処理
- 不要オブジェクトの解放
- メモリリークの防止

### Network Efficiency
- API呼び出しの最適化
- キャッシュ戦略の導入
- エラーハンドリングの強化

## テスト戦略

### Unit Tests
- 各Serviceクラスの単体テスト
- Protocol Mockingを使用した依存関係のテスト
- ViewModelのロジックテスト

### Integration Tests
- エンドポイント間の連携テスト
- LLM APIとの統合テスト
- データ永続化テスト

### UI Tests
- SwiftUI Viewのテスト
- ユーザー操作のテスト
- エッジケースの検証

## 拡張性と保守性

### Plugin Architecture
- Tool Protocolによる新しいツールの容易な追加
- LLM Providerの柔軟な切り替え
- 設定のカスタマイズ性

### Code Organization
- 明確なディレクトリ構造
- Protocolベースの依存関係
- 単一責任の原則の遵守

### Documentation
- 包括的なUML図の提供
- インラインコードドキュメント
- アーキテクチャ決定の記録

## まとめ

Kurokoプロジェクトは、現代的なSwift開発のベストプラクティスを活用し、複雑なAIエージェントシステムを構築しています。MVVMアーキテクチャ、Protocol-Oriented Programming、State Machine Patternなどのパターンを組み合わせ、保守性が高く拡張性のあるシステムを実現しています。

このアーキテクチャは、AIエージェントアプリケーションの開発における優れた基盤を提供し、今後の機能拡張と保守に適した設計となっています。
