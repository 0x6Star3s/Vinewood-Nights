#!/usr/bin/env python3
"""
handling_tune.py - realne dane auta -> handling GTA. Jedna komenda robi wszystko:

  python tools/handling_tune.py             # dry run: co by sie zmienilo
  python tools/handling_tune.py --apply     # zapis, backup w backups/handling-tune-<data>/
  python tools/handling_tune.py --only pista,r33

Dla kazdego auta z tabeli SPECS:
  1. wpisuje klase (cls) do vehicles.meta <vehicleClass>,
  2. naklada szablon klasy z handling_fix.py (tryb template: grip, hamulce, zawieszenie, stabilizator...),
  3. z realnych danych liczy to, czym auta maja sie roznic:
       pw  = KM / masa                                  (moc na kg; 250 KM/1700 kg = 0.15, 720/1400 = 0.51)
       fMass                    = masa
       nInitialDriveGears       = biegi
       fDriveBiasFront          = 0 rwd, 1 fwd, 0.3-0.45 awd
       fInitialDriveForce       = 0.20 + 0.40*pw           [0.24 .. 0.44]  (vanilla 0.25-0.36; Zentorno 0.354)
       fInitialDriveMaxFlatVel  = vmax_kmh / 1.45          [125 .. 185]    (x1.32 = km/h w grze; 185 = 244 km/h)
       fInitialDragCoeff        = 11 - vmax_kmh / 60       [6.5 .. 10]     (szybsze auto = mniejszy opor)
       fBrakeForce              = 0.80 + 0.40*pw           [0.80 .. 1.10]
       fTractionCurveMax/Min    = szablon klasy + (pw - 0.30)*0.30   [-0.10 .. +0.12]  (mocniejsze = lepsze opony)
  4. na koniec reczne poprawki z TUNE (jesli sa).
Auta spoza SPECS nie sa ruszane. Wzory sa idempotentne (drugi run nic nie zmienia).
Po --apply: restart serwera, /dv, spawn od nowa (handling jest cache'owany); zmiana klasy w vehicles.meta wymaga reconnectu.
"""
import argparse, glob, re, shutil, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from handling_fix import T, KEYS, fix_item, getv, setv  # noqa: E402

ROOT = "D:/game/FiveM/local4Word6/txData/resources/[addon]"
DRIVE = {"rwd": 0.0, "fwd": 1.0, "awd": 0.35, "awd_r": 0.30, "awd_f": 0.45}  # awd_r = tylnonapedowe AWD (AMG, M xDrive), awd_f = quattro/SUV

