# Profiling harness

**Start with [PLAN.md](PLAN.md)** - status, what is done, what is left,
and the traps. This file only covers how to run the harness.

Cycle-accurate measurement of Mikroreise, used to drive the ARM2 optimisation
work on this branch. Not part of the demo build — safe to delete before any
merge to `main`.

## Requirements

A build of [Arculator](https://github.com/sarah-walker-pcem/arculator) with
`--enable-headless`, which produces `arculator-headless` alongside the normal
binary, plus the `arculator_mcp` Python package that ships with it. Point
`ARCULATOR_ROOT` at that checkout:

```sh
export ARCULATOR_ROOT=/path/to/arculator
python tools/profile/timeline.py a3000-riscos311
```

The headless binary runs the emulation core single-threaded in lockstep with a
control socket — a command is serviced, the machine advanced by an explicit
cycle count, the result read back, and nothing runs in between. That is what
makes these measurements repeatable.

## Scripts

| Script | Purpose |
|---|---|
| `mikroprofile.py` | Shared: assemble+link the tree, wrap the image in a runnable `!Reise`, boot a machine, run it |
| `timeline.py` | Performance gate. Profiles the whole 173-second run in 2-second windows and reports how much of it holds 50 Hz |
| `regress.py` | Correctness gate. Screenshot hashes at 16 fixed frames |

## Reading the numbers

`timeline.py` reports **% of budget**, which is the demo's own code *plus* the
fixed QTM and RISC OS cost, against the machine's 50 Hz frame:

| Machine | Frame budget | QTM + RISC OS |
|---|---:|---:|
| A3000 — ARM2 8 MHz, MEMC1 | 160,000 cycles | 29,551 |
| A3020 — ARM250 12 MHz, MEMC1A | 240,000 cycles | 43,117 |

Profiling only `&8000-&3E700` understates a frame by around 18%, because the
music player lives in the RMA and never appears in the demo's own address
range. The overheads above were measured by pointing the profiler at the RMA
and ROM separately.

## Why the correctness gate runs on an A5000

Parts of the scene are driven by QTM's VU levels, which advance on interrupts
rather than on frames. On a machine that is dropping frames, a faster build
therefore draws something genuinely different — that is the demo behaving
correctly, not a regression.

`regress.py` uses the A5000/ARM3 config because the demo has ample headroom
there and holds a solid 50 fps both before and after any optimisation. It stays
frame-locked, so successive builds are directly comparable. Two independent
runs of the same build produce identical hashes for all 16 frames.

**Do not use the A3000 for correctness checking.**
