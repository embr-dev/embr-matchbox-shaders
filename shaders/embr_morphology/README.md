# embr_morphology

表示名: **Embr Morphology**。向き付きモルフォロジー。RGB をチャンネルごとに min / max するか、Luma だけを min / max する。

## Files

| Pass | Role |
|------|------|
| `.1` | Angle（1 回目）。Circle は矩形半径 |
| `.2` | Angle+90°（Square / Circle の 1 回目。Line はコピー） |
| `.3` | Angle+45°（Circle の菱形 1 回目。他はコピー） |
| `.4` | Angle+135°（Circle の菱形 1 回目。他はコピー） |
| `.5` | Angle（Open / Close の 2 回目） |
| `.6` | Angle+90°（Square / Circle の 2 回目） |
| `.7` | Angle+45°（Circle の菱形 2 回目） |
| `.8` | Angle+135°（Circle の菱形 2 回目）。Mix |
| `.xml` | UI |
| `.1.glsl.png` | サムネイル原画（128×92） |
| `.1.glsl.p` | GLSL モード用プロキシ（同じ解像度、`flame_proxy_icon`） |

PNG 解像度のまま `.p` にする。`.mx` のサムネイルは **Linux** で焼く。Mac の `shader_builder` は `DISPLAY=:0` でも Matchbox サムネイルは空。

```bash
# macOS: GLSL 用 sidecar
flame_proxy_icon --from-png shaders/embr_morphology/embr_morphology.1.glsl.png

# Linux: サムネイル付き .mx
flame_proxy_icon --from-png embr_morphology.1.glsl.png
shader_builder -m -p embr_morphology.*.glsl
```

`.1.glsl` だけだと後続パスが入らず `CreateRenderGraph` になる。全パスを渡した `.mx` は Flame 2025（Metal / macOS）で動作確認済み。

Matchbox に `#include` が無いため、ヘルパーは各パスに同じ実装を置く。パスごとの差は `main` と使う uniform だけ。

## Inputs

| Socket | Type | Notes |
|--------|------|--------|
| Front | Front | 必須。RGB。マットは親からパススルー（`MatteProvider` は False） |
| Strength | Matte | 任意。Size の画素ごと乗数（R）。未接続は White（1） |

## Controls

| Control | Values | Notes |
|---------|--------|--------|
| Channel | RGB（既定）, Luma | RGB は R/G/B 独立。Luma は `adsk_getLuminance` のみ morph し、色比は残す |
| Kernel | Circle（既定）, Square, Line | Square は直交 2 軸。Line は 1 方向。Circle は矩形＋菱形の八角形 |
| Mode | Open / Close（既定）, Dilate / Erode | |
| Size | int -256–256（既定 0） | 半径（ピクセル）。符号で方向。0 は何もしない |
| Angle | float -360–360°（既定 0、Inc 1） | Square は 90° 周期。Circle は 45° 周期。Line は 180° 周期（0=水平、90=垂直） |
| Mix | float 0–1（既定 1） | 元 Front とのブレンド。0 は原画、1 は効果のみ |

| Mode | Size + | Size − |
|------|--------|--------|
| Dilate / Erode | Dilate | Erode |
| Open / Close | Close（Dilate→Erode） | Open（Erode→Dilate） |

## Notes

- Square: 辺 `2 * |Size| + 1` の正方形を Angle で回転。
- Line: 長さ `2 * |Size| + 1` の線分を Angle 方向に取る。
- Circle: 軸方向半径 `round(0.414 * R)` の矩形と、残り `R - that` の菱形の Minkowski 和（八角形）。Angle で全体を回転。
- Luma: 作業 RGB のまま `adsk_getLuminance` を min/max。結果は `rgb * (Y' / Y)`。Y≈0 は無彩色 `vec3(Y')`。log / linear への変換はしない。
- Strength: 各パスの半径を `round(|Size| * clamp(R, 0, 1))` にする。Mix とは独立。
- Mix は最終パスで `mix(Front, processed, Mix)`。
- 端は `CLAMP_TO_EDGE`。回転サンプリングのため `LINEAR`。
- Adaptive Degradation 時は半径を最大 8 に落とす。
- 配置: フォルダごと `/opt/Autodesk/shared/matchbox/shaders/` へ。
