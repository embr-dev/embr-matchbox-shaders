#!/usr/bin/env python3
"""PNG を Autodesk Flame の .p プロキシに変換する（解像度はそのまま）。

`.mx` のサムネイル正本はこれでも Mac の shader_builder でもない。
Linux で discreet_proxy（flame_proxy_icon）してから Linux の
shader_builder -m -p する。詳細は docs/api/packaging.md。

  gem install discreet_proxy
  flame_proxy_icon --from-png input.png
"""

from __future__ import annotations

import struct
import subprocess
import sys
import tempfile
from pathlib import Path


def _read_png_rgb(path: Path) -> tuple[int, int, list[tuple[int, int, int]]]:
    try:
        from PIL import Image

        img = Image.open(path).convert("RGB")
        w, h = img.size
        return w, h, list(img.getdata())
    except ImportError:
        pass

    with tempfile.TemporaryDirectory() as tmp:
        bmp_path = Path(tmp) / "proxy.bmp"
        result = subprocess.run(
            ["sips", "-s", "format", "bmp", str(path), "--out", str(bmp_path)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0 or not bmp_path.exists():
            raise RuntimeError(
                "PNG を読めません。Pillow を入れるか macOS の sips が必要です。\n"
                f"{result.stderr.strip()}"
            )
        return _read_bmp_rgb(bmp_path)


def _read_bmp_rgb(path: Path) -> tuple[int, int, list[tuple[int, int, int]]]:
    data = path.read_bytes()
    if data[:2] != b"BM":
        raise RuntimeError(f"BMP ではありません: {path}")
    offset, header_size = struct.unpack_from("<II", data, 10)
    w, h_signed = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp != 24:
        raise RuntimeError(f"24-bit BMP のみ対応（bpp={bpp}）")
    bottom_up = h_signed > 0
    h = abs(h_signed)
    row_stride = (w * 3 + 3) & ~3
    pixels: list[tuple[int, int, int]] = [(0, 0, 0)] * (w * h)
    for y in range(h):
        src_y = y if bottom_up else (h - 1 - y)
        row = offset + src_y * row_stride
        for x in range(w):
            b, g, r = data[row + x * 3 : row + x * 3 + 3]
            # BMP は下から。getdata と同じ上から順に直す
            dest_y = h - 1 - y if bottom_up else y
            pixels[dest_y * w + x] = (r, g, b)
    return w, h, pixels


def png_to_proxy(png_path: Path) -> Path:
    if png_path.suffix.lower() != ".png":
        raise ValueError(f"入力は .png: {png_path}")
    if not png_path.exists():
        raise FileNotFoundError(png_path)

    w, h, pixels = _read_png_rgb(png_path)
    if w % 4 != 0:
        raise ValueError(f"幅は 4 の倍数が必要（今は {w}）。128×92 か 268×194。")

    out_path = png_path.with_suffix(".p")
    row_stride = (w * 3 + 3) & ~3

    with out_path.open("wb") as f:
        f.write(struct.pack(">H", 0xFAF0))
        f.write(struct.pack(">H", 0x0000))
        f.write(struct.pack(">f", 1.1))
        f.write(struct.pack(">HHH", w, h, 130))
        f.write(struct.pack(">IIIIII", 0, 0, 0, 0, 0, 0))
        f.write(struct.pack(">H", 0))
        for row in range(h - 1, -1, -1):
            packed = bytearray()
            for col in range(w):
                packed.extend(pixels[row * w + col])
            packed.extend(b"\x00" * (row_stride - w * 3))
            f.write(packed)

    return out_path


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    failed = False
    for arg in argv[1:]:
        path = Path(arg)
        try:
            out = png_to_proxy(path)
            print(f"{path} → {out}")
        except (OSError, ValueError, RuntimeError) as exc:
            print(f"error: {path}: {exc}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
