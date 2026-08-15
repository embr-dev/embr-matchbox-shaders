#!/usr/bin/env bash
# Mac から Linux の shader_builder でサムネイル付き .mx を焼く。
#
# Usage:
#   tools/pack_mx_linux.sh user@flame-linux shaders/embr_morphology
#
# 環境変数:
#   SHADER_BUILDER  既定 /opt/Autodesk/flame_2025/bin/shader_builder
#   DISPLAY         リモート側。未設定なら :0（コンソール GUI が必要）
#
# グロブは Linux 側で展開する。Mac の zsh で *.glsl を先に展開しない。

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 user@host shaders/<name>" >&2
  exit 1
fi

host=$1
src=$(cd "$2" && pwd)
name=$(basename "$src")
builder=${SHADER_BUILDER:-/opt/Autodesk/flame_2025/bin/shader_builder}
remote=$(ssh "$host" 'mktemp -d /tmp/embr-mx.XXXXXX')

rsync -a --delete \
  --include="${name}.xml" \
  --include="${name}.glsl" \
  --include="${name}.*.glsl" \
  --include="${name}.glsl.png" \
  --include="${name}.glsl.p" \
  --include="${name}.1.glsl.png" \
  --include="${name}.1.glsl.p" \
  --exclude='*' \
  "$src/" "$host:$remote/"

ssh "$host" bash -s -- "$remote" "$name" "$builder" <<'REMOTE'
set -euo pipefail
remote=$1
name=$2
builder=$3
export DISPLAY=${DISPLAY:-:0}
cd "$remote"
shopt -s nullglob
files=( "$name".*.glsl )
if [[ ${#files[@]} -eq 0 ]]; then
  files=( "$name".glsl )
fi
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no glsl in $remote" >&2
  exit 1
fi
"$builder" -m -p "${files[@]}"
REMOTE

scp -q "$host:$remote/${name}.mx" "$src/${name}.mx"
ssh "$host" "rm -rf $(printf '%q' "$remote")"
echo "wrote $src/${name}.mx"
