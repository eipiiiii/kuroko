# Kurokoプロジェクト アーキテクチャドキュメント

## 概要

このドキュメントは、Kurokoプロジェクトの完全なアーキテクチャ構造をUML図で可視化したものです。Kurokoは、AIエージェントを活用したSwiftUIベースのチャットアプリケーションです。

## ドキュメント一覧

### 動作フロー可視化ドキュメント
- **[user-input-to-output-flow.md](user-input-to-output-flow.md)**: ユーザー入力から出力までの完全な動作フロー説明
- **[processing-sequence-diagram.puml](processing-sequence-diagram.puml)**: PlantUMLシーケンス図 - コンポーネント間の処理シーケンス
- **[data-flow-diagram.puml](data-flow-diagram.puml)**: データフロー図 - システム内のデータ受け渡し
- **[component-interaction-flow.puml](component-interaction-flow.puml)**: コンポーネント相互作用図 - 各コンポーネントの依存関係

### ファイル依存関係ビュー
- **[file-dependencies.puml](file-dependencies.puml)**: ファイル依存関係図 - ファイル間の直接的な依存関係と使用関係

### 説明ドキュメント
- **[architecture-overview.md](architecture-overview.md)**: アーキテクチャの詳細な概要説明

## アーキテクチャ概要

Kurokoプロジェクトは、以下のアーキテクチャパターンに基づいて構築されています：

### 主要コンポーネント

#### 1. **UI Layer (Presentation Layer)**
- **Views**: SwiftUIベースのユーザーインターフェース
- **ViewModels**: MVVMパターンの実装、UI状態管理

#### 2. **Agent Core (Business Logic Layer)**
- **AgentRunner**: エージェント実行の中心的なコントローラー
- **AgentState**: エージェントの状態管理
- **Task Planning**: 複雑なタスクの計画と実行

#### 3. **Service Layer**
- **LLM Services**: 言語モデルとの通信（OpenRouter APIなど）
- **Tool Services**: 外部ツールの実行（ファイル操作、カレンダー、検索など）
- **Configuration Services**: 設定管理
- **Session Management**: チャットセッションの永続化

#### 4. **Data Layer**
- **Models**: データ構造とDTOs
- **File System**: ファイル操作とアクセス管理

### アーキテクチャパターン

#### MVVM (Model-View-ViewModel)
UIロジックとビジネスロジックを分離し、テスト容易性と保守性を向上。

#### Dependency Injection
サービス間の疎結合を実現し、テストとモジュール化を容易に。

#### State Machine Pattern
AgentRunnerが複雑なエージェント状態遷移を管理。

#### Protocol-Oriented Programming
Swiftの特性を活かしたインターフェースベースの設計。

## 図の見方と利用ガイド

### 動作フロー可視化ドキュメント
- **目的**: ユーザー入力から最終出力までの完全な処理フローの理解
- **特徴**: エンドツーエンドの処理シーケンスとデータフローの可視化
- **包含内容**:
  - **user-input-to-output-flow.md**: 詳細な処理フロー説明と状態遷移
  - **processing-sequence-diagram.puml**: PlantUMLシーケンス図（全処理シーケンス）
  - **data-flow-diagram.puml**: データフロー図（コンポーネント間データ受け渡し）
  - **component-interaction-flow.puml**: コンポーネント相互作用図（依存関係）
- **利用**: 新規開発時の処理理解、エラー解析、デバッグ支援

### File Dependencies (ファイル依存関係図)
- **目的**: ファイル間の直接的な依存関係と使用関係の把握
- **特徴**: 各ファイルがどのファイルをどのように使用しているかを可視化
- **関係種類**: import, 継承, コンポジション, 使用の4種類を色分け
- **利用**: リファクタリング時の影響範囲評価、依存関係の最適化
- **包含ファイル**: 32ファイルの完全な依存関係マップ

### 図の表記規則

#### 関係線の意味
- **実線**: 継承またはコンポジション（強い関連）
- **点線**: 依存関係（弱い関連）
- **矢印**: 関連の方向と依存の流れ

#### 色分け基準
- **LightBlue**: Presentation Layer (UI層)
- **LightGreen**: Business Logic Layer (業務ロジック層)
- **LightYellow**: Data Layer (データ層)
- **Red**: 外部依存関係

## 使用方法

### PlantUMLでの閲覧
1. PlantUMLをサポートするエディタ（VS Code + PlantUML拡張など）を使用
2. `file-dependencies.puml`ファイルを開いて図を確認

### 画像生成
```bash
# PlantUML CLIを使用してPNG画像を生成
plantuml file-dependencies.puml
```

### オンラインviewer
- [PlantUML Web Server](https://www.plantuml.com/plantuml/uml/)を使用してオンラインで閲覧可能

## 対象範囲

このドキュメントでは、以下の範囲を対象としています：
- ✅ `kuroko/`ディレクトリ配下の全ファイル
- ✅ SwiftUIベースのUIコンポーネント
- ✅ AIエージェント関連のビジネスロジック
- ✅ 外部API連携（LLM、ツール実行）
- ✅ データ永続化とセッション管理

除外範囲：
- ❌ テストコード
- ❌ 外部ライブラリの内部構造
- ❌ iOS/macOSフレームワークの詳細
- ❌ `参考用/`ディレクトリの内容

## 更新履歴

- **2025-12-22**: 動作フロー可視化ドキュメント追加
  - ユーザー入力から出力までの完全な動作フロー可視化
  - PlantUMLシーケンス図、データフロー図、コンポーネント相互作用図の作成
  - 詳細な処理フロー説明ドキュメントの作成
  - README.mdの更新と統合

- **2025-12-22**: 初回作成
  - ファイル依存関係図の作成（32ファイルの完全マップ）
  - kuroko/ディレクトリ配下の完全分析
  - アーキテクチャ概要ドキュメントの作成

## 連絡先

このドキュメントに関する質問や改善提案は、プロジェクトのIssueまたはPull Requestでお願いします。

---

*このドキュメントはKurokoプロジェクトの理解を助けるためのものであり、実際のコード実装とは一部異なる場合があります。最新の情報はソースコードを参照してください。*
