#!/usr/bin/env python3
"""
Convert 12-bit RGB4 palette file to 32-bit VIDC palette words.

Input:  binary file of 16-bit words, format 0x0rgb, 16 entries per scanline.
Output: binary file of 32-bit words, format 0x0bgr | (palette_index << 26),
        only for entries that changed from the previous scanline.
"""

import sys
import struct
import argparse

def rgb12_to_vidc(value, index):
    r = (value >> 8) & 0xF
    g = (value >> 4) & 0xF
    b = (value >> 0) & 0xF
    bgr = (b << 8) | (g << 4) | r
    return bgr | (index << 26)

def fmt_colour(value):
    if value is None:
        return '---'
    r = (value >> 8) & 0xF
    g = (value >> 4) & 0xF
    b = (value >> 0) & 0xF
    return f'#{r:X}{g:X}{b:X}'

def convert(in_path, out_path, verbose=False):
    with open(in_path, 'rb') as f:
        data = f.read()

    if len(data) % 2 != 0:
        sys.exit(f"Error: input file size ({len(data)}) is not a multiple of 2")

    words = struct.unpack_from(f'>{len(data)//2}H', data)
    num_scanlines = len(words) // 16
    out_words = []
    prev = [None] * 16

    changes_per_line = []
    for line in range(num_scanlines):
        row = words[line * 16:(line + 1) * 16]
        changed = 0
        line_changes = []
        for idx, w in enumerate(row):
            if w != prev[idx]:
                out_words.append(rgb12_to_vidc(w, idx))
                line_changes.append((idx, prev[idx], w))
                prev[idx] = w
                changed += 1
        out_words.append(0xFFFFFFFF)
        changes_per_line.append(changed)
        if verbose:
            detail = ', '.join(
                f"[{idx}] {fmt_colour(old)}->{fmt_colour(new)}"
                for idx, old, new in line_changes
            )
            print(f"Line {line:4d}: {changed:2d} change(s)  {detail}")

    with open(out_path, 'wb') as f:
        f.write(struct.pack(f'<{len(out_words)}I', *out_words))

    total_in = num_scanlines * 16
    total_out = len(out_words) - num_scanlines  # exclude terminators
    max_changes = max(changes_per_line)
    max_changes_after_first = max(changes_per_line[1:]) if num_scanlines > 1 else 0
    avg_changes = sum(changes_per_line) / num_scanlines
    print(f"Scanlines : {num_scanlines}")
    print(f"Written   : {total_out} / {total_in} entries ({total_in - total_out} saved, +{num_scanlines} terminators)")
    print(f"Max/line  : {max_changes} (excl. first: {max_changes_after_first})")
    print(f"Avg/line  : {avg_changes:.1f}")
    print(f"Output    : {out_path}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert RGB4 palette file to VIDC palette words.')
    parser.add_argument('input', help='Input palette file (16-bit words, 0x0rgb)')
    parser.add_argument('output', help='Output palette file (32-bit VIDC words)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Show number of palette changes per scanline')
    args = parser.parse_args()
    convert(args.input, args.output, verbose=args.verbose)
