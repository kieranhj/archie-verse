#!/usr/bin/env python3
"""
make_spark.py - Create a RISC OS !Spark-compatible archive from a folder.

Usage:
    python make_spark.py <folder> [-o output.spk]

RISC OS file type information is read from ',xxx' suffixes on local filenames
(e.g. '!Run,feb', '!RunImage,ff8') and stored in the RISC OS attribute block
inside the archive. The suffix is stripped from the stored filename.

The output is a two-level Spark archive:
  outer: one entry named after the folder (filetype 0xDDC = Spark archive)
  inner: one entry per file/subdirectory

Uses stored (uncompressed) method 0x82 for all entries. !Spark and SparkFS
can read stored archives.
"""

import argparse
import io
import os
import struct
import time
from pathlib import Path


# ---------------------------------------------------------------------------
# CRC-16/ARC  (polynomial 0xA001, init 0x0000)
# Verified against django3,ddc reference archive.
# ---------------------------------------------------------------------------

def crc16(data: bytes) -> int:
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc


# ---------------------------------------------------------------------------
# RISC OS timestamp helpers
# RISC OS uses a 5-byte centisecond count since 1900-01-01.
# ---------------------------------------------------------------------------

_RISCOS_EPOCH_CS = 220898880000  # centiseconds from 1900-01-01 to 1970-01-01


def _unix_to_riscos_cs(unix_time: float) -> int:
    return int(unix_time * 100) + _RISCOS_EPOCH_CS


def make_load_addr(filetype: int, unix_time: float) -> int:
    """RISC OS load address encoding filetype and top byte of timestamp."""
    cs = _unix_to_riscos_cs(unix_time)
    hi = (cs >> 32) & 0xFF
    return 0xFFF00000 | ((filetype & 0xFFF) << 8) | hi


def make_exec_addr(unix_time: float) -> int:
    """RISC OS exec address = lower 32 bits of centisecond timestamp."""
    return _unix_to_riscos_cs(unix_time) & 0xFFFFFFFF


def dos_date_time(unix_time: float):
    """Convert Unix timestamp to MS-DOS (date, time) tuple."""
    t = time.localtime(unix_time)
    date = ((t.tm_year - 1980) << 9) | (t.tm_mon << 5) | t.tm_mday
    tod  = (t.tm_hour << 11) | (t.tm_min << 5) | (t.tm_sec >> 1)
    return date, tod


# ---------------------------------------------------------------------------
# Filetype extraction from local filename convention
# ---------------------------------------------------------------------------

def get_filetype(filename: str):
    """
    Extract RISC OS filetype from a ',xxx' suffix.
    Returns (clean_name, filetype_int) or (filename, None) if no valid suffix.
    """
    if ',' in filename:
        name, suffix = filename.rsplit(',', 1)
        if 1 <= len(suffix) <= 3:
            try:
                return name, int(suffix, 16)
            except ValueError:
                pass
    return filename, None


# ---------------------------------------------------------------------------
# Archive entry writer
# ---------------------------------------------------------------------------

def write_entry(buf: io.BytesIO, arc_name: str, data: bytes,
                unix_time: float, filetype: int = None, attrs: int = 0x03):
    """
    Write a single Spark archive entry (header + data) to buf.

    method 0x82 = stored (no compression) + RISC OS attribute block.
    If filetype is None, method 0x02 is used (no RISC OS block).
    """
    has_riscos = filetype is not None
    method = 0x82 if has_riscos else 0x02

    fname = arc_name.encode('latin-1', errors='replace')[:13].ljust(13, b'\x00')
    size = len(data)
    file_crc = crc16(data)
    dos_date, dos_time = dos_date_time(unix_time)

    # Standard 29-byte ARC header
    buf.write(b'\x1a')
    buf.write(bytes([method]))
    buf.write(fname)
    buf.write(struct.pack('<I', size))   # compressed size (= original for stored)
    buf.write(struct.pack('<H', dos_date))
    buf.write(struct.pack('<H', dos_time))
    buf.write(struct.pack('<H', file_crc))
    buf.write(struct.pack('<I', size))   # original size

    # 12-byte RISC OS extension
    if has_riscos:
        buf.write(struct.pack('<I', make_load_addr(filetype, unix_time)))
        buf.write(struct.pack('<I', make_exec_addr(unix_time)))
        buf.write(struct.pack('<I', attrs))

    buf.write(data)


# ---------------------------------------------------------------------------
# Recursive archive builder
# ---------------------------------------------------------------------------

def build_archive(folder: Path) -> bytes:
    """
    Build a Spark inner archive from the contents of folder.
    Returns the archive as bytes (including end-of-archive marker).
    Subdirectories are stored as nested sub-archives with filetype 0xDDC.
    """
    buf = io.BytesIO()

    for item in sorted(folder.iterdir(), key=lambda p: p.name.lower()):
        mtime = item.stat().st_mtime
        clean_name, filetype = get_filetype(item.name)

        if item.is_file():
            write_entry(buf, clean_name, item.read_bytes(), mtime,
                        filetype=filetype, attrs=0x03)
        elif item.is_dir():
            sub_data = build_archive(item)
            dir_filetype = filetype if filetype is not None else 0xDDC
            write_entry(buf, clean_name, sub_data, mtime,
                        filetype=dir_filetype, attrs=0x33)

    buf.write(b'\x1a\x80')  # end-of-archive marker (confirmed from reference)
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def create_spark(folder_path: str, output_path: str = None):
    folder = Path(folder_path)
    if not folder.is_dir():
        raise SystemExit(f'Error: {folder_path} is not a directory')

    if output_path is None:
        output_path = str(folder.parent / (folder.name + '.spk'))

    inner_data = build_archive(folder)
    mtime = folder.stat().st_mtime

    outer = io.BytesIO()
    write_entry(outer, folder.name, inner_data, mtime,
                filetype=0xDDC, attrs=0x33)
    outer.write(b'\x1a\x80')

    Path(output_path).write_bytes(outer.getvalue())
    print(f'Created: {output_path} ({Path(output_path).stat().st_size:,} bytes)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Create a RISC OS !Spark archive from a folder')
    parser.add_argument('folder', help='Input folder path')
    parser.add_argument('-o', '--output',
                        help='Output archive path (default: <folder>.spk)')
    args = parser.parse_args()
    create_spark(args.folder, args.output)
