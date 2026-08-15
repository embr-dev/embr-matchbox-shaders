# embr_despill

表示名: **Embr Despill**。Fill のスピル除去。キーは作らない。

Green / Blue / Cyan / Custom。display `clamp(rgb,0,1)` はしない。Mix は Amount と冗長なため外した。

## Files

| File | Role |
|------|------|
| `embr_despill.glsl` | シングルパス |
| `embr_despill.xml` | UI |
| `embr_despill.glsl.png` / `.p` | サムネイル（GLSL モード） |

## Inputs

| Socket | Type | Notes |
|--------|------|--------|
| Front | Front | 必須 |
| Back | Back | 任意。Replace Background。未接続 Black（加算ゼロ） |
| Matte | Matte | 任意。Amount の乗数（R）。未接続 White |

`MatteProvider` は False。

## Controls

| Control | Values | Notes |
|---------|--------|--------|
| Screen | Green（既定）, Blue, Cyan, Custom | Custom は Spill Colour を Green に揃えてから Green 式 |
| Algorithm | Average, Max, Double Blue（既定）, Double Red, Limit Blue, Limit Red | Green の上限。Blue は読替。Custom でも Green 式を使う |
| Cyan Mode | Coupled（既定）, Independent | Screen=Cyan のときだけ表示（Spill Colour と同じマス） |
| Spill Colour | vec3（既定 0,1,1） | Screen=Custom のときだけ表示。グレー／黒は無処理 |
| Fine Tune | 0.5–1.5（既定 1） | 上限の倍率 |
| Luma | 0–2（既定 0.5） | グレー埋め。0 でオフ |
| Colour | 0–2（既定 1） | Replace Colour × スピル。黒ポットは加算ゼロ |
| Replace Colour | vec3（既定 黒） | Colour > 0 のとき使う |
| Background | 0–2（既定 1） | Back × スピル。未接続 Back は加算ゼロ |
| Amount | 0–1（既定 1） | × Matte.r。0 は原画 |
| View | Result, Spill, Diff | 診断。Amount Replace 無視 |

Luma / Colour / Background は加算で共存する。既定は Luma 0.5、Colour 1・黒、Background 1。Back 未接続と黒ポットでは Luma だけが効く。

## Screen

| Screen | 制限 |
|--------|------|
| Green | `g' = min(g, FineTune * cap)` |
| Blue | `b' = min(b, FineTune * cap)`。Double Blue→Double Green、Limit Blue→Limit Green |
| Cyan Coupled | `(g+b)/2` が lim を超えた比率で G と B を同じだけ下げる。Average の lim は `r`。Limit Blue は `min(g,b)` |
| Cyan Independent | Green 式と Blue 式を元の RGB から同時に適用 |
| Custom | グレー軸まわりで Spill Colour の色相を Green に回し、`limit_green`（Algorithm + Fine Tune）して戻す。グレー／黒は無処理。Cyan Mode は使わない |

## View

| View | 出力 |
|------|------|
| Result | 仕上げ |
| Spill | `max(orig - limited, 0)`。埋める量（非負） |
| Diff | `orig - limited`。符号あり |

単チャンネルの `min` と Cyan Coupled の factor≤1 では、Spill と Diff は同じ絵になる。Custom は回転後に G だけ切るので、戻したあとの Diff は幕色方向（非負とは限らない）。

## 処理順

1. `limited`（Screen + Algorithm + Fine Tune。Cyan Mode。Custom は Spill Colour）
2. Replace（Luma + Colour + Background）
3. `mix(orig, restored, Amount * Matte)`

## Notes

- 作業空間のまま。log 変換なし。ハイライト >1 と負値を通す。
- 配置: フォルダごと `/opt/Autodesk/presets/2025/matchbox/shaders/EMBR/`（この Mac の検証場所）。
- `shader_builder -m` コンパイルは [OK]（2025 / macOS）。`.mx` はソースにしない。
