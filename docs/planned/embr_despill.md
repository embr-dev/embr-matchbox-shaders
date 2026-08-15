# embr_despill（仕様）

表示名: **Embr Despill**。グリーンバック / ブルーバック / **シアン（サウスシー）**の色かぶり（スピル）除去。

キー抜き（マット生成）はしない。マットは上流の Master Keyer / 3D Keyer 等を前提。Fill 用 Front のスピルだけを直す。

関連: [README.md](README.md)、[gotchas.md](../api/gotchas.md)、LOGIK `AFX_DeSpill` / `crok_despill`（参考。コピーしない）。

## 背景色の整理

| 名称 | 実態 | スピルの主成分 | 備考 |
|------|------|----------------|------|
| グリーンバック | chroma green | **G** | 明るく肌・髪に乗りやすい |
| ブルーバック | chroma blue | **B** | 緑物・低照度向き |
| **シアン / サウスシー** | サウスシーブルー布。名称は Blue だが現場感は **C（シアン ≒ G+B）** | **G と B の両方** | 規格 RGB 非公開・ロット差。B 単体デスピルだと緑側が残る |

**シアンに対するデスピルは可能。** RGB ではシアン＝R が相対的に低く G・B が高い状態。やることは:

1. **Coupled** — `(G+B)/2` が R（やその変形）を超えた分だけ、G と B を同じ比率で下げる（色相をシアンのまま落とす）
2. **Independent** — Green 式と Blue 式を同じ画素に両方かける（実務でよくやる「緑＋青デスピル」）
3. **Custom** — Spill Colour の色相を Green に回し、Green の Algorithm をかけて戻す

サウスシーブルー布は Screen=**Cyan**（G+B）で扱う。Blue 単チャンネルにはしない。ロット差は Screen=Custom。

Flame: Master Keyer Spill が定番。Matchbox の価値は式の再現・複数 Algorithm・Cyan 明示・Spill View・Keyer 分離。

## 定番アルゴリズム（複数・Matchbox 向き）

方針: **Algorithm Popup で式を全部選べる**（3つに減らさない）。先例は DespillMadness / bm_Despill / McEwan。

### A1. Green / Blue — 単チャンネル

| ID | UI 名 | Green | Blue（ラベルは同じ。中身は読替） |
|----|-------|-------|----------------------------------|
| 0 | Average | `g' = min(g,(r+b)/2)` | `b' = min(b,(r+g)/2)` |
| 1 | Max | `g' = min(g,max(r,b))` | `b' = min(b,max(r,g))` |
| 2 | Double Blue | `g' = min(g,(r+2*b)/3)` | → Double Green: `b' = min(b,(r+2*g)/3)` |
| 3 | Double Red | `g' = min(g,(2*r+b)/3)` | `b' = min(b,(2*r+g)/3)` |
| 4 | Limit Blue | `g' = min(g,b)` | → Limit Green: `b' = min(b,g)` |
| 5 | Limit Red | `g' = min(g,r)` | `b' = min(b,r)` |

Tooltip: Blue では Double Blue＝Double Green、Limit Blue＝Limit Green。

### A2. Cyan — 二チャンネル

#### Coupled（シアン本線・既定）

```
avg = 0.5 * (g + b);
lim = <Algorithm が決める> * fine_tune;
factor = 1.0;
if (avg > lim && avg > 1e-6)
    factor = lim / avg;
g2 = g * factor;
b2 = b * factor;
r2 = r;
```

amount / matte は処理順の段 3 で掛ける。このブロックでは掛けない。

| ID | UI 名 | Cyan Coupled の `lim` | 意味 |
|----|-------|----------------------|------|
| 0 | Average | `r` | シアン平均を R までに。**Cyan 既定** |
| 1 | Max | `r` | Coupled では Average と同型。差は Fine Tune と Independent |
| 2 | Double Blue | `r` | Coupled では差が小さい。**Independent で Double 系が本領** |
| 3 | Double Red | `r` | 同上（R 基準） |
| 4 | Limit Blue | `min(g, b)` | 狭い方に平均を合わせる。強い Coupled |
| 5 | Limit Red | `r` | Average と同じ lim。名前は Green 族と揃える |

