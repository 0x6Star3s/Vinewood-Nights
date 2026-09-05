import re, glob, json, statistics
from pathlib import Path
from collections import Counter

ROOT = "D:/game/FiveM/local4Word6/txData/resources/[addon]"


def readx(p):
    t = Path(p).read_bytes().decode("utf-8", "replace").replace("\0", "")
    return re.sub(r"<!--.*?-->", "", t, flags=re.S)


FIELDS = ["fMass", "fInitialDragCoeff", "fDownforceModifier", "fPercentSubmerged", "fDriveBiasFront", "nInitialDriveGears",
          "fInitialDriveForce", "fDriveInertia", "fClutchChangeRateScaleUpShift", "fClutchChangeRateScaleDownShift",
          "fInitialDriveMaxFlatVel", "fBrakeForce", "fBrakeBiasFront", "fHandBrakeForce", "fSteeringLock",
          "fTractionCurveMax", "fTractionCurveMin", "fTractionCurveLateral", "fTractionSpringDeltaMax",
          "fLowSpeedTractionLossMult", "fCamberStiffnesss", "fTractionBiasFront", "fTractionLossMult",
          "fSuspensionForce", "fSuspensionCompDamp", "fSuspensionReboundDamp", "fSuspensionUpperLimit",
          "fSuspensionLowerLimit", "fSuspensionRaise", "fSuspensionBiasFront", "fAntiRollBarForce",
          "fAntiRollBarBiasFront", "fRollCentreHeightFront", "fRollCentreHeightRear", "fCollisionDamageMult",
          "fEngineDamageMult", "fPetrolTankVolume"]


def fnum(s):
    try:
        return float(s)
    except Exception:
        return None


hand = {}
dup = []
for f in glob.glob(glob.escape(ROOT) + "/**/handling.meta", recursive=True):
    t = readx(f)
    for item in re.finditer(r'<Item type="CHandlingData">(.*?)</Item>\s*(?=<Item type="CHandlingData">|</HandlingData>)', t, flags=re.S):
        b = item.group(1)
        name = re.search(r"<handlingName>\s*([^<\s]+)\s*</handlingName>", b)
        if not name:
            continue
        name = name.group(1).lower()
        d = {"file": f.replace(ROOT + "/", "").replace("\\", "/")}
        for k in FIELDS:
            m = re.search(r"<%s value=\"([^\"]+)\"" % k, b)
            d[k] = fnum(m.group(1)) if m else None
        m = re.search(r'<vecCentreOfMassOffset x="([^"]+)" y="([^"]+)" z="([^"]+)"', b)
        d["comx"], d["comy"], d["comz"] = (fnum(m.group(1)), fnum(m.group(2)), fnum(m.group(3))) if m else (None, None, None)
        m = re.search(r'<vecInertiaMultiplier x="([^"]+)" y="([^"]+)" z="([^"]+)"', b)
        d["inx"], d["iny"], d["inz"] = (fnum(m.group(1)), fnum(m.group(2)), fnum(m.group(3))) if m else (None, None, None)
        if name in hand:
            dup.append((name, hand[name]["file"], d["file"]))
        hand[name] = d

veh = {}
for f in glob.glob(glob.escape(ROOT) + "/**/vehicles.meta", recursive=True):
    t = readx(f)
    starts = [m.start() for m in re.finditer(r"<modelName>", t)]
    for i, st in enumerate(starts):
        b = t[st:starts[i + 1] if i + 1 < len(starts) else len(t)]
        mn = re.search(r"<modelName>\s*([^<\s]+)", b)
        hid = re.search(r"<handlingId>\s*([^<\s]+)", b)
        vc = re.search(r"<vehicleClass>\s*([^<\s]+)", b)
        gn = re.search(r"<gameName>\s*([^<\s]*)", b)
        if mn and hid:
            veh[mn.group(1)] = {"handlingId": hid.group(1).lower(), "class": (vc.group(1) if vc else "?").replace("VC_", ""),
                                "gameName": gn.group(1) if gn else "", "file": f.replace(ROOT + "/", "").replace("\\", "/")}

