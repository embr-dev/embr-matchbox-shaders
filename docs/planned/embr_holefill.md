# embr_holefill（検討メモ・未実装）

表示名案: **Embr Hole Fill**。キーマットの **内部穴・ゴミ**を直し、**ソフトエッジは残す**。

関連: [README.md](README.md)、[embr_morphology](../../shaders/embr_morphology/README.md)、将来の distance（概要）。キー生成はしない。

状態: **処理方針＋ UI 仕様まで確定・未実装**。

## 意図

1. ソフトマット `m` から **コア（2値）**を切る  
2. コアに Close / Open  
3. `max` / `min` で元のフォールオフを残す  

マットの Unpremultiply は不要（対象はカバレッジ）。色の Edge Extend は別シェーダ。

## 処理（確定）

```
m       = source_coverage(...);     // Source による
if (invert) m = 1.0 - m;
core    = step(threshold, m);
filled  = morph_close(core, fill_size);   // Mode に応じて
opened  = morph_open(core, speck_size);   // Mode に応じて
repaired =
  Fill Holes     → max(m, filled)
  Remove Specks  → min(m, opened)
  Both           → min(max(m, filled), opened_from_that)  // Close→Open 順
out_cov = mix(m, repaired, mix_amount);
// Output に応じて RGB / A へ載せる
```

Both の Open は Close 後の結果に対して行う（穴を埋めてから白ゴミを落とす）。

## UI 設計方針

- **主操作は 3 つ**: Mode / Threshold / Size。ここだけで 8 割のショットが直る  
- Morph と同じく **Mix のみ**（Amount と二重にしない）  
- **Core Replace は Mode に置かない**（View で Core / Processed を見る）  
- Unpremultiply は出さない  
- Kernel は Square / Circle のみ（Line・Angle なし）  
- Both のときだけ Speck Size を出す（UICondition）

## 入力

| Socket | InputType | NoInput | 役割 |
|--------|-----------|---------|------|
| Front | Front | Error | 必須。色のパススルー、またはマット自体 |
| Matte | Matte | Black | Source=Matte のとき使う。未接続かつ Source=Matte なら GLSL で Front Alpha にフォールバック |
| Strength | Matte | White | Size / Speck Size の画素ごと乗数（R）。未接続=1 |

`LimitInputsToTexture="True"`。

### MatteProvider

**`True`（確定）**。直したカバレッジを `gl_FragColor.a` に書き、子へ渡す。マット修復ノードとしての本命。

## Controls（確定）

Page 名: **Hole Fill**。列は Morph に合わせて 2 列。

### Col 0 — Source

| Row | Control | Type | Default | 内容 |
|-----|---------|------|---------|------|
| 0 | **Source** | Popup | Front Alpha | カバレッジの取り出し元 |
| 1 | **Invert** | bool | False | 処理前に `1 - m` |
| 2 | **Mode** | Popup | Fill Holes | 修復の種類 |
| 3 | **View** | Popup | Result | 診断 |
| 4 | **Output** | Popup | Replace Alpha | 出力の載せ方 |

**Source**

| Value | Title | 式 |
|-------|-------|-----|
| 0 | Front Alpha | `front.a` |
| 1 | Front Red | `front.r`（マットを RGB で流すパイプ） |
| 2 | Matte | `matte.r`。未接続時は `front.a` |

**Mode**

| Value | Title | 処理 |
|-------|-------|------|
| 0 | Fill Holes | Close → `max(m, filled)` |
| 1 | Remove Specks | Open → `min(m, opened)` |
| 2 | Both | Close → `max` のあと Open → `min` |

**View**

| Value | Title | 内容 |
|-------|-------|------|
| 0 | Result | 最終出力 |
| 1 | Source | 入力カバレッジ `m`（Invert 後） |
| 2 | Core | 2 値コア |
| 3 | Processed | Morph 後（合成前） |
| 4 | Diff | `abs(result - m)`（変化量の可視化。値域は clamp しない） |

**Output**

| Value | Title | 内容 |
|-------|-------|------|
| 0 | Replace Alpha | `rgb = front.rgb`、`a = out_cov`。キー後の色＋マット直し（**既定**） |
| 1 | Matte RGB | `rgb = vec3(out_cov)`、`a = out_cov`。マット専用パイプ |

View が Result 以外のときは診断用にグレー表示（`vec3(v)` + `a = v`）。Output は Result 時だけ意味を持つ。

