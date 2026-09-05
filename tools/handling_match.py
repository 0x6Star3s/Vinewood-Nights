#!/usr/bin/env python3
"""
handling_match.py - dopasuj auto do wzorca z bazy vanilla GTA V.

Zamiast liczyc zawieszenie wzorami (handling_tune.py), bierzemy auto Rockstara o podobnych
parametrach i kopiujemy z niego "czucie" - zawieszenie, stabilizator, srodek przechylu, krzywe
trakcji, inercje. To jest strojone pod fizyke GTA, wiec zachowuje sie poprawnie w grze.
Tozsamosc auta (masa, biegi, naped, moc, predkosc maks.) zostaje nasza.

  python tools/handling_match.py find --mass 1920 --vmax 250 --hp 510 --drive awd --gears 8
  python tools/handling_match.py find --like m4c                 # parametry bierze z naszego auta
  python tools/handling_match.py seed --into m4c --from FELON2   # dry run
  python tools/handling_match.py seed --into m4c --from FELON2 --apply

Baza: tools/vanilla/merged-handling.meta (800 aut, kopia oryginalow z GTA V).
"""
import argparse, glob, re, shutil, sys, time
from pathlib import Path

ROOT = "D:/game/FiveM/local4Word6/txData/resources/[addon]"
VANILLA = Path(__file__).parent / "vanilla" / "merged-handling.meta"
DRIVE = {"rwd": 0.0, "fwd": 1.0, "awd": 0.35}

# "czucie" - kopiowane ze wzorca. Reszta (masa, biegi, naped, moc, vmax, opor, hamulce, flagi) zostaje nasza.
FEEL = ["fSuspensionForce", "fSuspensionCompDamp", "fSuspensionReboundDamp", "fSuspensionUpperLimit",
        "fSuspensionLowerLimit", "fSuspensionBiasFront", "fAntiRollBarForce", "fAntiRollBarBiasFront",
        "fRollCentreHeightFront", "fRollCentreHeightRear", "fTractionCurveMax", "fTractionCurveMin",
        "fTractionCurveLateral", "fTractionSpringDeltaMax", "fLowSpeedTractionLossMult", "fCamberStiffnesss",
        "fTractionBiasFront", "fTractionLossMult", "fSteeringLock", "fBrakeBiasFront", "fHandBrakeForce",
        "fDriveInertia", "fClutchChangeRateScaleUpShift", "fClutchChangeRateScaleDownShift"]
VEC = {"comZ": "vecCentreOfMassOffset", "inertiaZ": "vecInertiaMultiplier"}
# GEOMETRIA modelu - NIE kopiowana ze wzorca. Wysokosc srodka przechylu i srodek ciezkosci zaleza od
# ksztaltu konkretnego modelu; wzorzec Rockstara jest strojony pod SWOJ model. Przeniesienie rollC 0.37 -> 0.27
# z Buffalo na Chargera skonczylo sie dachowaniem w zakrecie przy pelnej predkosci.
GEOMETRY = {"fRollCentreHeightFront", "fRollCentreHeightRear", "fSuspensionRaise", "comZ"}
# stabilizator: bierzemy wieksza z wartosci (wlasna vs wzorzec) - seed nigdy nie oslabia zabezpieczenia przed przechylem
NEVER_LOWER = {"fAntiRollBarForce"}
# pola do porownania przy szukaniu wzorca: nazwa -> waga (im mniejsza skala, tym czulsze)
SCORE = {"fMass": 400.0, "fInitialDriveMaxFlatVel": 15.0, "fInitialDriveForce": 0.05, "fDriveBiasFront": 0.35}
# podwodne/latajace/motory - odpadaja
SKIP_SUB = ("CBoatHandlingData", "CFlyingHandlingData", "CBikeHandlingData", "CSeaPlaneHandlingData",
            "CSubmarineHandlingData", "CTrainHandlingData")


