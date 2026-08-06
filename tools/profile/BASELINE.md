# Baseline — release build at `main`

Measured with the harness in this directory, `_DEBUG, 0`, assembled and linked
from a clean tree. The build reproduces the released `!RunImage` byte-for-byte
when `_DEBUG` is set back to 1, so the toolchain is trustworthy.

## A3000 — ARM2 8 MHz, MEMC1, 4 MB

| | |
|---|---:|
| Windows holding 50 Hz | **60 / 106 (56.6%)** |
| Worst window | **183.3%** of budget |
| Mean window | 91.3% of budget |
| Minimum frame rate | **24.8 fps** |

A frame that overruns by a single cycle costs a whole vsync, so the heavy 3D
sections halve cleanly to 25 fps rather than degrading gradually.

## Where the time goes at the peak

Measured on the A3020 at pattern 30.5 and attributed to routines. Shares are
similar on the A3000; absolute cycles are higher.

| Routine | cyc/frame | % of A3020 budget |
|---|---:|---:|
| `transform_3d_scene` | 62,387 | 26.0% |
| — rotation loop | 42,961 | 17.9% |
| — scale/translate loop | 19,362 | 8.1% |
| `mode9_drawline_with_clip` | 59,505 | 24.8% |
| `project_3d_scene` | 37,030 | 15.4% |
| `draw_3d_scene_outline` | 18,184 | 7.6% |
| `screen_cls_with_word` | 13,098 | 5.5% |
| QTM music player (RMA) | 37,063 | 15.4% |
| RISC OS (ROM) | 6,054 | 2.5% |

On the A3000 `transform_3d_scene` alone reaches **99,838 cycles/frame — 62% of
the entire frame budget**, and it runs once per frame regardless of how many
eyes are drawn.

## Costs worth knowing

Measured per instruction, on hardware timing that models ARM2 Booth multiply
and MEMC page behaviour.

- **A negative multiplier operand costs 11 extra cycles.** The multiplier stops
  early only when the remaining bits of Rs clear, so a sign-extended negative
  runs all 16 Booth cycles. Verified by flipping the sign of a coefficient of
  identical magnitude: 16.0/17.2c versus 5.0/6.2c.
- Line drawing, per pixel: shallow DDA 18.6c, steep DDA 24.7c, Bresenham 21.3c.
  The unconditional branch closing each loop is 5.3–5.4c on its own.
- Full-screen operations: `screen_cls_with_word` 13,098 cyc/frame (3.13
  bytes/cycle), `screen_copy` 34,151 cyc/frame (1.20 bytes/cycle).

## Correctness reference

`baseline_frames.json` holds screenshot hashes for 16 fixed frames on the
A5000/ARM3 config. Two independent runs of the same build reproduce all 16
exactly, so any difference is a real change in output.
