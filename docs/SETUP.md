# Vinewood Nights – dokumentacja techniczna

[← README](../README.md) · [README (PL)](../README.pl.md)

---

Lokalny serwer FiveM (FXServer) na QBCore, uruchamiany przez txAdmin, z bazą
MariaDB w Dockerze. Repo trzyma konfigurację, zasoby (bez ciężkich modeli),
narzędzia do pojazdów i dokumentację/audyty.

---

## Szybki start

```bash
docker compose up -d          # baza (kontener local4word6-projectterrific-db, port 3307)
cp txData/secrets.cfg.example txData/secrets.cfg
start-server.bat              # baza + generator pojazdów + FXServer
```

`start-server.bat` (dawniej `start_8158_default.bat`) robi po kolei:

1. `docker compose up -d --wait` — bez bazy FXServer nie wczyta graczy, więc
   skrypt przerywa, jeśli kontener nie wstanie,
2. `txData/resources/[addon]/generate_vehicle_resources.py` — przepisuje listę
   aut do `vehicles.cfg`, `vMenu/config/addons.json` i sekcji
   AUTO-GENERATED w `qb-core/shared/vehicles.lua`,
3. `artifact/FXServer.exe +set serverProfile default`.

W `txData/secrets.cfg` uzupełnij `sv_licenseKey`
(https://keymaster.fxserver.com) i `mysql_connection_string`. Plik jest
w `.gitignore` i nigdy nie trafia do repo.

---

## Struktura

```
start-server.bat        start serwera (baza -> generator -> FXServer)
docker-compose.yml      MariaDB 10.6 na porcie 3307
docs/                   dokumentacja i audyty
tools/                  skrypty do pojazdów (handling, tekstury, lint Lua)
patches/                lokalne poprawki do zasobów-podmodułów
txData/server.cfg       główna konfiguracja + lista zasobów
txData/projectterrific.cfg  konfiguracja stacku QBCore
txData/resources/       zasoby serwera ([addon] = pojazdy, [qb], [jobs], ...)
artifact/               FXServer (poza gitem)
backups/                kopie robione przez narzędzia (poza gitem)
```

Stack jest **QBCore** (`projectterrific.cfg`). ESX i `lachee-garage`
z `docs/PLAN.md` są wyłączone.

---

## Narzędzia (`tools/`, Python 3 + numpy)

| skrypt | do czego |
|---|---|
| `ytd_inspect.py` | co siedzi w `.ytd`: wymiary, format, mipmapy, MiB |
| `ytd_optimize.py` | downscale / kompresja DXT / mipmapy w `.ytd`, własny parser RSC7 — zweryfikowany w grze (tenf: 128 → 96 MiB) |
| `handling_audit.py` | tabela handlingu wszystkich aut vs zakresy vanilla → `handling_report.json` |
| `handling_fix.py` | normalizacja `handling.meta`: `clamp` (przycina wartości do zakresu klasy) albo `template` (szablon klasy) |
| `handling_tune.py` | realne dane auta (masa/KM/vmax/napęd/biegi) → handling wg wzorów; jedna komenda, idempotentna |
| `handling_match.py` | dopasowanie auta do wzorca z bazy 800 handlingów Rockstara (`tools/vanilla/merged-handling.meta`) |
| `script_lint.py` | szuka skryptów Lua, które w runtime nadpisują fizykę pojazdów (raportuje, nie edytuje) |
| `test_handling_fix.py` | test regresji: szablon klasy nie może ruszać sprężyn/tłumienia autora |

Typowe wywołania:

```bash
python tools/ytd_inspect.py  "txData/resources/[addon]"
python tools/ytd_optimize.py "txData/resources/[addon]"            # dry run
python tools/ytd_optimize.py "txData/resources/[addon]" --apply    # backup w backups/ytd-<data>/
python tools/handling_audit.py
python tools/handling_fix.py "txData/resources/[addon]" --mode template --only tenf
python tools/handling_fix.py "txData/resources/[addon]" --apply    # backup w backups/handling-<data>/
python tools/handling_tune.py --apply
python tools/handling_match.py find --like m4c
python tools/script_lint.py --res qb-vehicles
python tools/test_handling_fix.py
```

Każdy skrypt domyślnie robi **dry run**; zapis dopiero z `--apply`, zawsze
z kopią w `backups/`. Po zmianie handlingu: `restart <zasób>`, `/dv` i spawn
od nowa. Po zmianie `.ytd`: `restart <zasób>` + ponowne połączenie gracza
(cache klienta). Szczegóły i stan prac: `tools/README.md`.

Skille Claude Code (`.claude/skills/`): `fivem-handling-generator` (dane
techniczne auta → gotowy `handling.meta`) i `fivem-resource-workflow` (praca
na zasobach bez restartu całego serwera).

---

## Dokumentacja (`docs/`)

| plik | zawartość |
|---|---|
| `docs/agent.md` | przewodnik po projekcie dla agentów/AI: ścieżki, technologie, czego nie ruszać |
| `docs/PLAN.md` | plan rozwoju serwera |
| `docs/AUDIT.md` | audyt całego serwera (2026-09-02): 40 znalezisk, zasoby, logi, kod |
| `docs/AUDIT_EKONOMIA.md` | ekonomia: sklepy, bank, bankomaty, źródła dochodu, balans |
| `docs/AUDIT_POJAZDY.md` | pojazdy: tekstury `.ytd` i handling vs wartości Rockstara |
| `docs/AUDIT_DZIALANIE.md` | audyt działania (2026-09-05): zapis stanu, bank, garaże, holowanie, menu |
| `docs/HANDLING.md` | research `handling.meta`: co robi każde pole, percentyle z 504 aut vanilla |

`patches/` trzyma starsze poprawki do zasobów z `txData/resources/[local]/`
z czasów, gdy były one podmodułami.

---

## Czego nie ma w repo

Modele i tekstury pojazdów (`.yft`, `.ydr`, `.ytd`, `.dds`, `.rpf`) — ponad
4 GB, przekraczają limity GitHuba. Poza gitem są też `txData/cache/`,
`artifact/`, `backups/`, `txData/secrets.cfg` i `txData/admins.json`
(hash hasła admina txAdmin).

Zasoby z `txData/resources/[local]/` (`jg-vehicleindicators`, `lachee-garage`,
`ts_esx-CarKeys`) były kiedyś podmodułami git – repo trzymało tylko wskaźnik na
cudze repozytorium, a lokalne poprawki nigdy nie opuszczały dysku. Teraz są
zwykłymi plikami tego repo i wersjonują się razem z resztą serwera.
