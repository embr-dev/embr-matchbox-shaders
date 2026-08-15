# embr_pixelspread（検討メモ・未実装）

表示名案: **Embr Pixel Spread**。キー縁の汚れた色を直し、透明／低 α 側へ **前景色を押し出す**（Edge Extend 族）。

関連: [README.md](README.md)、[embr_holefill.md](embr_holefill.md)（α 修理・別物）、[embr_morphology](../../shaders/embr_morphology/README.md)、下節の **別シェーダ候補**。

状態: **方向性確定・UI は未詰め・未実装**（2026-08-15）。

---

## 意図と非スコープ

| やる | やらない（本シェーダ） |
|------|------------------------|
| 縁の RGB を内側のきれいな色で伸ばす | マット穴の α 埋め → **embr_holefill** |
| ソフトマット縁のスピル色・MB 汚染の軽減 | 任意サイズの色 Solidify → **別シェーダ**（下節） |
| Premul / Unpremul を明示 | 本格 Inpaint / Push–Pull ピラミッド |

用途の主眼は Nuke EdgeExtend / LOGIK Pixel Spread / `crok_matte_edge` の色押し出し側。

---

## 統合するアルゴリズム（1 ノード）

入出力・Size・Mix・Detail・Premul が共有できるものだけ Mode で併置する。

| Mode（仮） | 系統 | 概要 |
|------------|------|------|
| **Dilate** | Morph Max/Min | α／輝度を重みに近傍 RGB を拡張。安価・定番 |
| **Blur** | Blur + Unpremult | premul ぼかし → α で割る（古典 Pixel Spread） |
| **Stretch** | Gradient advect | α 勾配方向にサンプルをずらす |
| **Smear** | Gradient 系の強い版 | Stretch より長くにじませる |
| （任意）**Erode Push** | Erode→押し戻し | コアを削ってから外へ戻す簡易 EdgeExtend |

共通後段（Mode 非依存）:

- **Detail Restore** — extend 後に原画を min/max または軽い周波数戻し
- **Premultiply in / out** — 入出力の premul 前提トグル
- **Edge Mask** 出力（View または A）— 縁だけ別処理用
- **Mix** / Selective

参考（コピーしない）: Nuke EdgeExtend、VectorExtendEdge、`crok_pixelspread` / `crok_matte_edge`（Spread Type）、Ls_Dilate、LOGIK フォーラムの blur+divide 説明。

---

## 処理の骨格（仮）

```
src_rgb, src_a = front (+ matte override)
work = IsPremultiplied ? src : src_rgb * src_a   // 作業は premul 寄りが扱いやすいことが多い

extended = switch(mode):
  Dilate  → morph_max_color(work, radius, guided_by_a)
  Blur    → blur(work) ; unpremult_safe
  Stretch → sample(work, uv - amount * grad(a))
  Smear   → 同上（距離・減衰違い）

extended = detail_restore(extended, front, detail_amount)
out_rgb  = PremultiplyOut ? extended.rgb : unpremult_safe(extended)
out      = mix(front, out_rgb(+a), mix * selective)
```

数式・パス数は実装前に確定。Blur は分離ガウシアン、Dilate は Morph 短半径または既存 morph パターン流用。

**linear / unclamped**: 表示 `clamp(rgb,0,1)` はしない（grade / despill と同じ）。`unpremult_safe` は α≈0 の除算ガードのみ。

---

## UI（方向のみ・未確定）

| 列 | コントロール案 |
|----|----------------|
| Setup | Mode、Is Premultiplied、Premultiply Out、Mix、View（Result / Source / Edge Mask / Diff） |
| Spread | Size / Amount、Aspect、（Stretch/Smear 時）Edge Width、Detail Amount |
| Matte | Source Alpha / Matte / Inverted 系（Nuke EdgeExtend に近い選択） |

主操作は **Mode + Size + Detail**。マット整形（Gamma/Erode/Blur の Matte Edge 本体）は本ノードの主目的にしない。

入力: Front 必須、Matte 任意、Selective 任意。`MatteProvider` は要検討（既定 False 寄り。Edge Mask を A に載せるなら要実機）。

---

## 別シェーダとして検討するもの（併記）

本メモのスコープ外。必要ならそれぞれ独立メモ／実装にする。

| 仮名 | 内容 | 分ける理由 | 関連 |
|------|------|------------|------|
| **embr_solidify**（仮） | JFA / 最近傍で透明部に色をコピー・補間 | パス数 8–12+。任意サイズ穴の **色埋め**が主目的。縁の微調整 UI と合わない | `embr_distance` と一体または直後 |
| **embr_matte_edge**（仮） | マットの Erode/Blur/Gamma／幅・ソフト | 主出力がマット。色スプレッドはオプションに過ぎない | holefill / morph と役割分担 |
| **embr_edge_push**（仮） | 法線・距離からベクトル場を作り本格ワープ | 中間パス・変位が本体。薄い Spread Mode に載せると肥大化 | Stretch で足りなければ分離 |
| （作らない）Push–Pull ピラミッド | ミップ多解像度穴埋め | Matchbox の RT モデルと相性が悪い | — |
| （作らない）本格 Inpaint | Telea / PatchMatch 等 | リアルタイム枠外 | — |

### holefill / solidify / pixelspread の役割分担

| シェーダ | 主に直すもの |
|----------|----------------|
| **embr_holefill** | **α（カバレッジ）**の穴・ゴミ。ソフトエッジ保持 |
| **embr_pixelspread** | **RGB** を縁の外／低 α へ伸ばす（縁色直し） |
| **embr_solidify**（別検討） | 透明領域への **RGB 最近傍埋め**（大穴・プレート穴） |
| **embr_distance**（概要） | 距離場。solidify / holefill v2 の基盤 |

---

## 実装優先度

- grade / median と独立。Morph・分離ブラーがあれば Phase 1 は現実的
- 初版 Mode: **Dilate + Blur** を先に、Stretch/Smear はすぐ後
- solidify / matte_edge / edge_push は **本シェーダ完成後に別検討**（このメモの表を更新）

## やらないこと（本シェーダ）

- JFA Solidify の内蔵
- マット専用 Edge ツールのフル再現を主目的にすること
- LOGIK / Nuke の無断再配布
- 表示レンジ clamp

## 次のステップ

1. Mode 一覧と処理順を疑似コードで固定  
2. Dilate / Blur のパス数見積もり  
3. UI を holefill 並みに確定してから実装  
