# Lightbox

Action のライティングループに GLSL スニペットを挿入する。Look 開発（3D ライト × グレーディング × 調整レイヤー）。**このリポジトリの主対象は Matchbox**。Lightbox は API が共有されるためここに置く。

配置: `/opt/Autodesk/presets/<version>/action/lightbox/`  
ビルド: `shader_builder -l -x gain.glsl`  
パッケージ: `shader_builder -l -p gain.glsl` → `.lx`

## 構造

1. 前方宣言（uniform と使う `adsk_*`）。
2. `vec4 adskUID_lightbox(vec4 source)`。

グローバル記号（関数・uniform・定数）はすべて **`adskUID_` 接頭辞**。GLSL に namespace がなく、複数 Lightbox を Action シェーダ文字列に結合するため。衝突するとロード済み Lightbox が全部無効になる。

```glsl
uniform float adskUID_gain;

vec4 adskUID_lightbox(vec4 source)
{
    source.rgb = source.rgb * adskUID_gain;
    return vec4(source.rgb, source.a);
}
```

`source` はプライオリティ順で前のライト / Lightbox のフラグメント。戻り値の RGB は Lightbox の Mix でブレンドされ、**アルファは Mix されない**。必ず有効な `source.a` を返す。アルファを上書きするとライト形状を差し替えられる。

アルファを編集するときは、特に理由がなければ `source.a * myAlpha`。白で潰すとシーン情報が消える。

モダン Lightbox は **GLSL 460 のみ**（複数シェーダ結合の制約）。旧 130 以下とは混在可。Matchbox のような 430–450 は不可。

## 親ライトの影響

プライオリティエディタの順が入力を決める。

| ライト | Lightbox タイミング | ブレンド | 入力色 |
|--------|---------------------|----------|--------|
| inactive | n/a | additive | 現在のフラグメント（未シェード） |
| active | post-light | additive | 現在のフラグメント（シェード済み） |
| inactive | n/a | solo | diffuse（未シェード） |
| active | post-light | solo | そのライトでシェードした diffuse |

その他 UI:

- **Pre / Post** — ライト計算の前か後か。API: `adsk_isLightboxRenderedBeforeLight()`。
- **Lightbox Normals** — ライト inactive でも法線を渡せる。
- **Additive / Solo** — `adsk_isLightAdditive()`。Solo は diffuse を突き抜ける。

疑似コードは公式「Creating a Lightbox Shader」の `computeShading` / `computeLightbox`。シーン Ambient → IBL → ライトループ（シェーディング + Lightbox）→ Fog → Blending。

## いつ Lightbox を書くか

- **初級**: ライトのシェイプのまま色を足す / 色空間変換。必ずマットを返す（Matchbox の `MatteProvider` に相当する選択はない）。
- **中級**: 頂点・ライト位置でアルファを変調し、減衰やクリップを自前計算。
- **上級**: 上流の計算を無視してパイプラインを置き換える。Action が一度描き、Lightbox が再描画するため重い。非最適化例: `GGXIBLExample.glsl`。

## Lightbox API

位置・方向はカメラ空間。

### 照明とシェーディング

```glsl
vec3 adsk_getNormal();
vec3 adsk_getComputedNormal();
vec3 adsk_getBinormal();
vec3 adsk_getTangent();
vec3 adsk_getVertexPosition();
vec3 adsk_getCameraPosition();

bool adsk_isLightActive();
bool adsk_isLightAdditive();
vec3 adsk_getLightPosition();
vec3 adsk_getLightColour();          // colour * intensity
vec3 adsk_getLightDirection();
vec3 adsk_getLightTangent();

void adsk_getLightShadowDecayType(out int lightDecayType, out int shadowDecayType);
// NO_DECAY=0 LINEAR=1 QUADRATIC=2 CUBIC=3 EXP=4 EXP2=5
float adsk_getLightDecayRate();

bool adsk_isSpotlightFalloffParametric();
float adsk_getSpotlightParametricFalloffIn();
float adsk_getSpotlightParametricFalloffOut();
float adsk_getSpotlightSpread();
float adsk_getLightAlpha();          // cutoff * decay * GMask

bool adsk_isPointSpotLight();
bool adsk_isDirectionalLight();
bool adsk_isAmbientLight();
bool adsk_isAreaRectangleLight();
bool adsk_isAreaEllipseLight();
float adsk_getAreaLightWidth();
float adsk_getAreaLightHeight();

bool adsk_isLightboxRenderedFromDiffuse();
bool adsk_isLightboxRenderedBeforeLight();
vec3 adsk_getComputedDiffuse();
float adsk_getShininess();
vec3 adsk_getComputedSpecular();
```

