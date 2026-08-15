# embr_flow_soften（仕様・未実装）

表示名案: **Embr Flow Soften**。  
局所の **流れ方向（構造テンソル）**を推定し、**流れに沿ってだけ**ぼかす。髪の主方向に乗る筋は残し、**流れに逆らう細い毛・飛び毛**を抑える。

旧称・別名: Structure-aware soften / Anisotropic soften / Hair flow blur。

関連: [proposals.md](proposals.md)、[README.md](README.md)、[gotchas.md](../api/gotchas.md)、[embr_morphology](../../shaders/embr_morphology/README.md)（近傍パスの慣例）。  
参考思想のみ（コピーしない）: coherence-enhancing diffusion、LIC、異方性ガウシアン。`crok_beauty` の全面肌平滑とは別物。

状態: **仕様確定・未実装**（2026-08-15）。

---

## 目的

| やる | やらない |
|------|----------|
| 髪マット内で主流れに沿う 1D ブラー | キー生成・髪マット自動抽出 |
| 流れと直交する細かい毛の抑制 | 全面美容 Soften（肌テクスチャ平滑） |
| Selective で当てる範囲を限定 | 背景ごと方向場に巻き込むこと |
| View で方向場・異方性の診断 | 表示 `clamp(rgb,0,1)` |

典型: キー後／ロト後の髪マットを Selective に繋ぎ、逆立つ産毛やクロスする細い毛だけ落とす。

---

## 処理パイプライン

```
Front ─► Guide(Y) ─► Grad ─► Structure Tensor (blur) ─► θ, anisotropy
                                    │
                                    ▼
                         Along-flow 1D blur (radius, samples)
                                    │
                         optional cross-flow weak blur / HF suppress
                                    │
                         mix(Front, softened, amount * selective)
```

### 1. Guide（向き推定用）

向きは **ガイド輝度**から取る（ぼかすのは Front RGB）。

```
g = guide_source:   // Popup
  Front Luma  → adsk_getLuminance(front.rgb)   // 既定
  Front Red   → front.r
  Matte       → matte.r                         // 別ガイドがあるとき
```

必要なら推定前に Guide を軽いガウシアン（`Guide Soft`、既定小）で平滑し、1本毛ノイズで θ が暴れないようにする。

### 2. 勾配と構造テンソル

```
// 中心差分（px）
gx = 0.5 * (g(x+1,y) - g(x-1,y))
gy = 0.5 * (g(x,y+1) - g(x,y-1))

// 生テンソル
Jxx = gx * gx
Jxy = gx * gy
Jyy = gy * gy

// テンソル平滑（等方ガウシアン、半径 Tensor Soft）
Jxx, Jxy, Jyy = blur(Jxx, Jxy, Jyy)
```

### 3. 流れ角 θ と異方性

対称行列 `[[Jxx,Jxy],[Jxy,Jyy]]` の固有分解:

```
// 大きい固有値 λ+ の固有ベクトル ≈ 勾配方向（エッジ法線）
// 小さい固有値 λ- の固有ベクトル ≈ 流れ（接線）＝髪の向き

trace = Jxx + Jyy
det   = Jxx*Jyy - Jxy*Jxy
disc  = max(trace*trace - 4.0*det, 0.0)
sqrt_d = sqrt(disc)
lambda_max = 0.5 * (trace + sqrt_d)
lambda_min = 0.5 * (trace - sqrt_d)

// 法線（勾配側）
nx = Jxx - lambda_min   // または lambda_max に対応する成分
ny = Jxy
// 安定化: 長さが小さいときは (1,0) などへフォールバック
n = normalize(vec2(nx, ny) + eps)

// 接線（流れ）= 法線を 90°
t = vec2(-n.y, n.x)

coherence = (lambda_max - lambda_min) / (lambda_max + lambda_min + eps)
// 0 ≈ 等方（ぼかし弱い／スキップ寄り）、1 ≈ はっきりした流れ
```

実装時は固有ベクトルの符号フリップに注意（θ と θ+π は同じ線なので 1D ブラーには問題なし）。

### 4. 流れ方向ブラー（本体）

Front RGB（作業空間のまま。log 変換しない）を、接線 `t` に沿って 1D 加重平均。

```
R = Along Size          // px、adsk_degrade 時は上限（例: 8）
N = Along Samples       // 片側サンプル数。固定奇数長を内部決定でも可

sum = 0
wsum = 0
for i in -N .. +N:
    u = uv + t * (i * step_px) / resolution
    w = gaussian(i, sigma) * optional_bilateral(front, sample)  // bilateral は Phase 2
    sum += texture(front, u).rgb * w
    wsum += w
blurred = sum / max(wsum, eps)
```

- **Along Size**: 流れ方向の半径（主操作）
- サンプルは `CLAMP_TO_EDGE`
- クラシック GLSL: ループは有界定数。`N` はコンパイル時上限（例: 最大 16）＋実行時 `Along Size` で実効長を切る

### 5. 逆毛抑制（Cross）

流れに逆らう細い毛は、主に **接線と直交する方向の高周波**として残る。

| Mode（Cross） | 内容 |
|---------------|------|
| **Off** | Along のみ |
| **Weak Cross**（既定） | 法線 `n` 方向に短い 1D ブラー（`Cross Size` ≪ Along） |
| **High-freq Suppress** | `front - blur_along` の法線成分を減らす（Phase 2 でも可） |

```
along = blur_1d(front, t, Along Size)
cross = blur_1d(along, n, Cross Size)   // Weak Cross
out_s = mix(along, cross, Cross Amount)
```

