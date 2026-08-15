# embr_holefill → embr_fillmatte

実装名: **Embr Fill Matte**（`shaders/embr_fillmatte`）。マット専用。入力は Matte のみ。

状態: **実装**（2026-08-15）。出力は Comp。Preview で入力へ赤い Edge ガイド。

## 動作

```
m     = matte.r
ls    = linearstep(low, high, m)
fill  = close_square(ls, close_size)
edge  = blur(octagon_dilate(fill, size + softness) - octagon_erode(fill, size + softness), softness)
comp  = mix(fill, m, edge)

Preview off → comp
Preview on  → mix(vec3(m), red, edge * 0.5)  // A は comp
```

Close は正方形。Edge の Size は硬い芯（既定 0）。Softness は半径に足してから box blur。

パス: `.1` Linear step → `.2–5` Close → `.6–9` Edge Dilate 八角形 → `.10–13` Edge Erode 八角形 → `.14` Dilate−Erode → `.15–16` Softness + Comp / Preview。