Coupled は参照が主に R だけなので、Green の6式ほど差が出ない。**Cyan での式の差は主に ID0/4、Fine Tune、Cyan Mode=Independent**。Tooltip で Independent を勧める。

#### Independent（緑式＋青式を同時）

同じ Algorithm ID で、Green 用の上限制限と Blue 用の上限制限を両方適用（順序: 先に G、次に B。または同時に元 `rgb` から計算して合成）。

例 Average Independent:

```
g2 = min(g, (r+b)/2);
b2 = min(b, (r+g)/2);  // g は元の g を使う（同時計算）
```

これでシアンのかぶりを両翼から削る。Double / Limit も A1 の読替表どおり両側に適用。

#### Cyan Mode コントロール

| Control | 内容 |
|---------|------|
| **Cyan Mode** | Popup: **Coupled**（既定）/ **Independent**。Screen=Cyan のときだけ有効（`UIConditionValue="2"` Disable） |

### A3. Custom — Green に揃えてから Green 式

やることは Green と同じ: **幕色チャンネルが他チャンネルを超えた分だけ切る。** ピックが Green でないときは、等ウェイトグレー軸まわりに色相を回してから同じ式を使う。HSV 分解（S を切る等）ではない。`adsk_rgb2hsv` も使わない（linear で色相が不安定）。

```
k   = max(spill_colour, 0)
ang = chroma_angle(Green) - chroma_angle(k)   // 平面は (1,1,1) に直交
limited = rotate(-ang, limit_green(rotate(ang, rgb)))
```

`limit_green` は Screen=Green と同一（Algorithm + Fine Tune）。Cyan Mode は使わない。

| ピック | 実質 |
|--------|------|
| `(0,1,0)` 緑 | 回転 0°。Screen=Green と同一 |
| `(0,0,1)` 青 | 240°。Green 式が Blue 相当になる |
| 幕から拾った緑 | 数度だけ回してから Green 式。肌は通常 `g ≤ cap` で無処理 |
| グレー／黒 | chroma が無いので無処理 |

軸投影（`dot(rgb, normalize(key))` を残差長で切る）はデスピルではない。肌の G は輝度成分が大きく、幕色方向へ一括で削られてマゼンタになる。

Fine Tune は Green と同じ向き（0.5 が強く、1.5 が弱い）。既定ポットは `(0, 1, 1)`。

### B. 置換・仕上げ（全 Screen / Algorithm 共通）

`spill_amt = adsk_getLuminance(spill_pos)`。`spill_pos = max(orig - limited, 0)`（チャンネルごと）。`max(..., 0)` は **復元量の符号だけ**。display clamp ではない。

Luma / Colour / Background は **加算で共存**（Popup で排他しない）。

```
restored = limited
         + vec3(luma * spill_amt)
         + replace_colour * colour * spill_amt
         + back.rgb * background * spill_amt
```

| 項 | 既定 | 意味 |
|----|------|------|
| Luma | 0.5 | グレー埋め。0 でオフ |
| Colour | 1 | Replace Colour の倍率。黒ポットは加算ゼロ |
| Background | 1 | Back の倍率。0 でオフ |

全部 0 が埋めなし。既定は Luma 0.5、Colour 1・黒、Background 1。Back 未接続と黒ポットでは Luma だけが効く。

Back 未接続: Matchbox は検出できない。`NoInput="Black"` → Background を上げても加算ゼロ。Luma への自動フォールバックはやらない。

### C. 次の版

| 族 | 内容 |
|----|------|
| Red screen | 単チャンネル R |
| 空間スピル | Batch 側 |

## 処理順（固定）

Amount を式の中と外で二重に掛けない。

```
1. limited  = algorithm(orig, fine_tune)     // amount は掛けない
2. restored = replace(limited, orig, back)
3. result   = mix(orig, restored, amount * matte.r)
```

`clamp(rgb, 0, 1)` はどの段でもしない。Mix は Amount と冗長なため外した。

### Fine Tune（全 Algorithm）

単チャンネル: `g' = min(g, fine_tune * cap)`。`cap` は Algorithm の上限（Average なら `(r+b)/2`）。1.0 が式どおり。0.5–1.5。

Cyan Coupled も同じ: `lim *= fine_tune` のあと factor を計算。**factor の mix に amount を入れない**（上の段 3 で掛ける）。