# handlingName (male litery) -> (klasa, masa kg, KM, vmax km/h, naped, biegi). Dane fabryczne, w przyblizeniu.
S = lambda cls, m, hp, v, d, g: dict(cls=cls, mass=m, hp=hp, vmax=v, drive=d, gears=g)
SPECS = {
    # Audi
    "a8lw12": S("SEDAN", 2110, 500, 250, "awd_f", 8), "ocnauda8l22h": S("SEDAN", 2150, 460, 250, "awd_f", 8),
    "oycs8": S("SEDAN", 2230, 571, 250, "awd_f", 8), "tenf": S("SEDAN", 2075, 600, 250, "awd_f", 8),
    "rs6rabt20": S("SEDAN", 2075, 700, 300, "awd_f", 8), "rs7r": S("SEDAN", 2065, 740, 320, "awd_f", 8),
    "rs5": S("COUPE", 1730, 450, 250, "awd_f", 8), "ocnetrongt": S("COUPE", 2347, 646, 250, "awd_f", 2),
    "r8cabt": S("SUPER", 1630, 610, 330, "awd_r", 7), "r8sol": S("SUPER", 1630, 610, 330, "awd_r", 7),
    "gcmr8spyder2022": S("SUPER", 1695, 620, 329, "awd_r", 7),
    # Bentley
    "21bentayga": S("SUV", 2416, 550, 290, "awd_f", 8), "ikx3gtone": S("SPORT", 2244, 635, 333, "awd_f", 8),
    # BMW
    "18mh5": S("SEDAN", 1855, 600, 250, "awd_r", 8), "2021m5": S("SEDAN", 1865, 625, 250, "awd_r", 8),
    "gcmm52021": S("SEDAN", 1855, 600, 250, "awd_r", 8), "bmwm5cs": S("SEDAN", 1825, 635, 250, "awd_r", 8),
    "gcmm5cs": S("SEDAN", 1825, 635, 250, "awd_r", 8), "m5perf16": S("SEDAN", 1870, 600, 250, "rwd", 7),
    "m3f80": S("SEDAN", 1520, 431, 250, "rwd", 7), "m3g80c": S("SEDAN", 1730, 510, 250, "rwd", 8),
    "m4c": S("COUPE", 1920, 510, 250, "awd_r", 8), "bmwm4cs": S("COUPE", 1580, 460, 280, "rwd", 7),
    "bmwx5": S("SUV", 2345, 530, 250, "awd_f", 8), "mobm23": S("EMERGENCY", 1800, 510, 250, "rwd", 8),
    # Dodge
    "16charger": S("SEDAN", 2075, 707, 328, "rwd", 8), "gcmcharger2021re": S("SEDAN", 2075, 797, 327, "rwd", 8),
    "charger69": S("MUSCLE", 1750, 375, 210, "rwd", 4),
    # Ferrari
    "488": S("SUPER", 1475, 670, 330, "rwd", 7), "pista": S("SUPER", 1385, 720, 340, "rwd", 7),
    "f812c21": S("SUPER", 1487, 830, 340, "rwd", 7), "f822": S("SUPER", 1435, 720, 340, "rwd", 7),
    # Ford
    "mst": S("MUSCLE", 1650, 600, 290, "rwd", 6),
    # Koenigsegg / Pagani
    "agerars": S("SUPER", 1395, 1160, 400, "rwd", 7), "bc": S("SUPER", 1218, 800, 380, "rwd", 7), "imola": S("SUPER", 1246, 838, 380, "rwd", 7),
    # Lamborghini / McLaren
    "aventadors": S("SUPER", 1575, 740, 350, "awd_r", 7), "gcmlamboultimae": S("SUPER", 1550, 780, 355, "awd_r", 7),
    "lp750sv": S("SUPER", 1525, 750, 350, "awd_r", 7), "huracancp": S("SUPER", 1382, 640, 325, "awd_r", 7),
    "gcm765ltspider": S("SUPER", 1388, 765, 330, "rwd", 7), "m720": S("SUPER", 1419, 720, 341, "rwd", 7),
    # Mercedes
    "21s580m": S("SEDAN", 2150, 503, 250, "awd_f", 9), "s500": S("SEDAN", 2030, 455, 250, "rwd", 9),
    "s500w223": S("SEDAN", 2100, 435, 250, "awd_f", 9), "gcmw223": S("SEDAN", 2100, 435, 250, "awd_f", 9),
    "e400": S("SEDAN", 1850, 333, 250, "awd_f", 9), "c63w205": S("SEDAN", 1800, 510, 250, "rwd", 7),
    "e63amg": S("SEDAN", 1950, 612, 250, "awd_r", 9), "e63sf": S("SEDAN", 1950, 612, 250, "awd_r", 9),
    "merce63s": S("SEDAN", 1950, 612, 250, "awd_r", 9), "e63estate": S("SEDAN", 2100, 612, 250, "awd_r", 9),
    "gt63s": S("SEDAN", 2120, 639, 315, "awd_r", 9), "gxa45": S("SEDAN", 1560, 421, 270, "awd_f", 8),
    "mbcls21": S("COUPE", 1980, 435, 250, "awd_f", 9), "s63b": S("COUPE", 2115, 612, 250, "awd_r", 9),
    "amggtrr20": S("SPORT", 1630, 585, 318, "rwd", 7), "brabusgt600": S("SPORT", 1650, 600, 325, "rwd", 7),
    "sl63": S("SPORT", 1970, 585, 315, "awd_r", 9), "mbslr": S("SPORT", 1768, 626, 334, "rwd", 5),
    "22g63": S("SUV", 2560, 585, 240, "awd_f", 9), "w463as": S("SUV", 2560, 585, 240, "awd_f", 9),
    "lartegle": S("SUV", 2300, 435, 250, "awd_f", 9),
    # Nissan / Subaru / Jaguar / Lexus
    "r33": S("SPORT", 1540, 320, 250, "awd_r", 5), "as_zr350": S("SPORT", 1600, 400, 250, "rwd", 6),
    "subarung": S("SEDAN", 1550, 305, 255, "awd", 6), "gcmftype2022": S("SPORT", 1743, 575, 300, "awd_r", 8),
    "gcmnx260s2022": S("SUV", 1900, 275, 200, "awd_f", 8),
    # Porsche
    "porsche992": S("SPORT", 1515, 450, 308, "rwd", 8), "pgt322": S("SPORT", 1435, 510, 318, "rwd", 7),
    "porcaygt22": S("SUV", 2220, 640, 300, "awd_f", 8),
    # SUV / luksus
    "gcmrangerover2022": S("SUV", 2500, 530, 250, "awd_f", 8), "rangerover2": S("SUV", 2310, 575, 283, "awd_f", 8),
    "rrst": S("SUV", 2400, 400, 225, "awd_f", 8), "coastline": S("SUV", 2660, 571, 250, "awd_f", 8),
    "rrghost21": S("SEDAN", 2490, 571, 250, "awd_f", 8), "escaladesport": S("SUV", 2600, 420, 200, "awd_f", 10),
    "explorer": S("SUV", 2100, 365, 200, "awd_f", 6), "20tundra": S("OFF_ROAD", 2600, 381, 180, "awd_f", 6),
}

