# マルチパス・Selective・Action

## マルチパス

効果を複数 `.glsl` に分割する。

```
embr_blur.1.glsl
embr_blur.2.glsl
embr_blur.xml
```

- XML は `<Shader Index="1">` … `<Shader Index="2">`。
- 後続パスは前パス結果を `uniform sampler2D adsk_results_pass1;` として読む（番号は 1 始まり）。
- XML のその Uniform に `Index` / `NoInput` は付けない。名前が規約。
- ブラウザではルートグループ（`embr_blur.glsl` 相当）を選ぶ。`-p` で単一 `.mx` にまとめると迷いが減る。
- 公式の高速ブラー相当: `EXAMPLES/PyramidBlur`。

同じコントロールを全パスで使うときは [xml-schema.md](xml-schema.md) の `<Duplicate>`。

### マルチ実行（同一パスの繰り返し）

`EXAMPLES/MultiExecutionSeparableGaussianBlur`。`<Shader NbExecutions="N" GridSubdivision="1" Clear="0" ...>`。ガウシアン等でパスファイルを増やさずに反復する。

### カスタム mipmap / 複数 RT

`OutputNbLevels` / `OutputNbResults`。例: `MultiTargetCustomMipmaps`。`Mipmaps` 例は mipmap ブラー。

### 時間方向

- `adsk_previous_frame_*` / `adsk_next_frame_*` — TemporalSampling。**Action では使えない**。
- `adsk_accum_texture` + `adsk_accum_no_prev_frame` + ルートの `AccumulatePass` / `AccumulationFromStartFrame` — Accumulate 例。Adaptive Degradation 対応が有効になる。

## Selective FX

Matchbox の特殊化。Selective ノードの分離結果でエフェクトを変調する（単純ブレンド以上。ブラー境界など）。

1. XML で `InputType="Selective"` の入力を宣言する。
2. GLSL でそのアルファの白部分に効果をかけ、黒は入力を維持する。
3. Selective ノードが Serial pipeline のとき、接続は自動。

Matchbox の Shader セクションに追加される UI:

- **Mix** — 分離結果のゲインで全体強度。
- **Outside** — 分離を反転。同じ Selective で内と外に別シェーダを掛けられる。

## Matchbox in Action

Batch / Timeline でも使えるが、Action では次が追加される。

### テクスチャにペアレント

Diffuse / Normal / UV / Displacement（HW のみ）/ Parallax / IBL / Specular / Emissive / Lens Flare / Substance。テクスチャ空間、Media list の後・オブジェクトの前（前処理）。Stereo オブジェクトには非対応。

F8（Action Object Solo）で Context / Result / Result Matte を切り替え。ウィジェット操作もここ。

XML: `SupportsAction="True"`。`ShaderType` と `SoftwareVersion` は `shader_builder` が書く。

2026.1 以降、Matchbox ノードとリンクは Schematic でオレンジ（それ以前は黒）。

### Camera FX（カメラにペアレント）

シーン全体のポスト。Live Preview でないと見えない。他ノードには繋げず Camera のみ。供給シェーダの一部は `ACTION_CAMERA_FX` フォルダ。

自動接続するには XML `InputType` を Action 出力に合わせる（一覧は [xml-schema.md](xml-schema.md)）。未設定なら Shader メニューのパッチパネル。

GMask をカメラに繋ぎ、ポスト専用にできる。`InputType="GMask"` のシェーダがその入力を使う。

Camera FX のレンダは Multi-Render Targets。Accumulation On/Off で全パスが単一 MRT。Accumulation RGBA は MRT 2 本。

Lens Flare と Rays は Camera FX パイプラインの最後（Comp 出力で有効時）。

### 開発時の InputType

Camera FX 向けは使うパスだけ宣言する。例: 深度フォグなら `Front` + `Z-Depth` または `Z-Depth HQ`。HQ は 32-bit が 2×16-bit にパックされるので `DecodeZDepthHQ` 例に従う。

## Timeline トランジション

`SupportsTransition="True"`。`EXAMPLES/TransitionShader`。`TimelineUseBack` で Back の使用を制御。

## UI 専用 Matchbox

`EXAMPLES/UIOnly`。見た目は出さず、Expression 用パラメータだけ置く。
