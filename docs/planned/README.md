# 作成予定シェーダ

実装前の引き継ぎメモ。規範は常に [docs/api](../api/README.md) と既存の [embr_morphology](../../shaders/embr_morphology/README.md)。ここに書いた未実装の uniform / XML 属性は推測で足さない。

最終整理: 2026-08-15。

## 優先順位

| 順 | シェーダ | 状態 | 詳細 |
|----|----------|------|------|
| 1 | **embr_median** | 仕様済み・未実装 | [embr_median.md](embr_median.md) |
| — | **embr_despill** | 検討済み・未実装 | [embr_despill.md](embr_despill.md)。Green/Blue/**Cyan·South Sea**。**linear / display Clamp 禁止** |
| — | **embr_holefill** | 仕様済み・未実装 | [embr_holefill.md](embr_holefill.md)。ソフトエッジ保持。**UI 確定** |
| — | **embr_grade** | 調査＋段階仕様・未実装 | [embr_grade.md](embr_grade.md)。MasterGrade 代替。**Phase 1=Encoding+Primaries+CDL** |
| 2 | embr_tophat | アイデア | 下の概要。Morph のパス再利用 |
| 3 | embr_distance | アイデア | Jump Flood。holefill v2 と接続可 |

`.mx` は今は作らない。ソース（`.glsl` + `.xml` + PNG）だけ。Mac の `shader_builder -p` は 2025 Metal で `CreateRenderGraph` になった観測あり。検証は後日 Linux / 手動コンパイル。

## 共通で踏襲するもの（Morph）

- `embr_` プレフィックス。置き場 `shaders/<name>/`
- クラシック GLSL（`#version` なし、`texture2D` / `gl_FragColor`）
- Front 必須、Strength/Selective マット任意（未接続 White）、Mix
- 必要なら `SupportsAdaptiveDegradation` + GLSL `adsk_degrade`
- 既定 `MatteProvider="False"`（holefill など例外は各メモ）
- MIT、`CommercialUsePermitted="True"`
- DisplayName / Description は英語。必要なら Description に日本語併記
- 動的インデックス配列禁止。`main()` からの早期 `return` 禁止
- 色系は **表示 `clamp(rgb,0,1)` 禁止**（grade / despill）。アルゴリズム上の min/max は可

## 後続の概要

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

マットから近似距離場。Jump Flood（8–12 パス固定）。測地 Dilate や骨格化はパス数が解像度依存なので対象外。

### embr_despill

キー抜きはしない。Green / Blue / **Cyan（サウスシー）**。Coupled / Independent。Algorithm 6 択 + Replace。**linear / Clamp 禁止**。[embr_despill.md](embr_despill.md)

### embr_holefill

マット穴・ゴミ。`max(m, close(threshold(m)))` 系。UI（Source / Mode / Threshold / Size / Output）確定。[embr_holefill.md](embr_holefill.md)

### embr_grade

MasterGrade が弱い **Log / Linear の作業空間**を正面から扱うグレーディング。Resolve（LGG / Log SMH）・Baselight（zones / stops）・ASC CDL / ACES を調査済み。**Grade Encoding**（Pass / Temp Cineon Log）で Linear にも Log 操作感。段階実装（Phase 1 Foundation → Tone/Curves → Zones）。[embr_grade.md](embr_grade.md)

## 作らないもの

連結成分、面積 Opening、ヒストグラム均等化、FFT、**非有界**フラッドフィル、本格 Inpaint、Poisson、任意半径の厳密 2D median ソート、MasterGrade 専用 UI の複製、フル OCIO / T-CAM 複製。
