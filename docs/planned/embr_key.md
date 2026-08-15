# embr_key（仕様）

表示名: **Embr Key**。グリーンバック向けマット。

**2026-08-15 ボツ。** Matchbox キーヤーの実装を止めた。`shaders/embr_key` は削除済み。再開時はこのファイルの「中断ログ」から。

関連: [README.md](README.md)、[embr_despill.md](embr_despill.md)、[embr_holefill.md](embr_holefill.md)。

---

## 中断ログ（2026-08-15）

高精度キー（色度 2D + YUV 楕円）を Matchbox で試作したあと、実装ごとボツ。

試したもの（シングルパス、クラシック GLSL）:

- Screen カラーポット + Space（Chromaticity / YUV）
- 色度: `rgb/(r+g+b)` の距離。Range が半径。内側=背景
- YUV: `adsk_rgb2yuv` の軸別楕円。Range Y/U/V。面の内側=背景
- Garbage（Matte、未接続 Black）/ Core（Selective、未接続 Black）
- Invert、Preview（Front へ半透明赤、A はマット）
- 一度 Inner（芯）+ Softness（縁ランプ）を入れ、のち色体積のハード境界だけに縮小

分かったこと:

- Flame に Master Keyer / 3D Keyer がある。Matchbox では立方体プロットも `sampler3D` も無い
- Colour ポットに `IconType="Pick"` を付ける EXAMPLES が無い（ポットのスポイトに頼る）
- Inner の単位が Space で変わる（XML Default は一つ）。YUV に切ると Inner を 1 付近に合わせ直す必要がある
- 芯・縁の二段は FillMatte と役割が被る。色キー単体にするとハード体積だけになる
- `Name="mode"` の 0–3 は使わない（UI 列が消える）。Space は Max=1 の Popup
- Core を `InputType="Selective"` にすると Selective FX の Mix/Outside が付く可能性がある

再開するときの候補:

- Matchbox キーヤーを本線にしない。マットは Flame キーヤー、穴は FillMatte、スピルは Despill
- どうしても出すなら色体積＋ Preview だけ。Inner/Softness は入れない
- 既定は Video/Log 作業。Scene-linear のまま距離を取らない

実装フォルダは削除済み。

---

## 意図（当時）

前景マット（人物=1）。Close なし。Despill はしない。