Custom: 回転後の `limit_green` が Fine Tune を使う。

### View

| View | 値 | 出力（clamp しない） |
|------|----|----------------------|
| Result | 0 | `result`（段 3） |
| Spill | 1 | `spill_pos = max(orig - limited, 0)`。埋める量（非負） |
| Diff | 2 | `orig - limited`（符号あり） |

Spill / Diff は Amount / Replace の前の診断。ホスト側の表示に任せる。

単チャンネルの `min` と Cyan Coupled の factor≤1 では、**Spill と Diff は同じ絵**。Custom は回転を挟むので Diff に符号が出ることがある。

## 入力

| Socket | 用途 |
|--------|------|
| Front | 必須 |
| Back | 任意。Replace Background。未接続 Black |
| Matte | 任意。Amount マスク。未接続 White |

ソケット順は Front → Back → Matte（XML `Index` 0, 1, 2）。

`MatteProvider="False"`。

## linear 前提（Clamp 禁止）

**想定パイプラインは scene-linear / unclamped float**（Float16 / Float32）。log 変換はしない。表示レンジへの押し込みはしない。

| やる | やらない |
|------|----------|
| スピル上限の `min(g, lim)` / `max(r,b)` など **アルゴリズム内の比較** | `clamp(rgb, 0.0, 1.0)`、巨大な display clamp（`crok_ibk` 系） |
| `>1` の highlights・`<0` の負値を通す | 出力を非負に強制する最終 clamp |
| 復元量だけ `max(front - limited, 0)` | 中間バッファを 0–1 に丸める |

理由: linear 素材（ACES / scene-referred）では 1 超えが正規。0–1 clamp はハイライトと負のマット周辺を壊す。`crok_ibk` との差別化でもある（IBK 減算＋重い clamp ではなく、式ベース・unclamped）。

実装メモ:

- 出力ビット深度は Flame の Front に合わせる想定。シェーダ側で 0–1 に正規化しない
- View=Spill / Diff も値域を clamp しない（可視化はホスト側）
- コメント・変数名で `clamp` を避け、`limited` / `despilled` を使う（アルゴリズムの `min` と混同しない）

## Flame / LOGIK との役割

| 手段 | 向くこと |
|------|----------|
| Master Keyer Spill | 一体型・インタラクティブ |
| `AFX_DeSpill` | Average 単色のみ |
| `crok_ibk` | IBK 減算＋display 寄りの clamp が多い |
| DespillMadness | 複数式の先例 |
| **embr_despill** | Green/Blue/**Cyan**/Custom、6 Algorithm、Coupled/Independent、Replace、View、**linear / no display clamp** |

## Matchbox UI（複数アルゴリズム＋シアン）

- シングルパス。クラシック GLSL。`#version` なし
- Screen: **Green / Blue / Cyan / Custom**

| Control | Type | Default | 内容 |
|---------|------|---------|------|
| Screen | Popup | Green | Green / Blue / Cyan / Custom |
| Algorithm | Popup | Double Blue | 0–5。Custom でも Green 式として使う |
| Cyan Mode | Popup | Coupled | Coupled / Independent。Screen=Cyan のときだけ **Hide**。Spill Colour と同じ Row/Col |
| Spill Colour | vec3 Colour | (0,1,1) | Screen=Custom のときだけ **Hide**。Green に色相揃え |
| Fine Tune | float | 1 | 0.5–1.5 |
| Luma | float | 0.5 | グレー埋め。Colour / Background と加算 |
| Colour | float | 1 | Replace Colour の倍率。黒ポットは加算ゼロ |
| Replace Colour | vec3 Colour | 黒 | Colour > 0 のとき |
| Background | float | 1 | Back の倍率。未接続は加算ゼロ |
| Amount | float | 1 | 0–1。× Matte。0 は原画 |
| View | Popup | Result | Result / Spill / Diff |

UI 列: Screen（Screen / Algorithm / Cyan Mode または Spill Colour / Fine Tune）、Replace、Output（Amount / View）。

Screen: Green=0, Blue=1, Cyan=2, Custom=3。Cyan Mode と Spill Colour は Row 2 Col 0 を共有。`UIConditionType="Hide"`。Mix は Amount と冗長なので入れない。

GLSL は `if (screen == …)` / `if (algorithm == …)` 分岐。動的配列禁止。早期 `return` 禁止。

