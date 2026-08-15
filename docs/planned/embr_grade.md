# embr_grade（検討メモ・未実装・段階実装）

表示名案: **Embr Grade**。Flame 標準 **MasterGrade の代替／補強**を目指すプライマリ〜セカンダリ灰色。  
目標感は DaVinci Resolve / Baselight 級の **作業空間を意識した**グレーディング。一発で全部は作らず **Phase で出荷**する。

関連: [README.md](README.md)、[shader-api.md](../api/shader-api.md)（`adsk_scene2log` / `adsk_log2scene` / `adskEvalDynCurves` / ColourWheel*）、[xml-schema.md](../api/xml-schema.md)。

状態: **調査＋段階仕様の初稿・未実装**（2026-08-15）。

---

## なぜ作るか（MasterGrade の弱み）

公式 MasterGrade（Lustre 由来の Matchbox）は Video / Log / Scene-linear の **Image Type** を持つが:

1. **Image Type はコントロールの応答を切り替えるだけ**で、色空間変換はしない（LOGIK 教材でも明記）
2. Log / Linear を混同すると、同じ数値でも挙動が噛み合わない
3. カスタム Matchbox からは **MasterGrade 専用ウィジェットは使えない**（公式注記）。通常の ColourWheel / Curve / float で組み立てる必要がある
4. VFX で欲しい **ASC CDL（非クランプ）**や Resolve 的 Log SMH、Baselight 的ゾーン（stops）が第一級ではない

Embr Grade の差別化:

| 柱 | 内容 |
|----|------|
| **Grade Encoding** | Pass-Through と **一時 Log／疑似 ACEScct で打って戻す**を明示（Linear 素材でも Log 操作感） |
| **作業単位** | Video=0–1 慣習、Log=printer / code value、Linear=**stops / 0.18 grey** |
| **ASC CDL** | Slope/Offset/Power + Sat。**表示 clamp なし**（ACEScct 付録に準拠） |
| **Resolve 系** | LGG+Offset、Log Shadow/Mid/Highlight + Low/High Range |
| **Baselight 系** | 後期 Phase で mid-grey 基準ゾーン（stops）。T-CAM/Chromogen の複製はしない |
| **Selective** | マットで強度。キーヤーは内蔵しない |

---

## 調査メモ（参照した考え方）

### DaVinci Resolve

| 系 | 要点 | Embr への取り込み |
|----|------|-------------------|
| Primaries LGG + Offset | 重なり合うトーン帯。定番バランス | Phase 1 Video / 共通 |
| Log Wheels SMH | **帯の重なりが少ない**。Low/High Range で境界 | Phase 1 Log |
| HDR Palette | 色空間Aware・知覚的作業空間・コントラストと彩度の分離・ゾーン | Phase 3 以降（簡略ゾーン）。フル HDR UI は Matchbox では無理 |
| Node HDR Mode | 広い緯度向けにコントロールを再スケール | Grade Encoding + Linear 単位で近似 |
| Color Mgmt | ノード外の CST / RCM / ACES | Flame 側 CM に任せ、シェーダは **作業空間を宣言するだけ** |

### Baselight (FilmLight)

| 系 | 要点 | Embr への取り込み |
|----|------|-------------------|
| FilmGrade | Log（Cineon 系）向きのフィルム的操作 | Log Brightness ≒ printer lights 感 |
| Base Grade | **18% grey 基準・stops ゾーン**、グローバル Flare/Balance/Contrast/Sat | Phase 3「Zones」 |
| T-CAM / Chromogen / Curve Grade | 外見モデル・相手色空間・高度カーブ | **複製しない**（プロプライエタリ＋巨大）。思想だけ「知覚的・scene-referred」 |

### ASC CDL / ACES

```
sop = in * slope + offset
out = (sop > 0) ? pow(sop, power) : sop   // 負は power しない
// Sat: luma + sat * (rgb - luma)、Rec.709 係数
// ACEScct 付録: limiting / display clamp しない
```

業界受け渡しの最小共通言語。VFX の look 往復に必須 → **Phase 1 から独立ページ**。

### Flame / LOGIK

- MasterGrade: Primary + Tone（Blacks…Whites）+ Curves。Scene-linear は Exposure(stops)、Contrast Pivot=0.18、Offset=フレア相当
- `adsk_scene2log` / `adsk_log2scene`: **Cineon 風**のみ（フル OCIO ではない）。一時 Log 作業の足場にする
- ColourWheel / ColourWheelRGBOffset / Slope / Power、Curve + `adskEvalDynCurves`
- LOGIK に同等の「プロ級プライマリ一式」は前提にせず、式は公開仕様・教科書ベースで自前実装

---

## アーキテクチャ（全 Phase 共通）

```
Front ─► [optional encode] ─► CDL? ─► Primaries ─► Tone? ─► Curves? ─► Sat ─► [optional decode]
                ▲                      ▲
           Grade Encoding         Working Model
                │
         Selective / Matte → mix
```

