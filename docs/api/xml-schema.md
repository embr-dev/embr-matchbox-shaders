# shader_builder XML

`.glsl` だけでも動くが、使える UI には sidecar `.xml` が必要。`shader_builder -m -x file.glsl` で生成してから編集する。

`adsk_` で始まる uniform は UI に出ず、builder も UI 対象にしない（パス間テクスチャ `adsk_results_passN` などは XML に sampler として書く）。

## 構造

```xml
<!DOCTYPE ShaderNodePreset [
  <!ELEMENT ShaderNodePreset (Shader+, Page+)>
  <!ELEMENT Shader (Uniform+)>
  <!ELEMENT Uniform (SubUniform* | PopEntry* | Duplicate*)>
  <!ELEMENT SubUniform EMPTY>
  <!ELEMENT PopEntry EMPTY>
  <!ELEMENT Duplicate EMPTY>
  <!ELEMENT Page (Col+)>
  <!ELEMENT Col EMPTY>
]>
```

実装・コミュニティではドロップダウン子要素は **`PopupEntry`**（DTD の `PopEntry` ではなくこちらが通る）。

## `<ShaderNodePreset>`

| 属性 | 対象 | 既定 | 意味 |
|------|------|------|------|
| `Name` | 両方 | ファイル名 | ノード名。XML があるとファイル名より優先 |
| `Description` | 両方 | 空 | Schematic の Note |
| `HelpLink` | 両方 | 空 | ヘルプボタン用 URL（XML として合法な文字のみ） |
| `Version` | 両方 | `1` | 作者メタデータ。アプリは処理しない |
| `ShaderType` | 両方 | builder が設定 | `Matchbox` / `Lightbox` |
| `SoftwareVersion` | 両方 | builder が設定 | ビルドしたアプリ版 |
| `LimitInputsToTexture` | Matchbox | False | ソケット数を必要テクスチャ数に制限 |
| `MatteProvider` | Matchbox | False | True なら加工アルファを子へ渡す |
| `SupportsAction` | Matchbox | False | Action ノード向けヒント。Batch は常に可 |
| `SupportsTimeline` | Matchbox | False | Timeline FX 向けヒント |
| `SupportsTransition` | Matchbox | False | Timeline トランジション向け |
| `SupportsAdaptiveDegradation` | Matchbox | False | Batch 劣化。**GLSL で `adsk_degrade` 分岐が必要**。属性だけでは止まらない |
| `TimelineUseBack` | Matchbox | True | Timeline で Back を使うか |
| `CommercialUsePermitted` | 両方 | True | 商用可否の表示。アプリは強制しない |
| `AccumulatePass` | Matchbox | | 蓄積する中間パス（1 始まりの Shader Index） |
| `AccumulationFromStartFrame` | Matchbox | True | 蓄積を再帰的に進めるか。例は `EXAMPLES/Accumulate` |
| `OverrideNormals` | Lightbox | False | ジオメトリ法線が効果強度に影響するか |

## `<Shader>`（パスごと、Index は 1 始まり）

Lightbox は常に 1 つ。Matchbox はパス数だけ。

| 属性 | 既定 | 意味 |
|------|------|------|
| `Index` | 1 | パス番号（1 始まり） |
| `OutputBitDepth` | Output | `Output` / `8` / `16` / `Float16` / `Float32` |
| `OutputWidth` / `OutputHeight` | | 入力から決まらないときの RT サイズ。マルチパスでは**最後のパス**だけ。Action / Timeline では無視 |
| `OutputWidthScaleFactor` / `OutputHeightScaleFactor` | | 出力解像度に対する倍率（`1` / `0.5` など） |
| `OutputScaleFactorEffect` | | `0` floor / `1` round / `2` ceiling |
| `OutputNbLevels` | | カスタム mipmap 中間パスのレベル数 |
| `OutputNbResults` | | 中間パスが出すテクスチャ数 |

コミュニティで使われ、公式 EXAMPLES の `MultiExecutionSeparableGaussianBlur` にある追加属性:

| 属性 | 意味 |
|------|------|
| `NbExecutions` | 同じパスを繰り返す回数 |
| `GridSubdivision` | グリッド分割 |
| `Clear` | クリア（例: `0`） |