# reczne poprawki nakladane NA KONIEC (po wzorach). handlingName -> {pole: wartosc}.
# Przyklad: TUNE = {"pista": {"fSteeringLock": 42.0}}
TUNE = {
    # rs5: gracz zglosil za duzy przechyl boczny w zakretach (2026-09-04). Szablon COUPE daje
    # arb 0.70 / susF 2.40 / comp 1.40 / reb 2.00 / rc 0.35 - tu twardziej, dalej w zakresie vanilla.
    # vecInertiaMultiplier.y 1.60 -> 1.42 jest w samym handling.meta: setv() umie tylko os z.
    # Predkosc i opor trzymamy na szablonie klasy (160 = 211 km/h), inaczej derive() wrocilby do 172.4 (228 km/h).
    "rs5": {"fSuspensionForce": 2.65, "fSuspensionCompDamp": 1.55, "fSuspensionReboundDamp": 2.75,
            "fAntiRollBarForce": 0.95, "fRollCentreHeightFront": 0.40, "fRollCentreHeightRear": 0.38,
            "fInitialDriveMaxFlatVel": 160.0, "fInitialDragCoeff": 8.0, "fBrakeForce": 0.85,
            "fTractionCurveMax": 2.40, "fTractionCurveMin": 2.15},
}

# auta ze wzorca vanilla (handling_match.py seed) - szablon klasy ich NIE dotyka,
# bo nadpisalby zawieszenie/trakcje Rockstara. Dostaja tylko tozsamosc z derive().
SEEDED = {"m4c": "SENTINEL", "16charger": "BUFFALO4"}

clamp = lambda v, lo, hi: min(max(v, lo), hi)


