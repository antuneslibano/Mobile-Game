#!/usr/bin/env python3
"""Converte arte gerada (ChatGPT etc.) em texturas do jogo (0.23).

Terrenos: art_src/terrain/<nome>.png (qualquer tamanho, quadrado) →
assets/environment/terrain/<nome>.png, 128×128, emendável e com paleta de até 8 cores.
  1. Emenda: mistura cada borda com a borda oposta (cosseno) para a textura repetir sem
     costura, mesmo se a imagem original não for perfeitamente emendável.
  2. Redução por área (média de cada bloco) para 128×128: cada pixel do jogo = média de
     um quadrado da imagem original, sem borrar entre pixels.
  3. Paleta: corte pela mediana + refinamento k-means, até 8 cores (pixel art chapado, sem ruído de compressão).

Minérios: art_src/ores/<nome>.png (ilustração com fundo escuro) →
assets/environment/ores/<nome>_1..3.png, 16×16 com fundo transparente.
  ATENÇÃO (0.23): ilustrações grandes e detalhadas ficam ilegíveis nesse tamanho; use
  arte pensada para ícone pequeno (poucas formas grandes, contorno grosso).
  1. Fundo: GrabCut (OpenCV) + fechamento e preenchimento da silhueta.
  2. Recorta o miolo quadrado da pilha, reduz para caber em 16×16 (área), paleta de até
     10 cores.
  3. Contorno escuro de 1 pixel em volta; 3 variações (original, espelhada e mais
     clara) para os depósitos não parecerem carimbados.
  Opcional: art_src/ores/<nome>_b.png vira a variação 3.

Uso: python3 tools/import_art.py terrain|ores [nome ...]
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


ORE = 16          # tamanho do sprite de depósito no jogo (EnvArt.ORE)
ORE_COLORS = 10
BG_TOL = 22.0     # diferença máxima de cor entre vizinhos do fundo


def silhouette(a: np.ndarray) -> np.ndarray:
    """Máscara do objeto (pilha de minério) numa ilustração com fundo escuro e brilho.
    GrabCut (OpenCV) com bordas e pretos como fundo certo e pixels claros como objeto
    provável; depois fecha os vãos (pedras cinzas entre os cristais) e preenche buracos."""
    import cv2
    bgr = cv2.cvtColor(a, cv2.COLOR_RGB2BGR)
    h, w = a.shape[:2]
    lum = a.astype(np.float32).mean(axis=2)
    m = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    m[lum > 95] = cv2.GC_PR_FGD
    m[lum < 14] = cv2.GC_BGD
    b = max(4, int(min(h, w) * 0.03))
    m[:b, :] = cv2.GC_BGD
    m[-b:, :] = cv2.GC_BGD
    m[:, :b] = cv2.GC_BGD
    m[:, -b:] = cv2.GC_BGD
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(bgr, m, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    k = max(9, int(min(h, w) * 0.04)) | 1
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    # Preenche buracos: tudo que não é alcançável pela borda no "não objeto".
    inv = (1 - fg).astype(np.uint8)
    ff = inv.copy()
    cv2.floodFill(ff, np.zeros((h + 2, w + 2), np.uint8), (0, 0), 2)
    fg[ff == 1] = 1
    # Só os pedaços relevantes (tira faíscas soltas).
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    keep = np.zeros_like(fg)
    if n > 1:
        big = st[1:, cv2.CC_STAT_AREA].max()
        for i in range(1, n):
            if st[i, cv2.CC_STAT_AREA] >= big * 0.03:
                keep[lab == i] = 1
    return keep.astype(bool)


def ore_sprite(src: Path, keep_whole: bool = False) -> Image.Image:
    im = Image.open(src).convert("RGB")
    a = np.asarray(im)
    fg = silhouette(a)
    ys, xs = np.nonzero(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # Recorte quadrado no centro da pilha (onde estão os cristais maiores): em 16 px a
    # pilha inteira vira farelo; o miolo fica legível. Baú e peças compactas ficam inteiros.
    if (x1 - x0) > (y1 - y0) * 1.15 and not keep_whole:
        side = int((y1 - y0) * 1.05)
        cx = int(np.average(xs))
        x0 = max(0, cx - side // 2)
        x1 = min(a.shape[1], x0 + side)
    rgb = a[y0:y1, x0:x1].astype(np.float32)
    alpha = fg[y0:y1, x0:x1].astype(np.float32)
    inner = ORE - 2  # sobra 1 pixel de cada lado para o contorno
    scale = inner / max(rgb.shape[0], rgb.shape[1])
    tw, th = max(1, round(rgb.shape[1] * scale)), max(1, round(rgb.shape[0] * scale))
    # Média ponderada pela cobertura (o fundo não escurece as bordas).
    pre = Image.fromarray(np.clip(rgb * alpha[..., None], 0, 255).astype(np.uint8)).resize((tw, th), Image.Resampling.BOX)
    cov = Image.fromarray((alpha * 255).astype(np.uint8)).resize((tw, th), Image.Resampling.BOX)
    pre_a = np.asarray(pre).astype(np.float32)
    cov_a = np.asarray(cov).astype(np.float32) / 255.0
    col = np.where(cov_a[..., None] > 0.01, pre_a / np.maximum(cov_a[..., None], 0.01), 0)
    solid = cov_a >= 0.45
    small = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    small = quantize(small, ORE_COLORS)
    out = np.zeros((ORE, ORE, 4), dtype=np.uint8)
    ox, oy = (ORE - tw) // 2, ORE - 1 - th  # apoiado embaixo (pilha no chão do bloco)
    sm = np.asarray(small)
    for y in range(th):
        for x in range(tw):
            if solid[y, x]:
                out[oy + y, ox + x, :3] = sm[y, x]
                out[oy + y, ox + x, 3] = 255
    # Contorno escuro onde a vizinhança tem pixel sólido.
    a_ = out[..., 3] > 0
    edge = np.zeros_like(a_)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        edge |= np.roll(a_, (dy, dx), axis=(0, 1))
    edge &= ~a_
    out[edge] = (20, 14, 18, 255)
    return Image.fromarray(out, "RGBA")


def ores(name: str) -> None:
    src = ROOT / "art_src" / "ores" / f"{name}.png"
    whole = name in ("bau",)
    v1 = ore_sprite(src, whole)
    v2 = v1.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    alt = ROOT / "art_src" / "ores" / f"{name}_b.png"
    if alt.exists():
        v3 = ore_sprite(alt, whole)
    else:
        # Original um pouco mais clara (brilho de outro ângulo).
        arr = np.asarray(v1).astype(np.float32)
        arr[..., :3] = np.clip(arr[..., :3] * 1.12, 0, 255)
        v3 = Image.fromarray(arr.astype(np.uint8), "RGBA")
    for i, v in enumerate((v1, v2, v3), 1):
        dst = ROOT / "assets" / "environment" / "ores" / f"{name}_{i}.png"
        v.save(dst)
    print(f"{name}: {src.name} → ores/{name}_1..3.png")


def main() -> None:
    kind = sys.argv[1] if len(sys.argv) > 1 else "terrain"
    names = sys.argv[2:] or sorted(p.stem for p in (ROOT / "art_src" / kind).glob("*.png") if not p.stem.endswith("_b"))
    for n in names:
        if kind == "terrain":
            terrain(n)
        elif kind == "ores":
            ores(n)


if __name__ == "__main__":
    main()
