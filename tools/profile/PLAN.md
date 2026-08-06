# ARM2 performance plan — status and handover

Living document for the work on `wip/arm2-50hz`. Read this first; `README.md`
covers how to run the harness, `BASELINE.md` records the untouched release
measurements.

## Goal and constraints

Get the **release** build (`_DEBUG, 0`, which is what `main` carries) as close
to a solid 50 Hz on an **A3000** (ARM2 8 MHz, MEMC1, 4 MB) as optimisation
alone allows.

Agreed with Kieran, 2026-08-06:

- **No content degradation.** No reduced geometry, no dropping the second eye.
  If optimisation alone falls short, report the shortfall rather than change
  what the demo shows.
- Small fixed-point rounding differences are acceptable.
- Commit locally to the branch; do not push.

**Honest projection.** The peak 3D sections started at 179.8% of an ARM2 frame
and are now at 163.4%. Finishing the outstanding line-drawing work plus the
`sin` terms should reach roughly 130–140%. **50 Hz through the 3D sections is
not reachable without content changes**, which are excluded. Everything else in
the demo already holds 50 Hz or is close.

## Current state

Branch `wip/arm2-50hz`, six commits, nothing pushed:

```
d135273 tools/profile: align timeline windows to frames, and record results
044727b 3d-scene: put the scale, not the coordinate, in Rs in the scale loop
df3e2ce 3d-scene: extend the Rs sign fix to cos(A) and cos(B)
582c831 3d-scene: keep |cos(C)| in Rs, move the sign into the accumulate
07353ce tools/profile: land on the exact frame in the correctness gate
302dd7c tools/profile: cycle-accurate measurement harness for the ARM2 work
```

A3000, release build, frame-aligned windows of 100 frames:

| | Baseline (`main`) | Now | Change |
|---|---:|---:|---:|
| Windows holding 50 Hz | 54 / 85 (63.5%) | **56 / 85 (65.9%)** | +2 |
| Worst window | 179.8% | **163.4%** | −16.4 pts |
| Mean window | 81.3% | **78.4%** | −2.9 pts |

−16.4 points at the peak is roughly **26,200 cycles per frame**, all of it from
`transform_3d_scene`. Output is bit-identical on every comparable correctness
frame.

## The fact the work turns on

**On ARM2/ARM250 a negative multiplier operand costs 11 extra cycles.** The
multiplier only terminates early once the remaining bits of Rs have cleared, so
a sign-extended negative runs all 16 Booth cycles. Verified with a controlled
probe — same magnitude, sign flipped, then restored:

```
Rs = cos(C) = -256    16.00c   17.18c
Rs = cos(B) = +256     5.00c    6.15c
Rs = cos(C) restored  16.00c   17.07c
```

Two corollaries worth carrying into any new code:

- Put the operand with the **smaller magnitude, and ideally positive**, in Rs
  (the second source register, bits 11:8). `MUL Rd, Rm, Rs`.
- ARM2 forbids `Rd == Rm`, so the obvious operand swap is often illegal; use a
  scratch register and fold the move into a following instruction.

## Done

| Change | Commit | Measured |
|---|---|---|
| `\|cos(C)\|` in Rs, sign patched into the accumulate once per frame | `582c831` | worst 183.3% → 174.3% |
| Same for `cos(A)` and `cos(B)` | `df3e2ce` | worst → 165.5% |
| Scale loop: scale in Rs, not the coordinate | `044727b` | 31.4 → 22.2 cyc for the three multiplies |

The sign patching uses the self-modifying idiom already in the codebase
(`drawline_set_to_orr`, `dot_tunnel_patch_to_curved`): each coefficient has one
site that already had an `RSB` (patched to `MOV` when negative) and one that
gains a patchable slot. Patched once per frame in `transform_3d_scene`, not
tested per vertex.

## Investigated and rejected — do not re-attempt without new information

**Merging the scale/translate pass into the rotation loop.** This was the
largest single item identified (~19,400 cyc/frame on an A3020) and it is not
viable. `transform_3d_scene`'s rotation loop has **no free registers**: r6–r11
hold the six sin/cos coefficients, r0 and r14 are temps, r1/r2 are pointers,
r3–r5 the coordinates, r12 the count. Holding the scale and `object_pos` as
well means reloading them from memory per vertex (~13 cyc), which costs back
most of the ~28 cyc of loop overhead the merge would save. This is presumably
why it was written as two passes. Reconsider only alongside a register
reallocation of the whole routine — e.g. a concatenated 3×3 matrix, which needs
9 coefficients but frees the intermediate temps.

**Skipping the layer 0 screen clear when layer 1 does a full-screen copy**
(~13,000 cyc/frame). Correct in principle and cleanly implementable in
`fx_draw_layers`, but it only helps the static-screen sections, which already
run at ~33% of the A3000 budget. It contributes nothing to the 50 Hz goal. It
also produced a difference in the presented framebuffer that was never fully
explained (write-bank contents and palette identical) — likely the same display
race noted below. Worth revisiting only for its own sake.

## Outstanding, in priority order

**1. Line drawing** — untouched, and 30–72% of every section it appears in.
Measured per pixel: shallow DDA 18.6c, steep DDA 24.7c, Bresenham 21.3c.

