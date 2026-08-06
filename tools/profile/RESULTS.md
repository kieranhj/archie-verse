# Results so far — ARM2 optimisation

Release build, A3000 (ARM2 8 MHz, MEMC1, 4 MB). Frame-aligned windows of 100
frames, so both builds are measured over identical demo content.

| | Baseline (`main`) | Optimised | Change |
|---|---:|---:|---:|
| Windows holding 50 Hz | 54 / 85 (63.5%) | **56 / 85 (65.9%)** | +2 |
| Worst window | 179.8% | **163.4%** | −16.4 pts |
| Mean window | 81.3% | **78.4%** | −2.9 pts |
| Minimum frame rate | 25.0 fps | 24.9 fps | — |

−16.4 points at the peak is about **26,200 cycles per frame** recovered, all of
it from `transform_3d_scene`. Output is bit-identical on every comparable
correctness frame.

## What was done

**Sign-normalised the rotation coefficients.** The ARM2/ARM250 multiplier only
terminates early once the remaining bits of Rs have cleared, so a sign-extended
negative Rs runs all 16 Booth cycles. Measured with a controlled probe — same
magnitude, sign flipped, then restored:

```
Rs = cos(C) = -256    16.00c   17.18c
Rs = cos(B) = +256     5.00c    6.15c
Rs = cos(C) restored  16.00c   17.07c
```

11 cycles per multiply from the sign alone. `cos(A)`, `cos(B)` and `cos(C)` now
hold magnitudes, with the sign patched into the accumulate once per frame — the
same self-modifying idiom as `drawline_set_to_orr`.

**Fixed the operand order in the scale loop.** The scale is small and positive,
the coordinates signed and often negative; the coordinate was in Rs. Measured
31.4 → 22.2 cycles for the three multiplies.

## What was investigated and rejected

**Merging the scale/translate pass into the rotation loop** (~19,400 cyc/frame
on an A3020, the largest single item identified). The rotation loop has no free
registers: r6–r11 hold the six coefficients, r0/r14 are temps, r1/r2 pointers,
r3–r5 the coordinates, r12 the count. Holding the scale and `object_pos` too
would mean reloading them per vertex, costing back most of the loop overhead
the merge saves. This is presumably why it is two passes.

**Skipping the layer 0 screen clear** under a full-screen copy (~13,000
cyc/frame). Correct in principle, but it only helps the static-screen sections,
which already run at ~33% of the A3000 budget — it contributes nothing to the
50 Hz goal.

**Sign-normalising the six `sin` terms.** They sit in `MLA`, and ARM2 has no
multiply-subtract, so negating those products needs a MUL/MUL/SUB restructure
rather than a one-word patch. Still available; roughly the same size again as
the `cos` work.

## Still outstanding

Line drawing, which is 30–72% of every section it appears in and untouched so
far:

- Unroll the inner loops. The unconditional branch closing each one is 5.3–5.4
  cycles, 21% of the steep loop. The source already proposes this in a comment.
- Track the row pointer incrementally in the shallow loop instead of
  recomputing it per pixel (~24% of that loop).
- Collapse the even/odd `LDRB`/`STRB` pair when both pixels share a byte.

## Two findings about the demo itself

**A display race.** Frame 200 renders differently if four behaviourally inert
`mov r0, r0` are added to the main loop — ~21 pixels move, with the palette,
the vsync count and the write bank's contents all identical. With only two
banks, `get_next_bank_for_writing` can hand back a bank VIDC is still
presenting. `regress.py` treats that frame as timing-sensitive rather than a
correctness signal.

**QTM costs 22,932 cycles/frame on the A3000 — 14.3% of the machine** — and is
invisible to a profile of the demo's own address range. Any honest frame budget
has to include it.