## 色空間

作業空間のまま（log 変換しない）。**scene-linear / unclamped 前提**（上節）。次の版で API にある log/scene トグル可。

## やらないこと（初版）

- キー生成、IBK、空間ブラー
- LOGIK/Nuke の無断再配布
- サウスシーの固定 sRGB ハードコード
- サウスシー布を Blue 単チャンネルとして実装すること
- Algorithm を 3 つに潰すこと
- HSV / YUV をデスピル式にすること（チャンネルを切る方式は試して廃止。Custom の色相揃えはグレー軸の回転）
- **`clamp(rgb, 0, 1)` や display レンジへの押し込み**（linear 素材向け）

## 差別化

- シアン／サウスシーを **二チャンネル公式**で持つ（B 流用だけにしない）
- Coupled（比率維持）と Independent（G+B 式の併用）を切り替え
- 6 Algorithm + Replace + View
- **linear / unclamped**（`crok_ibk` の重い clamp・`AFX_DeSpill` の単式と差別化）

## 実装優先度

シングルパスで式分岐が主。

| 段階 | 内容 | 状態 |
|------|------|------|
| v1 | **Green のみ**。Algorithm 6、加算 Replace、View、Fine Tune、Amount | 済（Mix は後で外した） |
| v2 | Blue（読替表） | 済 |
| v3 | Cyan（Coupled / Independent）。Screen Popup | 済 |
| v4 | Custom（色軸 + Spill Colour） | 済 |
| v5 | South Sea 項目を削除。Cyan Mode は Cyan 以外 Disable | 済 |
| v6 | UI 列整理。既定 Algorithm=Double Blue、Colour=1・黒、Background=1 | 済 |
| v7 | Custom Mode Axis / HSV / YUV。Hue Width | 試して廃止 |
| v8 | HSV / YUV 削除。Custom は Axis のみ | 済。`shaders/embr_despill/` |
| v9 | Custom を等ウェイト chroma 軸に変更 | 全色で効かなくなったので破棄 |
| v10 | Custom: `normalize(SpillColour)` + `length(remainder)` | マゼンタ寄りになり破棄 |
| v11 | Custom: グレー軸で Green に色相揃え → `limit_green` → 戻す | 済 |

状態: **Green / Blue / Cyan / Custom。** Mix なし。linear / Clamp 禁止は全段階共通。

## v5 実機チェック

- CreateRenderGraph が出ない
- Screen は Green / Blue / Cyan / Custom のみ（South Sea 項目なし）
- Algorithm 6 択。Blue で Double/Limit の読替が効く。Custom でも Green 式として効く
- Cyan Mode は Cyan のときだけ操作できる。Green / Blue / Custom では Disable
- Custom: Spill Colour を幕色に合わせる。グレー／黒は無処理。Green と同じ Algorithm / Fine Tune。画面全体がマゼンタに寄らない
- Fine Tune 0.5 は強く、1.5 は弱い
- Amount × Matte.r。未接続 Matte は全画面。Mix は無い
- Replace は Luma / Colour / Background が加算で共存。全部 0 が埋めなし。Back 未接続 + Background は加算ゼロ
- View Spill / Diff。Amount Replace を動かしても診断が変わらない
- ハイライト >1 が潰れない（display clamp なし）

## 実機で決める数値（未決）

| 項目 | 仮 |
|------|-----|
| Green 既定 Algorithm | Double Blue |
| Cyan 既定 Algorithm | Double Blue |
| Cyan 既定 Cyan Mode | Coupled |
| Fine Tune / Luma / Colour / Background / Amount | 1.0 / 0.5 / 1.0 / 1.0 / 1.0 |
| Replace Colour | 黒 |

実プレートで Coupled vs Independent、サウスシー布は Cyan と Custom の差を確認する。

## 参考リンク

- Ben McEwan, Deconstructing Despill Algorithms: https://benmcewan.com/blog/understanding-despill-algorithms
- Autodesk Community, advanced keying / spill suppression: https://forums.autodesk.com/t5/flame-forum/advanced-keying-spill-suppression/td-p/4270497
- LOGIK: AFX_DeSpill, crok_despill
- サウスシーブルー布: MAGIC HAND FRN-SSB、越後屋スタジオ等
