#!/usr/bin/env python3
"""
Convert a PNG to a scanline-palette-constrained image.

Constraints:
  --max-colours  Max unique colours per scanline    (default 16)
  --max-changes  Max palette changes per scanline   (default 8)

Palette evolves across scanlines using Bélády's optimal replacement policy:
when a new colour must be added and the palette is full, evict the entry that
is (a) least used on the current scanline, and (b) furthest from its next use.

All palette colours are snapped to 4-bit per channel (multiples of 16) to
match VIDC hardware output.

Outputs:
  output_png   - result image showing the quantized colours
  output_pal   - per-scanline palette as 16-bit LE words in 0x0rgb format,
                 16 entries per scanline, compatible with pal_conv.py
  --bin FILE   - 4bpp indexed binary (RISC OS MODE 9 format):
                 pixel0 in low nibble, pixel1 in high nibble; each pixel's
                 nibble is its palette slot index for that scanline
"""

import sys
import struct
import argparse
import numpy as np
from PIL import Image
from collections import Counter


# ---- Colour utilities --------------------------------------------------------

def snap_colour(colour):
    """Snap an 8-bit RGB tuple to 4-bit per channel (truncate to multiple of 16)."""
    return tuple((c >> 4) << 4 for c in colour)

def rgb_to_pal_word(colour):
    """Convert snapped (r,g,b) to 0x0rgb 16-bit word."""
    r, g, b = colour
    return ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)

def nearest_idx(row_rgb, palette_rgb):
    """
    Vectorized nearest-palette-colour mapping.
    row_rgb:     [W, 3] uint8
    palette_rgb: [P, 3] float32
    Returns:     [W] int indices into palette
    """
    row = row_rgb.astype(np.float32)           # [W, 3]
    diff = row[:, np.newaxis, :] - palette_rgb  # [W, P, 3]
    dists = np.sum(diff ** 2, axis=2)           # [W, P]
    return np.argmin(dists, axis=1)             # [W]


# ---- Palette evolution -------------------------------------------------------

def build_use_table(line_counts):
    """colour -> sorted list of scanline indices where it appears."""
    table = {}
    for y, counts in enumerate(line_counts):
        for c in counts:
            table.setdefault(c, []).append(y)
    return table

def next_use_after(use_table, colour, after_line):
    """Next scanline > after_line where colour is used, or inf."""
    for line in use_table.get(colour, []):
        if line > after_line:
            return line
    return float('inf')

def evolve_palettes(pixels, max_colours, max_changes):
    height, width = pixels.shape[:2]

    # Snap all pixels to 4-bit colour space
    snapped = ((pixels >> 4) << 4)

    # Per-scanline colour counts (using snapped colours)
    line_counts = [
        Counter(map(tuple, snapped[y].tolist()))
        for y in range(height)
    ]

    use_table = build_use_table(line_counts)

    # Initial palette: top max_colours colours by coverage on first scanline
    first_sorted = sorted(line_counts[0], key=lambda c: -line_counts[0][c])
    palette = list(first_sorted[:max_colours])
    while len(palette) < max_colours:
        palette.append((0, 0, 0))

    scanline_palettes = []

    for y in range(height):
        counts = line_counts[y]
        palette_set = set(palette)

        # Colours needed on this line but absent from palette, highest coverage first
        missing = sorted(
            ((c, counts[c]) for c in counts if c not in palette_set),
            key=lambda x: -x[1]
        )

        budget = max_colours if y == 0 else max_changes

        for colour, _ in missing:
            if budget <= 0:
                break

            # Bélády's: evict entry with (lowest current use, furthest future use)
            best_slot = max(
                range(max_colours),
                key=lambda i: (
                    -counts.get(palette[i], 0),
                     next_use_after(use_table, palette[i], y)
                )
            )
            palette[best_slot] = colour
            palette_set = set(palette)
            budget -= 1

        scanline_palettes.append(list(palette))

    return scanline_palettes, snapped


# ---- Image quantization & stats ----------------------------------------------

