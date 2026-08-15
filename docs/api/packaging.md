# ビルド・プリセット・配置

## shader_builder

場所: `/opt/Autodesk/<product_home>/bin`（旧 `/usr/discreet/<product_home>/bin`）。

```bash
shader_builder --help
shader_builder -m -x embr_tint.glsl          # Matchbox: 検証 + XML
shader_builder -l -x embr_gain.glsl          # Lightbox
shader_builder -m -p embr_tint.glsl          # 暗号化 .mx（シングルパス）
shader_builder -m -p embr_blur.*.glsl        # 暗号化 .mx（マルチパス。全 .glsl を渡す）
shader_builder -l -p embr_gain.glsl          # 暗号化 .lx
shader_builder -m -t embr_tint.glsl          # 空の preset テンプレート
shader_builder -u packaged.mx                # xml / png / .p を展開
shader_builder -m -p -d embr_tint.glsl       # コンパイルせずパッケージ
shader_builder -m -x -o /tmp/out embr_tint.glsl
```

| 短 | 長 | 意味 |
|----|-----|------|
| `-m` | `--matchbox` | Matchbox |
| `-l` | `--lightbox` | Lightbox |
| `-x` | `--write-xml` | sidecar XML |
| `-p` | `--package` | `.mx` / `.lx` |
| `-u` | `--unpack` | パッケージ展開 |
| `-t` | `--preset-template` | preset 雛形 |
| `-o` | `--output` | 出力先 |
| `-d` | `--do-not-compile` | `-p` と併用。コンパイルしない |
| `-h` | `--help` | ヘルプ |

成功時（概念）:

```
compiling shader file embr_tint.glsl ... [OK]
all shaders compiled ... [OK]
generating XML interface ...
creating XML file (embr_tint.xml) ... [OK]
```

エラーがあると XML は作られない。2025 以前は警告でも XML が出ることがある。**2025.1 以降はより厳格**で、かつての警告がエラーになる。

### マルチパスの `.mx`

`shader_builder` は引数に列挙した `.glsl` だけをパッケージする。後続パスを自動では拾わない。

- **正しい**: シェルのグロブで全パスを渡す。`embr_blur.*.glsl`（例: `embr_blur.1.glsl` … `embr_blur.8.glsl`）。同じベース名の `.xml` と `.1.glsl.p`（なければ `.1.glsl.png`）は自動で拾う。
- **誤り**: `embr_blur.1.glsl` だけ。後続パスが `.mx` に入らず、Flame で `CreateRenderGraph` になる。コンパイルあり・なし（`-d`）どちらでも同じ。

成功時は各パスが `compiling shader file …N.glsl ... [OK]` と出る。1 本しか出ていなければ全パスを渡せていない。

観測（Flame 2025 / macOS）: 全パスを渡せばコンパイル `[OK]`。`.p` があれば `using thumbnail (…1.glsl.p)`。

macOS で `ERROR : Compiling shaders requires a valid Display` または `Warning : Did not compile shaders because no valid Display has been found` は、**`DISPLAY` 環境変数が空**なだけ。実在する X サーバは見ていない（`DISPLAY=/tmp/dummy` でも警告は消える）。

```bash
env DISPLAY=:0 /opt/Autodesk/flame_2025/bin/shader_builder -m -p shaders/embr_morphology/embr_morphology.*.glsl
```

