"""Measure the whole demo on one machine and report how much of it holds 50Hz.

  python tools/profile/timeline.py [config] [--json out.json]

Each window profiles the demo's own code, adds the fixed QTM + RISC OS
overhead, and compares the total against the machine's 50Hz frame budget.
"""
import argparse
import collections
import json
import sys

import mikroprofile as MP

WINDOW_US = 2_000_000
TEXT_LEN = 0x36700


def measure(config, samples_out=None, label=""):
    binf, mapf = MP.build("timeline")
    table = MP.symbols(mapf)
    app = MP.make_app(binf, MP.WORK + "/app_timeline")
    spec = MP.MACHINES[config]
    pool, m = MP.launch(config, app, table)

    fc = table.resolve("frame_counter")
    vs = table.resolve("vsync_count")
    rows = []
    while MP.read_word(m, fc) < 8600:
        f0, v0 = MP.read_word(m, fc), MP.read_word(m, vs)
        m.command_json(f"profile start {MP.TEXT_BASE:x} {TEXT_LEN:x}")
        m.command_json(f"run_us {WINDOW_US}")
        p = m.command_json("profile read 900")
        f1, v1 = MP.read_word(m, fc), MP.read_word(m, vs)
        m.command_text("profile stop")
        if f1 == f0:
            break
        by = collections.Counter()
        for e in p["entries"]:
            n = table.name_for(e["addr"])
            by[n[0] if n else "?"] += e["cycles"]
        demo = sum(v for k, v in by.items() if k not in MP.IDLE) / (f1 - f0)
        total = demo + spec["overhead"]
        top = [k for k in by if k not in MP.IDLE][:1]
        rows.append({
            "frame": f0, "t": round(f0 / 50.0, 1),
            "demo": round(demo), "total": round(total),
            "pct": round(100 * total / spec["budget"], 1),
            "fps": round(50.0 * (f1 - f0) / max(1, v1 - v0), 1),
            "top": top[0] if top else "",
        })
    pool.destroy_all()

    ok = [r for r in rows if r["pct"] <= 100]
    summary = {
        "config": config, "label": label, "windows": len(rows),
        "at_50hz": len(ok),
        "at_50hz_pct": round(100 * len(ok) / max(1, len(rows)), 1),
        "worst_pct": max(r["pct"] for r in rows),
        "min_fps": min(r["fps"] for r in rows),
        "mean_pct": round(sum(r["pct"] for r in rows) / len(rows), 1),
    }
    if samples_out:
        json.dump({"summary": summary, "rows": rows},
                  open(samples_out, "w"), indent=1)
    return summary, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("config", nargs="?", default="a3000-riscos311")
    ap.add_argument("--json")
    ap.add_argument("--label", default="")
    ap.add_argument("--detail", action="store_true")
    a = ap.parse_args()

    s, rows = measure(a.config, a.json, a.label)
    if a.detail:
        print(f"  {'t':>6} {'fps':>5} {'%budget':>8}  dominant")
        for r in rows:
            flag = "  <<<" if r["pct"] > 100 else ""
            print(f"  {r['t']:6.1f} {r['fps']:5.1f} {r['pct']:7.1f}%  "
                  f"{r['top']}{flag}")
    print(f"\n=== {s['config']} {s['label']} ===")
    print(f"  windows at 50Hz : {s['at_50hz']}/{s['windows']} "
          f"({s['at_50hz_pct']}%)")
    print(f"  worst window    : {s['worst_pct']}% of budget")
    print(f"  mean window     : {s['mean_pct']}% of budget")
    print(f"  min fps         : {s['min_fps']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