### マップ

`getMapValue` は生テクスチャ。`getMapCoord` は補間座標。**z で割って** UV にする（0 除算に注意）。

```glsl
vec4 adsk_getComputedDiffuseMapValue(in vec3 vertexPos);
vec4 adsk_getDiffuseMapValue(in vec2 texCoord);
vec4 adsk_getEmissiveMapValue(in vec2 texCoord);
vec4 adsk_getSpecularMapValue(in vec2 texCoord);
vec4 adsk_getNormalMapValue(in vec2 texCoord);
vec4 adsk_getReflectionMapValue(in vec2 texCoord);
vec4 adsk_getUVMapValue(in vec2 texCoord);
vec4 adsk_getParallaxMapValue(in vec2 texCoord);

vec3 adsk_getDiffuseMapCoord();
vec3 adsk_getEmissiveMapCoord();
vec3 adsk_getSpecularMapCoord();
vec3 adsk_getNormalMapCoord();
vec3 adsk_getParallaxMapCoord();
vec2 adsk_getReflectionMapCoord(in vec3 vrtPos, in vec3 normal);
```

### 変換・IBL・マテリアル・シャドウ

```glsl
mat4 adsk_getModelViewMatrix();
mat4 adsk_getModelViewInverseMatrix();

int  adsk_getNumberIBLs();
bool adsk_isCubeMapIBL(in int idx);
bool adsk_isAngularMapIBL(in int idx);
vec3 adsk_getCubeMapIBL(in int idx, in vec3 coords, float lod);
vec3 adsk_getAngularMapIBL(in int idx, in vec2 coords, float lod);
bool adsk_isAmbientIBL(in int idx);
float adsk_getIBLDiffuseOffset(in int idx);
mat4 adsk_getIBLRotationMatrix(in int idx);

vec4  adsk_getMaterialDiffuse();
vec4  adsk_getMaterialSpecular();
vec4  adsk_getMaterialAmbient();
float adsk_getMaterialRoughness();
float adsk_getMaterialSpecularity();
float adsk_getMaterialMetalness();
float adsk_getMaterialAnisotropy();
float adsk_getMaterialSubSurfaceScattering();

vec3 adsk_getComputedShadowCoefficient();  // ライト色に乗算。親がシャドウキャスタ
bool adsk_isSceneLinear();
```

IBL API は HWAA × 高解像度マップで重い。HWAA を切るかマップを下げる。

色変換・ブレンド・`adsk_getTime` は [shader-api.md](shader-api.md) と共通。

## 公式 EXAMPLES

| 名前 | 内容 |
|------|------|
| LightboxBasics | API なし Gain |
| LightboxAPISimple | API 一覧と減衰 |
| SimpleLight | Action ライト相当を API で再構成 |
| PhysicallyBasedIBL | PBR モードの IBL |
| GGXMaterial | Specular.R=Specular, Specular.G=Metallic, Shine=Roughness |
| GGXIBLExample | マテリアルを乗っ取らず Lightbox 内で GGX IBL |

## プロキシ

8-bit PNG、**128×92**。同名で `.glsl` / `.xml` と同じフォルダ。
