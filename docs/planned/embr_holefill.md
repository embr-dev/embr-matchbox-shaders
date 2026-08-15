# embr_holefill（検討メモ・未実装）

表示名案: **Embr Hole Fill**。キーマットの **内部穴・ゴミ**を直し、**ソフトエッジは残す**。

関連: [README.md](README.md)、[embr_morphology](../../shaders/embr_morphology/README.md)、将来の [embr_distance](README.md)（概要）。キー生成はしない。

## 意図（ユーザー案の読み）

現場でやりたいこと:

1. ソフトマット `m` から **コア（2値）**を切る
2. コアに対して穴埋め（足りなければモルフォロジー）
3. **輪郭帯だけ元の `m` に戻す**（シルエットのソフトを壊さない）

「Unpremultiply → 2値 →（Morph）→ 境界に元マスク」はこの意図の言い方として正しい。  
Matchbox 実装では次のように整理する。

## Unpremultiply について

- 穴埋めの対象は **カバレッジ（Matte / α）**。マット自体を unpremultiply する必要はない
- Front が RGB×α の premul なら、色の修復は別（Edge Extend / despill）。本シェーダの主出力は **直したマット**
- UI に Unpremultiply を出すなら「Front 色を α で割ってプレビュー」程度のオプションに留め、コア処理とは分離する

## 推奨パイプライン（初版）

ユーザー案より合成を単純化した版。多くの穴埋めでこれで足りる。

```
m      = matte.r;                    // または Front.a。Channel で選択
core   = step(threshold, m);         // 2値コア
filled = morph_close(core, radius);  // 穴・細い切れを埋める（半径 ≥ 穴の半分程度）
out    = max(m, filled);             // ソフトエッジ復元の最短形
out    = mix(m, out, amount);
```

### なぜ `max(m, filled)` で境界が残るか

| 領域 | `m` | Close 後の `filled` | `max` の結果 |
|------|-----|---------------------|--------------|
| 外部 | ≈0 | 0 | 0 |
| ソフトエッジ（`0 < m < threshold`） | ソフト | 通常 0 | **元のソフト** |
| ソリッド | 高 | 1 | 高 / 1 |
| 内部の穴（`m≈0` だが囲まれている） | ≈0 | **1**（Close が届く範囲） | **埋まる** |

Close（Dilate→Erode）は 2値シルエットの外周をだいたい元に戻すので、閾値より外のフォールオフは触らない。  
「境界に元をペースト」と同等で、エッジマスク生成が不要。

### ユーザー案（明示的エッジ復元）が向くとき

Close 以外でコア外形がずれる、または 2値結果で上書きしたいとき:

```
edge = smoothstep(0.0, edge_w, m) * (1.0 - smoothstep(1.0 - edge_w, 1.0, m));
// または |m - blur(m)| や dilate(core)-erode(core)
out  = mix(filled, m, edge);
```

初版は **`max` 合成を既定**。Edge Restore モードは次点。

## モード

| Mode | コア処理 | 合成 | 用途 |
|------|----------|------|------|
| **Fill Holes**（既定） | Close | `max(m, filled)` | 内部の黒穴・細い切れ |
| **Remove Specks** | Open | `min(m, opened)` | 外部の白ゴミ |
| **Both** | Close のあと Open（または逆。実機で順を決める） | 上に同じ | 穴＋ゴミ |
| **Core Replace** | Close/Open | 明示エッジ復元 or 全面 `filled` | 検証・ハードマット用 |

Speck は「穴埋め」の対。同じツールに入れてよい（閾値＋半径が共通）。

## モルフォロジー

- 既に `embr_morphology` がある。穴埋め専用は **マット1ch・Close/Open・半径小さめ**が主
- 実装選択肢:
  1. **本シェーダ内に短い分離 Close/Open**（パス数を抑える。Square/Line で十分）
  2. Batch で `embr_morphology` を前段に置き、本シェーダは threshold + `max`/`min` だけ（薄いラッパ）
- 推奨: **1 を初版**（1 ノードで完結）。Kernel は Square 既定、Circle は任意。Angle は不要なら隠す
- 穴の直径が `2 * Size` を超えると Close では埋まらない → Size を上げるか、v2 の位相的穴埋めへ

## 位相的穴埋め（v2・任意サイズの閉穴）

「外形に繋がっていない 0 領域だけ 1 にする」は **枠からの洪水**が本命。

- Matchbox では非有界フラッドフィルは非現実的（[README の作らないもの](README.md)）
- 近似: Jump Flood / 距離場で「背景（枠連結）」をラベルし、非背景かつ低 α を穴とみなす → `embr_distance` と連携する別モード
- 初版スコープ外。Size 付き Close で「最大穴サイズ」を明示する方がアーティストにも分かりやすい

## UI（案）

| Control | Type | Default | 内容 |
|---------|------|---------|------|
| Channel | Popup | Matte R | Matte R / Front A / Front R |
| Mode | Popup | Fill Holes | Fill Holes / Remove Specks / Both / Core Replace |
| Threshold | float | 0.5 | コア切り |
| Size | int | 2 | Close/Open 半径（px）。`adsk_degrade` で上限 |
| Amount | float | 1 | |
| Mix | float | 1 | 元マットとのブレンド |
| View | Popup | Result | Result / Core / Filled / Diff |

入力: **Matte 必須**（または Front の A）。Strength マットは任意（半径乗数）。  
`MatteProvider="True"` にするかは用途次第:

- マット修正ノードとして子へ渡すなら **True** を検討
- Morph と同様に親マットパススルーなら False＋出力は Front にマットを載せる

実機の Action / Batch での繋ぎ方を見て決める（未決）。

## やらないこと（初版）

- 本物のフラッドフィル / 連結成分 / 面積条件の Opening
- RGB エッジカラーの拡散（Edge Fill / extend）— 別シェーダ
- マットの unpremultiply を必須ステップにすること
- 巨大 Size の厳密 2D（Morph と同じく分離＋ degrade）

## 差別化

| 手段 | 差 |
|------|-----|
| `embr_morphology` Close | RGB/Luma 向き。ソフトエッジを閉じると輪郭が太る |
| **embr_holefill** | 閾値コアだけ Morph → `max`/`min` で **元のフォールオフを残す** |
| 手動 Batch | 同じことは組める。1 ノード化が価値 |

## 実装優先度

- median / despill と独立。Morph があるので **実装コストは低め**（分離 Close + 合成）
- 距離場穴埋めは `embr_distance` の後

状態: **方針案・未実装**。合成の既定は `max(m, close(threshold(m)))`。

## 実機で決めること

| 項目 | 仮 |
|------|-----|
| MatteProvider | 要実機 |
| Both の順 | Close→Open |
| Threshold 既定 | 0.5 |
| Kernel | Square |
| 大きな穴 | Size を上げる。位相的 fill は v2 |
