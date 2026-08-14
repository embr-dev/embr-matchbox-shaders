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

## 定番アルゴリズム（種類は多い・Matchbox 向き）

デスピルは「一つの正解」ではなく、**チャンネル超過をどう上限に落とすか**のバリエーション集です。Nuke の DespillMadness / `bm_Despill`、McEwan の解説、`AFX_DeSpill` はいずれも同じ一族です。Embr の方針は **アルゴリズムを Popup で全部選べる**こと（3つに減らさない）。

出典の骨格: Ben McEwan *Deconstructing Despill Algorithms*、DespillMadness / `bm_Despill`、LOGIK `AFX_DeSpill`（Average 系）。共通操作は **スピル色チャンネルを他チャンネルから組み立てた上限にクランプ**する。

表記: 入力 `rgb`。スクリーンが Green のとき処理対象は `g`。Blue / サウスシーでは対象を `b` に読み替える。

### A. チャンネルクランプ族（本線・初版で全部載せる）

| ID | 名前（UI） | Green スクリーン時の式（概念） | 性質 |
|----|------------|--------------------------------|------|
| 0 | **Average** | `g' = min(g, (r+b)/2)` | 肌向き。既定。`AFX_DeSpill` と同系 |
| 1 | **Max** | `g' = min(g, max(r,b))` | 強い。暗くマゼンタ寄り |
| 2 | **Double Blue** | `g' = min(g, (r+2*b)/3)` | 青を厚め。緑落ちがマイルド |
| 3 | **Double Red** | `g' = min(g, (2*r+b)/3)` | 赤を厚め。肌・暖色 |
| 4 | **Limit Blue** | `g' = min(g, b)` | 単純・暗い。Restore 前提 |
| 5 | **Limit Red** | `g' = min(g, r)` | 同上 |

Blue / South Sea では対象を `b` に替え、Double/Limit の「他方」を Green と Red に読み替える（下表）。

| ID | 名前（UI・固定英語） | Blue / South Sea 時の式 |
|----|----------------------|-------------------------|
| 0 | Average | `b' = min(b, (r+g)/2)` |
| 1 | Max | `b' = min(b, max(r,g))` |
| 2 | Double Blue → 実装では **Double Green** | `b' = min(b, (r+2*g)/3)` |
| 3 | Double Red | `b' = min(b, (2*r+g)/3)` |
| 4 | Limit Blue → 実装では **Limit Green** | `b' = min(b, g)` |
| 5 | Limit Red | `b' = min(b, r)` |

XML の Popup ラベルはスクリーンで切り替えられないので、**固定名 Average / Max / Double Blue / Double Red / Limit Blue / Limit Red** とし、Tooltip に「When Screen is Blue or South Sea, Double Blue means Double Green, Limit Blue means Limit Green」と書く。内部は `screen` で分岐。

**Fine Tune**（DespillMadness の LimitPercentage 相当、0.5–1.5 くらい）:

```
limit = computed_limit * fine_tune;
spill_ch = min(spill_ch, limit);
```

1.0 が式どおり。上げると緩め、下げると攻め。

**Amount**（0–1）: `out_ch = mix(orig_ch, clamped_ch, amount * matte)`。

### B. 置換・仕上げ（アルゴリズムの後段・全 Algorithm 共通）

クランプだけだと縁が暗く補色に寄る。McEwan / Autodesk フォーラムと同じ後処理を **Replaceモード**として載せる。

| Replace | 内容 |
|---------|------|
| **None** | クランプ結果のみ |
| **Luma**（既定） | `spill = front - despilled`（正の成分）→ 輝度化して `despilled` に `Restore` 倍で加算 |
| **Colour** | スピル量にユーザー色（または補色）を乗せて足す |
| **Background** | Matte/Spill 量 × Back（任意入力）。未接続時は Luma にフォールバック |

これが「アルゴリズムを変える」のもう一軸。同じ Average でも Replace で見えが変わる。

### C. 次の版で足せる族（初版は ID 予約または未実装でよい）

| 族 | 内容 | Matchbox |
|----|------|----------|
| **Axis / Key Color** | ピック色方向の超過を引く。サウスシーのロットずれ向き | シングルパスで可 |
| **Hue suppress** | キー色相の彩度を落とす（MasterGrade Hue vs Sat に近い） | HSV 手書き。可だが精度注意 |
| **Red screen** | 対象チャンネル R。Screen に Red を足すだけ | 式は Green と同じ骨格 |
| 空間的スピル | ブラー／Pixel Spread 連携 | Batch 側。シェーダ本体には入れない |

### サウスシー向け

1. **Screen = South Sea** → 内部は Blue と同じ式群。Algorithm 既定は **Double Blue（= Double Green）** または Average。Tooltip でシアン寄りを案内。
2. **Screen = Custom**（次の版）→ Key Color + Axis。

## スピル差分と輝度復元（推奨ワークフロー）

チャンネルを落とすだけだと縁が暗く・補色（緑→マゼンタ、青→黄）に寄る。McEwan / Autodesk フォーラム（Hugo 系セットアップ）と同じ流れを 1 ノードに載せる。

1. `despilled` = 上のクランプ結果  
2. `spill = max(front - despilled, 0)`（チャンネルごと、または対象チャンネルのみ）  
3. **Replace = Luma**: `despilled + Restore * vec3(luminance(spill))`  
4. **Replace = Background**: 上記の係数に Back を乗算（`crok_despill` / additive 系の考え方）

