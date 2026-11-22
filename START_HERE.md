# allstar-parts: start here

Bitshifters' parts for the Allstar Megademo for the Acorn Archimedes (ARM2/ARM250), built on the archie-verse framework (ARM assembler, vasm + vlink). Includes the donut and space parts.

| | |
|---|---|
| GitHub | https://github.com/bitshifters/allstar-parts (public) |
| Upstream | none; split out of `D:\archie\mine\archie-verse` (branch wip/allstar-parts there) |
| Local path | D:\archie\mine\allstar-parts (moved from OneDrive\Archie\Repos\allstar-parts on 2026-11-22) |
| Branch | master (only branch) |
| Last commit | 2025-06-23: More nits. |

## What's in here

- `archie-verse.asm` entry, `src/` (`app.asm`, `fx/`, `rasters-donut.asm`, `sync.asm`, `loader.asm`), `lib/` framework.
- `data/` assets (fonts, gfx, UV tables, MODs); `bin/` tools (vasm, vlink, snmake, Shrinkler, LZ4, Python converters).
- `Makefile.mk` (real build via `make.bat` / `bin\snmake.exe`), `link_script*.txt`.
- `ref/archie-verse.txt`, `ref/framework-todos.txt`: notes.

## Build and run

- `make`: builds the `!Verse` folder (`make.bat !Verse`). Works (2026-11-22), including the asset conversion from an empty `build\`. The `bin\*.py` converters were ported to Python 3 on 2026-11-22 and `Makefile.mk` now runs them with `PYTHON2?=py -3` (variable name kept; override with `PYTHON2=...`). `akp2arc.py` was already Python 3.
- Other targets: `make deploy` (to `..\arculator\hostfs`), `make compress`, `make parts` (donut / space binaries), `make seq`, `make help`.
- Run: `!Verse` in Arculator (`D:\archie\mine\arculator`).

## Local changes

- None: clean tree, no stashes, no extra branches.

## Status and next steps

- Delivered to the Megademo; last work (2025-06) removed unused assets/FX and split out the notes file. See `ref/framework-todos.txt` for framework follow-ups.
- Builds again since the Python 3 port (2026-11-22).

## See also

- `README.md`, `ref/`; `D:\archie\mine\archie-verse`.