処理順（Resolve ノード内の「HDR→Primaries」に似せた固定順）:

1. Grade Encoding（必要なら lin→作業空間）
2. ASC CDL（ページで Bypass 可）
3. Primaries（Working Model 依存）
4. Tone / Zones（Phase 2+）
5. Curves（Phase 2+）
6. Master Saturation（常時）
7. Encoding 戻し
8. `mix(front, graded, amount * selective)`

**やらない（全 Phase）**

- MasterGrade UI の複製（専用ウィジェット不可）
- フル OCIO / 任意カメラ IDT の内蔵（Flame CM に任せる）
- Baselight T-CAM / Chromogen の逆工程
- 表示レンジへの `clamp(rgb,0,1)`（despill と同じ **unclamped** 方針。任意 Soft Clip は別トグル）
- 内蔵キーヤー（Selective / Matte のみ）

---

## Grade Encoding（MasterGrade 弱点への回答）

| Value | Title | 動作 |
|-------|-------|------|
| 0 | Pass-Through（既定） | 作業空間のまま打つ。入力が本当に Log / Video / Linear のとき |
| 1 | Temp Cineon Log | `adsk_scene2log` → 操作 → `adsk_log2scene`。**Scene-linear プレートに Log 操作感を載せる** |
| 2 | Temp ACEScct-like（Phase 2） | 公開 ACEScct 式の近似で lin↔log。CDL を「正しい」空間で打つ用 |

Working Model（Video / Log / Linear）と Encoding は **別軸**:

- Linear プレート + Encoding=Temp Log + Model=Log → Resolve で言う「ログ空間で Log ホイール」に近い
- Linear + Encoding=Pass + Model=Linear → Exposure/Contrast(stops)
- Log プレート + Encoding=Pass + Model=Log → printer / SMH
- Video + Pass + Video → LGG

Tooltip で「Encoding は変換、Model はどの式のプライマリか」と明記。

---

## Phase 1 — Foundation（最初の出荷）

目標: **Log / Linear で破綻しにくいプライマリ + CDL**。シングルパス優先。

### 入力

| Socket | NoInput | 役割 |
|--------|---------|------|
| Front | Error | 必須 |
| Selective | White | グレード強度（R）。未接続=全面 |
| Matte | White | Selective と同義にしてもよいが、公式に合わせ **Selective** を優先。Matte は省略可 |

`MatteProvider="False"`（親マットパススルー）。`LimitInputsToTexture="True"`。

### Page 0 — Setup

| Control | Type | Default | 内容 |
|---------|------|---------|------|
| Working Model | Popup | **Video** | Video / Log / Scene-Linear。既定は Video（現場の初期バランス用） |
| Grade Encoding | Popup | Pass-Through | Pass-Through / Temp Cineon Log |
| Bypass CDL | bool | True | Phase 1 は CDL ページを独立。既定オフ運用でも可 → **Bypass CDL=True**（触るまで CDL 無効） |
| Saturation | float | 1 | 0–4。最終寄り |
| Mix | float | 1 | 0–1 |
| Soft Clip | bool | False | 任意のハイライト緩和。既定オフ（clamp ではない） |
| View | Popup | Result | Result / Source / Diff |

Working Model 切替で Primary ページの表示を `UICondition` 切替（値リセットは Flame 任せ。Tooltip で「Model 変更は式が変わる」）。

### Page 1 — Primaries（Model 別）

#### Video（Resolve LGG 系）

| Control | UI | 式の骨格 |
|---------|-----|----------|
| Lift | ColourWheelRGBOffset + Master float | 黒寄り。白ピボット既定 1 |
| Gamma | ColourWheel + Master | 中間。黒白ピボット |
| Gain | ColourWheelRGBSlope + Master | 白寄り。黒ピボット 0 |
| Offset | ColourWheelRGBOffset + Master | 全体加算 |

ピボット数値は Phase 1 では固定（0/1）。Controls ページは Phase 2。

#### Log（Resolve Log + MasterGrade Log の合成）

| Control | UI | 内容 |
|---------|-----|------|
| Brightness | ColourWheelRGBOffset + Master | Log での平行移動（printer / code 感）。MasterGrade Brightness に相当 |
| Contrast | float | Pivot 周り |
| Pivot | float | Log: -1…+1（MasterGrade に合わせる仮）。既定 ~ middle grey |
| Shadow / Midtone / Highlight | 各 ColourWheelRGBOffset + Master | Resolve Log SMH。**重なり少なめのウェイト** |
| Low Range / High Range | float | SMH 境界（Resolve 同趣旨） |

SMH ウェイトは公開できる滑らかな区分関数（例: smoothstep 境界）。Legacy Resolve 曲線の完全再現はしない。

#### Scene-Linear（MasterGrade Linear + Baselight 的単位）