def derive(sp):
    pw = sp["hp"] / sp["mass"]
    tpl = T.get(sp["cls"], T["SEDAN"])
    tmax0, tmin0 = tpl[KEYS.index("fTractionCurveMax")], tpl[KEYS.index("fTractionCurveMin")]
    dt = clamp((pw - 0.30) * 0.30, -0.10, 0.12)
    d = sp["drive"]
    return {
        "fMass": float(sp["mass"]),
        # >8 biegow wychodzi poza tablice przelozen i psuje redukcje (dziala dopiero od buildu 1.0.1604)
        "nInitialDriveGears": float(min(sp["gears"], 8)),
        "fDriveBiasFront": DRIVE[d] if isinstance(d, str) else float(d),
        "fInitialDriveForce": clamp(0.20 + 0.40 * pw, 0.24, 0.44),
        "fInitialDriveMaxFlatVel": clamp(sp["vmax"] / 1.45, 125, 185),
        "fInitialDragCoeff": clamp(11 - sp["vmax"] / 60, 6.5, 10),
        "fBrakeForce": clamp(0.80 + 0.40 * pw, 0.80, 1.10),
        "fTractionCurveMax": tmax0 + dt,
        "fTractionCurveMin": tmin0 + dt,
    }


def apply_values(b, vals, log):
    for k, v in vals.items():
        old = getv(b, k)
        if old is None:
            log.append(f"      {k:32s} (brak pola)")
        elif abs(old - v) > 1e-6:
            log.append(f"      {k:32s} {old:>10.4f} -> {v:.4f}")
            b = setv(b, k, v)
    return b


def backup_write(path, data, bkroot):
    rel = Path(path).resolve().as_posix().split("/txData/resources/", 1)[-1]
    bk = Path(bkroot) / rel
    bk.parent.mkdir(parents=True, exist_ok=True)
    if not bk.exists():
        shutil.copy2(path, bk)
    Path(path).write_bytes(data.encode("utf-8"))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--only", help="tylko te handlingName, po przecinku")
    ap.add_argument("--backup", default="D:/game/FiveM/local4Word6/backups/handling-tune-" + time.strftime("%Y%m%d-%H%M%S"))
    a = ap.parse_args()
    only = set(x.lower() for x in a.only.split(",")) if a.only else None
    found = set()
    for f in sorted(glob.glob(glob.escape(ROOT) + "/**/handling.meta", recursive=True)):
        txt = Path(f).read_text(encoding="utf-8", errors="replace")
        out = txt
        for m in list(re.finditer(r'<Item type="CHandlingData">.*?</Item>\s*(?=<Item type="CHandlingData">|</HandlingData>)', txt, flags=re.S)):
            b = m.group(0)
            name = re.search(r"<handlingName>\s*([^<\s]+)", b)
            hn = name.group(1).lower() if name else None
            if hn not in SPECS or (only and hn not in only):
                continue
            found.add(hn)
            sp = SPECS[hn]
            log = []
            if hn in SEEDED:
                log.append(f"      (wzorzec {SEEDED[hn]} - zawieszenie i trakcja z vanilla)")
                vals = {k: v for k, v in derive(sp).items() if not k.startswith("fTractionCurve")}
                nb = apply_values(b, vals, log)
            else:
                nb, _ = fix_item(b, sp["cls"], "template", log)
                nb = apply_values(nb, derive(sp), log)
                nb = apply_values(nb, TUNE.get(hn, {}), log)
            # klasa w vehicles.meta obok
            vm = Path(f).with_name("vehicles.meta")
            if vm.exists():
                vt = vm.read_text(encoding="utf-8", errors="replace")
                nvt = re.sub(r"(<vehicleClass>\s*)VC_\w+", lambda mm: mm.group(1) + "VC_" + sp["cls"], vt, count=1)
                if nvt != vt:
                    log.append(f"      vehicleClass -> VC_{sp['cls']}")
                    if a.apply:
                        backup_write(vm, nvt, a.backup)
            if nb != b:
                print(f"{hn:16s} [{sp['cls']}] {sp['hp']} KM / {sp['mass']} kg / {sp['vmax']} km/h  ({f.split('[addon]')[-1]})")
                print("\n".join(log))
                out = out.replace(b, nb, 1)
        if out != txt and a.apply:
            backup_write(f, out, a.backup)
    missing = set(SPECS) - found - (set(SPECS) - only if only else set())
    if missing:
        print("nie znaleziono:", ", ".join(sorted(missing)))
    print("ZAPISANO" if a.apply else "[dry run - dodaj --apply]")


if __name__ == "__main__":
    main()
