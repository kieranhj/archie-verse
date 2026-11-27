# mikroreise: start here

Mikroreise, a red/cyan anaglyph 3D demo for the Acorn Archimedes (ARM250, 4 MB), released at
Deadline 2023 (1st in the Three-Dee compo). Code by kieran, music by Rhino. Built on the
archie-verse demo framework.

| | |
|---|---|
| GitHub | https://github.com/bitshifters/mikroreise (public) |
| Upstream | remote `upstream` = https://github.com/kieranhj/archie-verse (the framework it grew from) |
| Local path | D:\bitshifters\mikroreise (moved from OneDrive\Archie\Repos\mikroreise on 2026-11-22) |
| Branch | wip/arm2-50hz; others: main, wip/2026-11-tidy |
| Last commit | 2026-08-06: tools/profile: PLAN.md as the single handover document |

## What's in here
- `archie-verse.asm`: top-level source; `src\`: effects, 3D scene, sequence data, loader.
- `Makefile.mk`: the real build (run by bundled `bin\snmake.exe`); `make.bat` calls it.
- `data\`: graphics, fonts, music, text; `folder\`: files copied into the `!Reise` app.
- `tools\profile\`: ARM2 cycle-accurate profiling harness (PLAN.md, README.md, BASELINE.md).
- `bin\`: vasm, vlink, Shrinkler, lz4, dos2unix, png2arc*.py; `ref\`: notes.
- `!Reise\`: built app folder (ignored).

## Build and run
- `make`: runs `make.bat` = `snmake -f Makefile.mk` default target `deploy` (works, 2026-11-22):
  builds `!Reise` and copies it to `..\arculator\hostfs\!Reise`.
- Other targets: `make folder` (build `!Reise` only), `make shrink`, `make compress`, `make seq`, `make help`.
- Tools: bundled in `bin\`. The PNG converters (`bin\*.py`) were ported to Python 3 on 2026-11-22
  (byte-identical output) and `Makefile.mk` runs them with `PYTHON2?=py -3` (override with
  `PYTHON2=...`); they only run if a source PNG is newer than its `build\*.bin`.
- Run in Arculator with an ARM250 / 4 MB config; needs anaglyph glasses.

## Local changes
- wip/arm2-50hz: 7 commits ahead of main (2026-08-06): the ARM2 performance work and the
  `tools/profile` harness. Pushed to origin.
- wip/2026-11-tidy (pushed 2026-11-21): snapshot of the uncommitted work below.
- Uncommitted now: `ref/three-dee.txt` (modified), `ref/elite-3d-temp.txt` and `.vscode/` (untracked).
- `tools/profile/mikroprofile.py` defaults to `D:\archie\mine\arculator`
  (fixed from the old OneDrive path on 2026-11-26).

## Status and next steps
- tools/profile/PLAN.md is the handover: aim is a 50 Hz release build on an A3000 (ARM2) with no
  content cuts. Peak 3D sections went from 179.8% to 163.4% of an ARM2 frame; projection is
  130-140% after the remaining line-drawing and sin work, so 50 Hz through the 3D parts is not
  reachable without content changes.

## See also
- README.md, tools/profile/PLAN.md, D:\archie\mine\archie-verse, D:\bitshifters\push.
