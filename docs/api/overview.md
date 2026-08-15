# Overview

Matchbox と Lightbox は、Autodesk Flame / Flare / Flame Assist で **GLSL フラグメントシェーダ**を実行してカスタムエフェクトを作る仕組み。Sparks は非推奨。拡張の主経路は Matchbox と OFX。

## Matchbox vs Lightbox

| | Matchbox | Lightbox |
|--|----------|----------|
| 用途 | Batch / BFX / Timeline / Tools / Modular Keyer / Action（テクスチャ前処理・Camera FX） | Action のライティングループに差し込む色・ライティング効果 |
| エントリ | `void main()` → `gl_FragColor`（クラシック） | `vec4 adskUID_lightbox(vec4 source)` |
| パス数 | 複数可（`Name.1.glsl`, `Name.2.glsl`, …） | 常に 1 |
| 入力 | `sampler2D` を最大 **6**（7 本目以降は無視） | Action パイプラインのフラグメント（ライトにペアレント） |
| パッケージ | `.mx` | `.lx` |
| グローバル記号 | 通常の uniform 名 | すべて `adskUID_` 接頭辞（名前衝突防止） |

Flame では両方使える。Flare は Lightbox と Action 内 Matchbox あり。Flame Assist は Lightbox / Action Matchbox なし（BFX・Timeline・MK の Matchbox は可）。

## 最小構成

1. **`.glsl`** — 必須。これだけでも Flame は粗い UI を生成する。
2. **`.xml`** — sidecar。`shader_builder -x` で生成し、UI・入力ソケット・用途ヒントを編集する。
3. **プロキシ** — GLSL は sidecar `.p`（`flame_proxy_icon`、PNG 解像度のまま）。`.mx` のサムネイルは Linux の `shader_builder`。詳細は [packaging.md](packaging.md)。
4. **プリセット** — 任意。`<name>.preset.xml`。

マルチパスでは `Name.1.glsl` + `Name.2.glsl` + 単一の `Name.xml`。ブラウザではルートの `Name.glsl`（またはパッケージ）を選ぶ。

## 作成ワークフロー

1. `.glsl` を書く（uniform と使用する API を**前方宣言**する）。
2. `shader_builder -m -x shader.glsl` でコンパイル検証と XML 生成。
3. エラーを直し、再実行。2025.1 以降は警告だったものがエラーになることがある。
4. XML を編集（DisplayName、Row/Col/Page、InputType、Default、Tooltip）。
5. Flame の Shader Paths または `/opt/Autodesk/shared/matchbox/shaders/` に置いて読み込む。
6. 必要なら `.mx` を作る。シングルパスは `shader_builder -m -p shader.glsl`。マルチパスは `shader_builder -m -p shader.*.glsl`（全パス。詳細は [packaging.md](packaging.md)）。

## GLSL バージョン

| 環境 | クラシック（推奨既定） | モダン（2025.1+、明示時のみ） |
|------|------------------------|--------------------------------|
| Linux Matchbox | 実質 GLSL 130。互換のため 120 相当で書く | `#version 430` / `440` / `450` / `460` |
| macOS Matchbox | **GLSL 120**（Action は OpenGL core profile 非準拠） | 同上（Vulkan/Metal 経由） |
| Lightbox | 120/130。グローバルは `adskUID_` | **460 のみ**（複数 Lightbox を結合するため）。旧 130 以下とは混在可 |

クラシックでは `#version 120` を付けるコミュニティ慣例があるが、Flame 2025.2 以降は `#version` が厳格に解釈され、130 機能を使っていると壊れる。**このリポジトリの既定は `#version` 行を書かない**（エンジン側の互換変換に任せる）。モダン形式では各 `.glsl` 先頭に `#version` が必須。

Flame 2024.1 以降、ロード時に GLSL を SPIR-V（Vulkan / Metal）向けに変換・クリーンアップする。詳細は [gotchas.md](gotchas.md)。

## 前方宣言

Matchbox / Lightbox とも、使う uniform と `adsk_*` API はファイル前方で宣言する。`shader_builder` が警告・エラーの行番号を正しく出すため。
