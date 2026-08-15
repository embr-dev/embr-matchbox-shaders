# 作成予定シェーダ

実装前の引き継ぎメモ。規範は常に [docs/api](../api/README.md) と既存の [embr_morphology](../../shaders/embr_morphology/README.md)。ここに書いた未実装の uniform / XML 属性は推測で足さない。

## 優先順位

| 順 | シェーダ | 状態 | 詳細 |
|----|----------|------|------|
| 1 | **embr_median** | 仕様済み・未実装 | [embr_median.md](embr_median.md) |
| — | **embr_despill** | 検討済み・未実装 | [embr_despill.md](embr_despill.md)。Green/Blue/**Cyan·South Sea**。**linear / display Clamp 禁止**。median と独立 |
| — | **embr_holefill** | 仕様済み・未実装 | [embr_holefill.md](embr_holefill.md)。ソフトエッジ保持のマット穴埋め。UI 確定。median と独立 |
| 2 | embr_tophat | アイデア | 下の概要。Morph のパス再利用 |
| 3 | embr_distance | アイデア | Jump Flood。パスが多い。holefill v2 の位相的穴埋めと接続可 |

`.mx` は今は作らない。ソース（`.glsl` + `.xml` + PNG）だけ。Mac の `shader_builder -p` は 2025 Metal で `CreateRenderGraph` になった観測あり。検証は後日 Linux / 手動コンパイル。

## 共通で踏襲するもの（Morph）

- `embr_` プレフィックス。置き場 `shaders/<name>/`
- クラシック GLSL（`#version` なし、`texture2D` / `gl_FragColor`）
- Front 必須、Strength マット任意（未接続 White）、Mix、`adsk_degrade` で半径クランプ
- Channel: RGB / Luma（Luma は `adsk_getLuminance`、色比は `rgb * (Y'/Y)`）
- `SupportsAdaptiveDegradation="True"` かつ GLSL 側で `adsk_degrade`
- `MatteProvider="False"`。MIT、`CommercialUsePermitted="True"`
- DisplayName / Description は英語。必要なら Description に日本語併記
- 動的インデックス配列禁止。`main()` からの早期 `return` 禁止

## 後続の概要（未詳細）

### embr_tophat

Morph と同じ向き付きカーネルで、演算だけ変える。

| Mode | 式 |
|------|-----|
| Gradient | Dilate − Erode |
| Top-hat | Front − Open |
| Black-hat | Close − Front |
| External | Dilate − Front |
| Internal | Front − Erode |

実装は `embr_morphology` の 8 パスに、最終パスで Front を残して差分する形が最短。Median より後でよい。

### embr_distance

マットから近似距離場。Jump Flood（8–12 パス固定）を想定。測地 Dilate や骨格化はパス数が解像度依存なので対象外。Median / Top-hat の後。

### embr_despill

キー抜きはしない。Green / Blue / **Cyan（サウスシー）**のスピル除去。シアンは G+B 同時（Coupled / Independent）。Algorithm 6 択 + Replace。詳細は [embr_despill.md](embr_despill.md)。

### embr_holefill

マットの内部穴・ゴミ。コアを 2 値化 → Close/Open → `max`/`min` で元のソフトエッジを残す。詳細は [embr_holefill.md](embr_holefill.md)。非有界フラッドフィルはしない（Size 付き Morph）。任意サイズの閉穴は distance 連携の v2。

## 作らないもの

連結成分、面積 Opening、ヒストグラム均等化、FFT、**非有界**フラッドフィル、本格 Inpaint、Poisson、任意半径の厳密 2D median ソート。
