# Vinewood Nights

Serwer FiveM (FXServer) oparty o QBCore, uruchamiany lokalnie przez txAdmin.
Baza danych MariaDB startuje z `docker-compose.yml`.

## Uruchomienie

1. Baza danych:

   ```
   docker compose up -d
   ```

   Kontener `local4word6-projectterrific-db` nasłuchuje na porcie 3307 i musi
   działać zanim wystartuje FXServer.

2. Sekrety:

   ```
   cp txData/secrets.cfg.example txData/secrets.cfg
   ```

   Uzupełnij `sv_licenseKey` (klucz z https://keymaster.fxserver.com) oraz
   `mysql_connection_string`. Plik jest w `.gitignore` i nigdy nie trafia do repo.

3. Serwer: `start_8158_default.bat`

## Czego nie ma w repo

Zasoby graficzne pojazdów (`.yft`, `.ydr`, `.ytd`, `.dds`, `.rpf`) są wyłączone
z gita, bo ważą ponad 4 GB i przekraczają limity GitHuba. Trzymaj je lokalnie
albo w osobnym magazynie. Wyłączone są też `txData/cache/`, `artifact/`,
`backups/` oraz `txData/admins.json` z hashem hasła administratora txAdmin.

## Dokumentacja

- `PLAN.md` — plan rozwoju serwera
- `AUDIT.md`, `AUDIT_EKONOMIA.md`, `AUDIT_POJAZDY.md` — audyty serwera
- `HANDLING.md` — fizyka pojazdów
- `tools/` — skrypty pomocnicze
