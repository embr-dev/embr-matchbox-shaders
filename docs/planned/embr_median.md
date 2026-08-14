# embr_median（仕様・未実装）

表示名: **Embr Median**。向き付き median。ソルトペッパー、スキャンライン、細いゴミ用。

このファイルが実装時の正本。変更したら「未決」と「却下」も更新する。

関連: [README.md](README.md)（予定一覧）、[embr_morphology](../../shaders/embr_morphology/README.md)、[gotchas.md](../api/gotchas.md)。

## 目的

- Size をアーティストが自由に決められる（内部クランプあり）
- 水平・垂直・任意角
- **2D らしい結果**を、任意サイズでも Matchbox の制約内で出す

Morph の「1D を直交に重ねる」は min/max では矩形に対して数学的に正しい。median は non-separable で、横 median → 縦 median は正方形窓の median と見た目の差が大きい。可分合成を 2D と呼ばない。

## 非目標

- 任意 `R` の全画素厳密 2D median（標本 `(2R+1)²`。`R=256` で約 26 万点）
- 256 ビン配列ヒストグラム（動的インデックスが SPIR-V / Metal で危険。`crok_median` はビン削減で M1 クラッシュ回避）
- Huang のスライド ヒストグラム（画素独立のフラグメントでは不可）
- 3×3 反復を大きい窓の代用として黙って出す（油画化。やるなら Iterations と別名）

LOGIK の `crok_median` はグリッチ寄りで NC 由来。本物の median を MIT で出すのが差別化。コピーしない。

## アルゴリズム（採用）

画素ごとに **1 回の median** を取る。窓の形だけ変える。Morph の Line / Square / Circle が「違う構造要素の本物の morph」であるのと同じ。

Median の求め方はどの Mode も同じ: **値の二分探索 + 個数カウント**。標本を配列に積まない。

```
lo, hi = 初期区間
for iter in 0 .. BISECT_ITERS-1:
    mid = 0.5 * (lo + hi)
    count = 0
    for each sample s in window:
        if value(s) <= mid:
            count += 1
    if count >= target_rank:   // median なら (N+1)/2 相当
        hi = mid
    else:
        lo = mid
結果 = 0.5 * (lo + hi)
```

- `BISECT_ITERS`: **12**（約 8 bit。上げるな。コストが線形）
- マット / 0–1 前提なら初期 `[0, 1]`
- 一般 RGB/Luma は、同じ窓でもう 1 回 min/max を取って `[vmin, vmax]` にするか、最初は `[0, 1]` で足りるか未決（下）
- `target_rank`: 奇数個なら `(N+1)/2`。偶数は下側中央（`N/2`）でよい（未決にしない。**下側**で固定）
- `value`: Channel が Luma なら `adsk_getLuminance`、RGB なら R/G/B を独立に 3 回（コスト×3）

クラシック制約: 動的 `float a[N]` 禁止。ループは有界。`main()` 末尾で一度だけ `gl_FragColor`。

### Mode 0 — Disk（既定）= なんちゃって 2D

半径 `R` の円盤上から **標本数 N を固定**し、その集合の本物の median を取る。`R` は点の間隔だけを変える。

| 定数 | 値 | 理由 |
|------|-----|------|
| `DISK_DIRS` | 16 | 22.5° 刻み。等方に近づける |
| `DISK_RINGS` | 4 | 中心を除く環。合計点は中心 + 16×4 = **65**（奇数） |
| 角度オフセット | `angle`（度） | 水平・垂直・回転 |

点 `k = ring * DISK_DIRS + dir`（0-based、中心は別）:

- 中心: `uv`
- `dir = 0..15`, `ring = 1..4`
- `deg = angle + dir * (360 / 16)`
- `dist = (float(ring) / float(DISK_RINGS)) * float(R)` ピクセル
- オフセット: `(cos(deg)*dist/W, sin(deg)*dist/H)`

`R=0` は no-op（Front を返す）。`R=1` では点が重なる。小さい `R` は Exact に近い。大きい `R` は間引き円盤。間の塊は残ることがある。これは仕様。

テクスチャ読み: 二分探索 12 回 × 65 点 ≈ **780 / 画素**（Luma）。`R` に依存しない。

### Mode 1 — Exact 2D

円盤（または正方形）内の **全画素**を数える厳密 2D。`R` を **`EXACT_R_MAX = 4`** にクランプ（直径 9、最大 81 点）。UI の Size が大きくても Exact では 4。Tooltip で明示。

内側判定: `i*i + j*j <= R*R`（ピクセル）。中心含む。点数が偶数になり得るので rank は下側中央。

