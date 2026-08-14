# embr_despill（検討メモ・未実装）

表示名案: **Embr Despill**。グリーンバック / ブルーバック / サウスシーブルーの色かぶり（スピル）除去。

キー抜き（マット生成）はしない。マットは上流の Master Keyer / 3D Keyer 等を前提。Fill 用 Front のスピルだけを直す。

関連: [README.md](README.md)、[gotchas.md](../api/gotchas.md)、LOGIK `AFX_DeSpill` / `crok_despill`（参考。コピーしない）。

## 背景色の整理

| 名称 | 実態 | スピルの主成分 | 備考 |
|------|------|----------------|------|
| グリーンバック | 一般的な chroma green | **G** | センサー感度が高く明るい。金髪・肌に緑が乗りやすい |
| ブルーバック | 一般的な chroma blue | **B** | 緑物・低照度向き。青スピルは影に紛れやすい |
| サウスシー | **サウスシーブルー**（日本のクロマキー布ブランド色。MAGIC HAND FRN-SSB 等） | **B 寄り、シアン寄りになりやすい** | 規格 RGB は公開されていない。ロットで少し違う。青系統として扱うが、クラシックブルーより G 成分が乗ることがある |

サウスシーを「第3の軸」として独立アルゴリズムにするより、**Blue プリセット + Balance（シアン寄り）**、または **Key Color ピック**の方が現場のばらつきに耐える。

Flame 本体: Master Keyer の Spill / Colour Suppression が定番（LOGIK でも「抑制は Master Keyer」派が多い）。Matchbox で出す価値は、**再現可能な式・Spill マット出力・BG への色置換・Batch で Keyer と分離**。

## 定番アルゴリズム（画素単位・Matchbox 向き）

出典の骨格: Ben McEwan *Deconstructing Despill Algorithms*、DespillMadness / `bm_Despill`、LOGIK `AFX_DeSpill`（Average 系）。いずれも **スピル色チャンネルを他チャンネルから組み立てた上限にクランプ**する。

表記: 入力 `rgb`。スクリーンが Green のとき処理対象は `g`。Blue / サウスシーでは対象を `b` に読み替える。

| 名前 | Green スクリーン時の式（概念） | 性質 |
|------|--------------------------------|------|
| **Average** | `g' = min(g, (r+b)/2)` | 肌を残しやすい。`AFX_DeSpill` と同系。既定候補 |
| **Max** | `g' = min(g, max(r,b))` | より強く落とす。暗い／マゼンタ寄りになりやすい |
| **Double Blue Avg** | `g' = min(g, (r+2*b)/3)` | 青を厚めに参照。緑落ちがマイルド |
| **Double Red Avg** | `g' = min(g, (2*r+b)/3)` | 赤を厚め。肌・暖色向きのことが |
| **Limit Blue** | `g' = min(g, b)` | 単純・暗く赤寄り。輝度復元とセットが前提 |
| **Limit Red** | `g' = min(g, r)` | 同上 |

Blue スクリーン（およびサウスシー既定）:

| 名前 | 式（概念） |
|------|------------|
| Average | `b' = min(b, (r+g)/2)` |
| Max | `b' = min(b, max(r,g))` |
| Double Green Avg | `b' = min(b, (r+2*g)/3)` |
| Double Red Avg | `b' = min(b, (2*r+g)/3)` |
| Limit Green / Limit Red | `b' = min(b, g)` / `min(b, r)` |

**Balance**（0–1）で Average と Max の閾値を混ぜる、または Double の重みを連続化するのが UI として分かりやすい。

```
// Green, Balance: 0 = Average 寄り, 1 = Max 寄り（例）
limit = mix((r+b)*0.5, max(r,b), balance);
g2 = min(g, limit);
```

**Amount**（0–1）: `g_out = mix(g, g2, amount)`。部分適用。

### サウスシー向け

1. **Screen = South Sea** → 内部は Blue と同じ式。Balance の既定を **シアン寄り**（例: Double Green Avg 側、または Balance を Average より少し Max/Green 参照に）にするだけ。Tooltip に「South Sea Blue fabric; tweak Balance if the plate is more cyan」。
2. **Screen = Custom** → ピックした `key_color` に対し、スピル量をキー色方向の超過分として取る（下の「軸デスピル」）。ロット差・照明で色がずれたときに使う。

軸デスピル（初版に入れるか未決。入れるなら Mode の一つ）:

```
// 概念。クラシック GLSL で可
spill_axis = normalize(key_color - luminance(key)*vec3(1)); // またはキーから灰を引いた方向
excess = max(0, dot(rgb - gray, spill_axis));
rgb2 = rgb - excess * spill_axis * amount;
```

厳密な正規化は log/lin で変わる。初版は **チャンネルクランプ（Green/Blue/SouthSea）を本線**、Custom 軸は次の版でもよい。

## スピル差分と輝度復元（推奨ワークフロー）

チャンネルを落とすだけだと縁が暗く・補色（緑→マゼンタ、青→黄）に寄る。McEwan / Autodesk フォーラム（Hugo 系セットアップ）と同じ流れを 1 ノードに載せる。

