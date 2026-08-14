# 互換性・Vulkan・よくある失敗

## レンダラ（2024.1+）

Flame 2024.1 から Matchbox GLSL はロード時に **SPIR-V** へ変換され、Vulkan / Metal 上で動く。OpenGL 1.20/1.30 のまま書くクラシックシェーダは、変換レイヤがクリーンアップする。

影響:

- 短く衝突しやすい `#define`（例: `V`）が変換後に壊れることがある（2025.1 の `crok_vhs`）。プレフィックス付き名にする。
- `#version 120` が**本当に 120 として解釈**されるようになった。130 の関数を使っていると落ちる。2025.2 では `#version 120` を消すと直った例がある（LOGIK `y_*`）。
- このリポジトリのクラシックシェーダは **`#version` を書かない**。
- `shader_builder` と実行時コンパイラは一致しないことがある。両方で確認する。

## 2025.1 の厳格化

以前は警告で通った暗黙キャストなどがエラーになる。例: `vec4` を `vec2` UV に代入。

## GLSL でやってはいけないこと（クラシック）

Flame が描画グラフを組めず、ログに `PIPELINE: CProcessShader::RenderFrame::CreateRenderGraph` が出ることがある。

- **`main()` から早期 `return` しない**。`if/else` で色を決め、末尾で一度だけ `gl_FragColor` を書く。
- `const mat3` / `const vec3` の初期化は可能なら 1 行。
- グローバル `const` に短い名前（`ONE`, `V`）を使わない。
- 動的インデックスの配列（`float[N](...)` + ループ変数）は避ける。ループは有界 + 解析的、または `if/else` 展開。
- クラシックでは `texture()` / `in` / `out` / `layout` を使わない。
- `gl_FragCoord` のスペルを間違えない（`gl_Frag_Coord` はコンパイル失敗）。

## XML / builder

- Mac の `shader_builder` は「コンパイル失敗」だけ出し、行番号を出さないことが多い → Linux でビルド。
- モダン形式: uniform block は **1 行 1 メンバー**。コンマ並びは XML UI が空になる（2026.2）。
- `adsk_results_passN` に `Index` / `NoInput` を付けない。
- 複数パスの同一パラメータは `<Duplicate>`。付け忘れると UI が二重。
- `SupportsAdaptiveDegradation="True"` だけでは劣化しない。`adsk_degrade` 分岐が必要。
- 入力は最大 6。
- `InputType` と `InputColor` が両方あると `InputType` が勝つ。
- LOGIK Matchbook の XML 検証は builder より厳しいことがある。

## プラットフォーム

| | Linux | macOS |
|--|-------|--------|
| クラシック GLSL | 130 相当まで余裕 | 120 相当が安全 |
| builder のエラー | 行番号あり | 貧弱。XQuartz 必須 |
| 確認 | 必須 | 必須（Linux だけで ship しない） |

## ブラウザに出ない

1. Shader Paths / `shared/matchbox/shaders/` を確認。
2. Mode を Matchbox ↔ GLSL。
3. マルチパスはルート名で読む。バラバラの `.1.glsl` だけ置かない。
4. XML の `Name` がファイル名と大きく違うと迷う。`embr_` で揃える。

## 色・ブレンド

- 2025.1 で `LinearLight` の意味が変わった。旧 Photoshop 相当は `PsLinearLight` (32)。Flame 版は `LinearLight` (37)。
- シーンリニア想定の演算を log プロジェクトにそのまま掛けない。必要なら `adsk_log2scene` / `adsk_scene2log`。

## ライセンスとクレジット

- 公式 EXAMPLES は学習用。コピーして自作として出さない。
- LOGIK / crok / 個人シェーダを分解して学ぶのはコミュニティ推奨。再配布はライセンスとクレジット。
- Shadertoy 等は GLSL が新しいことが多く、クラシック Matchbox へは移植が必要。
- このリポジトリは MIT。派生元が NC なら `CommercialUsePermitted="False"` と README に例外を書く。
