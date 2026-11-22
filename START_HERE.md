# push: start here

Push, a 64 KB demo for the Acorn Archimedes (ARM2, 2 MB) by Bitshifters, released at Revision
2024. Built on the archie-verse demo framework.

| | |
|---|---|
| GitHub | https://github.com/bitshifters/push (public) |
| Upstream | remote `upstream` = https://github.com/kieranhj/archie-verse (the framework it grew from) |
| Local path | D:\archie\mine\push (moved from OneDrive\Archie\Repos\push on 2026-11-22) |
| Branch | main (only local branch) |
| Last commit | 2024-04-02: Remove unused code modules. |

## What's in here
- `archie-verse.asm`: top-level source; `src\`: effects, sequence, loader.
- `Makefile.mk`: the real build (run by bundled `bin\snmake.exe`); `make.bat` calls it.
- `data\`: graphics, music; `particles.lua`: particle sequence script.
- `bin\`: vasm, vlink, Shrinkler, lz4, dos2unix, png2arc*.py, table generators.
- `!Push\`: built app folder (ignored).

## Build and run
- `make`: runs `make.bat` = `snmake -f Makefile.mk` default target `deploy` (works, 2026-11-22):
  builds `!Push` and copies it to `..\arculator\hostfs\!Push`.
- Other targets: `make folder` (build `!Push` only), `make shrink` (Shrinkler-packed loader build,
  likely the 64 KB release form), `make compress` (shrink + copy to hostfs), `make seq`, `make help`.
- PNG conversion: the `bin\*.py` converters were ported to Python 3 on 2026-11-22 (byte-identical
  output) and `Makefile.mk` runs them with `PYTHON2?=py -3` (override with `PYTHON2=...`); they only
  run if a source PNG is newer than its `build\*.bin`.

## Local changes
- Working tree clean; no stashes. `upstream/wip/*` refs are archie-verse branches, not Push's.

## Status and next steps
- Released; "Party version" 2024-03-29, repo tidy 2024-03-30, then unused modules removed.
  No TODO or plan notes found.

## See also
- README.md, D:\archie\mine\archie-verse, D:\archie\mine\mikroreise.
