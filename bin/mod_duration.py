"""
Calculate playback duration of ProTracker MOD files.
Simulates playback tracking speed (Fxx), position jump (Bxx), and pattern break (Dxx).
Outputs durationTable entries in 50fps frames for archie-verse/src/app.asm.
"""
import struct
import os
import sys

def parse_mod(filename):
    with open(filename, 'rb') as f:
        data = f.read()

    # Detect 31 vs 15 sample format from magic at offset 1080
    magic = data[1080:1084]
    known_magic = {
        b'M.K.', b'M!K!', b'4CHN', b'6CHN', b'8CHN',
        b'FLT4', b'FLT8', b'2CHN', b'OCTA', b'16CN', b'32CN',
    }
    if magic in known_magic or (magic[0:2] == b'M.' and magic[2:4] == b'K.'):
        num_samples = 31
    else:
        num_samples = 15

    num_channels = 4
    if magic == b'6CHN':
        num_channels = 6
    elif magic in (b'8CHN', b'OCTA', b'FLT8'):
        num_channels = 8

    offset = 20  # skip title
    for _ in range(num_samples):
        offset += 30  # skip each sample header

    song_length = data[offset]
    offset += 2  # song_length + restart byte
    pattern_table = list(data[offset:offset + 128])
    offset += 128
    if num_samples == 31:
        offset += 4  # skip magic

    # Load patterns (number of patterns = highest index in table + 1)
    active_table = pattern_table[:song_length]
    num_patterns = max(active_table) + 1 if active_table else 0

    patterns = []
    for _ in range(num_patterns):
        pattern = []
        for _row in range(64):
            channels = []
            for _ch in range(num_channels):
                b0, b1, b2, b3 = data[offset], data[offset+1], data[offset+2], data[offset+3]
                offset += 4
                sample = (b0 & 0xF0) | ((b2 & 0xF0) >> 4)
                period  = ((b0 & 0x0F) << 8) | b1
                effect  = b2 & 0x0F
                param   = b3
                channels.append((sample, period, effect, param))
            pattern.append(channels)
        patterns.append(pattern)

    return {
        'song_length':   song_length,
        'pattern_table': active_table,
        'patterns':      patterns,
    }


def calculate_duration(mod):
    """
    Simulate playback and return total duration in seconds.

    Timing formula (ProTracker / PAL):
        ticks/sec   = BPM * 0.4       (125 BPM -> 50 Hz)
        sec/row     = speed / (BPM * 0.4)
                    = speed * 2.5 / BPM
    """
    pattern_table = mod['pattern_table']
    patterns      = mod['patterns']
    song_length   = mod['song_length']

    speed = 6    # ticks per row
    bpm   = 125  # beats per minute

    pos = 0   # order-list position
    row = 0   # row within current pattern

    visited = set()          # (pos, row) -> detect song loop
    row_timings = []         # accumulate (speed, bpm) per row

    while pos < song_length:
        state = (pos, row)
        if state in visited:
            break
        visited.add(state)

        pat_idx = pattern_table[pos]
        if pat_idx >= len(patterns):
            break
        row_data = patterns[pat_idx][row]

        # Record timing BEFORE processing effects (row plays at current speed/bpm)
        row_timings.append((speed, bpm))

        # Scan all channels for effects
        jump_pos   = None   # Bxx
        break_row  = None   # Dxx

        for (_samp, _period, effect, param) in row_data:
            if effect == 0xF:            # Fxx — set speed or BPM
                if param == 0:
                    pass                 # F00: stop (treat as no-op here)
                elif param < 0x20:
                    speed = param
                else:
                    bpm = param
            elif effect == 0xB:          # Bxx — position jump
                jump_pos = param % song_length
            elif effect == 0xD:          # Dxx — pattern break (param is BCD row)
                break_row = (param >> 4) * 10 + (param & 0x0F)

        # Advance position
        if jump_pos is not None:
            pos = jump_pos
            row = break_row if break_row is not None else 0
        elif break_row is not None:
            pos += 1
            row = break_row
            if pos >= song_length:
                break
        else:
            row += 1
            if row >= 64:
                row = 0
                pos += 1
                if pos >= song_length:
                    break

    total_seconds = sum(s * 2.5 / b for s, b in row_timings)
    return total_seconds


def load_dj3_mods(makefile_path):
    """Parse the DJ3_MODS variable from Makefile.mk and return a list of relative paths."""
    paths = []
    in_block = False
    with open(makefile_path) as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith('DJ3_MODS'):
                in_block = True
                rest = stripped.split(':=', 1)[1].strip()
            elif in_block:
                rest = stripped
            else:
                continue

            cont = rest.endswith('\\')
            value = rest[:-1].strip() if cont else rest.strip()
            if value.startswith('./'):
                value = value[2:]
            if value.endswith('.mod'):
                paths.append(value)
            if not cont:
                break

    return paths


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Generate durationTable .asm include from MOD files')
    parser.add_argument('-o', metavar='FILE', help='output file (default: stdout)')
    parser.add_argument('--makefile', metavar='FILE', default='Makefile.mk',
                        help='path to Makefile.mk relative to repo root (default: Makefile.mk)')
    args = parser.parse_args()

    base = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(base)

    makefile_path = os.path.join(repo, args.makefile)
    rel_paths = load_dj3_mods(makefile_path)
    if not rel_paths:
        print(f'error: no DJ3_MODS entries found in {makefile_path}', file=sys.stderr)
        sys.exit(1)

    lines = []
    for idx, rel_path in enumerate(rel_paths):
        path = os.path.join(repo, rel_path)
        name = os.path.splitext(os.path.basename(rel_path))[0]
        try:
            mod    = parse_mod(path)
            secs   = calculate_duration(mod)
            frames = int(secs * 50)
            mins, s = divmod(int(secs), 60)
            lines.append(f"    .long    {frames:<8} ; {idx}: {name} ({mins}m{s:02d}s)")
        except Exception as e:
            print(f'error parsing {rel_path}: {e}', file=sys.stderr)
            sys.exit(1)

    output = '\n'.join(lines) + '\n'

    if args.o:
        with open(args.o, 'w') as f:
            f.write(output)
    else:
        sys.stdout.write(output)

if __name__ == '__main__':
    main()
