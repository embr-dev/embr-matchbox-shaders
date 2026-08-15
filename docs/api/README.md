# Matchbox / Lightbox API Docs（Cursor 用）

Autodesk Flame 向け **Matchbox**（および関連する Lightbox）をこのリポジトリで作成するための API リファレンス。

エージェントは Matchbox / Lightbox / `shader_builder` / `.glsl` / sidecar `.xml` を扱うとき、**先にこのディレクトリを読む**。詳細はファイル単位で progressive disclosure する。

## 読む順番

| 状況 | 読むファイル |
|------|----------------|
| 新規 Matchbox を作る | [overview.md](overview.md) → [matchbox-glsl.md](matchbox-glsl.md) → [xml-schema.md](xml-schema.md) |
| `adsk_*` / 色変換 / blend | [shader-api.md](shader-api.md) |
| マルチパス・Selective・Action / Camera FX | [multipass-action.md](multipass-action.md) |
| Lightbox | [lightbox.md](lightbox.md) |
| ビルド・プリセット・配置・LOGIK 公開 | [packaging.md](packaging.md) |
| 動かない / 2024.1 以降 / Mac | [gotchas.md](gotchas.md) |
| 出典 | [SOURCES.md](SOURCES.md) |
| 未実装の予定シェーダ | [docs/planned/README.md](../planned/README.md) |

## このリポジトリの既定

- **既定はクラシック GLSL**（`texture2D` / `gl_FragColor`、macOS 互換のため GLSL 1.20 相当）。Flame 2025.1+ の `#version 430` uniform block 形式は、ユーザーが明示したときだけ使う。
- シェーダは `shaders/<name>/` に置く。ファイル名と XML `Name` は `embr_` プレフィックス。
- ライセンスは MIT。XML は `CommercialUsePermitted="True"`。
- ソース（`.glsl` + `.xml`）をリポジトリに置く。`.mx` 暗号化パッケージは配布用オプションであり、ソースの代わりにしない。

## 公式の所在（Flame インストール内）

| 種類 | パス |
|------|------|
| `shader_builder` | `/opt/Autodesk/<product_home>/bin/shader_builder` |
| Matchbox 例 | `/opt/Autodesk/presets/<version>/matchbox/shaders/EXAMPLES/` |
| Lightbox 例 | `/opt/Autodesk/presets/<version>/action/lightbox/EXAMPLES/` |
| ユーザー共有配置 | `/opt/Autodesk/shared/matchbox/shaders/` |
| Flame Preferences | Shader Paths（Search ウィジェット用） |

古いドキュメントの `/usr/discreet/...` は現行の `/opt/Autodesk/...` に読み替える。