これで警告は消える。LOGIK でも Mac で同じ回避が通った例がある（[Compiling shaders requires a valid Display](https://forum.logik.tv/t/error-compiling-shaders-requires-a-valid-display/2952)）。恒久的にするなら [XQuartz](https://www.xquartz.org) を入れてログアウト／ログインすると `DISPLAY` が付く。builder は GLUT / OpenGL にリンクしている。

**Matchbox モードの `.mx` サムネイルは Mac の `shader_builder` では焼けない。** `DISPLAY=:0` 付きでも空のまま（確認済み）。GLSL モードの sidecar `.p` は Mac で見える。同じ Mac Flame でも **Linux 製 `.mx` はサムネイルが出る。** サムネイル付きパッケージは Linux で作る。

Mac の builder は行番号付きエラーを出さないことが多い。

モダン `#version 430` では uniform block 内を **1 行 1 宣言**にする。`float adsk_result_w, adsk_result_h;` だと 2026.2 付近の builder が UI なし XML を出す。

## プリセット

Flame 内で見た目を作り、Node Prefs（Action なら Shader タブ）の **UI XML Shell Printout** を押す。アプリをシェルから起動しているとそのシェルに XML が出る（Mac はシェル起動が安全）。

```xml
<Presets>
  <Preset Name="Sepia">
    <Shader Index="1">
      <Uniform Type="float" DisplayName="Contrast" Name="adskUID_contrast" Value="95.6"/>
    </Shader>
  </Preset>
</Presets>
```

- カーブの位置・タンジェントはプリセット非対応。
- ファイル名: `<shader>.preset.xml`。パッケージに含める。
- `-t` で空テンプレートを出して貼り付けてもよい。
- ユーザーがシェル出力を送って作者が取り込む、という流れが公式想定。

## プロキシ（ブラウザサムネイル）

GLSL モードはディスク上の sidecar **`.p`** を読む。PNG だけでは出ない。`.mx`（Matchbox モード）のサムネイルは **Linux の `shader_builder -m -p` が焼く**。Mac 製は `DISPLAY=:0` 付きでも空（確認済み）。同じ Mac Flame でも Linux 製 `.mx` は見える。

解像度は PNG のまま `flame_proxy_icon` する。縮小は不要。

| 出典 | サイズ |
|------|--------|
| Flame 2025 Help の PNG | 8-bit **128×92**（このリポジトリのソース） |
| Shader Builder API Guide 2016 / 公式 EXAMPLES の一部 `.p` | **126×92** |
| LOGIK / コミュニティ | `Name.glsl.png` + `Name.glsl.p`。例: 268×194 |
| [discreet_proxy](https://github.com/julik/discreet_proxy) 既定 | 126×92（入力 PNG のサイズを維持して書く） |

ファイル名は Flame がアイコンを読む `.glsl` に合わせる。

- シングルパス: `embr_tint.glsl.png` → `embr_tint.glsl.p`
- マルチパス: `embr_blur.1.glsl.png` → `embr_blur.1.glsl.p`（最初のパス）

変換は [discreet_proxy](https://github.com/julik/discreet_proxy) の `flame_proxy_icon`（Julik Tarkhanov）。サムネイル付き `.mx` は Linux で `.p` を作ってからパッケージする。

```bash
# Linux（サムネイル付き .mx）
flame_proxy_icon --from-png embr_morphology.1.glsl.png
shader_builder -m -p embr_morphology.*.glsl
```

```bash
# macOS（GLSL モード用 sidecar のみ）
flame_proxy_icon --from-png shaders/embr_morphology/embr_morphology.1.glsl.png
```

### Mac から Linux へ SSH して焼く

可能。ソースを送って Linux の `shader_builder` だけ走らせ、`.mx` を回収する。

```bash
tools/pack_mx_linux.sh user@flame-linux shaders/embr_morphology
```

手でやるなら:

```bash
rsync -a shaders/embr_morphology/ user@host:/tmp/embr_morphology/
ssh user@host 'export DISPLAY=:0; cd /tmp/embr_morphology; /opt/Autodesk/flame_2025/bin/shader_builder -m -p embr_morphology.*.glsl'
scp user@host:/tmp/embr_morphology/embr_morphology.mx shaders/embr_morphology/
```

- `embr_morphology.*.glsl` は **SSH の先で**展開する。Mac の zsh で先に展開するとローカルパスが送られて失敗する。引用符で囲む。
- Linux も GUI コンソールが無い SSH だけだと `no valid Display` になる。その機にログインセッションがあるなら `DISPLAY=:0`（[LOGIK](https://forum.logik.tv/t/error-compiling-shaders-requires-a-valid-display/2952)）。
- `.p` は Mac で作って同梱してよい。Linux に `flame_proxy_icon` が無ければそれで足りる。
- 共有ディスク上なら rsync は不要。Linux 側でそのパスを `cd` して `shader_builder` するだけ。

LOGIK Matchbook に載せるなら `.glsl.png` と `.glsl.p` を揃える。

## インストールパス

| 用途 | パス |
|------|------|
| 工場出荷 Matchbox | `/opt/Autodesk/presets/<version>/matchbox/shaders/` |
| 工場出荷 Lightbox | `/opt/Autodesk/presets/<version>/action/lightbox/` |
| 共有カスタム | `/opt/Autodesk/shared/matchbox/shaders/` |
| Search ウィジェット | Preferences → Shader Paths。サブフォルダ可 |

ブラウザに出ないときは Mode を Matchbox と GLSL で切り替える。

このリポジトリのソースは `shaders/<name>/`。Flame へはフォルダごと shared にコピーする。

## 公式 EXAMPLES（Matchbox）

`/opt/Autodesk/presets/<version>/matchbox/shaders/EXAMPLES/`

| 名前 | 内容 |
|------|------|
| Accumulate | `adsk_accum_texture` |
| Blending | int popup と blend API |
| BuildList | int popup のみ |
| ColourWheel | Colour Wheel ウィジェット |
| ConditionalUI | 条件付き UI |
| CubeMapSampler | cubemap 入力 |
| Curves | Curve ウィジェット 2 種 |
| DecodeZDepthHQ | Action Z-Depth HQ のデコード |
| GridFetchingComp / CompMulti / Replace | `adsk_texture_grid` |
| ImageLighting / Position / Rotation / Scaling | 2D 変換・ライト |
| InputSockets | InputType と色 |
| LightsAPI | シーンライト情報 |
| MatchboxAPI | Matchbox API 呼び出し |
| Mipmaps | mipmap ブラー |
| MultiExecutionSeparableGaussianBlur | `NbExecutions` |
| MultiTargetCustomMipmaps | カスタム mipmap |
| PyramidBlur | 高速ガウシアン相当のマルチパス |
| TemporalSampling | 前・次フレーム |
| TransitionShader | Timeline トランジション |
| UIOnly | Expression 用 UI のみ |

## LOGIK Matchbook / Portal

- リポジトリ: https://logik-matchbook.org/
- 共有: https://logik-matchbook.org/sharing
- Portal: https://logik-portal.com/matchboxes/
- フォーラム: https://forum.logik.tv/

アップロードは **ファイル単位**（フォルダごと不可）。少なくとも `.xml` と `.glsl`。アイコンは `.glsl.png` / `.glsl.p`。`.mx` / `.lx` だけは無効。暗号化パッケージを出すなら **復号できる XML とアイコンも必須**。`.mx` があるとダウンロードはパッケージのみ（ソース非公開）。

GitHub webhook: `https://logik-matchbook.org/github-hook` を repo に足すと push で取り込まれる。

コミュニティの巨大コレクションは `crok_*`（Ivar）など。参考にしてよいが、再配布はライセンスとクレジットを守る。

## バージョン互換

新しい Matchbox を古い Flame で使う保証はない（API と XML スキーマ更新）。**古いものを新しい Flame で使う方向はサポート**される。`SoftwareVersion` は builder が書く。意図的に最低バージョンを示すコミュニティ慣例もある。
