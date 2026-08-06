"""Shared harness for building Mikroreise and measuring it under Arculator.

Depends on `arculator-headless` and the `arculator_mcp` Python package from a
build of Arculator with `--enable-headless`. Point ARCULATOR_ROOT at that
checkout. See README.md.
"""
import hashlib
import os
import shutil
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARC_ROOT = os.environ.get(
    "ARCULATOR_ROOT",
    r"C:\Users\khcon\OneDrive\Projects\arculator-sarah")
EXE = os.path.join(ARC_ROOT, "arculator-headless.exe")
WORK = os.path.join(REPO, "build", "profile")

sys.path.insert(0, os.path.join(ARC_ROOT, "mcp"))

from arculator_mcp import keys as keymap            # noqa: E402
from arculator_mcp.client import MachinePool        # noqa: E402
from arculator_mcp.symbols import SymbolTable       # noqa: E402

VASM = os.path.join(REPO, "bin", "vasmarm_std_win32.exe")
VLINK = os.path.join(REPO, "bin", "vlink.exe")

# Cycles per 50Hz frame, and the fixed QTM + RISC OS overhead measured outside
# the demo's own address range. Both are needed to judge a frame honestly: a
# profile of &8000-&3E700 alone silently omits ~18% of the machine.
MACHINES = {
    "a3000-riscos311": dict(mhz=8, budget=160_000, overhead=29_551),
    "a3020-riscos311": dict(mhz=12, budget=240_000, overhead=43_117),
    "a5000-arm3-riscos311": dict(mhz=25, budget=500_000, overhead=0),
}

TEXT_BASE = 0x8000
IDLE = {"get_next_bank_for_writing", "mark_write_bank_as_pending_display"}


def build(tag="prof"):
    """Assemble and link the current tree. Returns (bin_path, map_path)."""
    os.makedirs(WORK, exist_ok=True)
    obj = os.path.join(WORK, f"{tag}.o")
    binf = os.path.join(WORK, f"{tag}.bin")
    mapf = os.path.join(WORK, f"{tag}.map")
    lst = os.path.join(WORK, f"{tag}.lst")

    r = subprocess.run([VASM, "-L", lst, "-m250", "-Fvobj", "-opt-adr",
                        "-o", obj, "archie-verse.asm"],
                       cwd=REPO, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("vasm failed:\n" + r.stdout + r.stderr)
    # vlink must be invoked with forward slashes; it mis-parses some argument
    # forms when a backslash path follows -T.
    r = subprocess.run([VLINK, "-T", "link_script.txt", "-b", "rawbin1",
                        "-o", binf.replace("\\", "/"),
                        obj.replace("\\", "/"),
                        "-M" + mapf.replace("\\", "/")],
                       cwd=REPO, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("vlink failed:\n" + r.stdout + r.stderr)
    return binf, mapf


def make_app(binf, dest):
    """Build a runnable !Reise folder around a freshly linked image."""
    src = os.path.join(REPO, "!Reise")
    shutil.rmtree(dest, ignore_errors=True)
    # dirs_exist_ok because rmtree can fail silently under OneDrive
    shutil.copytree(src, dest, dirs_exist_ok=True)
    shutil.copy(binf, os.path.join(dest, "!RunImage,ff8"))
    return dest


def symbols(mapf):
    t = SymbolTable()
    t.load(mapf)
    return t


def _tap(m, sc, hold=40000):
    m.command_text(f"key {sc} 1")
    m.command_json(f"run_us {hold}")
    m.command_text(f"key {sc} 0")
    m.command_json(f"run_us {hold}")


def _type(m, text, enter=False):
    for ch in text:
        s, sh = keymap.char_to_keystroke(ch)
        if sh:
            m.command_text(f"key {keymap.SCANCODES['lshift']} 1")
        _tap(m, s)
        if sh:
            m.command_text(f"key {keymap.SCANCODES['lshift']} 0")
    if enter:
        _tap(m, keymap.SCANCODES["return"])


def launch(config, app_dir, table):
    """Boot a machine, copy the app into HostFS and start it running."""
    pool = MachinePool(EXE, ARC_ROOT, os.path.join(WORK, "sandbox"))
    mid, m = pool.create(config=config)
    dest = os.path.join(m.hostfs, "!Reise")
    shutil.rmtree(dest, ignore_errors=True)
    shutil.copytree(app_dir, dest, dirs_exist_ok=True)
    for _ in range(12):
        m.command_json("run_us 1000000")
    _tap(m, keymap.SCANCODES["f12"])
    m.command_json("run_us 500000")
    _type(m, "Run HostFS::HostFS.$.!Reise.!Run", enter=True)

    fc = table.resolve("frame_counter")
    for _ in range(60):
        m.command_json("run_us 1000000")
        if read_word(m, fc) > 0:
            break
    else:
        raise SystemExit("demo never started ticking")
    return pool, m


def read_word(m, addr):
    import struct
    return struct.unpack("<I", m.command(f"read {addr:x} 4")[-4:])[0]


def run_to_frame(m, table, frame):
    """Advance until frame_counter lands exactly on `frame`.

    Coarse stepping alone is not good enough for the correctness gate: a 0.5s
    step covers ~25 frames, so where it stops depends on execution speed, and a
    build that is merely faster would be compared at a different frame. Close
    the last stretch a quarter-frame at a time.
    """
    fc = table.resolve("frame_counter")
    vs = table.resolve("vsync_count")
    while read_word(m, fc) < frame - 30:
        m.command_json("run_us 500000")
    while read_word(m, fc) < frame:
        m.command_json("run_us 2000")
    got = read_word(m, fc)
    if got != frame:
        raise SystemExit(f"overshot frame {frame}, landed on {got}")

    # Landing on the right frame is not enough on its own. We arrive at an
    # arbitrary point within it, and the screenshot returns whichever frame
    # VIDC last presented - so a sample can fall either side of a display swap
    # depending only on how fast the build ran. Advance to the next vsync so
    # the sample is pinned to a hardware-timed boundary.
    v0 = read_word(m, vs)
    while read_word(m, vs) == v0:
        m.command_json("run_us 1000")
    return got


def screenshot_hash(m):
    return hashlib.sha256(m.command("screenshot")).hexdigest()[:16]