| Control | UI | 内容 |
|---------|-----|------|
| Exposure | ColourWheel 的 RGB + Master（stops） | `rgb * exp2(exposure)`。色付きはチャンネル別 stops |
| Contrast | float | Pivot 周り。Pivot 既定 **0.18**、単位 stops 相対 |
| Pivot | float | stops relative to 0.18 |
| Offset | ColourWheelRGBOffset + Master | 加算フレア／ゼロ点。linear 単位 |

### Page 2 — CDL

| Control | Type | Default |
|---------|------|---------|
| Slope | ColourWheelRGBSlope または vec3 | 1,1,1 |
| Offset | ColourWheelRGBOffset | 0,0,0 |
| Power | ColourWheelRGBPower | 1,1,1 |
| Saturation | float | 1 |

Bypass 時スキップ。**clamp なし**。負の sop に power しない。

### Phase 1 の UI 制約

- Row 0–4 / Col 少数 → ホイールは **1 ページに詰め込みすぎない**。Video と Log で Conditional Hide
- MasterGrade のような「1 ホイール＋タブ」は不可。コントロールは並立
- 英語 DisplayName。Description に日本語併記可

### Phase 1 完了条件

- [ ] Linear プレート + Temp Log + Log Model で SMH / Brightness が破綻なく動く
- [ ] Linear + Pass + Linear Model で Exposure(stops) が 0.18 基準
- [ ] CDL が unclamped、負値で NaN なし
- [ ] Selective で Mix
- [ ] Linux `shader_builder` + Mac Flame で表示確認

---

## Phase 2 — Tone + Curves + ACEScct-like

| 追加 | 内容 |
|------|------|
| Grade Encoding = Temp ACEScct-like | 公開式。CDL/Primaries を log 作業空間で |
| Tone | Blacks / Shadows / Midtones / Highlights / Whites（MasterGrade Tone に近い）。Linear 時は stops 単位の Start/Width |
| Curves | Master + RGB。`ValueType=Curve` + `adskEvalDynCurves`。Scene-linear グラフは stops 表示を目指すが、XML Curve の軸はホスト依存 → ドキュメントで説明 |
| Temperature / Tint | 簡易（Planck 近似または LMS シフトの簡易版） |
| Soft Clip パラメータ | 肩の強さ（仍オフ既定） |

処理順に Tone を Primaries の後、Curves をその後へ挿入。

---

## Phase 3 — Zones（Baselight Base Grade 思想）＋セカンダリ薄味

| 追加 | 内容 |
|------|------|
| Zones | mid-grey 基準の Dark / Dim / Light / Bright（stops）。Global Contrast / Balance / Flare |
| Hue vs Sat 等 | Curve ベースの簡易セカンダリ（フル Qualifier は作らない） |
| Printer Lights | Log 専用の 0.025 log ステップ等（ADX 慣習を Tooltip） |

T-CAM・相手色空間マッチングは対象外。

---

## Phase 4 — 磨き（任意）

- View: luma / saturation isolation
- CDL の Slope/Offset を Printer 操作にマッピングするヘルパ
- プリセット用の値のドキュメント（ASC CDL XML 入出力は Matchbox 外）
- Image ノード内での使い方を README に

---

## 実装上の注意

| 項目 | 方針 |
|------|------|
| パス数 | Phase 1 は **1 パス**。Curve が増えたら必要なら分割 |
| float 精度 | OutputBitDepth=`Output`。内部も clamp しない |
| `adsk_getLuminance` | Sat / SMH ウェイト用。係数は `adsk_getLuminanceWeights` または Rec.709 をドキュメント化 |
| Adaptive Degradation | グレード自体は軽い。`SupportsAdaptiveDegradation` は False でも可 |
| ライセンス | MIT。Resolve/Baselight のコードは使わない。式は ASC / ACES 公開仕様と一般的 LGG |
| 名前 | `embr_grade`。MasterGrade を名乗らない |

---

## UI ページ総覧（最終形の見通し）

| Page | 名前 | Phase |
|------|------|-------|
| 0 | Setup | 1 |
| 1 | Primaries | 1 |
| 2 | CDL | 1 |
| 3 | Tone | 2 |
| 4 | Curves | 2 |
| 5 | Zones | 3 |
| 6 | Secondary | 3 |

---

## 優先度と他シェーダとの関係

- 体積が大きいので **median / holefill / despill と並行可能**だが、実装着手は Phase 1 に限定
- 色管理は Flame プロジェクト CM が上流。本シェーダは「打つ場所」を明確にする
- despill の unclamped 方針と整合

状態: **Phase 分割と Encoding 方針まで確定寄り・UI 詳細は Phase 1 着手前にもう一段詰める**。  
Working Model 既定: **Video**（2026-08-15 確定）。

## 次の具体ステップ（実装前）

1. Phase 1 の Video LGG / Log SMH / Linear Exposure の数式を別節で確定（疑似コード）
2. XML の ColourWheel* 配置モック（Row/Col）。Popup 順は Video=0 / Log=1 / Scene-Linear=2（Default=0）
3. 実機で MasterGrade と並走比較するテストプレート（LogC / scene-linear EXR / Rec.709）
