# archie-verse: start here

"Into the Archie-Verse": the Acorn Archimedes demo / trackmo framework (ARM2/ARM250, ARM assembler with vasm + vlink) that most Bitshifters Archie prods since 2023 are built from. The checked-out branch wip/chipo-django3 is the Chipo Django 3 musicdisk (`!dj3`).

| | |
|---|---|
| GitHub | https://github.com/kieranhj/archie-verse (public) |
| Other remotes | origin2 = bitshifters/allstars-parts (typo, probably dead), origin3 = bitshifters/allstar-parts |
| Local path | D:\archie\mine\archie-verse (moved from OneDrive\Archie\Repos\archie-verse on 2026-11-22) |
| Branch | wip/chipo-django3 (current, 79 commits ahead of main); main last 2025-07-02; 33 other branches (see below) |
| Last commit | 2026-11-27: Add Amiga files for reference. (last code change 2026-04-23: Update songs.csv, the final release) |

## What's in here

- `archie-verse.asm` entry; `src/fx/` effects, `src/data/` sequences (incl. `src/data/dj3`), `src/gen/` Lua-generated tables; `lib/` framework.
- `data/` (gfx, fonts, music incl. `data/music/dj3`, `riscos/` modules RasterMan v0.40, QTM, MemAlloc); `bin/` (vasm, vlink, snmake, Shrinkler, LZ4, abc2, Python 3 converters, `make_spark.py`).
- `Makefile.mk` (real build via `make.bat` / `bin\snmake.exe`); `make-package.bat`, `make-rhino.bat`, `watch-rhino.bat` (packaging for Rhino, the musician); `latest.bat` (pulls tunes from Seafile).
- `ref/cd3.txt` (Chipo Django 3 notes and plan), `ref/framework-todos.txt`, `ref/archie-verse.txt`; `ref/amiga/` (Amiga version files for reference); `CLAUDE.md` (build and architecture overview).

## Build and run

- `make`: builds the `!dj3` folder in the repo (`make.bat !dj3`). Works (2026-11-22). Uses `python.exe` (Python 3) for asset conversion.
- Other targets: `make deploy` (make.bat's default: copies `!dj3` to `..\arculator\hostfs\Builds` and writes the Spark archive `build\django3,ddc`), `make compress`, `make parts`, `make seq`, `make music`, `make help`.
- Run `!dj3` in Arculator (`D:\archie\mine\arculator`).
- `latest.bat` copies from `..\..\..\..\Seafile\musicdisk3`, which was `C:\Users\khcon\Seafile` from the old OneDrive location and now resolves off the top of `D:`: needs an absolute path.

## Local changes

- Working tree clean (apart from ignored build output and `!Acid/`). `CLAUDE.md` and the Amiga reference zips (`ref/amiga/cd3.zip`, `cd3mods.zip`) are now committed; the RasterMan release zips `RM40.zip` / `RMV039REL.zip` are no longer in the folder.
- `wip/2026-11-tidy` (pushed): wip/chipo-django3 plus `CLAUDE.md` (the zips were not included).
- Branches ahead of main: wip/chipo-django3 (+79), wip/rasterman-v40 (+63), debug/keyboard-vsync (+64), debug/mouse-vsync (+65), wip/django3-min-pal (+41) are the 2026 Chipo Django 3 line; wip/mod-parser (+18, 2025-08). The 2023-2025 wip/* branches are 0-6 commits ahead and mostly merged history (party versions of aklang, allstar-parts, cracktro etc.).

## Status and next steps

- Chipo Django 3 is released. The clean release record is `D:\bitshifters\chipo-django3` (https://github.com/bitshifters/chipo-django3), cut from d9f27fa on 2026-11-27; it rebuilds the live `bs-django03,ddc` byte for byte. Released builds map to commits here as: party 2026-04-05 = 3387994, fix 1 2026-04-07 = bbfa5a1, fix 2 (live) 2026-04-23 = d9f27fa. The release form is `make compress` / `shrink` (LZ4 loader), not the default target.
- Known build bug, fixed only in chipo-django3: `Makefile.mk`'s `small-font.bin` rule calls the undefined `$(PYTHON2)`, so a fresh checkout fails there. The local tree only builds because `build\small-font.bin` already exists. Pass `PYTHON2=python.exe` to work round it.
- Remaining items in `ref/cd3.txt` (e.g. glitch logo on song load) were not done for the release.
- Decide whether to merge wip/chipo-django3 to main.

## See also

- `CLAUDE.md`, `README.md`, `ref/`; derived repos `D:\bitshifters\chipo-django3`, `D:\bitshifters\aklang`, `D:\bitshifters\allstar-parts`; `D:\bitshifters\arc-django`, `D:\bitshifters\arc-django-2` (parts 1 and 2).
