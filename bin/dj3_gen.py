"""
Generate assembly includes for the Chipo Django 3 music disc.
Single source of truth: data/music/dj3/songs.csv

Generates into build/:
  dj3_defs.asm         .equ Dj_Max_Songs          (app.asm)
  dj3_incbins.asm      incbin declarations         (data.asm)
  music_table.asm      .long entries               (app.asm)
  dj_menu_strings.asm  .byte title/artist pairs    (app.asm)
  volume_table.asm     .byte volume entries        (app.asm)
  duration_table.asm   .long durations (computed)  (app.asm)
  song_pause_table.asm .long pause entries         (app.asm)

To add a song: append a row to songs.csv, done.
"""
import csv
import os
import struct
import sys

SONGS_CSV = 'data/music/dj3/songs.csv'
MOD_DIR   = 'data/music/dj3'

# ---------------------------------------------------------------------------
# ProTracker MOD parser
# ---------------------------------------------------------------------------

def parse_mod(filename):
    with open(filename, 'rb') as f:
        data = f.read()

    magic = data[1080:1084]
    known_magic = {
        b'M.K.', b'M!K!', b'4CHN', b'6CHN', b'8CHN',
        b'FLT4', b'FLT8', b'2CHN', b'OCTA', b'16CN', b'32CN',
    }
    num_samples  = 31 if magic in known_magic else 15
    num_channels = 4
    if magic == b'6CHN':                          num_channels = 6
    elif magic in (b'8CHN', b'OCTA', b'FLT8'):   num_channels = 8

    offset = 20 + num_samples * 30          # title + sample headers

    song_length   = data[offset]
    offset       += 2                        # song_length + restart byte
    pattern_table = list(data[offset:offset + 128])
    offset       += 128
    if num_samples == 31:
        offset   += 4                        # skip magic tag

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
                channels.append((
                    (b0 & 0xF0) | ((b2 & 0xF0) >> 4),   # sample
                    ((b0 & 0x0F) << 8) | b1,             # period
                    b2 & 0x0F,                            # effect
                    b3,                                   # param
                ))
            pattern.append(channels)
        patterns.append(pattern)

    return {'song_length': song_length, 'pattern_table': active_table, 'patterns': patterns}


def calculate_duration(mod):
    """
    Simulate playback; return total seconds.
    sec/row = speed * 2.5 / bpm   (125 BPM -> 50 Hz on PAL)
    """
    pattern_table = mod['pattern_table']
    patterns      = mod['patterns']
    song_length   = mod['song_length']

    speed, bpm = 6, 125
    pos, row   = 0, 0
    visited    = set()
    timings    = []

    while pos < song_length:
        state = (pos, row)
        if state in visited:
            break
        visited.add(state)

        pat_idx = pattern_table[pos]
        if pat_idx >= len(patterns):
            break
        timings.append((speed, bpm))

        jump_pos  = None
        break_row = None

        for (_s, _p, effect, param) in patterns[pat_idx][row]:
            if effect == 0xF:
                if   param == 0:    pass
                elif param < 0x20:  speed = param
                else:               bpm   = param
            elif effect == 0xB:
                jump_pos  = param % song_length
            elif effect == 0xD:
                break_row = (param >> 4) * 10 + (param & 0x0F)

        if jump_pos is not None:
            pos, row = jump_pos, (break_row or 0)
        elif break_row is not None:
            pos += 1
            row  = break_row
            if pos >= song_length: break
        else:
            row += 1
            if row >= 64:
                row  = 0
                pos += 1
                if pos >= song_length: break

    return sum(s * 2.5 / b for s, b in timings)

# ---------------------------------------------------------------------------
# Code generators
# ---------------------------------------------------------------------------

def gen_defs(songs):
    return f'.equ Dj_Max_Songs, {len(songs)}\n'


def gen_incbins(songs):
    lines = []
    for s in songs:
        path  = f"{MOD_DIR}/{s['filename']}"
        label = s['label'] + '_mod_no_adr'
        lines.append(f'.p2align 2\n{label}:\n.incbin "{path}"\n')
    return '\n'.join(lines) + '\n'


def gen_music_table(songs):
    lines = []
    for i, s in enumerate(songs):
        label = s['label'] + '_mod_no_adr'
        lines.append(f'\t.long {label:<44} ; {i}')
    return '\n'.join(lines) + '\n'


def gen_menu_strings(songs):
    lines = [f'\t.byte "{s["title"]}", 0, "{s["artist"]}", 0' for s in songs]
    return '\n'.join(lines) + '\n'


def gen_volume_table(songs):
    lines = [f'\t.byte    {s["volume"]:<8} ; {s["label"]}' for s in songs]
    return '\n'.join(lines) + '\n'


def gen_duration_table(songs, repo):
    lines = []
    for i, s in enumerate(songs):
        path = os.path.join(repo, MOD_DIR, s['filename'])
        try:
            secs   = calculate_duration(parse_mod(path))
            frames = int(secs * 50)
            mins, sec = divmod(int(secs), 60)
            lines.append(f'\t.long    {frames:<8} ; {i}: {s["label"]} ({mins}m{sec:02d}s)')
        except Exception as e:
            print(f'error computing duration for {s["filename"]}: {e}', file=sys.stderr)
            sys.exit(1)
    return '\n'.join(lines) + '\n'


def gen_pause_table(songs):
    lines = [f'\t.long    {s["pause"]:<8} ; {s["label"]}' for s in songs]
    return '\n'.join(lines) + '\n'

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    base  = os.path.dirname(os.path.abspath(__file__))
    repo  = os.path.dirname(base)
    build = os.path.join(repo, 'build')

    csv_path = os.path.join(repo, SONGS_CSV)
    with open(csv_path, newline='') as f:
        songs = list(csv.DictReader(f))

    if not songs:
        print(f'error: no songs found in {csv_path}', file=sys.stderr)
        sys.exit(1)

    outputs = {
        'dj3_defs.asm':         gen_defs(songs),
        'dj3_incbins.asm':      gen_incbins(songs),
        'music_table.asm':      gen_music_table(songs),
        'dj_menu_strings.asm':  gen_menu_strings(songs),
        'volume_table.asm':     gen_volume_table(songs),
        'duration_table.asm':   gen_duration_table(songs, repo),
        'song_pause_table.asm': gen_pause_table(songs),
    }

    for name, content in outputs.items():
        with open(os.path.join(build, name), 'w') as f:
            f.write(content)
        print(f'wrote build/{name}')


if __name__ == '__main__':
    main()
