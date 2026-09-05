#!/usr/bin/env python3
"""
script_lint.py - znajdz skrypty Lua, ktore w czasie gry nadpisuja fizyke pojazdow.

Po co: 16charger nie przekraczal 80 km/h i nie mial wstecznego. Plik handling.meta byl poprawny -
winny byl skrypt (qb-vehicles/client/cl_doubleClutch.lua), ktory dusil obroty i zapinal limit
predkosci. Takiego bledu nie widac w zadnym audycie handlingu, bo pliku nikt nie ruszal.

  python tools/script_lint.py                 # skan wszystkich zasobow
  python tools/script_lint.py --res qb-vehicles
  python tools/script_lint.py -v              # z trescia linii

Narzedzie tylko RAPORTUJE. Automatyczna edycja cudzego Lua to proszenie sie o kolejna awarie -
poprawki robimy recznie, majac przed oczami kontekst.
"""
import argparse, os, re, sys
from collections import defaultdict

ROOT = "D:/game/FiveM/local4Word6/txData/resources"
SKIP_DIRS = {"[disabled]", "node_modules", ".git", "[test]"}

# wzorzec -> (etykieta, dlaczego to grozne)
CHECKS = [
    (r"\bSetVehicleMaxSpeed\s*\(", "limit predkosci",
     "limit zostaje na pojezdzie po wyjsciu kierowcy, jesli reset nie jest bezwarunkowy"),
    (r"\bSetEntityMaxSpeed\s*\(", "limit predkosci (entity)",
     "to samo, a na pojazdach zalecany jest SetVehicleMaxSpeed"),
    (r"\bSetVehicleCurrentRpm\s*\(", "wymuszanie obrotow",
     "duszenie obrotow w petli kasuje przyspieszenie; auto stoi na jednej predkosci"),
    (r"\bSetVehicleHandling(Float|Int|Vector)\s*\(", "nadpisanie handlingu",
     "zmienia fizyke ponad plikiem handling.meta - audyt pliku tego nie wykryje"),
    (r"\bSetVehicleUndriveable\s*\(", "blokada jazdy", "auto przestaje reagowac na gaz"),
    (r"\bSetVehicleEnginePowerMultiplier\s*\(", "mnoznik mocy", "cicha zmiana osiagow"),
    (r"\bSetVehicleEngineTorqueMultiplier\s*\(", "mnoznik momentu", "cicha zmiana osiagow"),
    (r"\bDisableControlAction\s*\(\s*\d+\s*,\s*(71|72|59|60|61|63|64|76)\b", "blokada sterowania",
     "71/72 to gaz i hamulec (hamulec = tez wsteczny), 76 to reczny"),
]
# progi predkosci wpisane na sztywno - klasyczne zrodlo "auto staje na okraglej liczbie"
THRESHOLD = re.compile(r"\*\s*(2\.236936|2\.23694|3\.6)\b")

RESET_OK = re.compile(r"SetVehicleMaxSpeed\s*\([^,]+,\s*0(\.0)?\s*\)")


def resources(root):
    for dirpath, dirnames, files in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(".lua"):
                yield os.path.join(dirpath, f)


def res_name(path, root):
    rel = os.path.relpath(path, root).replace("\\", "/").split("/")
    # pomijamy foldery-kategorie w nawiasach kwadratowych
    for part in rel:
        if not (part.startswith("[") and part.endswith("]")):
            return part
    return rel[0]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--res", help="tylko ten zasob")
    ap.add_argument("-v", "--verbose", action="store_true", help="pokaz tresc linii")
    a = ap.parse_args()

    hits = defaultdict(list)
    files_with_limit, files_with_reset = set(), set()

    for path in resources(a.root):
        rn = res_name(path, a.root)
        if a.res and rn.lower() != a.res.lower():
            continue
        try:
            lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines, 1):
            code = line.split("--", 1)[0]
            if not code.strip():
                continue
            for pat, label, why in CHECKS:
                if re.search(pat, code):
                    hits[rn].append((label, path, i, line.strip(), why))
                    if "SetVehicleMaxSpeed" in code:
                        files_with_limit.add(path)
                        if RESET_OK.search(code):
                            files_with_reset.add(path)
            if THRESHOLD.search(code) and re.search(r"[<>]=?\s*\d", code):
                hits[rn].append(("prog predkosci na sztywno", path, i, line.strip(),
                                 "auto zatrzymuje sie na okraglej liczbie niezaleznie od handlingu"))

    if not hits:
        print("czysto - zaden skrypt nie rusza fizyki pojazdow")
        return 0

    total = sum(len(v) for v in hits.values())
    print(f"{total} trafien w {len(hits)} zasobach\n")
    for rn in sorted(hits, key=lambda r: -len(hits[r])):
        print(f"== {rn}  ({len(hits[rn])})")
        seen = set()
        for label, path, i, text, why in hits[rn]:
            rel = os.path.relpath(path, a.root).replace("\\", "/")
            print(f"   {label:28s} {rel}:{i}")
            if a.verbose:
                print(f"      {text[:120]}")
            if label not in seen:
                print(f"      ryzyko: {why}")
                seen.add(label)
        print()

    leaky = files_with_limit - files_with_reset
    if leaky:
        print("UWAGA - ustawiaja limit predkosci, ale w tej samej linii nie ma resetu do 0.0;")
        print("sprawdz, czy reset wykonuje sie takze gdy gracz wysiada z auta:")
        for p in sorted(leaky):
            print("   " + os.path.relpath(p, a.root).replace("\\", "/"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