DTD ページには無いが Flame は読む。セパラブルブラー等で使う。

## `<Uniform>`

`Name` は GLSL の uniform 名と一致。**変更しない**。

### 共通

| 属性 | 内容 |
|------|------|
| `Type` | `float` `vec2` `vec3` `vec4` `int` `ivec2` `ivec3` `ivec4` `bool` `bvec2` `bvec3` `bvec4` `mat2` `mat3` `mat4` `mat2x3` `mat2x4` `mat3x2` `mat3x4` `mat4x2` `mat4x3` `sampler2D` |
| `DisplayName` | UI ラベル |
| `ChannelName` | アニメーションチャンネル名。Popup では `Name` と揃える慣例 |
| `Tooltip` | ツールチップ |
| `Row` | `0–4` |
| `Col` | `0–3`（Action 展開 UI は Page 側で最大 6 列） |
| `Page` | `0–6` |
| `Default` / `Min` / `Max` / `Inc` | 型に応じた数値または True/False |
| `ResDependent` | `None` / `Width` / `Height`（幅または高さでスケール）。公式スキーマ表記は `ResDependant` だが、builder 出力は `ResDependent` |

### UI 条件

| 属性 | 内容 |
|------|------|
| `UIConditionSource` | 参照する uniform 名 |
| `UIConditionValue` | その値のときアクティブ |
| `UIConditionInvert` | True で論理反転 |
| `UIConditionType` | `Disable` または `Hide` |

例: `EXAMPLES/ConditionalUI.xml`。

### `ValueType`（vec3 / ivec* / int）

| 値 | UI |
|----|-----|
| `Position` | 数値（XYZ） |
| `Colour` | カラーポット |
| `ColourWheel` | HGS ホイール。`AngleName`, `IntensityName1`, `IntensityName2`。`HueShift` で外輪回転 |
| `ColourWheelRGBOffset` | 0 基準 |
| `ColourWheelRGBSlope` | 1.0 基準、負なし |
| `ColourWheelRGBPower` | Slope の逆 |
| `Popup` | ドロップダウン。子に `<PopupEntry Title="..." Value="..."/>` |
| `Curve` | カーブ。int/ivec はハンドル。`adskEvalDynCurves` で評価 |
| `LargeCurve` | 3 列幅。Proportional と X/Y フィールド |
| `Proportional` | vec3/vec4 でラベル横に数値 |

### vec2 / vec3 アイコン

`IconType`: `None` / `Pick` / `Axis` / `Light`。Timeline Player では `None` と `Pick` のみ（`Light`/`Axis` は Pick に置換）。`IconDefaultState` はアイコンの On/Off。

`Action3DWidgets="True"`: Action 空間（原点が画像中心、右上が `(W/2, H/2)`）。

### sampler2D

| 属性 | 内容 |
|------|------|
| `Index` | ソケット順（0 始まり） |
| `NoInput` | `Error` / `Black` / `White` |
| `Mipmaps` | True のとき `GL_TEXTURE_MIN_FILTER` は mipmap 系 |
| `GL_TEXTURE_MIN_FILTER` / `MAG_FILTER` | `GL_NEAREST` `GL_LINEAR` `GL_NEAREST_MIPMAP_NEAREST` `GL_LINEAR_MIPMAP_NEAREST` `GL_NEAREST_MIPMAP_LINEAR` `GL_LINEAR_MIPMAP_LINEAR` |
| `GL_TEXTURE_WRAP_S` / `WRAP_T` | `GL_CLAMP` `GL_CLAMP_TO_BORDER` `GL_CLAMP_TO_EDGE` `GL_REPEAT` `GL_MIRRORED_REPEAT` |
| `GL_TEXTURE_BORDER_COLOR` | `"r,g,b"` |
| `InputType` | 下記 |
| `InputColor` | `"r,g,b"`（0–255）。`InputType` があるとその色が優先 |

#### `InputType`（Matchbox）

Batch / 一般:

- `Front`（赤）
- `Back`（緑）
- `Matte`（青）
- `Selective`

Action Camera FX（各 Action 出力に対応。未設定なら Shader メニューのパッチパネルで手動接続）:

