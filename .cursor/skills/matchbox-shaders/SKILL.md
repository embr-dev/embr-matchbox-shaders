---
name: matchbox-shaders
description: >-
  Creates and edits Autodesk Flame Matchbox (and Lightbox) shaders: GLSL
  fragment code, sidecar XML UI, shader_builder workflow, adsk_ API, multi-pass,
  Selective FX, Action Camera FX, and LOGIK packaging. Use when the user asks
  to make a Matchbox, Lightbox, .glsl/.xml shader, Flame custom effect, or
  mentions shader_builder, logik-matchbook, crok, or adsk_ uniforms.
---

# Matchbox shaders

Flame 用 Matchbox をこのリポジトリで作る。実装前に API docs を読む。未記載の XML 属性や `adsk_*` を勝手に足さない。

## 必読

1. [docs/api/README.md](../../../docs/api/README.md) — 索引とリポジトリ既定
2. 状況に応じて同じディレクトリの参照ファイル（GLSL / XML / API / マルチパス / パッケージ / gotchas）

Lightbox を頼まれたときだけ [lightbox.md](../../../docs/api/lightbox.md)。

## このリポジトリの既定

- 置き場: `shaders/<name>/`
- 名前: `embr_snake_case`（ファイル名、GLSL ベース名、XML `Name` を一致）
- シングルパス: `embr_foo.glsl` + `embr_foo.xml`
- マルチパス: `embr_foo.1.glsl`, `embr_foo.2.glsl`, … + 一つの `embr_foo.xml`
- クラシック GLSL（`texture2D`, `gl_FragColor`）。`#version` 行は書かない
- `#version 430` uniform block はユーザーが Flame 2025.1+ 専用と明示したときだけ
- MIT。`CommercialUsePermitted="True"`（派生元が NC なら False と README に例外）
- DisplayName / Description は英語（Flame / LOGIK 慣例）。必要なら Description に日本語を併記
- 入力最大 6。`LimitInputsToTexture="True"`
- ソースをコミットする。`.mx` は任意の配布物でありソースの代替にしない。マルチパスの `-p` は `Name.*.glsl`（全パス）。`.1.glsl` だけだと後続が入らない
- GLSL のサムネイルは sidecar `.p`（`flame_proxy_icon`、PNG 解像度のまま）。`.mx` のサムネイルは **Linux** の `shader_builder -m -p`。Mac からは `tools/pack_mx_linux.sh user@host shaders/<name>`

## 作業手順

1. 効果・入力（Front/Back/Matte/Selective）・パス数・Action/Timeline 可否を決める
2. GLSL を書く。uniform と使う `adsk_*` を前方宣言。`main()` 末尾で一度だけ `gl_FragColor`
3. XML を手で書くか、ユーザー環境に `shader_builder` があれば `shader_builder -m -x` で生成して編集
4. [gotchas.md](../../../docs/api/gotchas.md) の禁止事項を確認
5. サムネイルは `flame_proxy_icon --from-png`（PNG 解像度のまま）。`.mx` を出すなら Linux でパッケージ（[packaging.md](../../../docs/api/packaging.md)）
6. `shaders/<name>/README.md` に何をするシェーダか、入力、主なパラメータを短く書く

## GLSL チェック

- UV は `gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h)`
- 早期 `return` 禁止。短い `#define` / グローバル名（`V`, `ONE`）禁止
- `adsk_` は UI に出ない
- マルチパスの後続は `adsk_results_pass1` など（1 始まり）

## XML チェック

- `ShaderType="Matchbox"`。用途ヒント: `SupportsAction` / `SupportsTimeline` / `SupportsTransition`
- ソケットは `InputType`（Front/Back/Matte/Selective または Action パス名）
- パス間テクスチャに `Index` / `NoInput` を付けない
- 複数パスの同一 uniform は `<Duplicate>`
- UI グリッド: Page 0–6, Col 0–3, Row 0–4。末尾に `<Page>` / `<Col>`
- パターンは [xml-schema.md](../../../docs/api/xml-schema.md) の最小例に合わせる

## やってはいけないこと

- 公式 EXAMPLES や LOGIK シェーダをクレジットなしで再配布
- 未検証の GLSL 3/4 機能をクラシックシェーダに入れる
- `shader_builder` が無い環境で「コンパイル済み」と断言する。構文と API の静的チェックまで