異方性が低い（`coherence` 小）画素では Along/Cross を弱め、等方に落とさない／原画寄りにする（平らな肌や背景の誤爆防止）。

```
a = smoothstep(Coherence Min, Coherence Min + Coherence Soft, coherence)
effect = Amount * selective.r * a
out = mix(front.rgb, out_s, effect)
```

### 6. 出力

- RGB: 上記。A は Front パススルー（既定）
- `MatteProvider="False"`
- linear / unclamped: **表示 clamp なし**

---

## パス構成（案）

| Pass | 役割 |
|------|------|
| 1 | Guide 取得＋任意 Guide Soft。勾配用に輝度を書く |
| 2–3 | Jxx/Jxy/Jyy の分離ガウシアン（Tensor Soft） |
| 4 | θ（接線）と coherence を RT にパック（例: `rg = t`, `b = coherence`） |
| 5 | Along 1D blur |
| 6 | Cross（Weak 時）。Off ならコピー |
| 7 | Mix / Selective / View |

パス数は実装で詰める。Tensor Soft が小さければ 2–3 を短縮可。`adsk_degrade` 時は Along/Cross Size とサンプル数を落とす。

---

## 入力

| Socket | InputType | NoInput | 役割 |
|--------|-----------|---------|------|
| Front | Front | Error | 必須。ぼかす色 |
| Selective | Selective | White | 髪など効果範囲（R）。未接続=全面（非推奨・Tooltip で注意） |
| Matte | Matte | Black | Source=Matte のときガイド。未接続時は Front Luma にフォールバック |

`LimitInputsToTexture="True"`。

---

## UI（確定案）

Page: **Flow Soften**。2 列。

### Col 0 — Setup

| Control | Type | Default | 内容 |
|---------|------|---------|------|
| Guide | Popup | Front Luma | Front Luma / Front Red / Matte |
| Amount | float | 1 | 0–1。最終ブレンド |
| Coherence Min | float | 0.15 | これ未満は効果を弱める |
| Coherence Soft | float | 0.15 | Min からの立ち上がり幅 |
| View | Popup | Result | Result / Source / Direction / Coherence / Diff |

**View**

| Value | 内容 |
|-------|------|
| Result | 最終 |
| Source | 入力 Front |
| Direction | 接線方向の可視化（例: `0.5 + 0.5*t` を RG に） |
| Coherence | 異方性をグレー表示 |
| Diff | `abs(result - source)`（clamp しない） |

### Col 1 — Blur

| Control | Type | Default | Min–Max | 内容 |
|---------|------|---------|---------|------|
| Along Size | float | 6 | 0–32 | 流れ方向半径（px） |
| Cross Mode | Popup | Weak Cross | | Off / Weak Cross |
| Cross Size | float | 1 | 0–8 | 法線方向半径。Cross Mode≠Off で表示 |
| Cross Amount | float | 0.5 | 0–1 | Cross の効き。同上 |
| Tensor Soft | float | 2 | 0–16 | テンソル平滑半径（方向の安定） |
| Guide Soft | float | 0.5 | 0–8 | ガイド輝度の事前平滑 |

`UICondition`: Cross Size / Cross Amount は Cross Mode≠Off のときだけ表示。

Adaptive Degradation: `SupportsAdaptiveDegradation="True"`。`adsk_degrade` 時 Along Size≤8、サンプル上限削減、Tensor Soft≤4。

---

## 数式まとめ（疑似コード）

```
g = guide(uv)
g = gauss(g, Guide Soft)           // optional
J = blur(outer(grad(g)), Tensor Soft)
t, coherence = eigen_tangent(J)
along = blur1d_rgb(front, t, Along Size)
if CrossMode == WeakCross:
    soft = blur1d_rgb(along, perp(t), Cross Size)
    soft = mix(along, soft, Cross Amount)
else:
    soft = along
w = Amount * selective.r * smoothstep(CMin, CMin+CSoft, coherence)
out.rgb = mix(front.rgb, soft, w)
out.a = front.a
```

---

## やらないこと（初版）

- 髪キーヤー／色範囲キー
- LIC フル／本格 PDE 拡散の長反復
- 動的長配列・非有界ループ
- 大 Size 厳密 2D median
- beauty 用の周波数分離肌平滑を主目的にすること
- 表示レンジ clamp

---

## Phase 2（初版後）

| 項目 | 内容 |
|------|------|
| Bilateral along | 色差でサンプル重み（境界のにじみ軽減） |
| HF Suppress Cross | 法線方向ハイパス抑制モード |
| Angle Offset | θ に一定角度を加算（流れの手動補正） |
| Strength マット | Size の画素乗数（Morph 同様） |

---

## 実機で決めること

| 項目 | 仮 |
|------|-----|
| Along Size 既定 6 / max 32 | ○ |
| Tensor Soft 既定 2 | 髪の束次第で 3–4 も |
| Coherence Min 0.15 | マット内でも背景漏れに効く |
| Cross 既定 Weak / Size 1 | 強すぎると主髪も痩せる |
| ループ上限 N | 16 片側など |

テスト: 髪マット付きプレート、逆立つ産毛、三つ編み・分け目（方向が急変する箇所）、Selective なし全面（誤爆確認）。

---

## 実装チェックリスト

- [ ] クラシック GLSL、`#version` なし、早期 `return` なし
- [ ] 有界ループ、短い `#define` 禁止
- [ ] Direction / Coherence View で向きが髪に沿って見える
- [ ] Selective 外が無変化
- [ ] Linux `shader_builder` + Mac Flame
- [ ] README（英語 DisplayName、入力、主操作）
