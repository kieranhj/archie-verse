# archie-verse: start here

"Into the Archie-Verse": the Acorn Archimedes demo / trackmo framework (ARM2/ARM250, ARM assembler with vasm + vlink) that most Bitshifters Archie prods since 2023 are built from. The checked-out branch wip/chipo-django3 is the Chipo Django 3 musicdisk (`!dj3`).

| | |
|---|---|
| GitHub | https://github.com/kieranhj/archie-verse (public) |
| Other remotes | origin2 = bitshifters/allstars-parts (typo, probably dead), origin3 = bitshifters/allstar-parts |
| Local path | D:\archie\mine\archie-verse (moved from OneDrive\Archie\Repos\archie-verse on 2026-11-22) |
| Branch | wip/chipo-django3 (current, 75 commits ahead of main); main last 2025-07-02; 33 other branches (see below) |
| Last commit | 2026-04-23: Update songs.csv |

## What's in here

- `archie-verse.asm` entry; `src/fx/` effects, `src/data/` sequences (incl. `src/data/dj3`), `src/gen/` Lua-generated tables; `lib/` framework.
- `data/` (gfx, fonts, music incl. `data/music/dj3`, `riscos/` modules RasterMan v0.40, QTM, MemAlloc); `bin/` (vasm, vlink, snmake, Shrinkler, LZ4, abc2, Python 3 converters, `make_spark.py`).
- `Makefile.mk` (real build via `make.bat` / `bin\snmake.exe`); `make-package.bat`, `make-rhino.bat`, `watch-rhino.bat` (packaging for Rhino, the musician); `latest.bat` (pulls tunes from Seafile).
- `ref/cd3.txt` (Chipo Django 3 notes and plan), `ref/framework-todos.txt`, `ref/archie-verse.txt`; `CLAUDE.md` (untracked, build and architecture overview).

## Build and run

- `make`: builds the `!dj3` folder in the repo (`make.bat !dj3`). Works (2026-11-22). Uses `python.exe` (Python 3) for asset conversion.
- Other targets: `make deploy` (make.bat's default: copies `!dj3` to `..\arculator\hostfs` and writes the Spark archive `build\django3,ddc`), `make compress`, `make parts`, `make seq`, `make music`, `make help`.
- Run `!dj3` in Arculator (`D:\archie\mine\arculator`).
- `latest.bat` copies from `..\..\..\..\Seafile\musicdisk3`, which was `C:\Users\khcon\Seafile` from the old OneDrive location and now resolves off the top of `D:`: needs an absolute path.

## Local changes

- Untracked: `CLAUDE.md`, and `RM40.zip`, `RMV039REL.zip` (RasterMan releases), `cd3.zip`, `cd3mods.zip` (Chipo Django 3 assets / MODs, ~0.6 MB together).
- `wip/2026-11-tidy` (pushed): wip/chipo-django3 plus `CLAUDE.md` (the zips were not included).
- Branches ahead of main: wip/chipo-django3 (+75), wip/rasterman-v40 (+63), debug/keyboard-vsync (+64), debug/mouse-vsync (+65), wip/django3-min-pal (+41) are the 2026 Chipo Django 3 line; wip/mod-parser (+18, 2025-08). The 2023-2025 wip/* branches are 0-6 commits ahead and mostly merged history (party versions of aklang, allstar-parts, cracktro etc.).

## Status and next steps

- Chipo Django 3: most items in `ref/cd3.txt` PLAN are DONE; last commits were scrolltext, raster-bounce fix and `songs.csv` updates (April 2026). Remaining items: see `ref/cd3.txt` (e.g. glitch logo on song load).
- Decide what to do with the untracked zips and whether to merge wip/chipo-django3 to main.

## See also

- `CLAUDE.md`, `README.md`, `ref/`; derived repos `D:\bitshifters\aklang`, `D:\bitshifters\allstar-parts`; `D:\archie\mine\arc-django`, `D:\archie\mine\arc-django-2` (parts 1 and 2).