def quantize_image(snapped, scanline_palettes):
    """Returns (rgb result image, per-scanline index arrays [height][width])."""
    height, width = snapped.shape[:2]
    result = np.zeros_like(snapped)
    all_indices = []
    for y, palette in enumerate(scanline_palettes):
        pal_arr = np.array(palette, dtype=np.float32)
        indices = nearest_idx(snapped[y], pal_arr)
        result[y] = pal_arr[indices].astype(np.uint8)
        all_indices.append(indices)
    return result, all_indices

def print_stats(scanline_palettes, original, result, max_changes):
    height = len(scanline_palettes)

    # Palette change counts (index-by-index, not set difference)
    changes = [
        sum(1 for i in range(len(scanline_palettes[y]))
            if scanline_palettes[y][i] != scanline_palettes[y-1][i])
        for y in range(1, height)
    ]

    over = [y+1 for y, c in enumerate(changes) if c > max_changes]
    colours_per_line = [len(set(scanline_palettes[y])) for y in range(height)]

    # Per-pixel error vs original (using snapped source as reference)
    snapped_src = ((original >> 4) << 4).astype(np.int32)
    diff = snapped_src.astype(np.int32) - result.astype(np.int32)
    mse = np.mean(diff ** 2)
    psnr = 10 * np.log10(255**2 / mse) if mse > 0 else float('inf')
    changed_px = int(np.any(diff != 0, axis=2).sum())
    total_px = original.shape[0] * original.shape[1]

    print(f"Scanlines         : {height}")
    print(f"Colours/line      : min={min(colours_per_line)}  "
          f"max={max(colours_per_line)}  avg={sum(colours_per_line)/height:.1f}")
    if changes:
        print(f"Changes/line      : max={max(changes)}  avg={sum(changes)/len(changes):.1f}  "
              f"(limit={max_changes})")
    if over:
        print(f"  WARNING: {len(over)} line(s) exceed limit: {over}")
    print(f"Pixels changed    : {changed_px} / {total_px} "
          f"({100*changed_px/total_px:.1f}%)")
    print(f"PSNR vs source    : {psnr:.1f} dB")


# ---- File output -------------------------------------------------------------

def write_bin_file(all_indices, path):
    """Write per-scanline palette indices as RISC OS MODE 9 4bpp binary.
    Pixel 0 in low nibble, pixel 1 in high nibble (two pixels per byte)."""
    out = bytearray()
    for indices in all_indices:
        for x in range(0, len(indices), 2):
            out.append((indices[x + 1] << 4) | indices[x])
    with open(path, 'wb') as f:
        f.write(out)

def write_pal_file(scanline_palettes, path):
    words = [rgb_to_pal_word(c) for pal in scanline_palettes for c in pal]
    with open(path, 'wb') as f:
        f.write(struct.pack(f'>{len(words)}H', *words))


# ---- Main --------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Convert PNG to scanline-palette-constrained image.')
    parser.add_argument('input',       help='Input PNG')
    parser.add_argument('output_png',  help='Output PNG')
    parser.add_argument('output_pal',  help='Output .pal file for pal_conv.py')
    parser.add_argument('--max-colours', type=int, default=16,
                        help='Max unique colours per scanline (default 16)')
    parser.add_argument('--max-changes', type=int, default=8,
                        help='Max palette changes between scanlines (default 8)')
    parser.add_argument('--bin', metavar='FILE',
                        help='Output 4bpp indexed binary (RISC OS MODE 9)')
    args = parser.parse_args()

    img = Image.open(args.input).convert('RGB')
    pixels = np.array(img)

    print(f"Input: {args.input}  ({pixels.shape[1]}x{pixels.shape[0]}, "
          f"{len(set(map(tuple, pixels.reshape(-1, 3).tolist())))} colours)")

    palettes, snapped = evolve_palettes(pixels, args.max_colours, args.max_changes)
    result, all_indices = quantize_image(snapped, palettes)

    Image.fromarray(result, 'RGB').save(args.output_png)
    write_pal_file(palettes, args.output_pal)
    if args.bin:
        write_bin_file(all_indices, args.bin)

    print_stats(palettes, pixels, result, args.max_changes)
    print(f"Output PNG : {args.output_png}")
    print(f"Output pal : {args.output_pal}")
    if args.bin:
        print(f"Output bin : {args.bin}")


if __name__ == '__main__':
    main()
