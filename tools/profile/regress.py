"""Correctness gate: screenshot hashes at fixed frames, on a fast machine.

  python tools/profile/regress.py --save baseline.json     # record
  python tools/profile/regress.py --check baseline.json    # compare

Runs on the A5000/ARM3 config deliberately. The demo has ample headroom there
and holds a solid 50fps before and after any optimisation, so it stays
frame-locked and successive builds are directly comparable.

Do NOT use the A3000 for this. Parts of the scene are driven by QTM's VU
levels, which advance on interrupts rather than on frames, so on a machine that
is dropping frames a faster build legitimately draws something different. That
is a real behaviour of the demo, not a regression.
"""
import argparse
import json
import os
import sys

import mikroprofile as MP

CONFIG = "a5000-arm3-riscos311"
FRAMES = [200, 500, 900, 1400, 2000, 2600, 3100, 3600,
          4400, 5000, 5500, 6300, 6900, 7500, 8100, 8500]


def capture(outdir=None):
    binf, mapf = MP.build("regress")
    table = MP.symbols(mapf)
    app = MP.make_app(binf, MP.WORK + "/app_regress")
    pool, m = MP.launch(CONFIG, app, table)

    out = {}
    for f in FRAMES:
        MP.run_to_frame(m, table, f)
        out[str(f)] = MP.screenshot_hash(m)
        if outdir:
            os.makedirs(outdir, exist_ok=True)
            with open(os.path.join(outdir, f"frame{f:05d}.png"), "wb") as fh:
                from arculator_mcp import png
                fh.write(png.arfb_to_png(m.command("screenshot")))
    pool.destroy_all()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--save")
    ap.add_argument("--check")
    ap.add_argument("--png")
    a = ap.parse_args()

    got = capture(a.png)
    if a.save:
        json.dump(got, open(a.save, "w"), indent=1)
        print(f"saved {len(got)} frame hashes to {a.save}")
        return 0
    if a.check:
        want = json.load(open(a.check))
        bad = [k for k in want if want[k] != got.get(k)]
        for k in sorted(want, key=int):
            mark = "DIFF" if k in bad else "ok"
            print(f"  frame {k:>5}  {want[k]}  {got.get(k, '-')}  {mark}")
        if bad:
            print(f"\n{len(bad)}/{len(want)} frames differ: "
                  f"{', '.join(sorted(bad, key=int))}")
            return 1
        print(f"\nall {len(want)} frames identical")
        return 0
    print(json.dumps(got, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
