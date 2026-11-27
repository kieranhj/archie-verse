# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**archie-verse** is an Acorn Archimedes demo / trackmo (tracked music demo) framework targeting ARM2 or ARM250 machines. The entire codebase is ARM assembly, built with VASM and linked with vlink.

## Build Commands

All builds use `make.bat` (Windows) which wraps `snmake.exe -f Makefile.mk`:

```bat
make.bat              # Default: builds and deploys demo binary
make.bat music        # Build all music assets from MOD files
make.bat compress     # Build Shrinkler-compressed release binary
make.bat parts        # Build separate scene binaries (donut, space)
make.bat seq          # Build sequence/timeline version
make.bat clean        # Remove build artifacts
make-package.bat      # Create package for Arculator emulator
```

Key build flags (set in `app_config.h.asm`):
- `_DEBUG` — enables error vectors, raster display, debug variable watching
- `_SMALL_EXE` — enables compression (auto-set when `_DEBUG=0`)
- `_SLOW_CPU` — targets ARM2 (slower) vs ARM250
- `_WIMP_SLOT` — RAM allocation (currently 1000*1024)

## Architecture

### Entry Point and Structure

- `archie-verse.asm` — main entry, sets up WIMP slot, initializes all subsystems, runs main loop
- `app_config.h.asm` — compile-time feature flags (read this first to understand what's enabled)
- `lib_config.h.asm` — library feature enablement
- `link_script.txt` — memory layout; binary loads at `0x8000`

### Source Layout

- `src/fx/` — 35+ independent effect/scene modules (each self-contained)
- `src/data/` — sequence/timeline data variants (aklang, django, push, three-dee)
- `src/sys/` — system-level code
- `src/gen/` — Lua-generated code (tunnel maps, normals, dot tables)
- `lib/` — reusable library code (math, graphics primitives, audio, compression, debug)
- `data/` — source assets (PNG graphics, MOD music, fonts, UV tables, 3D objects)
- `bin/` — build tools (VASM assembler, vlink linker, LZ4/Shrinkler compressors, Python asset converters)

### Effect/Scene System

Each effect in `src/fx/` is independent. The demo timeline is driven by `src/data/sequence-data.asm`, which schedules effects relative to music beats/frames. Effects are frame-synchronized with music via VSYNC interrupts.

### Asset Pipeline

All assets are embedded in the binary (no runtime file loading). Source assets in `data/` are converted by Python scripts in `bin/` during the build:
- `png2arc.py` / `png2arc_font.py` — PNG → indexed binary
- `modparse.py` — ProTracker MOD → binary music data
- `uv-table-conv.py` — UV lookup table generation

Lua scripts in `src/lua/` / `src/gen/` pre-generate lookup tables (tunnels, normals, dot patterns) as assembly includes.

### Audio

- QTM module playback (embedded or external)
- ArchiKlang sample synthesis (`lib/archi-klang/`)
- Music data variants live in `src/data/` and `data/music/`

### Debug Features

When `_DEBUG=1`:
- Runtime variable watching via `dbg_watch_*` macros
- Keyboard callbacks via `keys_register_callback`
- Raster visualization with `SET_BORDER` macro
- RasterMan display preferred over standard error vectors

## Assembly Conventions

- Header files use `.h.asm` extension and are `%include`d
- Macros are defined in `lib/macros.h.asm`
- Screen addressing uses pre-defined macros for the target video mode (MODE 9, 16-color)
- BSS section holds pre-allocated lookup tables; they must fit within the WIMP slot
