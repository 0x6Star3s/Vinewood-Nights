#!/usr/bin/env python3
"""
handling_fix.py - normalize addon vehicle handling.meta files toward vanilla GTA V values.

  python handling_fix.py "D:/.../[addon]"                    # dry run (mode clamp), prints every change
  python handling_fix.py "D:/.../[addon]" --mode template    # dry run, aggressive mode
  python handling_fix.py "D:/.../[addon]" --apply            # write (backup first)
  python handling_fix.py "D:/.../[addon]" --only tenf,m3f80  # limit to handlingName(s)

Modes:
  clamp    (default) keep the modder's values, but clamp each parameter into the vanilla range of the class.
           Fixes the extremes (400 flatVel, brake 19, inverted traction, COM 9 m under the car) and keeps character.
  template reset the "feel" parameters (traction, brakes, drag, anti-roll, roll centre, damping, steering,
           inertia) to a vanilla-like template of the class; keep car-specific ones (mass, gears, drive bias,
           top speed and drive force - clamped; suspension limits, COM x/y, flags, seats). All cars of a class
           then drive consistently; tune single cars by hand afterwards.

Anchors (Rockstar values): ADDER, ZENTORNO (super); MASSACRO (sports); SCHAFTER3, COG55 (sedan); BALLER3, HUNTLEY (SUV);
NITESHAD (muscle); MAMBA (sports classic). Vehicle class comes from vehicles.meta <vehicleClass>;
boats/planes/helis/bikes are skipped.
"""
import argparse, glob, re, shutil, time
from pathlib import Path

SKIP_CLASSES = {"BOAT", "PLANE", "HELI", "MOTORCYCLE", "CYCLE", "RAIL", "TRAINS"}

# template per class (vanilla-like):
#            drag  flatVel  drvF   tMax  tMin  lat   brake bBias steer  susF  comp  reb   arb   arbB  rcF   rcR   lowSp trBias inZ
T = {
    "SUPER":         (9.0,  160, 0.34, 2.60, 2.45, 22.5, 1.00, 0.45, 40.0, 2.50, 1.45, 2.20, 0.90, 0.60, 0.38, 0.38, 1.40, 0.485, 1.60),
    "SPORT":         (9.5,  156, 0.34, 2.45, 2.25, 22.5, 0.90, 0.45, 42.0, 2.45, 1.40, 2.60, 0.60, 0.60, 0.30, 0.30, 1.00, 0.485, 1.80),
    "COUPE":         (8.0,  148, 0.30, 2.40, 2.15, 21.5, 0.85, 0.50, 40.0, 2.40, 1.40, 2.00, 0.70, 0.60, 0.35, 0.35, 1.10, 0.485, 1.80),
    "SEDAN":         (7.5,  148, 0.29, 2.45, 2.15, 21.0, 0.85, 0.50, 40.0, 2.50, 1.40, 2.00, 0.80, 0.60, 0.37, 0.36, 1.10, 0.485, 1.80),
    "MUSCLE":        (10.0, 145, 0.28, 2.25, 1.90, 20.5, 0.60, 0.60, 41.0, 1.90, 1.15, 1.70, 0.40, 0.55, 0.20, 0.20, 1.50, 0.480, 1.60),
    "SPORT_CLASSIC": (9.5,  148, 0.32, 2.40, 2.05, 20.5, 0.60, 0.55, 41.0, 2.20, 1.40, 2.50, 0.45, 0.60, 0.20, 0.20, 1.30, 0.480, 1.50),
    "SUV":           (8.0,  136, 0.27, 2.05, 1.70, 19.0, 0.60, 0.60, 35.0, 1.50, 0.95, 1.50, 0.80, 0.60, 0.55, 0.50, 1.50, 0.485, 1.50),
    "OFF_ROAD":      (9.0,  130, 0.26, 1.95, 1.65, 20.0, 0.60, 0.55, 35.0, 1.50, 0.90, 1.50, 0.70, 0.60, 0.50, 0.50, 1.40, 0.485, 1.60),
    "EMERGENCY":     (8.5,  155, 0.32, 2.45, 2.20, 21.0, 0.90, 0.50, 40.0, 2.40, 1.40, 2.10, 0.80, 0.60, 0.37, 0.36, 1.10, 0.485, 1.70),
    "VAN":           (10.0, 125, 0.24, 1.90, 1.60, 22.0, 0.60, 0.60, 35.0, 1.60, 1.00, 1.50, 0.60, 0.60, 0.50, 0.50, 1.30, 0.485, 2.00),
    "COMPACT":       (8.5,  135, 0.26, 2.20, 1.90, 21.0, 0.75, 0.55, 40.0, 2.20, 1.30, 2.00, 0.60, 0.60, 0.30, 0.30, 1.20, 0.485, 1.60),
}
KEYS = ["fInitialDragCoeff", "fInitialDriveMaxFlatVel", "fInitialDriveForce", "fTractionCurveMax", "fTractionCurveMin",
        "fTractionCurveLateral", "fBrakeForce", "fBrakeBiasFront", "fSteeringLock", "fSuspensionForce", "fSuspensionCompDamp",
        "fSuspensionReboundDamp", "fAntiRollBarForce", "fAntiRollBarBiasFront", "fRollCentreHeightFront", "fRollCentreHeightRear",
        "fLowSpeedTractionLossMult", "fTractionBiasFront", "inertiaZ"]
