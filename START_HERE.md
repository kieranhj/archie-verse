# aklang: start here

The ArchieKlang Announcetro: a 28 KB Acorn Archimedes intro (ARM assembler, vasm + vlink) released at NOVA 2024 in the Oldschool Demo Compo, the first Archie prod to use Virgill's AmigaKlang soft synth (via ArchieKlang). A stripped-down copy of the archie-verse framework.

| | |
|---|---|
| GitHub | https://github.com/bitshifters/aklang (public; GitHub fork of kieranhj/archie-verse) |
| Upstream | https://github.com/kieranhj/archie-verse (remote `upstream`; it is the user's own framework, `D:\archie\mine\archie-verse`) |
| Local path | D:\bitshifters\aklang (moved from OneDrive\Archie\Repos\aklang on 2026-11-22) |
| Branch | main (only local branch) |
| Last commit | 2025-01-30: Add a small README. |

## What's in here

- `archie-verse.asm`: entry point; `src/` effects and sequence; `lib/` framework libraries.
- `data/`: graphics, MOD music; `bin/`: vasm, vlink, snmake, Shrinkler, LZ4 and the Python asset converters.
- `Makefile.mk` (the real build, run by `bin\snmake.exe` via `make.bat`), `link_script*.txt`.
- `!AKlang/`: the built RISC OS application folder (gitignored).

## Build and run

- `make`: builds the `!AKlang` folder in the repo (`make.bat !AKlang`). Works (2026-11-22), using the converted assets already in `build\`.
- Other targets: `make deploy` (make.bat's default: also copies `!AKlang` to `..\arculator\hostfs\Builds`), `make compress` (Shrinkler-packed release, deployed), `make seq`, `make help`.
- Tools: all in `bin\`. Asset conversion: the `bin\*.py` PNG converters were ported to Python 3 on 2026-11-22 (byte-identical output) and `Makefile.mk` runs them with `PYTHON2?=py -3` (override with `PYTHON2=...`); `akp2arc.py` was already Python 3.
- Run: in Arculator (`D:\archie\mine\arculator`, hostfs `..\arculator\hostfs\Builds`), run `!AKlang`.

## Local changes

- None uncommitted, no stashes. The `upstream/wip/*` branches are archie-verse's, seen through the `upstream` remote.

## Status and next steps

- Released (NOVA 2024, party version merged 2024-06-15 via PR #1). Finished; only a README added since.

## See also

- `README.md`; `D:\archie\mine\archie-verse` (the framework), `D:\archie\mine\archieklang` (the synth port).
