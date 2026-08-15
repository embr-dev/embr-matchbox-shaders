# embr_color_warper（仕様）

表示名: **Embr Color Warper**。YUV クロマ平面のガウス重みカラーワーパー。キーなし。Baselight XGrade の「特定色を破綻少なく動かす」思想の Matchbox 近似。EAB / T-CAM は使わない。旧仮名 `embr_pivot`。

状態: **実装**（2026-08-15）。`shaders/embr_color_warper`。シングルパス。1 ピボット + 1 ピン + ASC CDL。複数はノード重ね。

関連: [shaders/embr_color_warper](../../shaders/embr_color_warper/README.md)、[shader-api.md](../api/shader-api.md)（`adsk_rgb2yuv` / `adsk_yuv2rgb` / `adsk_getLuminance`）、[embr_grade.md](embr_grade.md)。

## 式

```
yuv = adsk_rgb2yuv(rgb)
p   = adsk_rgb2yuv(pivot)
n   = adsk_rgb2yuv(pin)
w_move = 0
w_pin  = 0
if (falloff > 1e-6)
    w_move = exp(-0.5 * (length(yuv.yz - p.yz) / falloff)^2)
if (pin_falloff > 1e-6)
    w_pin = exp(-0.5 * (length(yuv.yz - n.yz) / pin_falloff)^2)
w   = w_move * (1 - w_pin)

cdl = ASC CDL(src)     // sop = src * slope + offset; pow if sop > 0; sat around luma
rgb = mix(src, cdl, w)
yuv = adsk_rgb2yuv(rgb)
Y'  = Y * exp2(exposure * w)
uv' = rotate(uv, hue * w) * mix(1, saturation, w)
rgb = adsk_yuv2rgb(Y', uv')
out = mix(src, rgb, mix_amount * selective.r)
```

Preview オン: シアン = Pin、赤 = ワープ（Pin 後）。A は Front。Pin Width 0 はピン無効。既定は 0.08。Pin の既定色は Macbeth Light Skin（0.761, 0.588, 0.510）。CDL は identity（Slope 1 / Offset 0 / Power 1 / Sat 1）なら従来どおり。抜き出しレイヤーには掛けない。

`exp2(x)` は `exp(x * ln2)`。クラシック GLSL に `exp2` が無い場合に備えて `0.69314718` を使う。

## やらないこと

キーヤー、マット出力、3D スコープ、複数ピボット／複数ピンを 1 ノードに詰める、FilmLight 色空間の複製、表示 clamp。