入れ子ループ `j,i in [-EXACT_R_MAX, EXACT_R_MAX]` を定数上限で回し、`abs(j)<=r && abs(i)<=r && i*i+j*j<=r*r` のときだけカウント。上限を 256 にするな。

Angle: Exact では **回さない**（グリッドは軸付き）。回転が要るときは Disk を使う。Tooltip に書く。

### Mode 2 — Line（1D）

Morph の Line と同じ。`Angle` 方向に `i = -R .. +R` の **2R+1** 点。この方向については本物の 1D median。

`R` は Morph と同じ **最大 256**。コストは 12 × (2R+1)。`R=256` は約 6k 読みで重い。`adsk_degrade` 時は最大 8。通常作業は数十を想定。

水平 = Angle 0、垂直 = 90。

### 採用しない Mode

| 案 | 理由 |
|----|------|
| Square = 横 median のち縦 median | 2D との差が大きい。ユーザー判断で却下 |
| 4 方向 1D を順に合成 | 可分と同じ問題 |
| 3×3 を Size 回反復 | 大きい窓の median ではない |
| 固定 3×3 ソートネットワークのみ | Size 自由と両立しない（Exact の R=1 相当としては内部利用可だが、Disk/Exact で足りる） |

## ファイル

シングルパスで足りる。Mix も `front` が残るので最終で `mix(orig, processed, mix_amount)`。

```
shaders/embr_median/
  embr_median.glsl
  embr_median.xml
  embr_median.glsl.png    # 128×92
  README.md
```

XML `Name="Embr Median"`（Morph に合わせ Display 名）。ファイルベース名は `embr_median`。

マルチパスにしない。`#include` は無いのでヘルパーは同ファイル内。

## 入力

| Socket | Type | Notes |
|--------|------|--------|
| Front | Front | 必須。RGB。`NoInput="Error"` |
| Strength | Matte | 任意。Size の画素ごと乗数（R）。未接続 White（1） |

`LimitInputsToTexture="True"`。`MatteProvider="False"`。

## コントロール

UI グリッド: Page 0、Col 0–1、Row 0–3。Morph に近い配置。

| Uniform | Type | Default | Row,Col | 内容 |
|---------|------|---------|---------|------|
| `channel` | int Popup | 1 Luma | 0,0 | 0 RGB（チャンネル独立）、1 Luma |
| `mode` | int Popup | 0 Disk | 1,0 | 0 Disk、1 Exact 2D、2 Line |
| `size` | int | 0 | 0,1 | 半径 px。Min 0、Max 256、Inc 1。0 は no-op |
| `angle` | float | 0 | 1,1 | 度。Min -360、Max 360、Inc 1。Disk のサンプル回転と Line の方向。Exact では無視 |
| `mix_amount` | float | 1 | 2,1 | 0 原画、1 効果のみ |
| （Strength） | sampler | — | ソケット | 上表 |

DisplayName: Channel / Mode / Size / Angle / Mix。Mode の PopupEntry: `Disk` / `Exact 2D` / `Line`。

Tooltip 要点（英語）:

- Disk: fixed 65 samples on a disk; Size scales spacing; not a dense 2D median at large Size
- Exact 2D: dense disk, Size clamped to 4, Angle ignored
- Line: 1D median along Angle; Size up to 256
- Channel Luma: morph luminance, keep chromaticity like morphology
- Strength: per-pixel multiplier on Size (red)

`SupportsAction="True"` `SupportsTimeline="True"` `SupportsTransition="False"` `SupportsAdaptiveDegradation="True"` `TimelineUseBack="False"` `SoftwareVersion="2025.0.0"` `Version="1"`。

## 半径の扱い（Morph と同じ関数名でよい）

```
clamp_radius(size):
    r = max(size, 0)          // median は符号なし。負 Size は 0
    r = min(r, 256)
    if adsk_degrade && r > 8: r = 8
    if mode == Exact 2D: r = min(r, 4)
    return r

apply_strength(r, uv):
    return round(r * clamp(strength.r, 0, 1))
```

Morph は Size の符号で Dilate/Erode を切り替えた。Median に方向は無い。**Min 0**。負は XML で入れない。

## Luma / RGB

Morph の `apply_luma` をコピー。

- Luma: 窓の輝度で median `Y'`。出力 `rgb * (Y'/Y)`。`Y < 1e-6` は `vec3(Y')`
- RGB: R,G,B 独立に同じ窓・同じ rank。ベクトル median（色空間距離）は初版ではやらない
- log / linear 変換はしない（Morph と同じ）

既定 Channel は **Luma**（RGB は 3 倍）。

## サンプリング