# clamp ranges per class: flatVel, driveForce, mass, tractionMax
CR = {"SUPER": ((150, 175), (0.28, 0.42), (1300, 2000), (2.4, 2.75)),
      "SPORT": ((135, 165), (0.26, 0.38), (1200, 1900), (2.3, 2.6)),
      "COUPE": ((125, 160), (0.22, 0.34), (1300, 2200), (2.1, 2.55)),
      "SEDAN": ((120, 155), (0.22, 0.34), (1400, 2600), (2.0, 2.6)),
      "MUSCLE": ((125, 160), (0.22, 0.34), (1300, 2100), (2.0, 2.45)),
      "SPORT_CLASSIC": ((125, 160), (0.24, 0.36), (1100, 1900), (2.1, 2.55)),
      "SUV": ((110, 150), (0.22, 0.30), (1800, 3200), (1.9, 2.3)),
      "OFF_ROAD": ((105, 145), (0.20, 0.30), (1500, 3200), (1.8, 2.3)),
      "EMERGENCY": ((130, 165), (0.24, 0.36), (1600, 2800), (2.1, 2.55)),
      "VAN": ((100, 140), (0.18, 0.28), (1800, 3500), (1.7, 2.2)),
      "COMPACT": ((110, 145), (0.18, 0.30), (900, 1600), (1.9, 2.4))}
# generic clamp ranges (vanilla min..max over passenger cars) used in both modes
G = {"fTractionCurveLateral": (18, 26), "fBrakeForce": (0.5, 1.3), "fBrakeBiasFront": (0.42, 0.66), "fSteeringLock": (34, 43),
     "fSuspensionForce": (1.3, 3.2), "fSuspensionCompDamp": (0.8, 2.0), "fSuspensionReboundDamp": (1.2, 3.2),
     "fSuspensionUpperLimit": (0.03, 0.35), "fSuspensionLowerLimit": (-0.35, -0.03), "fAntiRollBarForce": (0.3, 1.2),
     "fAntiRollBarBiasFront": (0.45, 0.7), "fRollCentreHeightFront": (0.05, 0.7), "fRollCentreHeightRear": (0.05, 0.7),
     "fLowSpeedTractionLossMult": (0.95, 1.6), "fTractionLossMult": (0.9, 1.1), "fTractionBiasFront": (0.46, 0.52), "fDriveInertia": (0.3, 1.1),
     "fHandBrakeForce": (0.3, 1.2),
     "fClutchChangeRateScaleUpShift": (1.5, 13), "fClutchChangeRateScaleDownShift": (1.5, 13), "nInitialDriveGears": (3, 8),
     "fInitialDragCoeff": (6, 12), "fDownforceModifier": (0, 100), "fCollisionDamageMult": (0.3, 2), "fEngineDamageMult": (0.5, 2),
     "fPercentSubmerged": (70, 100)}