- *Unroll the inner loops.* The unconditional branch closing each is 5.3–5.4
  cycles, 21% of the steep loop. `lib/line.asm` already proposes the approach
  in a comment: unroll to maximum length, compute the iteration count, poke a
  return instruction after N iterations and restore it afterwards.
- *Track the row pointer incrementally in the shallow loop.* It recomputes the
  address every pixel (`mov r9,r1,asr #16 / add r5,r12,r9,lsl #7 / add
  r5,r5,r9,lsl #5`), about 24% of that loop. The steep loop already does this
  with `add r1,r1,r9`; use `adds` on the fraction plus
  `addcs r5,r5,#Screen_Stride`.
- *Collapse the even/odd read-modify-write.* The loop is already unrolled into
  even/odd halves but issues `LDRB`+`STRB` for each. When y is unchanged across
  the pair — usual for a shallow line — that is one `LDRB`, two `ORR`s, one
  `STRB`, saving ~6.4c per pair.

**2. The six `sin` terms in `transform_3d_scene`.** Same 11-cycle sign penalty
as the `cos` terms, but they sit in `MLA` and ARM2 has no multiply-subtract, so
negating the product needs a MUL/MUL/SUB restructure rather than a one-word
patch. Roughly the same size of win again as the `cos` work.

**3. Smaller, already characterised.**

- Constant multiplies in `project_3d_scene` and `scene-2d.asm`:
  `mov r0,#VIEWPORT_SCALE>>12 / mul rd,r0,rd / mov rd,rd,asr #4` is a multiply
  by 160 = `5<<5`, so `add rd,rd,rd,lsl #2 / mov rd,rd,lsl #5`. Measured
  `project_3d_scene` 3.14 → 2.51 cyc/instr. Changes overflow behaviour beyond
  ±2048 px from screen centre (the new form is the better-behaved one).
- Hoist `Anaglyph_Enable_Skew` out of the per-dot loops in `starfield.asm` and
  `dot-tunnel.asm`: 13.1 cyc/star (~13,400 cyc/frame in the starfield) spent
  re-reading a value fixed for the whole frame. Branch to one of two loop
  bodies once per call. Note these sections already hold 50 Hz on an A3000, so
  this buys margin rather than frames.
- `plot_face_edge_list` routes through `mode9_drawline_orr` (21.3c/px) rather
  than the faster DDA loops (18.6c/px), to skip a clip test it does not need.
- `mode9_drawline_with_clip`'s clip preamble costs ~32 cycles per call even
  when nothing needs clipping — ~7,400 cyc/frame at 233 lines. A single
  wholly-on-screen test would remove most of it.
- The dot tunnel's patched no-ops (`mov r3,r3` ×2 per dot in straight mode) are
  ~3,000 cyc/frame. Patch a branch over them instead.

## Traps

**Toolchain**

- Build with bash, not PowerShell — PowerShell mangles `-T link_script.txt`
  into `.txt`. `mikroprofile.build()` handles this.
- A full `make.bat` needs Python 2 for the asset pipeline. The assets in
  `build/` are current, so only assemble+link is needed for source changes.
- Source files are CRLF and `.gitattributes` sets `* text=auto`. **Do not use
  `sed -i`** — it rewrites every line ending and produces a file that shows as
  modified with an empty diff.

**vasm**

- Local labels (`.1`, `.2`) are scoped to the preceding label, so introducing
  *any* label inside a loop silently re-scopes them and breaks the branches
  with `error 3005: reloc type 2 ... not supported`. `transform_3d_scene`'s
  loops are now named explicitly for this reason.

**Measurement**

- A profile of `&8000-&3E700` understates a frame by ~18%. QTM lives in the RMA
  and never appears there; on the A3000 it is **22,932 cyc/frame, 14.3% of the
  machine**. `timeline.py` adds the measured QTM + RISC OS overhead.
- Timeline windows must be **frame-aligned**, not time-aligned. A fixed
  2-second window lands on different demo content once a build runs at a
  different speed, which made the worst-window figure appear to move backwards
  on a change that was an improvement.
- The correctness gate runs on the **A5000/ARM3** deliberately. Parts of the
  scene are driven by QTM's VU levels, which advance on interrupts rather than
  frames, so on a machine that is dropping frames a faster build legitimately
  draws something different. Never use the A3000 for correctness.
- `run_to_frame` must land on the exact frame **and** pin the sample to a
  vsync. Both were bugs that reported false regressions before being caught.

## Two findings about the demo itself

**A display race.** Frame 200 renders ~21 pixels differently if four
behaviourally inert `mov r0, r0` are added to the main loop, with the palette,
the vsync count and the write bank's contents all identical. With only two
banks, `get_next_bank_for_writing` can hand back a bank VIDC is still
presenting. `regress.py` lists that frame in `UNSTABLE` and reports but does
not fail on it. Worth fixing on its own merits — a third bank, or a proper
FIFO, as the `TODO` in `archie-verse.asm` already suggests.

**The released `!RunImage` is a `_DEBUG` build.** The range checks are in the
inner loops — six instructions per vertex per eye in `project_3d_scene` alone,
plus a `QTM_Pos` SWI every frame. Worth 1–3% of the machine. `main` itself
carries `_DEBUG, 0`, so this only affects the shipped binary.
