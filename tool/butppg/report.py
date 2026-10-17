#!/usr/bin/env python3
"""Compares Tepovka's heart rate on BUT PPG with the ECG reference.

    python3 -I tool/butppg/report.py <dataset dir> <work dir>

Reads quality-hr-ann.csv and subject-info.csv from the dataset and
tepovka.csv (from butppg_eval_test.dart) from the work dir; writes
report.md, results.csv and a Bland-Altman figure to the work dir.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

METHODS = {
    "app_bpm": "Tepovka (paty pulzu)",
    "previous_bpm": "Výsledek do 10/2026",
    "spectral_bpm": "Spektrum",
}
# Codes as PhysioNet lists them; a record may have several ("2;3").
MOTION = {
    0: "klid", 1: "silnější přítlak", 2: "posun po čočce", 3: "chůze",
    4: "kašel", 5: "smích", 6: "změna světla", 7: "mluvení",
}


def read_rows(path: Path) -> list[list[str]]:
    with path.open(newline="", encoding="utf-8-sig") as f:
        sample = f.read(2048)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        return [r for r in csv.reader(f, dialect) if r]


def numeric(s) -> float | None:
    if s is None:
        return None
    if isinstance(s, (int, float)):
        return float(s)
    try:
        return float(s.replace(",", "."))
    except ValueError:
        return None


def load_annotations(dataset: Path) -> dict[str, dict]:
    rows = read_rows(dataset / "quality-hr-ann.csv")
    if numeric(rows[0][1]) is None:
        rows = rows[1:]
    return {r[0].strip(): {"good": int(float(r[1])), "ref": numeric(r[2])} for r in rows}


def load_subjects(dataset: Path) -> tuple[list[str], dict[str, dict]]:
    rows = read_rows(dataset / "subject-info.csv")
    header = [h.strip() for h in rows[0]]
    return header, {r[0].strip(): dict(zip(header, (c.strip() for c in r))) for r in rows[1:]}


def motion_codes(s: str) -> set[int]:
    return {int(v) for v in s.replace(",", ";").split(";") if v.strip().isdigit()}


def column(header: list[str], *needles: str) -> str | None:
    for h in header:
        low = h.lower()
        if all(n in low for n in needles):
            return h
    return None


def agreement(test: np.ndarray, ref: np.ndarray) -> dict:
    ok = np.isfinite(test) & np.isfinite(ref) & (ref > 0)
    t, r = test[ok], ref[ok]
    if len(t) == 0:
        return {"n": 0}
    d = t - r
    return {
        "n": int(len(d)),
        "bias": float(d.mean()),
        "sd": float(d.std(ddof=1)) if len(d) > 1 else 0.0,
        "mae": float(np.abs(d).mean()),
        "medae": float(np.median(np.abs(d))),
        "within5": float(100 * np.mean(np.abs(d) <= 5)),
        "within10": float(100 * np.mean(np.abs(d) <= 10)),
    }


def table(rows: list[tuple[str, dict]]) -> str:
    out = ["| | n | odchylka | SD | MAE | medián chyby | do 5 bpm | do 10 bpm |",
           "|---|---|---|---|---|---|---|---|"]
    for name, a in rows:
        if a.get("n", 0) == 0:
            out.append(f"| {name} | 0 | | | | | | |")
            continue
        out.append(
            f"| {name} | {a['n']} | {a['bias']:+.1f} | {a['sd']:.1f} | {a['mae']:.1f} | "
            f"{a['medae']:.1f} | {a['within5']:.0f} % | {a['within10']:.0f} % |"
        )
    return "\n".join(out)


def main() -> None:
    dataset, work = Path(sys.argv[1]), Path(sys.argv[2])
    ann = load_annotations(dataset)
    header, subjects = load_subjects(dataset)
    # By exact name: a search for "ear" would also find "Age [years]".
    site_col = next((h for h in header if h.lower() in ("ear/finger", "ear / finger")), None) \
        or column(header, "finger")
    motion_col = column(header, "motion")

    res_rows = read_rows(work / "tepovka.csv")
    res_header, res_rows = res_rows[0], res_rows[1:]
    recs = []
    for r in res_rows:
        row = dict(zip(res_header, r))
        a = ann.get(row["id"])
        if a is None:
            continue
        s = subjects.get(row["id"], {})
        recs.append({
            **row,
            "ref": a["ref"],
            "but_good": a["good"],
            "site": s.get(site_col, "") if site_col else "",
            "motion": s.get(motion_col, "") if motion_col else "",
        })

    def arr(key: str, sel=None) -> np.ndarray:
        vals = [numeric(r[key]) for r in recs if sel is None or sel(r)]
        return np.array([np.nan if v is None else v for v in vals], float)

    ref = arr("ref")
    lines = [f"# Tepovka na BUT PPG 2.0.0", "",
             f"Záznamů s referenčním tepem: {int(np.isfinite(ref).sum())} z {len(recs)}.", ""]

    def section(title: str, sel) -> None:
        r = arr("ref", sel)
        lines.extend([f"## {title}", "", table([(label, agreement(arr(k, sel), r)) for k, label in METHODS.items()]), ""])

    section("Všechny záznamy", None)
    section("Záznamy, které experti označili jako dobré", lambda r: r["but_good"] == 1)
    section("Záznamy, které experti označili jako špatné", lambda r: r["but_good"] == 0)
    for val, name in (("1", "prst"), ("0", "ucho")):
        section(f"Dobré záznamy, {name}", lambda r, v=val: r["but_good"] == 1 and r["site"] == v)
    for level, name in (("good", "dobrá"), ("medium", "střední"), ("poor", "špatná")):
        section(f"Kvalita podle Tepovky: {name}", lambda r, l=level: r["quality"] == l)

    # Motion, feet detector, all records
    mrows = []
    for code, name in MOTION.items():
        sel = lambda r, c=code: c in motion_codes(r["motion"])
        mrows.append((f"{name} ({code})", agreement(arr("app_bpm", sel), arr("ref", sel))))
    lines.extend(["## Tepovka podle pohybu (všechny záznamy; záznam s více kódy se počítá u každého)",
                  "", table(mrows), ""])

    # Tepovka quality vs the experts
    lines.extend(["## Ukazatel kvality Tepovky proti expertům", "",
                  "| Tepovka \\ experti | dobré | špatné |", "|---|---|---|"])
    for level in ("good", "medium", "poor", ""):
        g = sum(1 for r in recs if r["quality"] == level and r["but_good"] == 1)
        b = sum(1 for r in recs if r["quality"] == level and r["but_good"] == 0)
        lines.append(f"| {level or 'nehodnoceno'} | {g} | {b} |")
    tp = sum(1 for r in recs if r["quality"] == "good" and r["but_good"] == 1)
    fp = sum(1 for r in recs if r["quality"] == "good" and r["but_good"] == 0)
    fn = sum(1 for r in recs if r["quality"] != "good" and r["but_good"] == 1)
    tn = sum(1 for r in recs if r["quality"] != "good" and r["but_good"] == 0)
    sens = 100 * tp / max(1, tp + fn)
    spec = 100 * tn / max(1, tn + fp)
    lines.extend(["", f"„Dobrá“ podle Tepovky proti „dobré“ podle expertů: citlivost {sens:.0f} %, "
                      f"specificita {spec:.0f} %.", ""])

    none = [r for r in recs if numeric(r["app_bpm"]) is None]
    lines.extend([f"Tep nelze určit: {len(none)}× z {len(recs)} "
                  f"(z toho {sum(r['but_good'] == 1 for r in none)} záznamů, které experti označili jako dobré).",
                  "", "Chyba se počítá jen u záznamů, kde metoda tep dala.", ""])

    (work / "report.md").write_text("\n".join(lines), encoding="utf-8")
    with (work / "results.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(recs[0].keys()))
        w.writeheader()
        w.writerows(recs)

    # Bland-Altman for good records, both detectors
    good = lambda r: r["but_good"] == 1
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), sharey=True)
    for ax, key in zip(axes, ("previous_bpm", "app_bpm")):
        t, rf = arr(key, good), arr("ref", good)
        ok = np.isfinite(t) & np.isfinite(rf) & (rf > 0) & (t > 0)
        m, d = (t[ok] + rf[ok]) / 2, t[ok] - rf[ok]
        ax.scatter(m, d, s=6, alpha=0.35, color="#E53935")
        for v, ls in ((d.mean(), "-"), (d.mean() - 1.96 * d.std(), "--"), (d.mean() + 1.96 * d.std(), "--")):
            ax.axhline(v, color="#6E6D6D", ls=ls, lw=1)
        ax.set_ylim(-60, 60)
        ax.set_title(f"{METHODS[key]}\nbias {d.mean():+.1f}, SD {d.std():.1f} bpm", fontsize=10)
        ax.set_xlabel("průměr Tepovka a EKG (bpm)")
    axes[0].set_ylabel("Tepovka − EKG (bpm)")
    fig.tight_layout()
    fig.savefig(work / "bland_altman_good.png", dpi=150)
    print((work / "report.md").read_text())


if __name__ == "__main__":
    main()
