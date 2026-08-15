# embr_fillmatte

表示名: **Embr Fill Matte**。マット専用。入力は Matte のみ。出力は Comp。Preview で入力へ半透明の赤い Edge ガイド。

## Pipeline

```
linearstep → Close (square) → Fill
Fill → octagon Dilate / Erode → Edge → Softness blur
Comp = mix(Fill, input, Edge)
```

| File | Role |
|------|------|
| `.1` | Linear step（Low / High） |
| `.2–5` | Close Dilate H/V → Erode H/V |
| `.6–9` | Edge Dilate（八角形: 軸 → 対角） |
| `.10–13` | Edge Erode（Fill から。八角形） |
| `.14` | Dilate − Erode |
| `.15–16` | Softness box blur、Comp / Preview |
| `.xml` | UI |
| `.1.glsl.png` | サムネイル |

## Inputs

| Socket | Type | Notes |
|--------|------|--------|
| Matte | Matte | 必須。カバレッジ（R） |

`MatteProvider="True"`。RGB と A に同じカバレッジ（Preview 時は RGB がガイド、A は Comp）。

## Controls

| Control | Values | Notes |
|---------|--------|--------|
| Low | 0–1（既定 0） | Linear step の黒点 |
| High | 0–1（既定 0.25） | Linear step の白点 |
| Close | 0–64（既定 0） | Fill の穴埋め半径（px）。degrade 時は最大 8 |
| Size | 0–64（既定 0） | Edge の硬い芯（px）。八角形 |
| Softness | 0–64（既定 5） | Size に足してから box blur。芯は残る |
| Preview | bool（既定 off） | オン: 入力に半透明の赤い Edge。オフ: Comp |

## Notes

- Close は正方形 Dilate→Erode。
- Edge 半径は Size + Softness。八角形は Morphology Circle と同じ（軸 `0.414R`、対角 `R - 軸`）。
- Comp は Fill に、入力をソフト Edge で Mix。
- Preview の赤は `edge * 0.5`。A は Comp。
- 配置: `/opt/Autodesk/presets/2025/matchbox/shaders/EMBR/`
- `shader_builder -m` は全パスを渡す。`.mx` はソースにしない。