def readx(p):
    return Path(p).read_bytes().decode("utf-8", "replace")


def classes_from_vehicles_meta(root):
    m = {}
    for f in glob.glob(glob.escape(root) + "/**/vehicles.meta", recursive=True):
        t = re.sub(r"<!--.*?-->", "", readx(f).replace("\0", ""), flags=re.S)
        starts = [x.start() for x in re.finditer(r"<modelName>", t)]
        for i, st in enumerate(starts):
            b = t[st: starts[i + 1] if i + 1 < len(starts) else len(t)]
            hid = re.search(r"<handlingId>\s*([^<\s]+)", b)
            vc = re.search(r"<vehicleClass>\s*VC_([A-Z_]+)", b)
            if hid:
                m[hid.group(1).lower()] = vc.group(1) if vc else "SEDAN"
    return m


# pola wektorowe dostepne dla TUNE po nazwie klucza
VEC = {"inertiaZ": "vecInertiaMultiplier", "comZ": "vecCentreOfMassOffset"}


def getv(b, k):
    if k in VEC:
        m = re.search(r'<%s x="[^"]+" y="[^"]+" z="([^"]+)"' % VEC[k], b)
    else:
        m = re.search(r'<%s value="([^"]+)"' % k, b)
    return float(m.group(1)) if m else None


def setv(b, k, v):
    if k in VEC:
        pat = r'(<%s x="[^"]+" y="[^"]+" z=")[^"]+(")' % VEC[k]
        return re.sub(pat, lambda m: m.group(1) + f"{v:.6f}" + m.group(2), b, count=1)
    # pola n* sa calkowite - RAGE nie parsuje ulamka w polu int (auto dostaje bledna liczbe biegow)
    t = f"{int(round(v))}" if k.startswith("n") else f"{v:.6f}"
    return re.sub(r'(<%s value=")[^"]+(")' % k, lambda m: m.group(1) + t + m.group(2), b, count=1)