def getv(b, k):
    if k in VEC:
        m = re.search(r'<%s x="[^"]+" y="[^"]+" z="([^"]+)"' % VEC[k], b)
    else:
        m = re.search(r'<%s value="([^"]+)"' % k, b)
    return float(m.group(1)) if m else None


def setv(b, k, v):
    if k in VEC:
        return re.sub(r'(<%s x="[^"]+" y="[^"]+" z=")[^"]+(")' % VEC[k],
                      lambda m: m.group(1) + f"{v:.6f}" + m.group(2), b, count=1)
    t = f"{int(round(v))}" if k.startswith("n") else f"{v:.6f}"
    return re.sub(r'(<%s value=")[^"]+(")' % k, lambda m: m.group(1) + t + m.group(2), b, count=1)


def parse(path, blocks_only=False):
    """{NAZWA: (blok_xml, plik)} ze wszystkich CHandlingData w pliku."""
    d = Path(path).read_bytes().decode("utf-8", "replace").replace("\0", "")
    out = {}
    for m in re.finditer(r'<Item type="CHandlingData">.*?</Item>\s*(?=<Item type="CHandlingData">|</HandlingData>)', d, re.S):
        b = m.group(0)
        n = re.search(r"<handlingName>\s*([^<\s]+)", b)
        if n:
            out[n.group(1).upper()] = (b, str(path))
    return out


def ours():
    out = {}
    for f in sorted(glob.glob(glob.escape(ROOT) + "/**/handling.meta", recursive=True)):
        out.update(parse(f))
    return out


def cars():
    """vanilla, bez lodzi/samolotow/motorow"""
    return {k: v for k, v in parse(VANILLA).items() if not any(s in v[0] for s in SKIP_SUB)}


def find(target, db, n=8):
    scored = []
    for name, (b, _) in db.items():
        d, ok = 0.0, True
        for k, scale in SCORE.items():
            a, c = target.get(k), getv(b, k)
            if a is None or c is None:
                ok = False
                break
            d += ((a - c) / scale) ** 2
        if ok:
            scored.append((d ** 0.5, name, b))
    return sorted(scored)[:n]


