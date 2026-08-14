# Matchbox GLSL

Matchbox は確立されたシェーディングパイプラインに乗らない。フラグメントごとに `main()` が走り、結果を書き出す。

## クラシックテンプレート（既定）

```glsl
uniform float adsk_result_w;
uniform float adsk_result_h;

uniform sampler2D front;
uniform sampler2D back;
uniform sampler2D matte;

uniform float mix_amount;
uniform vec3 tint;
uniform bool clamp_neg;

void main(void)
{
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 uv = gl_FragCoord.xy / res;

    vec3 f = texture2D(front, uv).rgb;
    vec3 b = texture2D(back, uv).rgb;
    float m = texture2D(matte, uv).r;

    vec3 rgb = mix(b, f * tint, mix_amount * m);
    if (clamp_neg)
        rgb = max(rgb, 0.0);

    gl_FragColor = vec4(rgb, m);
}
```

### 必須パターン

- 解像度: `adsk_result_w` / `adsk_result_h`（宣言のみ。値は Flame が入れる）。
- UV: `gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h)`。原点は左下。
- サンプリング: `texture2D(sampler, uv)`。クラシックでは `texture()` も `in`/`out` も使わない。
- 出力: `gl_FragColor` を **`main()` の末尾で一度だけ**書く。早期 `return` は禁止（Flame が `main` にエピローグを挿入するため。ノードが描画グラフを組めなくなる）。
- `adsk_` で始まる uniform は UI に出ず、`shader_builder` も UI 用に扱わない。

### 座標

| 空間 | 作り方 | 用途 |
|------|--------|------|
| 正規化 UV `0–1` | `gl_FragCoord.xy / res` | テクスチャサンプリング |
| ピクセル | `gl_FragCoord.xy` | カーネル・オフセット（`1.0/res` を使う） |
| ビューポート Position ウィジェット | XML の vec2 がだいたい `0–1` | 幾何計算前に `pos * res` へ |

`gl_TexCoord[0]` は古い例に出るが、解像度付き `gl_FragCoord` を使う。

## モダンテンプレート（Flame 2025.1+、明示時のみ）

Vulkan / SPIR-V 規則のため **uniform は block 内**。同一行に複数 uniform を書かない（`shader_builder` が XML を生成できない）。

```glsl
#version 430

layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform AdskUniformBlock
{
    float adsk_result_w;
    float adsk_result_h;
};

layout(binding = 2) uniform UniformBlock
{
    float size;
};

layout(binding = 3) uniform sampler2D myInputTex;

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec4 tex0 = texture(myInputTex, uv * size);
    fragColor = vec4(tex0.rgb, 1.0);
}
```

Matchbox のモダン GLSL は 430 / 440 / 450 / 460。追加されるもの: 倍精度、pack/unpack、atomic、行列 determinant、FMA など。仕様は Khronos の GLSLangSpec。

## 入力ソケット

GLSL 側は `uniform sampler2D <name>;`。役割（Front / Back / Matte / Selective / Action パス）は **XML の `InputType`** で付ける。

- 最大 **6** 入力。それ以上は無視される。
- 未接続時の挙動は XML `NoInput`（`Error` / `Black` / `White`）。
- ソケット数をテクスチャ数に揃えるなら XML `LimitInputsToTexture="True"`。

## 時間・劣化・解像度

宣言して使う（定義しない）:

```glsl
uniform float adsk_time;          // タイムバー。1 始まりのフレーム番号（float）
uniform bool adsk_degrade;        // Batch Adaptive Degradation。True なら安いパスへ
uniform float adsk_result_frameratio;
uniform float adsk_result_pixelratio;
```

各サンプラー解像度（`front` の場合）:

```glsl
uniform float adsk_front_w;
uniform float adsk_front_h;
uniform float adsk_front_frameratio;
uniform float adsk_front_pixelratio;
```

`float adsk_getTime();` もフレーム番号（1 始まり）を返す。Lightbox と共通。

## アルファ / MatteProvider

Matchbox がアルファを加工し、子ノードへ渡すなら XML `MatteProvider="True"`。`False` のときは親のマットが子へパススルー。

## 公式の最小加算例

```glsl
uniform float adsk_result_w, adsk_result_h;

void main()
{
    vec2 coords = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec3 sourceColor1 = texture2D(input1, coords).rgb;
    vec3 sourceColor2 = texture2D(input2, coords).rgb;
    gl_FragColor = vec4(sourceColor1 + sourceColor2, 1.0);
}
```

このリポジトリでは可読性のため `adsk_result_w` と `adsk_result_h` を別行にする。