# approx vanilla GTA V ranges per class: flatVel, driveForce, tractionMax, mass, drag
R = {"SUPER": ((150, 175), (0.28, 0.42), (2.4, 2.75), (1300, 2000), (6, 13)),
     "SPORT": ((135, 165), (0.26, 0.38), (2.3, 2.6), (1200, 1900), (6, 13)),
     "SEDAN": ((120, 155), (0.22, 0.34), (2.0, 2.6), (1400, 2600), (6, 13)),
     "COUPE": ((125, 160), (0.22, 0.34), (2.1, 2.55), (1300, 2200), (6, 13)),
     "MUSCLE": ((125, 160), (0.22, 0.34), (2.0, 2.45), (1300, 2100), (6, 13)),
     "SUV": ((110, 150), (0.22, 0.30), (1.9, 2.3), (1800, 3200), (6, 14)),
     "OFF_ROAD": ((105, 145), (0.2, 0.30), (1.8, 2.3), (1500, 3200), (6, 15)),
     "SPORT_CLASSIC": ((125, 160), (0.24, 0.36), (2.1, 2.55), (1100, 1900), (6, 13)),
     "COMPACT": ((110, 145), (0.18, 0.30), (1.9, 2.4), (900, 1600), (6, 13)),
     "EMERGENCY": ((130, 165), (0.24, 0.36), (2.1, 2.55), (1600, 2800), (6, 13)),
     "MOTORCYCLE": ((130, 175), (0.25, 0.45), (2.0, 2.6), (150, 400), (8, 20)),
     "VAN": ((100, 140), (0.18, 0.28), (1.7, 2.2), (1800, 3500), (7, 15)),
     "COMMERCIAL": ((90, 130), (0.10, 0.22), (1.6, 2.1), (3000, 12000), (8, 18)),
     "INDUSTRIAL": ((90, 130), (0.10, 0.22), (1.6, 2.1), (3000, 12000), (8, 18)),
     "UTILITY": ((100, 140), (0.12, 0.25), (1.7, 2.2), (1500, 4000), (7, 15)),
     "OPEN_WHEEL": ((150, 185), (0.3, 0.5), (2.5, 3.2), (600, 1000), (5, 10))}

rows = []
for model, v in veh.items():
    h = hand.get(v["handlingId"])
    cls = v["class"]
    if not h:
        rows.append({"model": model, "class": cls, "handling": v["handlingId"], "issues": ["BRAK handlingu (phantom)"], "file": v["file"]})
        continue
    iss = []
    sev = 0
    rr = R.get(cls, R["SEDAN"])
    g = h.get
    fv, df, tm, mass, drag = g("fInitialDriveMaxFlatVel"), g("fInitialDriveForce"), g("fTractionCurveMax"), g("fMass"), g("fInitialDragCoeff")

    def chk(val, lo, hi, label, w=1):
        if val is None:
            return 0
        if val > hi:
            iss.append(f"{label} {val:g} > {hi}")
            return w
        if val < lo:
            iss.append(f"{label} {val:g} < {lo}")
            return w
        return 0

    sev += chk(fv, *rr[0], "flatVel", 2)
    sev += chk(df, *rr[1], "driveForce", 2)
    sev += chk(tm, *rr[2], "tractionMax", 2)
    sev += chk(mass, *rr[3], "mass", 1)
    sev += chk(drag, *rr[4], "drag", 1)
    tmin = g("fTractionCurveMin")
    if tm and tmin and tmin > tm:
        iss.append(f"tractionMin {tmin:g} > tractionMax {tm:g} (odwrocone)")
        sev += 2
    if tm and tmin and tmin < tm * 0.6:
        iss.append(f"tractionMin {tmin:g} << max (nagly poslizg)")
        sev += 1
    bf = g("fBrakeForce")
    if bf and bf > 2.0:
        iss.append(f"brakeForce {bf:g} (vanilla 0.6-1.5)")
        sev += 2
    if bf and bf < 0.4:
        iss.append(f"brakeForce {bf:g} (brak hamulcow)")
        sev += 1
    lat = g("fTractionCurveLateral")
    if lat and (lat < 15 or lat > 35):
        iss.append(f"tractionLateral {lat:g}")
        sev += 1
    arb, rcf, rcr, cz = g("fAntiRollBarForce"), g("fRollCentreHeightFront"), g("fRollCentreHeightRear"), h.get("comz")
    sf, cd, rd = g("fSuspensionForce"), g("fSuspensionCompDamp"), g("fSuspensionReboundDamp")
    flip = []
    if arb is not None and arb < 0.3:
        flip.append(f"antiRoll {arb:g}")
    if rcf is not None and rcf < 0.05:
        flip.append(f"rollCentreF {rcf:g}")
    if rcr is not None and rcr < 0.05:
        flip.append(f"rollCentreR {rcr:g}")
    if cz is not None and cz > (0.35 if cls in ("SUV", "OFF_ROAD", "VAN") else 0.2):
        flip.append(f"COM.z +{cz:g}")
    if sf is not None and sf < 1.2 and tm and tm > 2.4:
        flip.append(f"miekkie zaw {sf:g} + grip {tm:g}")
    if g("fSteeringLock") and g("fSteeringLock") > 45:
        flip.append(f"steeringLock {g('fSteeringLock'):g}")
    if flip:
        iss.append("WYWROTKA: " + ", ".join(flip))
        sev += 2
    if cz is not None and cz < -0.35:
        iss.append(f"COM.z {cz:g} (przyklejone)")
        sev += 1
    if arb is not None and arb > 2.5:
        iss.append(f"antiRoll {arb:g} (deska)")
        sev += 1
    if sf is not None and (sf < 0.8 or sf > 5):
        iss.append(f"suspensionForce {sf:g}")
        sev += 1
    if cd is not None and (cd < 0.5 or cd > 4):
        iss.append(f"compDamp {cd:g}")
        sev += 1
    if rd is not None and (rd < 0.5 or rd > 4.5):
        iss.append(f"reboundDamp {rd:g}")
        sev += 1
    for k in ("fSuspensionUpperLimit", "fSuspensionLowerLimit"):
        if g(k) is not None and abs(g(k)) > 0.35:
            iss.append(f"{k} {g(k):g}")
            sev += 1
    if g("fSteeringLock") and g("fSteeringLock") < 25:
        iss.append(f"steeringLock {g('fSteeringLock'):g} (nie skreca)")
        sev += 1
    if g("nInitialDriveGears") and (g("nInitialDriveGears") < 3 or g("nInitialDriveGears") > 8):
        iss.append(f"gears {g('nInitialDriveGears'):g}")
        sev += 1
    for k in ("fClutchChangeRateScaleUpShift", "fClutchChangeRateScaleDownShift"):
        if g(k) and g(k) > 13:
            iss.append(f"{k} {g(k):g} > 13")
            sev += 1
    if g("fTractionBiasFront") is not None and not (0.44 <= g("fTractionBiasFront") <= 0.54):
        iss.append(f"tractionBiasFront {g('fTractionBiasFront'):g}")
        sev += 1
    if g("fLowSpeedTractionLossMult") is not None and g("fLowSpeedTractionLossMult") > 1.6:
        iss.append(f"lowSpeedTractionLoss {g('fLowSpeedTractionLossMult'):g}")
        sev += 1
    if g("fPercentSubmerged") is not None and g("fPercentSubmerged") < 50:
        iss.append(f"percentSubmerged {g('fPercentSubmerged'):g}")
        sev += 1
    if g("fDriveInertia") is not None and (g("fDriveInertia") < 0.4 or g("fDriveInertia") > 2.0):
        iss.append(f"driveInertia {g('fDriveInertia'):g}")
        sev += 1
    if g("fDownforceModifier") is not None and g("fDownforceModifier") > 150:
        iss.append(f"downforce {g('fDownforceModifier'):g}")
        sev += 1
    if g("fCollisionDamageMult") is not None and g("fCollisionDamageMult") < 0.2:
        iss.append(f"collisionDmg {g('fCollisionDamageMult'):g} (niezniszczalne)")
        sev += 1
    rows.append({"model": model, "class": cls, "handling": v["handlingId"], "file": h["file"], "sev": sev, "issues": iss,
                 "flatVel": fv, "kmh_redline": round(fv * 1.32) if fv else None, "driveForce": df, "tractionMax": tm,
                 "tractionMin": tmin, "brake": bf, "mass": mass, "drag": drag, "antiRoll": arb, "rcF": rcf, "rcR": rcr,
                 "comz": cz, "susF": sf, "compD": cd, "rebD": rd, "lat": lat, "steer": g("fSteeringLock"), "gears": g("nInitialDriveGears"),
                 "driveBias": g("fDriveBiasFront"), "inz": h.get("inz")})

