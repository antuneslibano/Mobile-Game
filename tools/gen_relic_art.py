#!/usr/bin/env python3
"""Gera os sprites 16×16 das relíquias (0.19.1) em assets/environment/ores/relic_*_N.png.
Três variações por relíquia (mesmo desenho, brilhos em lugares diferentes).
Uso: python3 tools/gen_relic_art.py
Os .import desses PNGs precisam de importer="image" (como os outros minérios)."""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/environment/ores"

ART = {
    # Semente Primordial: casca de semente com veio verde vivo e um broto.
    "relic_seed": ({
        "k": "1e140a", "b": "6b4423", "B": "9a6a3a", "g": "3fbf4a", "G": "9dff7a", "w": "f0ffe0",
    }, [
        "................",
        ".........GG.....",
        "........GwGg....",
        "......gG.gG.....",
        ".......gGg......",
        "......kkgkk.....",
        ".....kbBgBbk....",
        "....kbBBgBBbk...",
        "....kbBgGgBbk...",
        "...kbBBBgBBBbk..",
        "...kbBgGwGgBbk..",
        "...kbbBBgBBbbk..",
        "....kbbBgBbbk...",
        ".....kbbgbbk....",
        "......kkkkk.....",
        "................",
    ]),
    # Âmbar Solar: gota de âmbar com um inseto preso dentro.
    "relic_amber": ({
        "k": "4a2205", "o": "c46a10", "O": "ffb43a", "y": "ffe08a", "w": "fffbe8", "i": "3a1a05",
    }, [
        "................",
        "......kkkk......",
        "....kkOOOOkk....",
        "...kOyyOOOOok...",
        "...kOywOOOOok...",
        "..kOOyOOOOOOok..",
        "..kOOOOiiOOOok..",
        "..kOOOiiiiOOok..",
        "..kOOOOiiOOOok..",
        "..kOOOiOOiOOok..",
        "..koOOOOOOOOok..",
        "...koOOOOOOok...",
        "...kooOOOOook...",
        "....kkooookk....",
        "......kkkk......",
        "................",
    ]),
    # Coração de Ferro: coração de metal rebitado com núcleo vermelho.
    "relic_heart": ({
        "k": "1c2028", "m": "6c7a8c", "M": "c8d4e4", "w": "ffffff", "r": "ff3a2a", "R": "ffb09a", "v": "3a4250",
    }, [
        "................",
        "................",
        "...kkk....kkk...",
        "..kmMMk..kMMmk..",
        ".kmMwMMkkMMMMmk.",
        ".kmMMMMmmMMMMmk.",
        ".kvMMMMrrMMMMvk.",
        ".kmMMMrRRrMMMmk.",
        "..kmMrRRRRrMmk..",
        "...kvMMrrMMvk...",
        "....kmMMMMmk....",
        ".....kmMMmk.....",
        "......kmmk......",
        ".......kk.......",
        "................",
        "................",
    ]),
    # Pérola do Brejo: pérola brilhante numa concha aberta.
    "relic_pearl": ({
        "k": "1c3038", "s": "4a6a5a", "S": "8ab09a", "p": "b8e2f0", "P": "eefcff", "w": "ffffff", "b": "7ab8d0",
    }, [
        "................",
        "................",
        "......kkkk......",
        "....kkbppbkk....",
        "...kbpPPPppbk...",
        "...kpPwwPPppk...",
        "..kbpPwPPPppbk..",
        "..kbpPPPPPppbk..",
        "..kbbpPPPppbbk..",
        "...kbbppppbbk...",
        ".kSkkbbbbbbkkSk.",
        ".kSSSkkkkkkSSSk.",
        "..ksSSSSSSSSsk..",
        "...kksssssskk...",
        ".....kkkkkk.....",
        "................",
    ]),
    # Lágrima de Magma: gota de crosta escura com magma rachando por dentro.
    "relic_magma": ({
        "k": "140806", "c": "3a1a14", "C": "5a2a1a", "o": "ff5a2a", "O": "ffa040", "y": "fff0a0",
    }, [
        ".......kk.......",
        ".......kk.......",
        "......kOOk......",
        "......kcok......",
        ".....kcOock.....",
        ".....kcoOck.....",
        "....kcCoOCck....",
        "....kcoOyocck...",
        "...kcCoyyOoCck..",
        "...kcooyyOocck..",
        "...kcCoOyoCcck..",
        "...kccCooCccck..",
        "....kccoocCck...",
        ".....kcccccк....".replace("к", "k"),
        "......kkkkk.....",
        "................",
    ]),
    # Prisma Eterno: prisma triangular que espalha um arco-íris.
    "relic_prism": ({
        "k": "241430", "p": "8a5aba", "P": "e0c0ff", "w": "ffffff",
        "r": "ff5a5a", "o": "ffb43a", "y": "ffe85a", "g": "5aff7a", "b": "5ab4ff",
    }, [
        "................",
        ".......kk.......",
        "......kwPk......",
        "......kPpk......",
        ".....kPwPpk.....",
        ".....kPPPpk.....",
        "....kPwPPppk....",
        "....kPPPPppk....",
        "...kPPwPPpppk...",
        "...kPPPPPpppk...",
        "..kPPPPPPppppk..",
        "..kkkkkkkkkkkk..",
        "................",
        "...r.o.y.g.b....",
        "..r.o.y.g.b.....",
        "................",
    ]),
    # Semente do guardião (0.21, arena): caroço vivo com veias e um núcleo pulsante.
    "boss_seed": ({
        "k": "1a0608", "d": "5a1424", "m": "9a2238", "r": "ff3a5a", "R": "ff9ab0", "w": "fff0f4", "v": "3a0c16",
    }, [
        "................",
        "......kkkk......",
        "....kkdmmdkk....",
        "...kdmmvmmmdk...",
        "...kmmrrrrmmk...",
        "..kdmrRRRRrmdk..",
        "..kmvrRwwRrvmk..",
        "..kmmrRwRRrmmk..",
        "..kdmrRRRRrmdk..",
        "..kdmmrrrrmmdk..",
        "...kdmmvmmmdk...",
        "...kddmmmmddk...",
        "....kkddddkk....",
        "......kkkk......",
        "................",
        "................",
    ]),
}

# Brilhos extras por variação (só em pixels vazios).
SPARKLES = [[], [(1, 2), (14, 12)], [(13, 1), (2, 13), (14, 7)]]


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (pal, rows) in ART.items():
        assert len(rows) == 16 and all(len(r) == 16 for r in rows), name
        for v, sp in enumerate(SPARKLES):
            img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch != ".":
                        img.putpixel((x, y), hexc(pal[ch]))
            for x, y in sp:
                if img.getpixel((x, y))[3] == 0:
                    img.putpixel((x, y), (255, 255, 230, 220))
            img.save(OUT / f"{name}_{v + 1}.png")


if __name__ == "__main__":
    main()
