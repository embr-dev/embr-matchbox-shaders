# embr_pixelspread（仕様）

表示名: **Embr Pixel Spread**。マットをガイドに縁の色を外へ伸ばす。

**2026-08-15 ボツ。** 実写キーでの見た目が実用に届かなかった。`shaders/embr_pixelspread` は削除済み。再開時はこのファイルの「中断ログ」から。

関連: [README.md](README.md)、[embr_holefill.md](embr_holefill.md)、[embr_morphology](../../shaders/embr_morphology/README.md)。

---

## 中断ログ（2026-08-15）

キー縁の dirty RGB を直し、透明側へきれいな色を伸ばす Matchbox を止めた。クオリティがいまいち、という判断。

試したもの（4 パス、クラシック GLSL）:

- Inset（分離 min）で縁を避けて色を取る
- Dilate: 分離 1D、より高い a の一番近い画素をコピー
- Blur: `matte - inset` の帯だけ premul ガウシアン
- Stretch: 局所勾配ジャンプ → 体のゴースト。のちブラーマット勾配を縁まで歩くハロー
- Smear: 8/16/32 レイで一番近い内側をコピー（筋・多角）
- 最後に Inset コアへ Front を戻し、Feather はコアより外へ広げない

分かったこと:

- 分離 Dilate は軸方向の筋が出る。2D 最近傍にするとレイの本数不足で神の光／コピーになる。本数を増やすと重い。
- Size 分だけ内側へジャンプすると、縁ではなく人物そのものがずれる。
- 1px 勾配は硬いキーでは外側でゼロ、残 α だと `rgb/a` が点々になる。
- Blur は内側をくり抜かないと服や顔がハローに混ざる。くり抜くとコアが穴になる。
- Front を元のマットで戻すと dirty 縁が戻る。Inset コアで戻しても、伸ばした側の色がまだ弱い。
- この系統の「きれいな縁伸ばし」は距離場（JFA）か、最近傍色埋め（solidify）の方が本命。Matchbox の有界ループ＋分離パスでは、大きい Size の等方ハローが作りにくい。

再開するときの候補:

- **embr_solidify**（JFA / 最近傍で透明部に色をコピー）として約束し直す
- Pixel Spread という名前で Dilate/Blur/Stretch/Smear を同居させない
- 大きい半径の 2D 探索を Matchbox フラグメントの二重ループでやらない

実装フォルダは削除済み。

---

## 意図（当時）

出力は不透明 RGB（A=1）。マットはガイド。縁の色を伸ばしたあと、Inset コアへだけ Front を戻す。

やらない: Detail / Mix / Selective / Premultiply Out、マット穴埋め、Inpaint。表示 `clamp(rgb,0,1)` はしない。

## 別シェーダとして検討するもの

| 仮名 | 内容 |
|------|------|
| **embr_solidify** | JFA / 最近傍で透明部に色をコピー |
| **embr_matte_edge** | マットの Erode/Blur/Gamma |
| **embr_edge_push** | 法線・距離のベクトル場ワープ |
