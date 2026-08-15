# 出典

Cursor 用に再構成した二次資料。規範は常に Autodesk の現行 Help と `shader_builder --help`。

## Autodesk（一次）

ユーザー保存（Flame Family 2025 Help → API Documentation → Shader Builder）:

- Shader Builder
- Creating a Matchbox Shader
- Matchbox Shader Examples
- Creating a Lightbox Shader
- Lightbox Shader Examples
- Creating Presets for a Shader
- About shader_builder XML
- Shader API Documentation

オンライン（収集時）:

- [Matchbox in Action (Flame 2026)](https://help.autodesk.com/cloudhelp/2026/ENU/Flame-Action/files/Action-Shading-and-Textures/about-matchbox-in-action.html)
- [Using Shaders to Create Your Own Effects (2017 Help)](https://help.autodesk.com/cloudhelp/2017/ENU/Flame/files/GUID-6068A3DC-2BF0-407E-AE8D-98DA97C3EF22.htm)
- [Shader Builder API Guide (2016 PDF)](http://docs.autodesk.com/flamepremium2016/shader_builder_api_guide_2016.pdf) — パスが `/usr/discreet` の歴史資料。現行は `/opt/Autodesk`

インストール内の正本:

- `/opt/Autodesk/<product>/bin/shader_builder`
- `/opt/Autodesk/presets/<version>/matchbox/shaders/EXAMPLES/`
- `/opt/Autodesk/presets/<version>/action/lightbox/EXAMPLES/`

## LOGIK / コミュニティ

- https://logik-matchbook.org/ — コミュニティ Matchbox リポジトリ
- https://logik-matchbook.org/sharing — アップロード規約
- https://logik-portal.com/matchboxes/
- https://forum.logik.tv/ — 特に:
  - Matchbox Shaders in the age of Vulkan & Metal（2024.1 SPIR-V）
  - Matchboxes not working in Flame 2025.1
  - Broken matchbox nodes in Flame 2025.2
  - Shader Utility 2026.2（uniform block は 1 行 1 宣言）
  - Multi-Execution Matchbox（`NbExecutions`）
  - Matchbox Help Thread（Mac builder、`gl_FragCoord`）
- [Erwan Leroy, Making your own Matchbox Shaders](https://erwanleroy.com/making-your-own-matchbox-shaders-for-flame-an-introduction-to-glsl/) — GLSL 入門と XML 編集
- コミュニティ実装慣例（早期 return 禁止、プロキシ命名など）は公開 Matchbox リポジトリの実践から要約。公式仕様ではない

## 用語の揺れ（ドキュメント間）

| 項目 | 扱い |
|------|------|
| `ResDependent` vs `ResDependant` | builder 出力の `ResDependent` を使う |
| `PopupEntry` vs DTD `PopEntry` | `PopupEntry` |
| プロキシ 128×92 vs 126×92 vs 268×194 | PNG ソースは 128×92。公式 EXAMPLES の一部 `.p` は 126×92。縮小は `.mx` サムネイルには無関係 |
| Flame ブラウザのサムネイル | GLSL は sidecar `.p`。`.mx` は **Linux の `shader_builder -p`**。Mac 製は `DISPLAY=:0` でも空（同じ Mac Flame でも Linux 製は見える） |
| `.p` の変換 | `gem install discreet_proxy` → `flame_proxy_icon --from-png`（Julik Tarkhanov）。PNG 解像度のまま |
| `shader_builder` パス | `/opt/Autodesk/.../bin` |
| LinearLight 番号 | 2025.1 で 32=PsLinearLight、37=Flame LinearLight |
