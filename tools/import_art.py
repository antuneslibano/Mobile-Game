#!/usr/bin/env python3
"""Converte arte gerada (ChatGPT etc.) em texturas do jogo (0.23).

Terrenos: art_src/terrain/<nome>.png (qualquer tamanho, quadrado) →
assets/environment/terrain/<nome>.png, 128×128, emendável e com paleta de até 8 cores.
  1. Emenda: mistura cada borda com a borda oposta (cosseno) para a textura repetir sem
     costura, mesmo se a imagem original não for perfeitamente emendável.
  2. Redução por área (média de cada bloco) para 128×128: cada pixel do jogo = média de
     um quadrado da imagem original, sem borrar entre pixels.
  3. Paleta: corte pela mediana + refinamento k-means, até 8 cores (pixel art chapado, sem ruído de compressão).

Uso: python3 tools/import_art.py terrain [nome ...]
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
TILE = 128   # 0.23: o atlas de terreno usa 128×128 (TerrainTextures.TERRAIN_TILE)
COLORS = 8
SEAM = 0.12   # fração da largura misturada com a borda oposta


def seamless(a: np.ndarray) -> np.ndarray:
    """Mistura as bordas com o lado oposto (a imagem passa a emendar nos 4 lados)."""
    h, w, _ = a.shape
    out = a.astype(np.float32)
    for axis, n in ((1, w), (0, h)):
        k = int(n * SEAM)
        rolled = np.roll(out, n // 2, axis=axis)  # o meio vira borda e vice-versa
        t = np.ones(n, dtype=np.float32)
        ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, k))
        t[:k] = ramp
        t[n - k:] = ramp[::-1]
        shape = (1, n, 1) if axis == 1 else (n, 1, 1)
        t = t.reshape(shape)
        # Perto das bordas, usa a versão deslocada (que é contínua ali).
        out = out * t + rolled * (1.0 - t)
    return out


def quantize(img: Image.Image, colors: int) -> Image.Image:
    q = img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE)
    return q.convert("RGB")


def terrain(name: str) -> None:
    src = ROOT / "art_src" / "terrain" / f"{name}.png"
    im = Image.open(src).convert("RGB")
    s = min(im.size)
    im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width - s) // 2 + s, (im.height - s) // 2 + s))
    a = seamless(np.asarray(im))
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    small = im.resize((TILE, TILE), Image.Resampling.BOX)
    out = quantize(small, COLORS)
    dst = ROOT / "assets" / "environment" / "terrain" / f"{name}.png"
    out.save(dst)
    print(f"{name}: {src.name} {Image.open(src).size} → {dst.relative_to(ROOT)} {out.size}")


def main() -> None:
    kind = sys.argv[1] if len(sys.argv) > 1 else "terrain"
    names = sys.argv[2:] or sorted(p.stem for p in (ROOT / "art_src" / kind).glob("*.png"))
    for n in names:
        if kind == "terrain":
            terrain(n)


if __name__ == "__main__":
    main()
