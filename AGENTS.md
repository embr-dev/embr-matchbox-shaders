# embr-matchbox-shaders

Autodesk Flame 用 Matchbox シェーダ（Embr）。

## エージェント向け

Matchbox / Lightbox / GLSL / sidecar XML を扱うときは:

1. スキル **matchbox-shaders** を適用する
2. 先に [docs/api/README.md](docs/api/README.md) を読む（Cursor 用 API docs）

推測で `adsk_*` や XML 属性を足さない。出典は `docs/api/SOURCES.md`。

## リポジトリ規約

- シェーダ: `shaders/<name>/`（`embr_` プレフィックス）
- クラシック GLSL が既定（macOS 互換）。モダン `#version 430` は明示時のみ
- ライセンス: MIT