def fix_item(b, cls, mode, log):
    tpl = T.get(cls, T["SEDAN"])
    cr = CR.get(cls, CR["SEDAN"])
    changes = {}

    def put(k, v0, v1):
        changes[k] = (changes[k][0] if k in changes else v0, v1)

    def clamp(k, lo, hi):
        nonlocal b
        v = getv(b, k)
        if v is None:
            return
        nv = min(max(v, lo), hi)
        if abs(nv - v) > 1e-6:
            put(k, v, nv)
            b = setv(b, k, nv)

    def setk(k, nv):
        nonlocal b
        v = getv(b, k)
        if v is None or abs(nv - v) < 1e-6:
            return
        put(k, v, nv)
        b = setv(b, k, nv)

    for k, (lo, hi) in (("fInitialDriveMaxFlatVel", cr[0]), ("fInitialDriveForce", cr[1]), ("fMass", cr[2])):
        clamp(k, lo, hi)
    for k, (lo, hi) in G.items():
        clamp(k, lo, hi)
    if mode == "template":
        for k, tv in zip(KEYS, tpl):
            if k in ("fInitialDriveMaxFlatVel", "fInitialDriveForce"):
                continue
            if k == "inertiaZ":
                m = re.search(r'(<vecInertiaMultiplier x="[^"]+" y="[^"]+" z=")([^"]+)(")', b)
                if m and abs(float(m.group(2)) - tv) > 1e-6:
                    put("vecInertiaMultiplier.z", float(m.group(2)), tv)
                    b = b[: m.start(2)] + f"{tv:.6f}" + b[m.end(2):]
                continue
            setk(k, tv)
    else:
        lo, hi = cr[3]
        clamp("fTractionCurveMax", lo, hi)
        tmax, tmin = getv(b, "fTractionCurveMax"), getv(b, "fTractionCurveMin")
        if tmin is not None and tmax is not None and (tmin > tmax - 0.08 or tmin < tmax * 0.7):
            setk("fTractionCurveMin", round(tmax - 0.2, 3))
    # centre of mass z: vanilla cars 0..+0.1, SUVs up to +0.3; never far below the floor
    m = re.search(r'(<vecCentreOfMassOffset x="[^"]+" y="[^"]+" z=")([^"]+)(")', b)
    if m:
        z = float(m.group(2))
        nz = min(max(z, -0.15), 0.3 if cls in ("SUV", "OFF_ROAD", "VAN") else 0.15)
        if abs(nz - z) > 1e-6:
            put("vecCentreOfMassOffset.z", z, nz)
            b = b[: m.start(2)] + f"{nz:.6f}" + b[m.end(2):]
    for k, (v0, v1) in changes.items():
        log.append(f"      {k:32s} {v0:>10.4f} -> {v1:.4f}")
    return b, bool(changes)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root")
    ap.add_argument("--mode", choices=["clamp", "template"], default="clamp")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--backup", default="D:/game/FiveM/local4Word6/backups/handling-" + time.strftime("%Y%m%d-%H%M%S"))
    ap.add_argument("--only", help="only handlingName(s), comma separated")
    a = ap.parse_args()
    classes = classes_from_vehicles_meta(a.root)
    only = set(x.lower() for x in a.only.split(",")) if a.only else None
    nfiles = nitems = 0
    for f in sorted(glob.glob(glob.escape(a.root) + "/**/handling.meta", recursive=True)):
        txt = readx(f)
        out = txt
        changed_any = False
        for m in list(re.finditer(r'<Item type="CHandlingData">.*?</Item>\s*(?=<Item type="CHandlingData">|</HandlingData>)', txt, flags=re.S)):
            b = m.group(0)
            name = re.search(r"<handlingName>\s*([^<\s]+)", b)
            if not name:
                continue
            hn = name.group(1).lower()
            if only and hn not in only:
                continue
            cls = classes.get(hn)
            short = f.split("[addon]")[-1]
            if cls is None:
                print(f"{hn:16s} ({short}) - no vehicles.meta entry, skipped")
                continue
            if cls in SKIP_CLASSES:
                print(f"{hn:16s} class {cls} - skipped")
                continue
            log = []
            nb, ch = fix_item(b, cls, a.mode, log)
            if ch:
                nitems += 1
                changed_any = True
                print(f"{hn:16s} [{cls}] {len(log)} changes  ({short})")
                print("\n".join(log))
                out = out.replace(b, nb, 1)
        if changed_any:
            nfiles += 1
            if a.apply:
                rel = Path(f).resolve().as_posix().split("/txData/resources/", 1)[-1]
                bk = Path(a.backup) / rel
                bk.parent.mkdir(parents=True, exist_ok=True)
                if not bk.exists():
                    shutil.copy2(f, bk)
                Path(f).write_bytes(out.encode("utf-8"))
    print(f"\n{nitems} handling items in {nfiles} files would change" + ("" if a.apply else "  [dry run - add --apply]"))
    seen = {}
    for f in glob.glob(glob.escape(a.root) + "/**/handling.meta", recursive=True):
        for m in re.finditer(r"<handlingName>\s*([^<\s]+)", readx(f)):
            seen.setdefault(m.group(1).lower(), []).append(f.split("[addon]")[-1])
    dups = {k: v for k, v in seen.items() if len(v) > 1}
    if dups:
        print("\nDUPLICATE handlingName (last loaded wins - delete the copies you do not want):")
        for k, v in dups.items():
            print(f"  {k}: " + ", ".join(v))


if __name__ == "__main__":
    main()
