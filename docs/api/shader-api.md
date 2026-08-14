# Shader API（`adsk_*`）

`adsk_` で始まる名前は UI に出ない。位置・方向は **カメラ空間**（local × modelView）。

Lightbox 専用 API の詳細シグネチャは [lightbox.md](lightbox.md) も参照。

## Matchbox 専用 uniforms

各パスに無条件で渡される。必要なものだけ宣言して使う。

| 名前 | 型 | 意味 |
|------|-----|------|
| `adsk_result_w` / `adsk_result_h` | float | 出力解像度（px） |
| `adsk_result_frameratio` | float | 出力フレーム比 |
| `adsk_result_pixelratio` | float | 出力ピクセル比 |
| `adsk_results_pass{N}` | sampler2D | パス N の結果（1 始まり）。後続パスで宣言して通常どおり `texture2D` |
| `adsk_results_pass{N}_w` / `_h` | float | そのパス結果のサイズ |
| `adsk_previous_frame_{sampler}` | sampler2D | 前フレーム。**Action 内では不可** |
| `adsk_next_frame_{sampler}` | sampler2D | 次フレーム。**Action 内では不可** |
| `adsk_time` | float | タイムバー。1 始まり |
| `adsk_degrade` | bool | Adaptive Degradation 要求 |
| `adsk_{sampler}_w` / `_h` | float | その sampler の解像度 |
| `adsk_{sampler}_frameratio` / `_pixelratio` | float | その sampler の比 |
| `adsk_accum_texture` | sampler2D | 直前出力。時間方向エフェクト。Adaptive Degradation 対応が有効になる |
| `adsk_accum_no_prev_frame` | bool | 履歴なし。`adsk_accum_texture` と併用 |
| `adsk_texture_grid` | sampler2D | シェーダ同梱画像（ロゴ等） |

### 前・次フレーム

カレントの `{sampler_name}` を GLSL で宣言・使用している必要がある。XML 例（公式 TemporalSampling）:

```xml
<Uniform Type="sampler2D" Name="adsk_previous_frame_input1"/>
<Uniform Index="0" NoInput="Error" DisplayName="input1" Type="sampler2D" Name="input1" ... />
```

### `adsk_texture_grid` が読める形式

Alias, Cineon, DPX, jpeg, Maya, OpenEXR, Pict, Pixar, SGI, Softimage, Targa, Tiff, Wavefront。

## 色管理・色空間（Matchbox と Lightbox）

```glsl
vec3  adsk_scene2log(in vec3 src);   // scene linear → Cineon log
vec3  adsk_log2scene(in vec3 src);   // 逆
vec3  adsk_rgb2hsv(in vec3 src);
vec3  adsk_hsv2rgb(in vec3 src);
vec3  adsk_rgb2yuv(in vec3 src);
vec3  adsk_yuv2rgb(in vec3 src);
vec3  adsk_getLuminanceWeights();
float adsk_getLuminance(in vec3 color);

float adsk_highlights(in float pixel, in float halfPoint);
float adsk_shadows(in float pixel, in float halfPoint);
// midtones = 1.0 - adsk_shadows(...) - adsk_highlights(...)
```

`halfPoint` はカーブが 50% になる X。

### ダイナミックカーブ

XML で `ValueType="Curve"`（または `LargeCurve`）の int / ivec ハンドルを渡す。

```glsl
float adskEvalDynCurves(in int dynCurveId, in float x);
vec2  adskEvalDynCurves(in ivec2 dynCurveId, in vec2 x);
vec3  adskEvalDynCurves(in ivec3 dynCurveId, in vec3 x);
vec4  adskEvalDynCurves(in ivec4 dynCurveId, in vec4 x);
```

## ブレンド（Matchbox と Lightbox）

```glsl
vec4 adsk_getBlendedValue(int blendType, vec4 srcColor, vec4 dstColor);
```

| 値 | モード |
|----|--------|
| 0 | Add |
| 1 | Sub |
| 2 | Multiply |
| 10 | LinearBurn |
| 11 | Spotlight |
| 13 | Flame_SoftLight |
| 14 | HardLight |
| 15 | PinLight |
| 17 | Screen |
| 18 | Overlay |
| 19 | Diff |
| 20 | Exclusion |
| 29 | Flame_Max |
| 30 | Flame_Min |
| 32 | PsLinearLight（旧 LinearLight。Photoshop 相当） |
| 33 | LighterColor |
| 37 | LinearLight（Flame。2025.1 で追加。クランプなしの Ps 相当） |

2025.1 より前は `LinearLight` が Photoshop 相当。2025.1 で `PsLinearLight` に改名し、`LinearLight` は Flame 版。

## 時間（Matchbox と Lightbox）

```glsl
float adsk_getTime();  // フレーム番号。1 始まり float
```

## Lightbox のみ（一覧）

照明・シェーディング、マップ、変換、IBL、マテリアル、シャドウ係数、`adsk_isSceneLinear()`。シグネチャは [lightbox.md](lightbox.md)。

## Z-Depth HQ（Action）

Action の Z-Depth HQ は 32-bit Z を 2 本の 16-bit チャンネルにパックする。デコードは公式例 `DecodeZDepthHQ`（`EXAMPLES/`）に従う。Camera FX の `InputType` は [multipass-action.md](multipass-action.md)。