json.dump({"rows": rows, "dup": dup, "handling_count": len(hand), "veh_count": len(veh)}, open("handling_report.json", "w"), indent=1)
print(f"handling items: {len(hand)}, vehicles.meta models: {len(veh)}, duplicate handlingName: {len(dup)}")
for d in dup:
    print("  DUP", d)
scored = [r for r in rows if "sev" in r]
print(f"\nmodels with 0 issues: {sum(1 for r in scored if not r['issues'])} / {len(scored)}; phantoms: {len(rows) - len(scored)}")
c = Counter()
for r in scored:
    for i in r["issues"]:
        c[i.split(" ")[0] if not i.startswith("WYWROTKA") else "WYWROTKA"] += 1
print("issue counts:", c.most_common())


def vals(k):
    return [r[k] for r in scored if r.get(k) is not None]


for k in ("flatVel", "kmh_redline", "driveForce", "tractionMax", "tractionMin", "brake", "mass", "drag", "antiRoll", "rcF", "comz", "susF", "lat", "steer", "gears"):
    v = vals(k)
    if v:
        print(f"{k:12s} min={min(v):8.3f} median={statistics.median(v):8.3f} max={max(v):8.3f} n={len(v)}")
print("\nclass counts:", Counter(r["class"] for r in scored).most_common())
print("\n===== worst 30 =====")
for r in sorted(scored, key=lambda r: -r["sev"])[:30]:
    print(f"{r['model']:16s} {r['class']:9s} sev={r['sev']:2d} fv={r['flatVel']}(~{r['kmh_redline']}km/h) df={r['driveForce']} tmax={r['tractionMax']} tmin={r['tractionMin']} brk={r['brake']} m={r['mass']} drag={r['drag']} arb={r['antiRoll']} rc={r['rcF']}/{r['rcR']} comz={r['comz']} sus={r['susF']} | " + "; ".join(r["issues"]))
print("\n===== phantoms =====")
for r in rows:
    if "sev" not in r:
        print(" ", r["model"], r["file"])
