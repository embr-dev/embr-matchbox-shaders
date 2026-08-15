# シェーダ提案リスト（未採択・検討用）

LOGIK 定番の焼き直しではなく、**コンポで効く**／**Batch だと組が重い**ものを集約したリスト。  
実装確定ではない。採択したら個別メモ（`embr_*.md`）へ昇格する。

作成: 2026-08-15。既存実装・ボツとの関係は [README.md](README.md)。

---

## 採択時の目安

| 向く | 向かない |
|------|----------|
| 近傍多数・方向場・距離場・前後フレーム | Gain/Sat 1 本、単純 Soft Clip |
| 式が長く途中バッファが増える一連処理 | フルキーヤー、巨大厳密 median、本格 Inpaint |
| Flame CM 上流前提でも「打つ場所」が明確 | MasterGrade 専用 UI の複製 |

ボツ済み（再提案しない）: Matchbox キーヤー、大 Size 2D median、薄い pixel spread。

---

## A. ユーザー要望に直結 — 髪の流れ Soften

### embr_flow_soften ★仕様化済み

**通称「Structure-aware soften」はこれ。**  
詳細仕様: **[embr_flow_soften.md](embr_flow_soften.md)**（構造テンソル → 接線 1D ブラー → Weak Cross）。

| 項目 | 内容 |
|------|------|
| やりたいこと | 主方向（髪の流れ）に沿うブラー。直交方向の細かい毛・飛び毛を抑える |
| 状態 | **仕様確定・未実装**（提案リストから昇格） |

---

## B. 近傍・多サンプル（ノードだと爆発）

| ID | 仮名 | 概要 | シェーダにする理由 | 状態 |
|----|------|------|-------------------|------|
| B1 | embr_flow_soften | 髪の流れ Soften | 異方性＋方向場 | **仕様** → [embr_flow_soften.md](embr_flow_soften.md) |
| B2 | embr_guided_edge | Guided / bilateral で縁だけノイズ落とし | エッジ保持平滑は手組みが長い | 提案 |
| B3 | embr_joint_upsample | 低解像マット／AO を Front に沿って持ち上げ | joint bilateral upsample | 提案 |
| B4 | embr_domain_blur | Domain-transform 系の大ソフト近似 | 巨大 Blur スタックより安い可能性 | 提案（要検証） |

---

## C. 距離・位相

| ID | 仮名 | 概要 | シェーダにする理由 | 状態 |
|----|------|------|-------------------|------|
| C1 | embr_solidify | JFA 最近傍で透明部へ色コピー | Dilate 連鎖では半径・品質が限界 | 提案（distance と連携） |
| C2 | embr_id_dilate | ID／マルチマット色の最近傍埋め | パス合成の隙間。JFA 向き | 提案 |
| C3 | embr_geodesic_dilate | 障害マットを避ける拡散（固定パス） | 普通の Dilate は壁貫通 | 提案 |
| C4 | embr_skeleton_matte | 細いマットの芯の近似 | Open/Close 手組みでは不安定 | 提案（低優先） |

`embr_distance`（README 概要）は C1/C2 の基盤候補。

---

## D. 色・知覚（1 ノードに閉じたい式）

| ID | 仮名 | 概要 | シェーダにする理由 | 状態 |
|----|------|------|-------------------|------|
| D1 | embr_warper_multi | Color Warper の多ピボット版 | 重み場の重ねは CC 積みでは無理 | 提案（既存 warper の後） |
| D2 | embr_sat_safe_contrast | 彩度を分離した stops Contrast | LGG 手組みだと彩度が連動 | 提案（grade に吸収も可） |
| D3 | embr_highlight_roll | 色相維持の linear 肩 | チャンネル別 Soft Clip より一体 | 提案 |
| D4 | embr_spillmap | despill 量だけマット出力 | 後段 Selective 用。焼き込みしない | 提案（despill 拡張でも可） |
| D5 | embr_plate_match | 2 ピッカーで Gain/Offset/簡易 CDL | プレート合わせを一発 | 提案 |

`embr_grade` は別メモで進行中。D2/D3 は grade に取り込むか専用か再判断。

---

## E. 縁・合成の一連処理

| ID | 仮名 | 概要 | シェーダにする理由 | 状態 |
|----|------|------|-------------------|------|
| E1 | embr_edge_rebuild | unpremult→清掃→recontam→detail を一続き | 途中バッファだらけの典型 | 提案 |
| E2 | embr_key_reconstruct | additive/mult 寄与の分解・再構成 | 式が Batch に散らばる | 提案 |
| E3 | embr_contact | wrap＋足元影＋縁 sat をマット駆動で一体 | LightWrap 複数より安定 | 提案 |
| E4 | embr_matte_density | キー専用 toe/shoulder | Grade ではないマット濃度 | 提案 |
| E5 | embr_grain_embed | BG 粒を FG 縁帯だけへ | 縁帯マスク＋粒抽出の一連 | 提案 |
| E6 | embr_screen_balance | スクリーン照明ムラの低周波 divide | キーなし前処理 | 提案 |

Pixel spread（薄い縁伸ばし）はボツ。色の大穴は **C1 solidify** 側。

---

## F. 時間・ベクトル

| ID | 仮名 | 概要 | シェーダにする理由 | 状態 |
|----|------|------|-------------------|------|
| F1 | embr_temporal_chroma | 前フレーム基準の色フリッカー抑制 | `adsk_previous_frame`＋双方向 | 提案 |
| F2 | embr_temporal_matte | α だけ時間平滑 | RGB を触らない | 提案 |
| F3 | embr_vector_smear | MV 短距離で縁色だけ移動 | 等方 Blur では方向が出ない | 提案（Action MV） |

---

## G. 診断（演算付き）

| ID | 仮名 | 概要 | シェーダにする理由 | 状態 |
|----|------|------|-------------------|------|
| G1 | embr_edge_diag | α 勾配・premul 誤差・縁段差の false color | 目視ノードでは拾えない | 提案 |
| G2 | embr_zone_view | 0.18 基準 stops ゾーン可視化±部分 Exposure | 画素ごとの露出診断 | 提案 |
| G3 | embr_premul_heat | \(c\) と \(\alpha\) の矛盾ヒートマップ | 連続値診断 | 提案 |

---

## H. 以前リストしたが優先度低／他に寄せる

| 案 | 扱い |
|----|------|
| Soft Contact from Z | Action Z 前提。E3 に含めても可 |
| AOV pack/unpack | 便利だがシェーダ必須度は低め |
| Printer lights 単体 | grade / CDL に吸収 |
| Geodesic の解像度依存版 | 作らないもの（パス爆発） |

---

## 推奨する検討順（案）

1. **embr_flow_soften**（仕様済み・未実装）→ [embr_flow_soften.md](embr_flow_soften.md)  
2. **embr_edge_diag** / **embr_edge_rebuild**（毎日の縁）  
3. **embr_solidify** + distance（pixelspread の代替）  
4. **embr_contact** / **embr_plate_match**  
5. warper 多ピボット・temporal・guided  

---

## 更新ルール

- 採択 → `docs/planned/embr_<name>.md` を新規作成し、本表の状態を「個別メモへ」に変更  
- ボツ → 理由を1行残して状態をボツに  
- 実装 → [README.md](README.md) の優先表と `shaders/` へ  
