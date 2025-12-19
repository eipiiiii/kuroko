# Kuroko 🤖

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-26+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

Kurokoは、Clineの自律制御アーキテクチャをSwiftで実装したAIエージェントアプリケーションです。Actモードを採用し、LLMとの対話を通じて自律的にタスクを実行します。

![Kuroko Demo](./assets/demo.gif)

## ✨ 特徴

### 🚀 自律制御アーキテクチャ
Clineの自律制御アーキテクチャをベースにした高度な自律制御システムを実装。

- **Act Mode**: 実行段階
  - 計画されたタスクの実行
  - ファイル操作、コマンド実行、API呼び出し
  - ツールの使用が可能

### 🛠️ 豊富なツール統合
AIエージェントが自律的にタスクを実行するための包括的なツールセット。

#### ファイルシステムツール
- ファイル/ディレクトリの読み取り・書き込み・検索
- 正規表現によるコード検索
- ファイルアクセス権限管理

#### Web・検索ツール
- Google Custom Search API連携
- リアルタイムWeb情報取得

#### Apple統合ツール
- **Calendar**: イベントの作成・取得・管理
- **Reminders**: リマインダーの作成・取得・管理

### 💬 リアルタイムストリーミング
- AIの思考プロセスをリアルタイム表示
- インタラクティブな対話体験
- 日本語・英語対応

### 🔒 安全な承認システム
ツール実行時の承認レベルを柔軟に設定：

- **Always Ask**: 毎回承認を求める（デフォルト）
- **Per Thread**: スレッドごとに一度承認
- **Auto Approve**: 自動承認

## システムアーキテクチャ

### 主要コンポーネント

1. **AgentRunner**: 状態マシンによる自律制御のコア
2. **KurokoViewModel**: UI状態管理とビジネスロジック
3. **LLMサービス**: OpenRouter、AnthropicなどのAPI統合
4. **ツールシステム**: プラガブルなツールアーキテクチャ
5. **セッション管理**: 会話履歴の保存と管理

### Act モードの実装

```swift
enum OperationMode {
    case act
}
```

Actモードでは、LLMとの対話を通じてツールを実行し、自律的にタスクを遂行します。

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
- iOS 26+

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

## ⚙️ 設定

### API設定

