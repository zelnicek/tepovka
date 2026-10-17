#!/usr/bin/env python3
"""Reads the PPG of every BUT PPG record into one JSON-lines file for the
Dart harness (butppg_eval_test.dart).

    python3 -I tool/butppg/export_ppg.py <dataset dir> <work dir>

WFDB is read here directly (header plus formats 16, 32, 212 and 80), so no
extra package is needed. The dataset is untrusted input: only numbers and
record names are taken from it.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np


def read_header(path: Path) -> tuple[dict, list[dict]]:
    lines = [l for l in path.read_text().splitlines() if l.strip() and not l.startswith("#")]
    head = lines[0].split()
    nsig = int(head[1])
    fs = float(head[2].split("/")[0]) if len(head) > 2 else 250.0
    nsamp = int(head[3]) if len(head) > 3 else None
    signals = []
    for line in lines[1 : 1 + nsig]:
        parts = line.split()
        gain, baseline = 200.0, None
        if len(parts) > 2:
            m = re.match(r"([-\d.eE+]+)(?:\((-?\d+)\))?", parts[2])
            if m:
                gain = float(m.group(1)) or 200.0
                baseline = int(m.group(2)) if m.group(2) is not None else None
        adc_zero = int(parts[4]) if len(parts) > 4 else 0
        signals.append(
            {
                "file": parts[0],
                "fmt": parts[1].split("x")[0].split(":")[0].split("+")[0],
                "gain": gain,
                "baseline": adc_zero if baseline is None else baseline,
                "name": " ".join(parts[8:]) if len(parts) > 8 else "",
            }
        )
    return {"nsig": nsig, "fs": fs, "nsamp": nsamp}, signals


def read_samples(dat: Path, fmt: str, nsig: int) -> np.ndarray:
    raw = dat.read_bytes()
    if fmt == "16":
        d = np.frombuffer(raw, dtype="<i2").astype(np.int64)
    elif fmt == "32":
        d = np.frombuffer(raw, dtype="<i4").astype(np.int64)
    elif fmt == "80":
        d = np.frombuffer(raw, dtype=np.uint8).astype(np.int64) - 128
    elif fmt == "212":
        b = np.frombuffer(raw, dtype=np.uint8).astype(np.int64)
        b = b[: len(b) // 3 * 3].reshape(-1, 3)
        s1 = b[:, 0] | ((b[:, 1] & 0x0F) << 8)
        s2 = b[:, 2] | ((b[:, 1] & 0xF0) << 4)
        d = np.column_stack([s1, s2]).ravel()
        d = np.where(d > 2047, d - 4096, d)
    else:
        raise ValueError(f"unsupported WFDB format {fmt} in {dat.name}")
    return d.reshape(-1, nsig) if nsig > 1 else d.reshape(-1, 1)


def main() -> None:
    dataset, work = Path(sys.argv[1]), Path(sys.argv[2])
    work.mkdir(parents=True, exist_ok=True)
    out = work / "ppg.jsonl"
    n = 0
    with out.open("w") as f:
        for hea in sorted(dataset.rglob("*_PPG.hea")):
            rec_id = hea.name.split("_")[0]
            if not re.fullmatch(r"\d{6}", rec_id):
                continue
            info, sigs = read_header(hea)
            data = read_samples(hea.with_name(sigs[0]["file"]), sigs[0]["fmt"], info["nsig"])
            gains = np.array([s["gain"] for s in sigs], float)
            bases = np.array([s["baseline"] for s in sigs], float)
            phys = (data - bases) / gains
            # BUT PPG stores each sample as a signal of its own, with its own
            # gain ("<id>_PPG <n> 30 1": n signals of one sample), so the
            # series runs across the signals. Ordinary records (one signal of
            # many samples) run down the first column.
            if info["nsamp"] == 1 and info["nsig"] > 1:
                ppg = phys[0, :]
            else:
                ppg = phys[:, 0]
                if info["nsamp"]:
                    ppg = ppg[: info["nsamp"]]
            f.write(json.dumps({"id": rec_id, "fs": info["fs"], "ppg": [round(float(v), 6) for v in ppg]}) + "\n")
            n += 1
    print(f"{n} records -> {out}")


if __name__ == "__main__":
    main()
