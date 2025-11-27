# MetalShaderMuseum 用 AI ガイド (AGENTS)

このドキュメントは、MetalShaderMuseum フォルダ以下の機能を AI に改良・拡張してもらうためのプロンプトテンプレート、構造の説明、改良方針、シェーダー追加・改良の標準手順、パフォーマンス要件、チェックリストをまとめたものです。AI に渡す際は、テンプレートの {波括弧} 部分をプロジェクトの実態に合わせて埋めてください。

## プロジェクト構造（前提）
- ルート: `SwiftUIShaderStudy/MetalShaderMuseum/`
- SwiftUIShaderStudy/MetalShaders/は過去の参考ソース。修正等を行わないこと。

- 主な構成:
  - `Shaders/` … 各シェーダーごとにディレクトリ（例: `shader04/`, `shader05/`）
    - 各ディレクトリ内に `.metal` ファイルと対応する Swift ラッパークラス（`public final class ShaderXX: MSMDrawable`）を配置
  - `Renderer/` … `MSMRenderer` などレンダリング/パイプライン管理
  - `Views/` … SwiftUI の UI（例: `MetalSharderMuseumSetting.swift`）
  - `Protocols/` … `MSMDrawable`, `MSMConfigurableShader` 等のプロトコル・共通型
- UI 連携:
  - `MetalShaderMuseum` の View からシェーダー選択ができる
  - 設定画面は `MSMConfigurableShader` 適合時に `settingsView()` を表示
  - `renderer.resetInteraction()` によりカメラ/操作系のリセットが可能

## 改良方針テンプレート
AI に渡す基本テンプレートです。必要に応じて詳細化してください。

---
以下の要件で MetalShaderMuseum フォルダ以下の機能を改良・拡張してください。

- 目的: {具体的な目的（例: 新しい ray marching の形状融合、操作反映の統一、UI 設定の拡充、パフォーマンス改善）}
- 変更対象フォルダ: `SwiftUIShaderStudy/MetalShaderMuseum/`
- 追加/変更の概要:
  - 新規シェーダー: `{shader名}` を `Shaders/{shaderDir}/` に追加
  - 既存シェーダー `{既存名}` の改良（ロジック/最適化/操作系適用）
  - 設定 UI の追加（`MSMConfigurableShader` 適合と `settingsView()` 実装）
  - `MetalShaderMuseum` のシェーダー選択 UI に新規項目を追加
- インタラクション:
  - 上位から渡される PAN/PINCH/回転（ズーム/回転/移動）を `{対象シェーダー}` に適用
  - 参考: `@fragment_primitives_smin.metal#L56-70` の `fragment_primitives_smin` の適用方法に準拠
- レンダリング要件:
  - 描画内容: {例: 平面上で球・立方体・多面体が近づき、融合（smin/smax/smooth union）し、離れるアニメーション}
  - 時間パラメータ `{time}` による周期的変化
  - カメラ/視点操作が反映されること
- パフォーマンス要件:
  - モバイルでも 60fps を目標、落ち込み時は 30fps を下回らない
  - 分岐削減、距離関数の安定化、最大ステップ/最大距離/ヒット閾値の明示
  - メモリアロケーションの最小化、Metal のリソース再利用
- 命名/配置/ビルド:
  - `.metal` ファイル名: `{shaderXX}.metal`
  - Swift ラッパー: `public final class {ShaderXX}: MSMDrawable`
  - フォルダ: `Shaders/{shaderXX}/`
  - `private struct ShaderOption: Identifiable` に `{ShaderXX}` を追加し、選択可能にする
- 出力形式:
  - 変更ファイル一覧
  - 追加ファイルの完全コード
  - 既存ファイルの差分（パッチ形式または挿入箇所を明示）
  - ビルド手順/注意点
  - 動作確認手順（UI からの選択、設定画面、パン/ピンチ/回転の確認）
  - パフォーマンス計測の観点
---

## 実装詳細（期待する具体項目）
1) シェーダー追加
- `Shaders/{shaderXX}/{shaderXX}.metal` を作成
- `public final class {ShaderXX}: MSMDrawable` を追加（`.metal` とパイプライン紐付け）
- `ShaderOption` に `{ShaderXX}` を追加し、UI で選択可能に

2) Ray Marching の内容
- 距離関数: 球/キューブ/多面体（例: dodecahedron or octahedron）の SDF
- 融合: smooth min（smin）で形状をブレンド（`fragment_primitives_smin` に準拠）
- アニメーション: `{time}` に応じてオブジェクト位置/スケールを変化
- マテリアル/ライティング: 法線は SDF 勾配から、簡易的な Lambert + AO も可
- 地面: 無限平面 or 限定平面

3) インタラクションの適用
- PAN → 位置移動または視点の平行移動
- PINCH → ズーム（FOV or 距離）
- 回転 → カメラの回転（オービット）またはシーン回転
- 既存の `fragment_primitives_smin` と同じ uniform/定数バッファ構造を踏襲

4) 設定 UI（任意/可能なら）
- `MSMConfigurableShader` に準拠し、`settingsView()` で以下を編集可能に:
  - 融合強度（k）
  - 最大ステップ数
  - ヒット閾値（epsilon）
  - 最大距離
  - 形状の有効/無効

5) パフォーマンス
- ループ上限と早期打ち切り
- 距離関数のブランチを減らし、min/max のみで表現
- フレームあたりの計算負荷が高い場合、LOD/簡易化モードを導入
- メタル側で一定のリソース再利用（パイプライン、バッファ）

6) 変更点の反映
- `MetalShaderMuseum` の View 側に選択肢と `settingsView()`（当該シェーダーのみ）を反映
- `renderer.resetInteraction()` で初期視点に戻ることを確認