`Front` `Back` `Matte` `Comp` `Albedo` `Ambient Occlusion` `Emissive` `GMask` `Lens Flare` `Motion Vectors` `3D Motion Vectors` `Normals` `Occluder` `Position` `Reflection` `Roughness` `Shadows` `Specularity` `UV` `Z-Depth` `Z-Depth HQ`

`Front` は Primary Output。`Comp` は Primary が別タイプのときの Action Comp。

### カーブ専用（`ValueType="Curve"`）

`CurveMinX` `CurveMaxX` `CurveMinY` `CurveMaxY`（既定 0–1）

`CurveBackground`: `0` 空 / `1` 色相グラデ / `2` 輝度グラデ

`CurveWrapArround`: `0` なし / `1` wrap（公式スペルは Arround）

`CurveShape`: `0` Min→Max 直線 / `1` 逆直線 / `2` S / `3` 逆 S / `4` MaxY 定数 / `5` MinY 定数 / `6` 中点定数

`CurveR` `CurveG` `CurveB`: カーブ色。`SubUniform` の `CurveName` でチャンネル名。

## `<SubUniform>`

親の成分ごと（vec3 なら 3 つ）。`Default` / `Inc` / `Min` / `Max` / `ResDependent` は親を上書き。

## `<Duplicate>`

複数パスで同じ uniform を UI に一度だけ出す。

```xml
<!-- pass 1 -->
<Uniform Row="0" Col="0" Page="0" Default="True" DisplayName="Filtering" Type="bool" Name="filtering"/>
<!-- pass 2 -->
<Uniform Type="bool" Name="filtering">
  <Duplicate/>
</Uniform>
```

Duplicate にしないと UI に二重表示される。

## `<PopupEntry>`

```xml
<PopupEntry Title="ReplaceMe" Value="0"/>
```

例: `EXAMPLES/BuildList.xml`。

## `<Page>` / `<Col>`

Action シングルパネル対応で Page は名前が 3 種:

| 属性 | 用途 |
|------|------|
| `Name` | 6 列すべて表示（展開 UI） |
| `ColName0_2` | 折りたたみ時の列 0–2 |
| `ColName3_5` | 折りたたみ時の列 3–5 |
| `Page` | 0 始まり、最大 6 |

`<Col Name="..." Col="0" Page="0"/>`。Col は 0 始まり、DTD 上最大 6。展開時は Page の子 Col が最大 6。

## 最小 XML 例

```xml
<ShaderNodePreset
    SupportsAdaptiveDegradation="False"
    SupportsAction="False"
    SupportsTransition="False"
    SupportsTimeline="False"
    TimelineUseBack="False"
    MatteProvider="False"
    CommercialUsePermitted="True"
    ShaderType="Matchbox"
    SoftwareVersion="2025.0.0"
    LimitInputsToTexture="True"
    Version="1"
    Description="Tint the front by a colour pot."
    Name="embr_tint">
  <Shader OutputBitDepth="Output" Index="1">
    <Uniform Index="0" NoInput="Error" DisplayName="Front" InputType="Front"
             Mipmaps="False"
             GL_TEXTURE_WRAP_T="GL_CLAMP_TO_EDGE" GL_TEXTURE_WRAP_S="GL_CLAMP_TO_EDGE"
             GL_TEXTURE_MAG_FILTER="GL_LINEAR" GL_TEXTURE_MIN_FILTER="GL_LINEAR"
             Type="sampler2D" Name="front"/>
    <Uniform Inc="0.01" Row="0" Col="0" Page="0" DisplayName="Tint"
             ValueType="Colour" Type="vec3" Name="tint">
      <SubUniform ResDependent="None" Max="1000000.0" Min="-1000000.0" Default="1.0"/>
      <SubUniform ResDependent="None" Max="1000000.0" Min="-1000000.0" Default="1.0"/>
      <SubUniform ResDependent="None" Max="1000000.0" Min="-1000000.0" Default="1.0"/>
    </Uniform>
  </Shader>
  <Page Name="Tint" ColName0_2="Tint" ColName3_5="Tint" Page="0">
    <Col Name="Colour" Col="0" Page="0"/>
  </Page>
</ShaderNodePreset>
```