def show(rows, target):
    cols = ["fMass", "fInitialDriveForce", "fInitialDriveMaxFlatVel", "fDriveBiasFront",
            "fSuspensionForce", "fAntiRollBarForce", "fRollCentreHeightFront", "comZ",
            "fTractionCurveMax", "fTractionCurveMin"]
    hdr = ["masa", "drvF", "flatV", "bias", "susF", "ARB", "rollC", "comZ", "tMax", "tMin"]
    print(f"{'':6s}{'wzorzec':14s}" + "".join(f"{h:>8s}" for h in hdr))
    print("-" * (20 + 8 * len(hdr)))
    print(f"{'':6s}{'CEL':14s}" + "".join(
        f"{target[c]:>8.2f}" if target.get(c) is not None else f"{'-':>8s}" for c in cols))
    print("-" * (20 + 8 * len(hdr)))
    for d, name, b in rows:
        print(f"{d:5.2f} {name:14s}" + "".join(
            f"{getv(b, c):>8.2f}" if getv(b, c) is not None else f"{'-':>8s}" for c in cols))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("find", help="znajdz wzorzec w bazie vanilla")
    f.add_argument("--like", help="wez parametry z naszego auta (handlingName)")
    f.add_argument("--mass", type=float)
    f.add_argument("--hp", type=float)
    f.add_argument("--vmax", type=float, help="km/h")
    f.add_argument("--drive", choices=list(DRIVE))
    f.add_argument("--gears", type=int)
    f.add_argument("-n", type=int, default=8)
    s = sub.add_parser("seed", help="przenies 'czucie' ze wzorca do naszego auta")
    s.add_argument("--into", required=True, help="nasz handlingName")
    s.add_argument("--from", dest="src", required=True, help="wzorzec z bazy vanilla")
    s.add_argument("--scale-mass", action="store_true",
                   help="przeskaluj sprezyny/stabilizator/tlumienie stosunkiem mas (wzorzec lzejszy niz nasze auto)")
    s.add_argument("--with-geometry", action="store_true",
                   help="kopiuj tez rollCentre/comZ/suspensionRaise ze wzorca (domyslnie zostaja wlasne - to geometria modelu)")
    s.add_argument("--apply", action="store_true")
    s.add_argument("--backup", default="D:/game/FiveM/local4Word6/backups/handling-match-" + time.strftime("%Y%m%d-%H%M%S"))
    a = ap.parse_args()
    db = cars()

    if a.cmd == "find":
        if a.like:
            b = ours().get(a.like.upper())
            if not b:
                sys.exit(f"nie znalazlem {a.like} w naszych zasobach")
            t = {k: getv(b[0], k) for k in SCORE}
        else:
            if not a.mass:
                sys.exit("podaj --mass albo --like")
            t = {"fMass": a.mass,
                 "fInitialDriveMaxFlatVel": min(max(a.vmax / 1.45, 125), 185) if a.vmax else None,
                 "fInitialDriveForce": min(max(0.20 + 0.40 * a.hp / a.mass, 0.24), 0.44) if a.hp else None,
                 "fDriveBiasFront": DRIVE[a.drive] if a.drive else None}
            if any(v is None for v in t.values()):
                sys.exit("do szukania potrzebne: --mass --hp --vmax --drive")
        show(find(t, db, a.n), t)
        print("\nwybierz wzorzec i: handling_match.py seed --into <nasze> --from <WZORZEC>")
        return

    src = db.get(a.src.upper())
    if not src:
        sys.exit(f"{a.src} nie ma w bazie vanilla (albo to lodz/samolot/motor)")
    tgt = ours().get(a.into.upper())
    if not tgt:
        sys.exit(f"{a.into} nie ma w naszych zasobach")
    sb, (tb, path) = src[0], tgt
    nb, log = tb, []
    # sprezyny i tlumienie skaluja sie z masa: ta sama sztywnosc pod ciezszym autem = miekciej
    SPRING = {"fSuspensionForce": 3.2, "fAntiRollBarForce": 1.2, "fSuspensionCompDamp": 2.0, "fSuspensionReboundDamp": 3.2}
    r = 1.0
    if a.scale_mass:
        mo, ms = getv(tb, "fMass"), getv(sb, "fMass")
        r = mo / ms if mo and ms else 1.0
        print(f"skalowanie masa: {ms:.0f} -> {mo:.0f} kg  (x{r:.3f})")
    for k in FEEL + list(VEC):
        if k in GEOMETRY and not a.with_geometry:
            continue
        v, old = getv(sb, k), getv(nb, k)
        if v is not None and k in SPRING and r != 1.0:
            v = min(v * r, SPRING[k])
        if k in NEVER_LOWER and v is not None and old is not None and v < old:
            v = old
        if v is None:
            continue
        if old is None:
            log.append(f"  {k:32s} (nasze auto nie ma tego pola)")
        elif abs(old - v) > 1e-6:
            log.append(f"  {k:32s} {old:>9.3f} -> {v:.3f}")
            nb = setv(nb, k, v)
    print(f"{a.into.upper()} <- wzorzec {a.src.upper()}   ({path.split('[addon]')[-1]})")
    print("\n".join(log) if log else "  (bez zmian)")
    if not a.apply:
        print("[dry run - dodaj --apply]")
        return
    bk = Path(a.backup) / Path(path).resolve().as_posix().split("/txData/resources/", 1)[-1]
    bk.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, bk)
    d = Path(path).read_bytes().decode("utf-8", "replace")
    Path(path).write_bytes(d.replace(tb, nb, 1).encode("utf-8"))
    print(f"ZAPISANO (backup: {bk.parent})")


if __name__ == "__main__":
    main()
