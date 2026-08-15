# embr_despill（検討メモ・未実装）

表示名案: **Embr Despill**。グリーンバック / ブルーバック / **シアン（サウスシー）**の色かぶり（スピル）除去。

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
3. **Axis** — ピック色／`normalize(vec3(0,1,1))` 方向の超過を引く（次の版でも可）

サウスシーは Screen プリセット **South Sea → 内部 Cyan**（Blue のエイリアスにしない）。

Flame: Master Keyer Spill が定番。Matchbox の価値は式の再現・複数 Algorithm・Cyan/South Sea 明示・Spill View・Keyer 分離。

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

### A2. Cyan / South Sea — 二チャンネル（初版から）

#### Coupled（シアン本線・既定）

```
avg = 0.5 * (g + b);
lim = <Algorithm が決める>;   // Fine Tune を掛ける
lim = lim * fine_tune;
factor = 1.0;
if (avg > lim && avg > 1e-6)
    factor = lim / avg;
g2 = mix(g, g * factor, amount * matte);
b2 = mix(b, b * factor, amount * matte);
r2 = r;
```

| ID | UI 名 | Cyan Coupled の `lim` | 意味 |
|----|-------|----------------------|------|
| 0 | Average | `r` | シアン平均を R までに。**Cyan / South Sea 既定** |
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
| **Cyan Mode** | Popup: **Coupled**（既定）/ **Independent**。Screen が Cyan または South Sea のときだけ意味がある（Green/Blue では無視または Hide） |

South Sea = Screen 値として Cyan と同じ分岐。Display 名だけ South Sea。

### B. 置換・仕上げ（全 Screen / Algorithm 共通）

| Replace | 内容 |
|---------|------|
| None | アルゴリズム適用のみ（表示レンジへの clamp なし） |
| Luma（既定） | `spill_pos = max(front - limited, 0)` → 輝度を `Restore` 倍で加算。最終 RGB は clamp しない |
| Colour | スピル量 × Replace Colour |
| Background | スピル量 × Back。未接続は Luma |

`spill_pos` の `max(..., 0)` は **復元量の符号だけ**（負のスピル差分を足さない）。入力の負値チャンネルや `>1` の highlights を落とすための display clamp ではない。

### C. 次の版

| 族 | 内容 |
|----|------|
| Axis / Key Color | `normalize(key - gray)` または固定 `normalize(vec3(0,1,1))`。ロットずれ・真シアンの微調整 |
| Hue suppress | キー色相の彩度落とし |
| Red screen | 単チャンネル R |
| 空間スピル | Batch 側 |

## Fine Tune / Amount

```
lim *= fine_tune;          // 0.5–1.5、1=式どおり
out = mix(orig, limited, amount * matte);  // limited = アルゴリズム適用後。clamp(rgb,0,1) しない
```

## 入力

| Socket | 用途 |
|--------|------|
| Front | 必須 |
| Matte | 任意。Amount マスク。未接続 White |
| Back | 任意。Replace=Background |

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
| **embr_despill** | Green/Blue/**Cyan·South Sea**、6 Algorithm、Coupled/Independent、Replace、View、**linear / no display clamp** |

## Matchbox UI（複数アルゴリズム＋シアン）

- シングルパス。クラシック GLSL。`#version` なし
- Screen: **Green / Blue / Cyan / South Sea**（South Sea は Cyan と同一コードパス）

| Control | Type | Default | 内容 |
|---------|------|---------|------|
| Screen | Popup | Green | Green / Blue / Cyan / South Sea |
| Algorithm | Popup | Average | 0–5（上表） |
| Cyan Mode | Popup | Coupled | Coupled / Independent（Cyan·South Sea 時） |
| Amount | float | 1 | 0–1 |
| Fine Tune | float | 1 | 0.5–1.5 |
| Replace | Popup | Luma | None / Luma / Colour / Background |
| Restore | float | 0.5 | |
| Replace Colour | vec3 Colour | | Replace=Colour |
| Mix | float | 1 | |
| View | Popup | Result | Result / Spill / Diff |

`UIConditionSource` で Cyan Mode を Screen=Cyan/South Sea のときだけ表示（xml-schema の条件付き UI。属性は docs に載っているものだけ）。

GLSL は `if (screen == …)` / `if (algorithm == …)` 分岐。動的配列禁止。早期 `return` 禁止。

## 色空間

作業空間のまま（log 変換しない）。**scene-linear / unclamped 前提**（上節）。次の版で API にある log/scene トグル可。

## やらないこと（初版）

- キー生成、IBK、空間ブラー
- LOGIK/Nuke の無断再配布
- サウスシーの固定 sRGB ハードコード
- South Sea を Blue 単チャンネルとして実装すること
- Algorithm を 3 つに潰すこと
- **`clamp(rgb, 0, 1)` や display レンジへの押し込み**（linear 素材向け）

## 差別化

- シアン／サウスシーを **二チャンネル公式**で持つ（B 流用だけにしない）
- Coupled（比率維持）と Independent（G+B 式の併用）を切り替え
- 6 Algorithm + Replace + View
- **linear / unclamped**（`crok_ibk` の重い clamp・`AFX_DeSpill` の単式と差別化）

## 実装優先度

median と独立。シングルパスで式分岐が主。

状態: **Cyan/South Sea は二チャンネル・linear（Clamp 禁止）で方針確定・未実装**。

## 実機で決める数値（未決）

| 項目 | 仮 |
|------|-----|
| Green 既定 Algorithm | Average |
| Cyan / South Sea 既定 Algorithm | Average |
| Cyan / South Sea 既定 Cyan Mode | Coupled |
| Fine Tune / Restore / Amount | 1.0 / 0.5 / 1.0 |

実プレートで Coupled vs Independent、South Sea で Blue 単体との差を確認する。

## 参考リンク

- Ben McEwan, Deconstructing Despill Algorithms: https://benmcewan.com/blog/understanding-despill-algorithms
- Autodesk Community, advanced keying / spill suppression: https://forums.autodesk.com/t5/flame-forum/advanced-keying-spill-suppression/td-p/4270497
- LOGIK: AFX_DeSpill, crok_despill
- サウスシーブルー布: MAGIC HAND FRN-SSB、越後屋スタジオ等
