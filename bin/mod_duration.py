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


# music_table order from src/app.asm
SONGS = [
    ( 0, "flight gone",        "data/music/dj3/adkd-flight-gone.mod"),
    ( 1, "wavering kb",        "data/music/dj3/505-23-wavering-kb.mod"),
    ( 2, "chips asmussen",     "data/music/dj3/andy-chips-asmussen.mod"),
    ( 3, "me doing me",        "data/music/dj3/chavez-me-doing-me.mod"),
    ( 4, "crome take me back", "data/music/dj3/crome-take-me-back.mod"),
    ( 5, "bang for the beep",  "data/music/dj3/curt-cool-bang-for-the-beep.mod"),
    ( 6, "darkside",           "data/music/dj3/filippp-darkside.mod"),
    ( 7, "herr irrtum",        "data/music/dj3/herr-irrtum-die-nmi-miamichip-gang.mod"),
    ( 8, "no mistake",         "data/music/dj3/nomistake-wattwurmshredde.mod"),
    ( 9, "novel",              "data/music/dj3/novel-django.mod"),
    (10, "echoes of the past", "data/music/dj3/okeanos-echoes-of-the-past.mod"),
    (11, "chipfly",            "data/music/dj3/slaxx-chipfly-final.mod"),
    (12, "vproject7",          "data/music/dj3/teis-vproject7.mod"),
    (13, "rettungsgasse",      "data/music/dj3/vincenzo-rettungsgasse.mod"),
    (14, "my life in melody",  "data/music/dj3/wotw-my-life-in-melody.mod"),
]

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Generate durationTable .asm include from MOD files')
    parser.add_argument('-o', metavar='FILE', help='output file (default: stdout)')
    args = parser.parse_args()

    base = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(base)

    lines = []
    for idx, name, rel_path in SONGS:
        path = os.path.join(repo, rel_path)
        try:
            mod    = parse_mod(path)
            secs   = calculate_duration(mod)
            frames = int(secs * 50)
            mins, s = divmod(int(secs), 60)
            lines.append(f"    .long    {frames:<8} ; {idx}: {name} ({mins}m{s:02d}s)")
        except Exception as e:
            lines.append(f"    ; ERROR parsing {name}: {e}")
            sys.exit(1)

    output = '\n'.join(lines) + '\n'

    if args.o:
        with open(args.o, 'w') as f:
            f.write(output)
    else:
        sys.stdout.write(output)

if __name__ == '__main__':
    main()
