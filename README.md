# Kuroko

Kurokoは、Clineの自律制御の仕組みをSwiftで実装したAIエージェントアプリです。Plan & Actモードをサポートし、LLMとの対話を通じてタスクを実行します。

## 特徴

### Plan & Act モード
Clineの自律制御アプローチを採用したPlan & Actモードを実装しています。

- **Plan Mode**: 計画段階
  - タスクの分析と理解
  - コードベースの探索
  - 実装戦略の立案
  - ツールの使用を制限

- **Act Mode**: 実行段階
  - 計画されたタスクの実行
  - ファイルの編集やコマンドの実行
  - ツールの使用が可能

### ツール統合
さまざまなツールを統合し、AIエージェントが自律的にタスクを実行できます。

- ファイルシステム操作 (読み取り、書き込み、検索)
- Web検索 (Google Custom Search)
- Apple Calendar/Reminders連携
- ターミナルコマンド実行

### ストリーミングレスポンス
リアルタイムでAIの思考プロセスを表示し、インタラクティブな対話を可能にします。

## システムアーキテクチャ

### 主要コンポーネント

1. **AgentRunner**: 状態マシンによる自律制御のコア
2. **KurokoViewModel**: UI状態管理とビジネスロジック
3. **LLMサービス**: OpenRouter、AnthropicなどのAPI統合
4. **ツールシステム**: プラガブルなツールアーキテクチャ
5. **セッション管理**: 会話履歴の保存と管理

### Plan & Act モードの実装

```swift
enum OperationMode {
    case plan
    case act
}
```

Planモードではツール実行が制限され、Actモードでのみ実際の変更が可能になります。

### 状態管理

```swift
enum AgentState {
    case idle
    case awaitingLLM
    case toolProposed(ToolCallProposal)
    case awaitingApproval(ToolCallProposal)
    case executingTool(ToolCallProposal)
    case completed
    case failed(String)
}
```

## インストール

### 必要条件
- Xcode 15+
- iOS 17+
- macOS 14+

### ビルド手順
1. リポジトリをクローン
```bash
git clone https://github.com/eipiiiii/kuroko.git
cd kuroko
```

2. Xcodeでプロジェクトを開く
```bash
open kuroko.xcodeproj
```

3. 依存関係を解決し、ビルド

## 設定

### API設定
- OpenRouter APIキーの設定
- Google Custom Search APIの設定
- モデル選択

### ツール設定
各ツールの有効/無効を個別に設定できます。

## 使用方法

### Plan & Act モードの切り替え
1. 設定画面から"Operation Mode"を選択
2. PlanモードとActモードを切り替え

### 対話の開始
1. テキストを入力
2. AIがPlanモードでタスクを分析
3. Actモードで実装を実行

## アーキテクチャの詳細

### AgentRunner
自律制御の中心となるクラス。状態マシンを実装し、LLMとの対話、ツール実行、承認プロセスを管理します。

### ツールシステム
プロトコルベースのプラガブルアーキテクチャ。新しいツールを簡単に追加できます。

```swift
protocol Tool {
    var name: String { get }
    var description: String { get }
    var parameters: [String: Any] { get }
    func execute(input: [String: Any]) async throws -> String
}
```

### LLM統合
複数のプロバイダをサポートし、統一されたインターフェースを提供します。

## 開発

### プロジェクト構造
```
kuroko/
├── Models/           # データモデル
├── Services/         # ビジネスロジック
├── ViewModels/       # UI状態管理
├── Views/           # SwiftUIビュー
└── Extensions/      # 拡張機能
```

### テスト
XCTestを使用したユニットテストとUIテストを実装しています。

## ライセンス

Apache License 2.0

## 貢献

IssueやPull Requestを歓迎します。開発に参加する場合は、まずIssueを作成して議論を始めましょう。

## 参考

このプロジェクトは、[Cline](https://github.com/cline/cline)の自律制御アーキテクチャをSwiftで再実装したものです。
