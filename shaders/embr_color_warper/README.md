# embr_color_warper

表示名: **Embr Color Warper**。YUV クロマ平面のガウス重みで、ピック色まわりだけ Hue / Exposure / Sat を動かす。**Pin** で別の色を固定する。**ASC CDL** は `mix(src, CDL(src), w)`。キーは切らない。

## Files

| File | Role |
|------|------|
| `embr_color_warper.glsl` | シングルパス |
| `embr_color_warper.xml` | UI |
| `embr_color_warper.glsl.png` / `.p` | サムネイル |

## Inputs

| Socket | Type | Notes |
|--------|------|--------|
| Front | Front | 必須 |
| Selective | Selective | 任意。R。Mix の乗数。未接続 White |

`MatteProvider="False"`。A は Front のまま。

## Controls

| Control | Values | Notes |
|---------|--------|--------|
| Pivot | vec3（既定 0, 0.5, 1） | ワープの中心色 |
| Width | 0–1（既定 0.12） | YUV クロマのガウス σ。0 は無効 |
| Pin | vec3（既定 0.761, 0.588, 0.510） | 固定する色。Macbeth Light Skin |
| Pin Width | 0–1（既定 0.08） | 固定のガウス σ。0 は無効 |
| Hue | −180–180°（既定 0） | グレーまわりの UV 回転。重み付き |
| Exposure | −4–4 stops（既定 0） | Y のみ。`exp2(exposure * w)` |
| Saturation | 0–4（既定 1） | UV スケール。1 は変化なし |
| Mix | 0–1（既定 1） | × Selective.r |
| Preview | bool（既定 off） | 赤＝ワープ（Pin 後）。シアン＝Pin。A は Front |
| Slope | vec3（既定 1,1,1） | ASC CDL。Page CDL |
| Offset | vec3（既定 0,0,0） | ASC CDL |
| Power | vec3（既定 1,1,1） | ASC CDL。負の SOP は pow しない |
| Saturation（CDL） | 0–4（既定 1） | SOP のあと。`adsk_getLuminance` |

## Notes

- `adsk_rgb2yuv` / `adsk_yuv2rgb`。T-CAM / EAB は使わない。
- ピボットは 1 つ、ピンは 1 つ。複数はノードを重ねる。
- 順: `w`（元のクロマ）→ CDL `mix(src, CDL(src), w)` → Hue / Exposure / Sat → Mix。
- 表示 `clamp(rgb,0,1)` はしない。
- 配置: フォルダごと `/opt/Autodesk/presets/2025/matchbox/shaders/EMBR/`（この Mac の検証場所）。
- `shader_builder -m` コンパイルは [OK]（2025 / macOS）。`.mx` はソースにしない。
