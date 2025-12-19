# プロジェクト固有ルール

## ビルド/テストの実行制約
- **ローカル環境では `swift build` 禁止**（ビルド時間が長いため）
- テスト実行はXcode経由または `swift test` を使用
- リリースビルドはCI/CDパイプラインでのみ実行

## 使用禁止ライブラリ・パターン
- **Combine禁止**: Swift Concurrency (async/await/Task) を使用する
- **RxSwift禁止**: Swift Concurrencyを使用する
- **UIKit/AppKitの古いパターン禁止**: SwiftUIを優先的に使用

## コーディング規約
- **Swift API Design Guidelines** に準拠する
- **命名規則**:
  - 型（Class/Struct/Enum）: PascalCase
  - 関数/変数/定数: camelCase
  - プロトコル: Protocol名は-able/-ing/-erで終わる
- **アクセス修飾子**: 必要最小限のアクセスレベルを使用（private/internal/public）
- **ドキュメント**: public APIには必ずドキュメントコメントを付ける

## アーキテクチャ方針
- **MVVMパターン必須**: View-ViewModel-Modelの分離を厳守
- **依存性注入**: サービスはプロトコル経由で注入する
- **SwiftUI Observation**: @Observableを使用し、@Publishedは使用しない
- **Repositoryパターン**: データアクセス層はRepositoryパターンで抽象化

## 非同期処理
- **async/await/Task必須**: コールバックベースの処理は禁止
- **MainActor**: UI更新は必ずMainActorで実行
- **構造化並行性**: Taskグループを使用した並行処理を推奨

## エラーハンドリング
- **throws/async throws**: エラーはthrowsで伝播させる
- **Result型**: コールバックベースの場合のみ使用
- **カスタムエラー**: ドメイン固有のエラー型を定義

## ファイル構造・組織化
- **ディレクトリ構造**: 機能別ではなく、役割別（Views/Models/Services）に整理
- **ファイル命名**: PascalCaseでファイル名を付ける
- **拡張子**: .swiftのみ使用

## デプロイメント制約
- **CI/CD経由のみ**: 本番デプロイは必ずCI/CDパイプラインを経由
- **コード署名**: 適切なコード署名を設定
- **Sandbox**: App Sandboxを有効化し、必要最小限の権限のみ付与

## セキュリティ
- **APIキー**: ハードコード禁止、Keychainまたは環境変数を使用
- **ファイルアクセス**: Sandbox内で動作し、ユーザー権限を尊重
- **ネットワーク**: HTTPSのみ使用、証明書ピン留めを検討

## パフォーマンス
- **メモリ管理**: 循環参照を避け、weak/strongキャプチャを適切に使用
- **UI更新**: 高頻度更新はCombineやTimerではなく、SwiftUIの状態管理を使用
- **画像/リソース**: 適切な圧縮とキャッシュを行う

## テスト
- **Unitテスト**: ビジネスロジックは必ずテストする
- **UIテスト**: SwiftUI ViewのテストはViewInspectorを使用
- **モック**: プロトコルベースの依存性注入により、テスト容易性を確保

## バージョン管理
- **コミットメッセージ**: 英語で記述、Conventional Commits形式を推奨
- **ブランチ戦略**: Git FlowまたはGitHub Flowを使用
- **PR**: レビュー必須、CI通過必須

## その他
- **Swiftバージョン**: iOS 26.0+ / macOS 26.0+ をターゲット
- **SwiftUI**: SwiftUIをメインUIフレームワークとして使用
- **ロギング**: print()の代わりにOSLogまたはカスタムロガー使用