#### OpenRouter API
1. [OpenRouter](https://openrouter.ai/)でアカウントを作成
2. APIキーを取得
3. アプリ設定 > API設定 > OpenRouter API Keyに設定
4. 利用可能なモデルを自動取得

#### Google Custom Search API
1. [Google Cloud Console](https://console.cloud.google.com/)でプロジェクト作成
2. Custom Search APIを有効化
3. APIキーを作成
4. [Custom Search Engine](https://cse.google.com/)で検索エンジン作成
5. 検索エンジンIDを取得
6. アプリ設定でAPIキー と 検索エンジンIDを設定

### モデル設定
- **デフォルトモデル**: GPT-4o Mini
- **対応プロバイダ**: OpenRouter, Anthropic
- **動的モデル取得**: APIキー設定後に利用可能なモデルを自動取得

### エージェント設定

#### 承認モード
- **Always Ask**: 毎回ツール使用前に承認を求める（安全重視）
- **Per Thread**: 会話スレッドごとに一度承認
- **Auto Approve**: 自動承認（上級者向け）

#### その他の設定
- **最大ツール呼び出し数**: 1回の実行で使用可能なツール数の上限
- **応答言語**: 日本語/英語
- **タイムゾーン**: システム日時の表示に使用
- **カスタムプロンプト**: AIの行動をカスタマイズ

### ツール設定
各ツールの有効/無効を個別に設定できます。デフォルトでは主要ツールが有効化されています。

## 🚀 使用方法

### 基本的な使い方

#### 1. 初期設定
- アプリを起動し、設定画面でAPIキーを設定
- OpenRouter APIキーが必須、Google Searchはオプション

#### 2. 会話の開始
- メイン画面下部の入力フィールドにタスクを入力
- 例: 「明日のスケジュールをチェックして、リマインダーを作成して」

#### 3. AIの応答を待つ
- AIがリアルタイムで思考プロセスを表示
- ツール使用が必要な場合、承認を求めるダイアログが表示

#### 4. 承認と実行
- ツール使用の承認/拒否を選択
- 承認された場合、AIが実際にタスクを実行

### 使用例

#### 📅 カレンダー管理
```
ユーザー: 「今日の会議をカレンダーに追加して」
AI: 現在のカレンダーを確認し、会議の詳細を確認
ツール: add_calendar_event (タイトル: "会議", 日時: 今日の適当な時間)
```

#### ✅ リマインダー作成
```
ユーザー: 「牛乳を買うリマインダーを作成して」
AI: リマインダーツールを使用して作成
ツール: add_reminder (タイトル: "牛乳を買う", 優先度: 中)
```

#### 🔍 情報検索
```
ユーザー: 「SwiftUIの最新バージョン情報を調べて」
AI: Google検索ツールを使用して情報を取得
ツール: Google Custom Searchで「SwiftUI latest version」を検索
```

#### 📁 ファイル操作
```
ユーザー: 「デスクトップのREADMEファイルを更新して」
AI: ファイル読み取り、内容確認、編集を実行
ツール: read_file, replace_in_file
```

### 高度な使用法

#### 複合タスク
```
「今週のスケジュールをチェックして、重要なタスクのリマインダーを作成し、関連ファイルを整理して」
```
- AIが複数のツールを組み合わせて実行
- カレンダー確認 → リマインダー作成 → ファイル整理

#### プログラミング支援
```
「新しいSwiftUIビューを作成して、ボタンのアクションを実装して」
```
- AIがコード生成、ファイル作成、編集を実行

### 承認モードの使い方

#### Always Ask（推奨）
- 初めて使用する場合に最適
- すべてのツール使用で確認
- 安全だが、操作が遅くなる

#### Per Thread
- 同じ会話内で複数回ツールを使用する場合
- スレッドごとに一度承認
- 効率的だが、注意が必要

#### Auto Approve
- 上級者向け
- すべてのツール使用を自動承認
- 危険な操作も実行される可能性あり

### セッション管理
- 会話履歴が自動保存
- 過去の会話を再開可能
- 設定はセッション間で保持

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
├── App/                    # アプリのエントリーポイント
│   └── kurokoApp.swift     # メインアプリ構造体
├── Models/                 # データモデル
│   ├── AgentModels.swift   # エージェント関連モデル
│   ├── FileSystemModels.swift  # ファイルシステム関連モデル
│   └── SessionModels.swift # セッションデータモデル
├── Services/               # ビジネスロジックと外部サービス連携
│   ├── API/                # APIサービス
│   │   └── OpenRouterAPIService.swift
│   ├── AgentMemoryService.swift  # エージェントメモリ管理
│   ├── AgentRunner.swift   # エージェント実行エンジン
│   ├── FileSystem/         # ファイルシステムサービス
│   │   └── FileAccessManager.swift
│   ├── KurokoConfigurationService.swift  # 設定管理
│   ├── LLM/                # LLM関連サービス
│   │   ├── Core/           # コアLLMインターフェース
│   │   │   ├── LLMModels.swift
│   │   │   ├── LLMProvider.swift
│   │   │   ├── LLMService.swift
│   │   │   └── UnsupportedLLMService.swift
│   │   ├── Factory/        # LLMサービスファクトリ
│   │   │   └── LLMServiceFactory.swift
│   │   └── Providers/      # 各プロバイダの実装
│   │       └── OpenRouterLLMService.swift
│   ├── ReflectionService.swift  # リフレクションサービス
│   ├── SearchService.swift  # 検索サービス
│   ├── SessionManager.swift # セッション管理
│   └── Tools/              # ツールシステム
│       ├── Core/           # ツール基盤
│       │   ├── DefaultToolExecutor.swift
│       │   ├── ToolErrors.swift
│       │   └── Tooling.swift
│       ├── Implementations/# 各ツールの実装
│       │   ├── Apple/      # Apple統合ツール
│       │   │   ├── AppleCalendarTool.swift
│       │   │   └── AppleRemindersTool.swift
│       │   ├── FileSystem/ # ファイルシステムツール
│       │   │   └── FileSystemTools.swift
│       │   └── Web/        # Web検索ツール
│       │       └── GoogleSearchTool.swift
│       └── Registry/       # ツールレジストリ
│           └── ToolRegistry.swift
├── ViewModels/             # UI状態管理
│   └── KurokoViewModel.swift  # メインViewModel
├── Views/                  # SwiftUIビュー
│   ├── FileAccessSettingsView.swift
│   ├── IOSContentView.swift
│   ├── SessionHistoryView.swift
│   ├── SettingsView.swift  # 設定ビュー
│   └── Shared/             # 共有ビューコンポーネント
│       ├── ActionButton.swift
│       ├── ChatView.swift
│       ├── InputArea.swift
│       └── MessageBubble.swift
├── Managers/               # マネージャークラス
│   └── ThemeManager.swift  # テーマ管理
├── Extensions/             # Swift拡張機能
│   ├── ColorExtensions.swift
│   └── ViewExtensions.swift
└── Assets.xcassets/        # アセットファイル

.agent/                     # エージェント作業管理ディレクトリ
├── task.md                 # 現在のタスクチェックリスト
├── implementation_plan.md  # 実装計画
├── rules.md                # プロジェクト固有ルール
└── walkthrough_YYYYMMDD_HHMM_feature-name.md  # 作業完了サマリ

kuroko.xcodeproj/           # Xcodeプロジェクトファイル
kurokoTests/                # ユニットテスト
kurokoUITests/              # UIテスト
```

### テスト
XCTestを使用したユニットテストとUIテストを実装しています。

#### ユニットテストの実行
```bash
# Xcodeでテストを実行
xcodebuild test -scheme kuroko -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'

# またはXcodeのProduct > Testメニューから実行
```

#### UIテストの実行
```bash
# XcodeでUIテストを実行
xcodebuild test -scheme kurokoUITests -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'

# またはXcodeのProduct > Testメニューから実行
```

#### テストカバレッジの確認
```bash
# テスト実行時にカバレッジを収集
xcodebuild test -scheme kuroko -enableCodeCoverage YES -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'
```

#### 継続的インテグレーション
GitHub Actionsを使用して自動テストを実行しています。プルリクエスト作成時にテストが自動実行されます。

## 🔧 トラブルシューティング

### よくある問題と解決法

#### API接続エラー
**症状**: 「APIキーが無効です」または接続エラー
```
解決法:
1. APIキーが正しく設定されているか確認
2. OpenRouterのクレジット残高を確認
3. ネットワーク接続を確認
4. APIキーを再生成して設定し直す
```

#### モデル取得エラー
**症状**: モデルリストが空または取得できない
```
解決法:
1. OpenRouter APIキーが正しいか確認
2. アプリを再起動
3. 設定 > API設定 > モデル取得ボタンを押す
```

#### ツール実行エラー
**症状**: ツールが実行できない、権限エラー
```
解決法:
1. ツールの権限設定を確認（設定 > ツール設定）
2. macOSのプライバシー設定でアプリの権限を確認
3. ファイルアクセスが必要な場合はデスクトップ等へのアクセス権限を付与
```

#### ストリーミングが遅い/停止する
**症状**: レスポンスが遅い、途中で止まる
```
解決法:
1. ネットワーク接続を確認
2. 別のモデルに切り替え（GPT-4o Miniなど軽量モデル）
3. アプリを再起動
```

#### カレンダー/リマインダーアクセスエラー
**症状**: Appleサービスとの連携ができない
```
解決法:
1. システム設定 > プライバシーとセキュリティ > カレンダー/リマインダー
2. Kurokoアプリにアクセス権限を付与
3. アプリを再起動
```

### ログの確認
デバッグ情報が必要な場合は、Xcodeのコンソールログを確認してください。

### サポート
問題が解決しない場合は、[GitHub Issues](https://github.com/eipiiiii/kuroko/issues)で報告してください。

## ライセンス

Apache License 2.0

## 貢献

IssueやPull Requestを歓迎します。開発に参加する場合は、まずIssueを作成して議論を始めましょう。

## 参考

このプロジェクトは、[Cline](https://github.com/cline/cline)の自律制御アーキテクチャをSwiftで再実装したものです。