1. `despilled` = 上のクランプ結果  
2. `spill = abs(front - despilled)`（または `front - despilled` を clamp）  
3. **Luma restore**: `spill_luma = luminance(spill)`（または desaturate）を `despilled` に加算  
4. 任意で `spill_luma` に Grade（gain）や、**Back** を乗算して縁色を BG に寄せる（`crok_despill` / additive 系の考え方）

Matchbox 入力案:

| Socket | 用途 |
|--------|------|
| Front | 必須。キー前プレート |
| Matte | 任意。Amount のマスク（白=フル despill）。未接続 White |
| Back | 任意。縁のスピル色を BG に置換するとき。未接続は輝度復元のみ |

`crok_despill` は Front/Back/Matte/既に Despilled の合成ハブ。Embr は **自分で despill する**側。役割が違う。

## Flame / LOGIK との役割分担

| 手段 | 向くこと |
|------|----------|
| Master Keyer Spill | インタラクティブ、キーと一体。LOGIK で抑制の本命とされることが多い |
| MasterGrade Hue vs Sat | 抑えすぎの補正 |
| `AFX_DeSpill` | 単純 Average 系。肌向き。MIT ではない想定で参考のみ |
| `crok_despill` | 既に despilled した素材と BG の LogicOps 組み立て |
| **embr_despill** | 式を固定・再現、Spill マット出力、Green/Blue/SouthSea プリセット、Batch で Keyer と分離 |

Embr は Master Keyer の置き換えではなく、**式が見える補完ツール**。

## Matchbox 実装方針（採用しやすい形）

- **シングルパス**。近傍サンプリングなし → Median / Morph より軽い。`adsk_degrade` は不要でもよい（付けるなら Amount を落とす程度）
- クラシック GLSL。`#version` なし
- スクリーン: Popup `Green` / `Blue` / `South Sea`（内部 Blue + Balance 既定差）/ 任意で後から `Custom`
- Algorithm: Popup `Average` / `Max` / `Double A` / `Double B` / `Limit A` / `Limit B`（ラベルはスクリーンに応じて「Double Blue」等に動的変更は XML では難しいので、**固定英語ラベル + Tooltip**、または Algorithm を Average/Max/Weighted の3つに減らして Weight スライダ1本）
- Amount, Balance, Restore（輝度復元量）, Mix
- 出力: RGB。オプションで Spill をアルファに載せるか、**第2出力が無い Matchbox では View モード**（Result / Spill Matte / Diff）を Popup で切替

UI を減らす初版案:

| Control | 内容 |
|---------|------|
| Screen | Green / Blue / South Sea |
| Algorithm | Average / Max / Soft（= Double 他チャンネル平均） |
| Amount | 0–1 |
| Balance | 0–1（閾値の混ぜ、または Soft の重み） |
| Restore | 0–1（スピル輝度の戻し） |
| Mix | 0–1 |
| View | Result / Spill / Diff |

入力: Front, Matte(Strength 相当), Back 任意。

`MatteProvider="False"`。アルファは触らない（親からパススルー）。

## 色空間

Morph と同じく **作業空間のまま**（log 変換しない）。log プレートでは Average の見えが変わる。Tooltip: “Works in the working space of the Front; grade before/after as needed.”  
次の版: `adsk_log2scene` / `adsk_scene2log` トグル（API docs に載っているものだけ）。

## やらないこと（初版）

- キー生成・コア／エッジマット
- IBK / clean plate 生成（別シェーダ）
- 空間ブラー付きスピル（Pixel Spread 連携は Batch 側）
- LOGIK / Nuke gizmo の移植・クレジットなし再配布
- サウスシーの固定 sRGB 数値をハードコード（生地・ロット依存）

## 既存ツールとの差別化メモ

- `AFX_DeSpill`: Average のみ、G/B/R。Embr は Algorithm + Restore + South Sea プリセット + View
- Master Keyer: 高機能だが式がブラックボックス。Embr はドキュメント化された式
- サウスシー: 国内スタジオで Grean と並ぶ布。Blue 一択 UI だと Balance を毎回いじる必要があるのでプリセット名を出す価値がある

## 実装優先度（リポジトリ全体）

画像処理シリーズ（median / tophat）とは別系統。キーイング需要が先なら **median と並行して仕様を固められる**（依存なし・シングルパスで実装も短い）。

状態: **検討済み・仕様は初版 UI まで仮決め・未実装**。実装前に Screen プリセットの実プレート（Green / Blue / サウスシー）で Average vs Max vs Soft を見比べ、South Sea の Balance 既定だけ数値確定する。

## 実機で決める数値（未決）

| 項目 | 仮 |
|------|-----|
| South Sea の Algorithm 既定 | Soft（Double Green 側） |
| South Sea の Balance 既定 | 0.35（Green の Average=0 より強め） |
| Restore 既定 | 0.5 |
| Amount 既定 | 1.0 |

## 参考リンク（出典）

- Ben McEwan, Deconstructing Despill Algorithms: https://benmcewan.com/blog/understanding-despill-algorithms
- Autodesk Community, advanced keying / spill suppression（Master Keyer → FrontCC → LogicOps）: https://forums.autodesk.com/t5/flame-forum/advanced-keying-spill-suppression/td-p/4270497
- LOGIK: AFX_DeSpill, crok_despill; forum “favorite green screen keying”
- サウスシーブルー布: MAGIC HAND FRN-SSB、越後屋スタジオ等のクロマキー説明（グリーンとサウスシーブルー並記）