### Col 1 — Repair

| Row | Control | Type | Default | Min–Max / Inc | 内容 |
|-----|---------|------|---------|---------------|------|
| 0 | **Threshold** | float | 0.5 | 0–1 / 0.01 | コア切り。Tooltip: これ以上をソリッドとみなす |
| 1 | **Size** | int | 2 | 0–64 / 1 | Fill の Close 半径（px）。Remove Specks 単独時は Open 半径 |
| 2 | **Speck Size** | int | 1 | 0–64 / 1 | Both の Open 半径。**Mode=Both のときだけ表示**（`UIConditionSource=mode` `UIConditionValue=2` `Hide`） |
| 3 | **Kernel** | Popup | Square | | Square / Circle |
| 4 | **Mix** | float | 1 | 0–1 / 0.01 | 元カバレッジとのブレンド |

**Size の意味（Mode 依存）**

| Mode | Size | Speck Size |
|------|------|------------|
| Fill Holes | Close 半径 | 非表示 |
| Remove Specks | Open 半径 | 非表示 |
| Both | Close 半径 | Open 半径 |

Tooltip（Size）: 埋められる穴の半径の目安。直径 roughly `2 * Size` まで。0 は threshold のみ（Morph なし）。

**Kernel**

| Value | Title | 備考 |
|-------|-------|------|
| 0 | Square | 既定。分離 2 パスで安い |
| 1 | Circle | 八角近似（Morph と同型）。丸い穴向き |

Angle / Line は出さない。

**Strength**: ソケットのみ（UI スライダなし）。`round(Size * clamp(strength.r, 0, 1))`。Speck Size にも同様。

**Adaptive Degradation**: `SupportsAdaptiveDegradation="True"` + `adsk_degrade` で Size / Speck Size 上限 8（Morph に合わせる）。

## レイアウト（XML イメージ）

```
Page "Hole Fill"
  Col 0 "Source":  Source, Invert, Mode, View, Output
  Col 1 "Repair":  Threshold, Size, Speck Size, Kernel, Mix
```

Preset 属性（Morph 踏襲 + 差分）:

- `MatteProvider="True"`
- `SupportsAction="True"` `SupportsTimeline="True"` `TimelineUseBack="False"`
- `SupportsAdaptiveDegradation="True"`
- `CommercialUsePermitted="True"` `LimitInputsToTexture="True"`
- Description（英語）: hole/speck repair on matte coverage; soft edge kept via max/min with original.

## パス構成（実装メモ）

| 案 | 内容 |
|----|------|
| 推奨 | 閾値パス → 分離 Close/Open（Square 2、Circle は Morph に近い複数）→ 最終合成パス |
| Size=0 | Morph パスをコピー通し、最終で `mix(m, max/min(m,core), …)` のみでも可 |

マルチパス時は Morph と同様 `<Duplicate/>`。最終パスだけ Mix / View / Output / Front。

## 採用しなかった UI

| 候補 | 理由 |
|------|------|
| Amount + Mix | マット修復では同義になりやすい。Morph に合わせ Mix のみ |
| Core Replace Mode | View=Core/Processed で足りる |
| Unpremultiply | カバレッジ処理と無関係。混乱のもと |
| Soft Threshold | 穴の境界が曖昧になる。ハード `step` の方が予測しやすい |
| Fill Size と Speck Size を常時表示 | Fill だけ使うとき冗長。Both だけ Speck Size |
| Line / Angle | 穴埋めに不要 |
| Size max 256 | マット穴では過剰。64＋ degrade。足りなければ Morph を前段に |

## 位相的穴埋め（v2）

枠連結の洪水は初版に入れない。UI も Mode に足さない。`embr_distance` 後に別 Mode または別シェーダ。

## やらないこと（初版）

- 非有界フラッドフィル、連結成分、面積 Opening  
- RGB Edge Fill  
- マットの Unpremultiply 必須化  

## 実機で触ってから変えうるもの

| 項目 | 仮の確定 | 変えうる条件 |
|------|----------|--------------|
| Threshold 既定 0.5 | ○ | ソフトキーが多いなら 0.1–0.25 |
| Size 既定 2 / max 64 | ○ | |
| Speck Size 既定 1 | ○ | |
| Output 既定 Replace Alpha | ○ | マット専用運用が主なら Matte RGB |
| Both = Close→Open | ○ | |
| Matte 未接続時 Front Alpha フォールバック | ○ | |