Matchbox 入力案:

| Socket | 用途 |
|--------|------|
| Front | 必須。キー前プレート |
| Matte | 任意。Amount のマスク（白=フル despill）。未接続 White |
| Back | 任意。Replace=Background のとき。未接続は Luma |

`crok_despill` は Front/Back/Matte/既に Despilled の合成ハブ。Embr は **自分で despill する**側。役割が違う。

## Flame / LOGIK との役割分担

| 手段 | 向くこと |
|------|----------|
| Master Keyer Spill | インタラクティブ、キーと一体。LOGIK で抑制の本命とされることが多い |
| MasterGrade Hue vs Sat | 抑えすぎの補正 |
| `AFX_DeSpill` | 単純 Average 系。肌向き。MIT ではない想定で参考のみ |
| `crok_despill` | 既に despilled した素材と BG の LogicOps 組み立て |
| DespillMadness / bm_Despill | Nuke で「アルゴリズム集合」の先例。Embr の UI モデル |
| **embr_despill** | 複数式を Popup で選択、Restore/Replace、Spill View、Green/Blue/SouthSea、Batch で Keyer と分離 |

Embr は Master Keyer の置き換えではなく、**式が見える・切り替えられる補完ツール**。

## Matchbox 実装方針（複数アルゴリズム前提）

- **シングルパス**。近傍サンプリングなし → Median / Morph より軽い
- クラシック GLSL。`#version` なし
- Screen: `Green` / `Blue` / `South Sea`（内部 Blue）。次の版で `Red` / `Custom`
- **Algorithm: 6 択を初版から全部**（Average / Max / Double Blue / Double Red / Limit Blue / Limit Red）。3 択に潰さない
- Fine Tune, Amount, Restore, Replace（None / Luma / Colour / Background）, Mix, View（Result / Spill / Diff）
- Colour Replace 用に `vec3 replace_color`（Colour ポット）

| Control | Type | Default | 内容 |
|---------|------|---------|------|
| Screen | Popup | Green | Green / Blue / South Sea |
| Algorithm | Popup | Average | 上表 0–5 |
| Amount | float | 1 | 0–1 |
| Fine Tune | float | 1 | 0.5–1.5、Inc 0.01 |
| Replace | Popup | Luma | None / Luma / Colour / Background |
| Restore | float | 0.5 | Replace が None 以外のとき効く |
| Replace Colour | vec3 Colour | 補色寄りの灰 | Replace=Colour |
| Mix | float | 1 | 0–1 |
| View | Popup | Result | Result / Spill / Diff |

入力: Front, Matte, Back 任意。`MatteProvider="False"`。

GLSL は `if (algorithm == 0) … else if …` で分岐（配列に式を載せるな）。`main()` 早期 return 禁止。

## 色空間

Morph と同じく **作業空間のまま**（log 変換しない）。log プレートでは Average の見えが変わる。Tooltip: “Works in the working space of the Front; grade before/after as needed.”  
次の版: `adsk_log2scene` / `adsk_scene2log` トグル（API docs に載っているものだけ）。

## やらないこと（初版）

- キー生成・コア／エッジマット
- IBK / clean plate 生成（別シェーダ）
- 空間ブラー付きスピル（Pixel Spread 連携は Batch 側）
- LOGIK / Nuke gizmo の移植・クレジットなし再配布
- サウスシーの固定 sRGB 数値をハードコード（生地・ロット依存）
- Algorithm を 3 つに減らして Weighted スライダ1本にまとめること（ユーザー要望は複数式の明示選択）

## 既存ツールとの差別化メモ

- `AFX_DeSpill`: Average のみ。Embr は 6 Algorithm + Fine Tune + Replace + View + South Sea
- DespillMadness: 同系統の「集合」UI。Embr は MIT・Flame Matchbox・サウスシープリセット
- Master Keyer: 高機能だが式がブラックボックス

## 実装優先度（リポジトリ全体）

画像処理シリーズ（median / tophat）とは別系統。キーイング需要が先なら **median と並行して仕様を固められる**（依存なし・シングルパスで実装も短い。式が増えても分岐だけ）。

状態: **複数アルゴリズム採用で方針確定・未実装**。実機では 6 式 × Green/Blue/SouthSea を見比べ、既定（Green→Average、South Sea→Double Blue）だけ確認。

## 実機で決める数値（未決）

| 項目 | 仮 |
|------|-----|
| Green の Algorithm 既定 | Average |
| South Sea の Algorithm 既定 | Double Blue（内部 Double Green） |
| Fine Tune 既定 | 1.0 |
| Restore 既定 | 0.5 |
| Amount 既定 | 1.0 |
| Replace 既定 | Luma |

## 参考リンク（出典）

- Ben McEwan, Deconstructing Despill Algorithms: https://benmcewan.com/blog/understanding-despill-algorithms
- Autodesk Community, advanced keying / spill suppression（Master Keyer → FrontCC → LogicOps）: https://forums.autodesk.com/t5/flame-forum/advanced-keying-spill-suppression/td-p/4270497
- LOGIK: AFX_DeSpill, crok_despill; forum “favorite green screen keying”
- サウスシーブルー布: MAGIC HAND FRN-SSB、越後屋スタジオ等のクロマキー説明（グリーンとサウスシーブルー並記）