- `CLAMP_TO_EDGE`
- Disk / Line の回転オフセットは **LINEAR**（Morph と同じ）
- Exact 2D の整数グリッドは **NEAREST** の方が中央値として正しい。未決だったが **Exact は NEAREST、他は LINEAR** で固定する
- UV: `gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h)`

XML の Front: Disk/Line 用に LINEAR を書いてよい。Exact の NEAREST は GLSL で `texture2D` しか無いクラシックではフィルタを GLSL から変えられない。**初版はすべて LINEAR**（XML で Front に LINEAR）。Exact のサブピクセル混ざりを問題にするなら後でパスを分ける。

## Adaptive Degradation

`adsk_degrade` が true なら `r = min(r, 8)`。Exact は元から ≤4 なので影響なし。Line/Disk の大半径プレビュー用。属性だけ立てず、GLSL で分岐すること。

## 性能目安

| Mode | Size | おおよその読み（Luma） |
|------|------|------------------------|
| Disk | 任意 | ~780 |
| Exact | ≤4 | ~12 × 点数（≤81 → ~1000） |
| Line | 8 | ~200 |
| Line | 64 | ~1500 |
| Line | 256 | ~6000（degrade 時は Size 8 相当） |

RGB は ×3。Disk を既定にするのはコストが Size に依存しないため。

## GLSL 骨格（実装時）

```
uniform float adsk_result_w, adsk_result_h;
uniform bool adsk_degrade;
uniform sampler2D front, strength;
uniform int channel, mode, size;
uniform float angle, mix_amount;
float adsk_getLuminance(vec3 color);
```

コンマ並びの uniform は 1 行 1 本に分ける（builder / 2026.2）。

ヘルパー案（名前は長く。`V` / `ONE` 禁止）:

- `step_from_angle(deg)` — Morph からコピー
- `clamp_radius` / `apply_strength` / `apply_luma`
- `sample_value(rgb)` — Luma or 呼び出し側で成分
- `bisect_median(...)` — 窓の数え方を Mode で分ける。配列に貯めない

`int` ループ変数を `for` 内で宣言してよいが、Morph に合わせ `int i;` を前に出してもよい。暗黙キャスト禁止（`vec4` を `vec2` に入れない）。`int(float * str + 0.5)` で round。

## README.md（シェーダフォルダ）に書くこと

Morph の README と同じ表: 何をするか、Files、Inputs、Controls、Mode の意味、Disk が間引きであること、Exact の Size クランプ、Line が 1D であること、配置パス。

## 実装手順

1. `docs/api` を読む。スキル matchbox-shaders
2. `shaders/embr_median/` を追加。GLSL 手書き
3. この環境に `shader_builder` は無い前提。XML は Morph を雛形に手書き
4. gotchas を確認
5. フォルダ README
6. ソースのみコミット。`.mx` をコミットしない
7. 実機: Linux で `shader_builder -m`、Mac Flame で Disk/Exact/Line・Luma/RGB・Strength・degrade・Size 0

## 実機確認チェック

- Size 0 が原画と一致（Mix=1 でも）
- Mix 0 が原画
- Strength 0 が Size 0 相当、未接続がフル Size
- 点ノイズ: Disk / Exact で消え、Line は Angle 方向の傷に強い
- Exact で Size 100 が 4 と同じ
- Exact で Angle を回しても結果が変わらない
- Disk で Angle 90° が 0° とわずかに違う（サンプル回転）
- Luma で色相が極端に飛ばない
- `adsk_degrade` で Line 大半径が軽くなる
- CreateRenderGraph が出ない（Mac / Linux）

## 却下ログ（再提案しない）

- 可分 Square を既定 2D にする
- 任意 R 厳密 2D をソートネットワークで
- ヒストグラム配列
- 初版からベクトル median / percentile / rank
- 初版から `.mx`

## 未決（実装してよい既定）

初版で困ったらここに戻す。

| 項目 | 初版の既定 |
|------|------------|
| 二分探索の初期区間 | Luma/RGB とも先に同じ窓で min/max（+2 走査）。マットが 0–1 でも害は少ない |
| Exact の形状 | 円盤 `i²+j²≤R²`（正方形窓にしない。Disk と一貫） |
| 偶数個の rank | 下側中央 |
| Front フィルタ | すべて LINEAR |
| Percentile | 次の版。`rank` uniform は足さない |
| NbExecutions | 使わない |

## 次の版でよいもの

- `embr_rank`: Disk/Line のまま percentile（k 番目）。median は k=50%
- Quality としてビン 16 の Fast（if 梯子。配列にしない）
- Exact を NEAREST にする専用パス
