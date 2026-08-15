# 作成予定シェーダ

実装前の引き継ぎメモ。規範は常に [docs/api](../api/README.md) と既存の [embr_morphology](../../shaders/embr_morphology/README.md)。ここに書いた未実装の uniform / XML 属性は推測で足さない。

最終整理: 2026-08-15。

**提案の棚卸し**（未採択のアイディア一覧）: [proposals.md](proposals.md)。髪の流れ Soften（Structure-aware）含む。

## 優先順位

| 順 | シェーダ | 状態 | 詳細 |
|----|----------|------|------|
| — | **embr_key** | **ボツ**（2026-08-15）。Matchbox キーヤーを止めた。シェーダは削除済み | 知見は [embr_key.md](embr_key.md) の中断ログ |
| — | **embr_median 系** | **中断**（2026-08-15）。大 Size 2D が実用に届かず。シェーダは削除済み | 知見は [embr_median.md](embr_median.md) の中断ログ |
| — | **embr_despill** | Green / Blue / Cyan / Custom（Green に色相揃え）。Mix なし | [embr_despill.md](embr_despill.md)、[shaders/embr_despill](../../shaders/embr_despill/README.md) |
| — | **embr_fillmatte** | マット専用。Linear-step Close Fill のあと Comp。Preview で入力へ赤い Edge ガイド | [embr_holefill.md](embr_holefill.md)、[shaders/embr_fillmatte](../../shaders/embr_fillmatte/README.md) |
| — | **embr_grade** | 調査＋段階仕様・未実装 | [embr_grade.md](embr_grade.md)。MasterGrade 代替。**Phase 1=Encoding+Primaries+CDL**。Model 既定 **Video** |
| — | **embr_color_warper** | **実装**（2026-08-15）。表示名 Embr Color Warper。YUV クロマのガウス重みで 1 ピボットを Hue / Exposure / Sat。1 ピン。ASC CDL は `mix(src, CDL(src), w)`。キーなし | [embr_color_warper.md](embr_color_warper.md)、[shaders/embr_color_warper](../../shaders/embr_color_warper/README.md) |
| — | **embr_pixelspread** | **ボツ**（2026-08-15）。クオリティ不足。シェーダは削除済み | 知見は [embr_pixelspread.md](embr_pixelspread.md) の中断ログ |
| 2 | embr_tophat | アイデア | 下の概要。Morph のパス再利用 |
| 3 | embr_distance | アイデア | Jump Flood。holefill v2 / **solidify** と接続可 |
| — | **提案リスト** | 検討用 | [proposals.md](proposals.md)。**embr_flow_soften**（髪の流れに沿うブラー／逆毛抑制）ほか |

ソース（`.glsl` + `.xml` + PNG）を正本にする。`.mx` を出すときはマルチパスを `Name.*.glsl` で全パス渡す（`.1.glsl` だけだと `CreateRenderGraph`）。手順は [packaging.md](../api/packaging.md)。

## 共通で踏襲するもの（Morph）

- `embr_` プレフィックス。置き場 `shaders/<name>/`
- クラシック GLSL（`#version` なし、`texture2D` / `gl_FragColor`）
- Front 必須、Strength/Selective マット任意（未接続 White）、Mix
- 必要なら `SupportsAdaptiveDegradation` + GLSL `adsk_degrade`
- 既定 `MatteProvider="False"`（fillmatte など例外は各メモ）
- MIT、`CommercialUsePermitted="True"`
- DisplayName / Description は英語。必要なら Description に日本語併記
- 動的インデックス配列禁止。`main()` からの早期 `return` 禁止
- 色系は **表示 `clamp(rgb,0,1)` 禁止**（grade / despill）。アルゴリズム上の min/max は可

## 後続の概要

### embr_key

**ボツ**（2026-08-15）。Matchbox キーヤーを止めた。シェーダは削除済み。再開するなら中断ログから。[embr_key.md](embr_key.md)

### embr_tophat

Morph と同じ向き付きカーネルで、演算だけ変える。

| Mode | 式 |
|------|-----|
| Gradient | Dilate − Erode |
| Top-hat | Front − Open |
| Black-hat | Close − Front |
| External | Dilate − Front |
| Internal | Front − Erode |

実装は `embr_morphology` の 8 パスに、最終パスで Front を残して差分する形が最短。

### embr_distance

マットから近似距離場。Jump Flood（8–12 パス固定）。測地 Dilate や骨格化はパス数が解像度依存なので対象外。**embr_solidify**（色の最近傍埋め）や holefill v2 の基盤候補。

### embr_despill

キー抜きはしない。Green / Blue / **Cyan** / Custom（Green に色相揃え）。Coupled / Independent。Algorithm 6 択 + 加算 Replace（Luma/Colour/Background）。Mix なし。**linear / Clamp 禁止**。[embr_despill.md](embr_despill.md)

### embr_fillmatte

マット専用。Linear-step Close Fill のあと Comp。Preview で入力へ赤い Edge ガイド。[embr_holefill.md](embr_holefill.md)

### embr_grade

MasterGrade が弱い **Log / Linear の作業空間**を正面から扱うグレーディング。Resolve / Baselight / ASC CDL を調査済み。**Grade Encoding** + Working Model（既定 **Video**）。段階実装。[embr_grade.md](embr_grade.md)

### embr_color_warper

**実装**（2026-08-15）。表示名 **Embr Color Warper**。YUV クロマ平面のガウス重みカラーワーパー。1 ノード 1 ピボット + 1 ピン + ASC CDL。キーなし。EAB / T-CAM は使わない。[embr_color_warper.md](embr_color_warper.md)

### embr_pixelspread

**ボツ**（2026-08-15）。縁伸ばしの見た目が実用に届かず削除。再開するなら JFA / solidify 側。[embr_pixelspread.md](embr_pixelspread.md)

## 作らないもの

連結成分、面積 Opening、ヒストグラム均等化、FFT、**非有界**フラッドフィル、本格 Inpaint、Poisson、Push–Pull ピラミッド、任意半径の厳密 2D median ソート、MasterGrade 専用 UI の複製、フル OCIO / T-CAM 複製。
