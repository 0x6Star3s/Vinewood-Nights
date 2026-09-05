# Audyt serwera FiveM (QBCore / ProjectTerrific) - 2026-09-02

Zakres: zasoby faktycznie startowane przez `txData/server.cfg` + `projectterrific.cfg` + `[addon]/vehicles.cfg` (233 zasoby, w tym 106 pojazdów).
Metoda: logi z 5 ostatnich sesji (runtime, twarde dowody), skrypt sprawdzający manifesty/zależności/eksporty,
oraz przegląd kodu (kod własny w całości, zasoby zewnętrzne wg wzorców: pętle, eventy sieciowe, SQL).
Nie uruchamiano serwera ani bazy. vMenu (binaria C#) nie był audytowany.

Legenda: [LOG] = potwierdzone w logach, [KOD] = zweryfikowane w kodzie.
Status napraw: [x] = zrobione, [~] = czesciowo (opis przy pozycji), brak = do zrobienia.

---

## 1. Błędy krytyczne (crash / nie działa)

1. [x] ZROBIONE 2026-09-02 - [LOG][KOD] **Renewed-Banking nie jest zainstalowany**, a 13 wywołań `exports['Renewed-Banking']:addAccountMoney` jest bez guardu:
   `[jobs]/qb-ambulancejob/server/main.lua:27,45,59,72,87`, `[jobs]/qb-policejob/server/main.lua:441,445,837`,
   `[qb]/qb-vehicleshop/server.lua:325,341,397,418`, `[qb]/qb-houses/server/main.lua:240`.
   Skutek: każdy respawn w szpitalu kończy się SCRIPT ERROR (log: `qb-ambulancejob/server/main.lua:72`), prowizje policji/salonu/nieruchomości nigdy nie trafiają na konta firm.
   Fix: zamienić `exports['Renewed-Banking']:addAccountMoney(` na `exports['qb-management']:AddMoney(` (eksport przez `server_exports` w `qb-management/fxmanifest.lua:22`, tak robi już `qb-phone/server/main.lua:316`).

2. [~] CZESCIOWO 2026-09-02 (przeniesiony do [standalone] + manifest bez builderow; brak `dist/` - trzeba wypakowac oficjalny release) - [KOD] **screenshot-basic leży w `[disabled]`**, a używają go: `[core-important]/qb-phone/client/main.lua:1400` (aparat), `[standalone]/ps-mdt/client/cl_mugshot.lua:23` (mugshoty), `[standalone]/ps-camera/client/cl_main.lua:182`.
   Skutek: zdjęcie telefonem / mugshot = "No such export requestScreenshotUpload".
   Fix: przenieść `screenshot-basic` do `[standalone]` (startuje z `ensure [standalone]`).

3. [x] ZROBIONE 2026-09-02 (zaleznosc usunieta - zasob nigdzie nie uzywa MySQL) - [KOD] **qb-bodycam ładuje `@mysql-async/lib/MySQL.lua`** (`[qb]/qb-bodycam/fxmanifest.lua:49`), a na serwerze jest tylko oxmysql. Zasób startuje, ale `MySQL` w `server.lua` jest nil.
   Fix: zamienić na `'@oxmysql/lib/MySQL.lua'`.

4. [x] ZROBIONE 2026-09-02 (+ guardy w /cash, /bank i walidacja `amount`) - [LOG][KOD] **qb-hud crashuje na graczu, który się jeszcze nie załadował** - `[hud]/qb-hud/server.lua:23-27`: `Player.PlayerData.job` odczytywane PRZED `if not Player`. 13 SCRIPT ERROR w logach.
   Fix: przenieść `if not Player ... then return end` nad linię 24.

5. [x] ZROBIONE 2026-09-02 (petla usunieta, lista budowana na zadanie + permission check na GetPlayersForBlips) - [LOG][KOD] **Pętla listy graczy w qb-adminmenu umiera po pierwszym błędzie** - `[adminmenu]/qb-adminmenu/server/server.lua:526-548`: `while true` co 1.5 s, `ped.PlayerData.charinfo` bez sprawdzenia nil (gracz w trakcie łączenia). Błąd zabija wątek, lista graczy w adminmenu przestaje się odświeżać do restartu zasobu.
   Fix: `if ped then` + budować listę dopiero na żądanie (callback), nie w pętli.

6. [x] ZROBIONE 2026-09-02 (docker compose up -d --wait + przerwanie startu gdy baza nie wstanie) - [LOG][KOD] **Baza startuje po serwerze**: log `connect ECONNREFUSED 127.0.0.1:3307`, `Connection to database timed out` x3, hitch 901 ms. Kontener `local4word6-projectterrific-db` (docker-compose, port 3307) nie był uruchomiony przy starcie FXServer; gracze nie mogą się załadować.
   Fix: w `start_8158_default.bat` przed FXServer: `docker compose up -d --wait`.

7. [x] ZROBIONE 2026-09-02 (cdn-fuel -> qb-target, qb-drugs przepisany, qb-platescan Config.OxTarget=false; ox_target nie startuje) - [LOG][KOD] **Dwa systemy targetu naraz**: `[standalone]/cdn-fuel/fxmanifest.lua:40-50` deklaruje `dependency 'ox_target'`, więc FXServer auto-startuje ox_target (log: "Started resource ox_target"), a cały stack używa qb-target (`setr UseTarget true`). Oba na LEFT ALT (`qb-target/init.lua:57`, `ox_target/client/main.lua:303`). `[qb]/qb-drugs/client/cornerselling.lua:55-268` też ma na sztywno `exports.ox_target`.
   Skutek: podwójne "oko", podwójny raycast, konflikt klawisza.
   Fix: cdn-fuel `shared/config.lua:60` -> `"qb-target"` i usunąć zależność ox_target; w qb-drugs 7 linii przepisać na `exports['qb-target']:AddTargetEntity`, albo świadomie zostać przy ox_target i zmienić klawisz jednego z nich.

8. [x] ZROBIONE 2026-09-02 (martwe data_file usuniete) - [KOD] **cdn-fuel deklaruje pliki, których nie ma**: `fxmanifest.lua:52-53` `data_file 'DLC_ITYP_REQUEST' 'stream/[electric_nozzle]/...ytyp'` - folder `stream/` w ogóle nie istnieje. Ładowarki elektryczne nie mają modeli.

9. [x] ZROBIONE 2026-09-02 (poprawiony handler playerJoining zamiast aktualizacji ox_lib) - [LOG][KOD] **ox_lib 3.6.0 ma bug playerJoining** - `[oxlib]/ox_lib/imports/addCommand/server.lua:21` używa `oldId` jako `source` (log: "TRIGGER_CLIENT_EVENT_INTERNAL: client 1 is not the same as the target 65536"). Podpowiedzi komend nie docierają do dołączających. ox_target 1.9.2 też stary.
   Fix: aktualizacja ox_lib (naprawione w nowszych wersjach).

10. [x] ZROBIONE 2026-09-02 - [KOD] **qb-core Kick() bez Wait** - `[core-important]/qb-core/server/functions.lua:415`: `while true` bez `Wait`, gdy `source` jest nil -> zawieszenie serwera. Fix: `if not source then return end`.

11. [x] ZROBIONE 2026-09-02 - [KOD] **qb-inventory woła nieistniejący `exports["qb-methlab"]`** (`server/main.lua:2204`) przy tworzeniu itemu `labkey`. Fix: guard `GetResourceState`.

## 2. Kod własny / generator pojazdów ([addon], wk_delveh, jg-vehicleindicators)

12. [x] ZROBIONE 2026-09-02 (vMenu addons.json = nazwy modeli z vehicles.meta, walidacja tez) - [KOD] **`generate_vehicle_resources.py:277-280` wpisuje do vMenu `addons.json` nazwy FOLDERÓW zamiast nazw modeli.** 25 wpisów to nie modele (`amr_car`, `hycadem8`, `mustangNFS`, `polaventador`, `exploler`, `dodgepol`, `22g63`, `s63b`, `r8sol`, ...), 12 prawdziwych modeli brakuje (`AMR_TAHOE`, `AMR_EXPLORER`, `m850`, `mst`, `polaventa`, `police2`, `19ranger2`, `explorer16`, `W463A`, `g5502019`, `G632019`, `G634X4`). vMenu nie widzi tych aut. `validate_generation` (:363) sprawdza tę samą złą listę, więc raportuje OK.
    Fix: budować listę z `<modelName>` z vehicles.meta.

13. [x] ZROBIONE 2026-09-02 (clean_xml + ostrzezenia; r8sol/aventadors/22g632/s63b sa juz w vehicles.lua) - [KOD] **`generate_vehicle_resources.py:116-118`: błąd parsowania XML -> `return []` po cichu.** RAGE toleruje komentarze `<!------->` i NUL-e na końcu pliku, expat nie. Wypadają: `[audi]/r8sol`, `[lamborghini]/aventadors`, `[mercedes]/22g63`, `[mercedes]/s63b` - nie ma ich w `qb-core/shared/vehicles.lua`, więc salon/garaż ich nie zna.
    Fix: `re.sub(r"<!--.*?-->", "", t, flags=re.S).rstrip("\0")` przed parsowaniem + warning zamiast pustej listy.

14. [x] ZROBIONE 2026-09-02 (porownanie lowercase, wygenerowany 2021M5 zniknal) - [KOD] **Duplikat klucza w `qb-core/shared/vehicles.lua`**: stockowy `'2021m5'` (:66) i wygenerowany `'2021M5'` (:744), różne ceny (180000 vs 90000). Generator porównuje case-sensitive (:299, :323). Fix: porównanie lowercase, usunąć :744. (Stock ma też duplikaty `caddy3`, `dinghy4`.)

15. [x] ZROBIONE 2026-09-02 (generator ostrzega o braku stream/.yft; 4 puste zasoby wypadly z vehicles.cfg: RS, auta, auta2, pd) - [KOD] **15 ensurowanych zasobów pojazdów ma PUSTY `stream/`** (`amr_car, RS, rs6+, rs615, m422, m4f82, zl12017, dodgepd, dodgepol, ems_19ranger2, exploler, polaventador, pd, auta, auta2`), 2 nie mają go wcale (`audi7rs`, `hycadem8`), 10 nie ma `vehicles.meta`, `488` nie ma żadnych meta. `[mercedes]/gt63s` i `W463AS` deklarują po 5 modeli-widm bez `.yft`. Auta są w salonie, ale nie spawnują.
    Fix: walidacja w generatorze (niepusty stream + `.yft` per modelName), usunąć puste foldery z `vehicles.cfg`.

16. [~] DO DECYZJI - generator zglasza to teraz jako ostrzezenia (dodgepol/police2, yacht4/jester2...), ale to Twoja zawartosc - nie usuwam plikow bez zgody. - [KOD] **Nadpisywanie stockowych aut**: `[dodge]/dodgepol/data/vehicles.meta` definiuje `police2`, `[misc]/yacht4` redefiniuje `jester2/massacro2/ratloader2/slamvan` jako addon. Zmienia handling stockowych aut na całym serwerze.

17. [x] ZROBIONE 2026-09-02 (walidacja netId/value + tylko kierowca; guard tez po stronie klienta) - [KOD] **jg-vehicleindicators `server.lua:1-3`**: event `set-state` bez walidacji `netId`/`value` i bez sprawdzenia, czy nadawca jest kierowcą. Dowolny klient wysyła nie-tabelę -> `client.lua:29` `ipairs(data)` wywala błąd u WSZYSTKICH klientów; można też migać cudzymi kierunkowskazami.
    Fix: `if type(value) ~= 'table' then return end` + `GetPedInVehicleSeat(veh, -1) == GetPlayerPed(source)`.

18. [x] ZROBIONE 2026-09-02 (NetworkRequestControlOfEntity, PlayerPedId, capsule 1.5 m) - [KOD] **wk_delveh `client.lua:44-52`**: `DeleteVehicle` bez `NetworkRequestControlOfEntity` - pod OneSync nie usunie auta należącego do innego klienta, 5 bezsensownych retry. Drobne: `:15` `GetPlayerPed(-1)` -> `PlayerPedId()`, `:76` capsule 5 m może złapać auto obok.

19. [x] ZROBIONE 2026-09-02 (folder bez pojazdow nie jest przenoszony, manifest regenerowany, CONTENT_UNLOCKING_META_FILE, kotwica po `local Vehicles = {`) - [KOD] Generator, drobne: `:140-157` przenosi każdy folder bez nawiasów w `[addon]` (np. `docs` -> `[docs]`), przerwany merge zostawia pół-przeniesiony folder; `:172-193` manifest pisany tylko raz (dodanie handling.meta później nie aktualizuje `__resource.lua`), brak `CONTENT_UNLOCKING_META_FILE`; `:334-339` `rfind("\n}")` zakłada, że ostatnia klamra zamyka `Vehicles`.

## 3. Exploity - serwer ufa danym od klienta [KOD]

**STATUS 2026-09-02: [x] przerobione** - qb-inventory (guardy amount>0, crafting z Config, stash/trunk/otherplayer), qb-dumpsters,
qb-prison, qb-smallresources (eventy z gotowka usuniete), qb-vehiclesales, qb-pawnshop, cdn-fuel, qb-drugs, qb-hotdogjob,
qb-truckerjob, qb-taxijob, qb-towjob, qb-phone (transfer + SQL), qb-atms, qb-vehicleshop, qb-policejob, ps-mdt, qb-houses,
qb-vehiclekeys, qb-community-service, qb-streetraces, futte-newspaper, faucety (traphouse/vineyard/truckrobbery/lotto/recyclejob/diving),
SQL injection w qb-management. qb-garages mial juz poprawna walidacje wlasnosci (audyt nieaktualny w tym punkcie).

Na lokalnym serwerze testowym z zaufanymi graczami to nie jest pilne, ale to są realne błędy logiki (każdy z nich = nieskończone pieniądze/itemy z konsoli F8 lub zmodyfikowanego klienta).

- **qb-inventory** (root cause wielu): `server/main.lua:221,1447` brak `amount > 0` w `AddItem/RemoveItem` -> ujemna ilość = duplikacja. `:1090,1106` craft: koszty z klienta, wynik `RemoveItem` ignorowany. `:2045` `SaveStashItems` zapisuje tabelę itemów od klienta. `:1058` `addTrunkItems` nadpisuje bagażnik. `:1304,1636` otwieranie ekwipunku dowolnego gracza po ID bez dystansu/kajdanek.
  Fix jednym guardem: `if not amount or amount <= 0 then return false end` na początku `AddItem` i `RemoveItem`; usunąć 3 eventy zapisu z klienta.
- **qb-dumpsters** `server/main.lua:34`: `givemoney(money)` kwota z klienta.
- **qb-prison** `server/main.lua:71,86`: crafting dowolnego itemu w dowolnej ilości, bez sprawdzenia więzienia.
- **qb-smallresources** `server/sv_meleeDamage.lua:9,18`: eventy `rodinium-weapons:processGiveCashAmount` / `cash:roll` dają/zabierają gotówkę dowolnemu graczowi. Nic ich nie używa - usunąć.
- **qb-vehiclesales** `server/main.lua:68`: `sellVehicleBack` wypłaca połowę ceny modelu z klienta i kasuje dowolną tablicę bez sprawdzenia właściciela.
- **qb-pawnshop** `server/main.lua:19,61`: cena i nagrody z klienta.
- **cdn-fuel** `server/fuel_sv.lua:12,74`, `station_sv.lua:80`: zwrot kwoty z klienta, saldo stacji z klienta, `amount < 1` = darmowe paliwo.
- **qb-drugs** `server/cornerselling.lua:25,34`, `deliveries.lua:14,30`: cena/ilość z klienta, `AddMoney` mimo nieudanego `RemoveItem`.
- **qb-hotdogjob** `:32`, **qb-truckerjob** `:30`, **qb-taxijob** `:14`, **qb-towjob** `:53`: wypłata liczona z argumentów klienta.
- **qb-phone** `server/main.lua:835`: `TransferMoney` bez sprawdzenia salda nadawcy (bank idzie w minus). Callback `:542` ma poprawną wersję - użyć jej.
- **qb-atms** `server/main.lua:64`: wypłata z konta dowolnego `cid` z klienta; gałąź offline `json.decode` na tabeli = błąd.
- **qb-vehicleshop** `server.lua:136,163`: raty/spłata - saldo i tablica z klienta.
- **qb-policejob** `server/main.lua:909,924,965`: Rob/Seize/Search bez sprawdzenia joba i kajdanek (tylko 2.5 m); `:824` mandat dowolnej wysokości.
- **ps-mdt** `server/main.lua:1764`: `removeMoney` bez sprawdzenia joba - każdy może ukarać każdego.
- **qb-houses** `server/main.lua:166,248,252,257,432`: klucze/odblokowanie/kasowanie domów bez sprawdzenia właściciela.
- **qb-vehiclekeys** `server/main.lua:34,45`: klucze do dowolnej tablicy, odblokowanie dowolnego auta po netId.
- **qb-garages** `server/main.lua:35,44`: zapis `mods`/`state` cudzego auta (zapytanie tylko po tablicy).
- **qb-community-service** `:15`, **qb-streetraces** `:19`, **futte-newspaper** `:48` (`AddItem(type)` = dowolny item za cenę gazety).
- Faucety bez cooldownu: qb-traphouse `:188`, qb-vineyard `:3,58,65`, qb-truckrobbery `:52`, qb-lotto `:12`, qb-recyclejob `:5`, qb-diving `:67`, qb-mechanicjob `:220`.
- **SQL injection**: `qb-management/server/sv_boss.lua:111`, `sv_gang.lua:97` (konkatenacja w `LIKE`), `qb-phone/server/main.lua:383` (`escape_sqli` nie escapuje backslasha). Fix: parametry `?`.

## 4. Wydajność

### Serwer
20. [ ] DO SPRAWDZENIA PRZY WLACZONEJ BAZIE - [LOG] **Hitch 300-900 ms co ~5 min** (20 w ostatniej sesji, 64 w sesji 18.05). 15 z 20 występuje bezpośrednio po `PLAYER SAVED` (autosave co `UpdateInterval`=5 min z `qb-core/client/loops.lua`). `QBCore.Player.Save` robi `json.encode` całego `metadata`/`inventory` + INSERT, `SaveInventory` drugi UPDATE. Przy 1 graczu 500 ms sugeruje bardzo duży JSON w kolumnie `metadata` lub `inventory` (nie zmierzono - baza była wyłączona).
    Do sprawdzenia: `SELECT citizenid, LENGTH(metadata), LENGTH(inventory) FROM players;` - jeśli setki KB, wyczyścić metadata (np. logi telefonu/mdt trzymane w metadata).
21. [x] ZROBIONE 2026-09-02 (indeks + PK w init SQL oraz docker/mariadb/migrations/2026-09-02-audyt.sql na istniejaca baze) - [LOG] **`phone_gallery` bez indeksu i bez klucza głównego** (`qb-phone/qb-phone.sql:83-87`), log: "qb-phone took 361 ms" na `SELECT * FROM phone_gallery WHERE citizenid = ?`. Fix: `ALTER TABLE phone_gallery ADD INDEX idx_cid (citizenid);`. (Jeśli tabela jest mała, 361 ms to latencja Docker Desktop, nie indeks.)
22. [x] ZROBIONE 2026-09-02 (Wait(1000)) - [KOD] **qb-weathersync `server/server.lua:267`**: `while true do Wait(0)` na serwerze tylko po to, by wykryć zmianę minuty. Fix: `Wait(1000)`.
23. [x] ZROBIONE 2026-09-02 (faktury: jedno IN (...), zdjecia kontaktow: jedno OR-owe zapytanie) - [KOD] **qb-phone `server/main.lua:212,339,404`**: N+1 zapytań `SELECT * FROM players` per faktura/czat/wynik przy otwarciu telefonu. Fix: jedno `WHERE citizenid IN (?)`.
24. [x] ZROBIONE 2026-09-02 (jednorazowe ladowanie) - [KOD] **qb-houses `server/main.lua:39`**: `while true ... Wait(7)` kręcąca się w nieskończoność po jednorazowym ładowaniu. Fix: wykonać raz.
25. [x] ZROBIONE 2026-09-02 (petla adminmenu usunieta; UpdateBlips to juz pusty stub) - [KOD] qb-adminmenu pętla 1.5 s po wszystkich graczach (pkt 5), qb-policejob `UpdateBlips` co 5 s z `TriggerClientEvent(-1)` - drobne przy małej liczbie graczy.

### Klient - assety (największy problem)
26. [ ] NIE DO ZROBIENIA Z POZIOMU KODU - przeskalowanie tekstur w OpenIV - [LOG] **232 przeciążone assety pojazdów**, `[addon]` = 3.8 GB. Tekstury `.ytd` zajmują do **224 MiB pamięci fizycznej każda** (s500w223 224, agerars 196, 21s580m 196, sccjkl 192, 21bentayga 184, r33 178, 16charger 176, pista 174, lp750sv 172, W463AS 172 ...), 174 razy komunikat "Oversized assets can and WILL lead to streaming issues (models not loading/rendering)". `as_zr350` ma 13 liveries po 32 MiB. To powoduje niewidoczne auta, długie ładowanie i crashe klienta przy kilku takich autach w pobliżu.
    Fix: przeskalować tekstury do 2K/1K (np. OpenIV / texture toolkit), usunąć liveries, albo wyrzucić najcięższe auta. Cel: `.ytd` < 16 MiB, `.yft` < 16 MiB.
27. [ ] ZOSTAWIONE - grupowanie 106 zasobow per marka to przebudowa calego [addon] - [KOD] **106 osobnych zasobów pojazdów** (jeden per auto) + 15 pustych. Każdy zasób to osobny start, osobny wpis w liście klienta i wydłużone dołączanie. Fix: jeden zasób per marka (generator już grupuje po markach).

### Klient - pętle per klatka (Wait(0)/Wait(1)) [KOD]
Od najdroższych:
28. [x] ZROBIONE (Wait(500)) - **qb-drugs `client/cornerselling.lua:296`** - `GetGamePool('CPed')` + dystans do KAŻDEGO peda co klatkę podczas sprzedaży. Fix: `Wait(500)`.
29. [x] ZROBIONE (event raz na aktywacje, 250 ms w spoczynku, glowna petla 100 ms) - **qb-tunerchip `client/nos.lua:146`** - `Wait(0)` zawsze; przy aktywnym nitro `TriggerServerEvent('nitrous:server:SyncFlames')` CO KLATKĘ (event sieciowy 60x/s). Fix: wysłać raz przy aktywacji, `Wait(250)` w spoczynku.
30. [x] ZROBIONE (flaga hotdogLoopRunning + petla konczy sie ze stoiskiem) - **qb-hotdogjob `client/main.lua:361-369`** - `while true do Wait(0)` bez `break`, tworzona na nowo przy każdym podniesieniu stoiska (`:476`) = wyciek wątków rosnący przez sesję. `:315,373` `GetClosestObjectOfType` co `Wait(3)`.
31. [x] ZROBIONE (Wait 500 poza autem) - **qb-vehiclefailure `client.lua:388`** - `Wait(0)` zawsze, `SetVehicleHandlingFloat` + `SetVehicleEngineTorqueMultiplier` co klatkę w aucie, natywy na nieaktualnym `vehicle` poza autem.
32. [x] ZROBIONE (kopia z electric_cl usunieta, druga petla gated) - **cdn-fuel `client/fuel_cl.lua:2689` i duplikat `client/electric_cl.lua:752`** - dwie pętle `Wait(0)`, ~10 natywów/klatkę każda; `fuel_cl.lua:146` `Wait(10)` zawsze. Fix: usunąć kopię electric, `Wait(250)` gdy nie w aucie.
33. [x] ZROBIONE (camera.lua przepisany, duplikaty usuniete, nil `ped` znikl) - **qb-smallresources `client/camera.lua:10,68`, `client/ignore.lua:73`** - trzy pętle robiące to samo (`IsPedArmed` + `DisableControlAction 140-142`); `camera.lua:47` używa niezdefiniowanego `ped` (nil). Fix: zostawić tylko ignore.lua.
34. [~] CZESCIOWO (Ragdoll uspiony; Emote/Keybinds nadal odpytuja klawisze co klatke) - **dpemotes** - 5 wątków per klatka (`Client/Emote.lua:22`, `EmoteMenu.lua:66,315`, `Keybinds.lua:21`, `Ragdoll.lua:13`). Fix: `RegisterKeyMapping`, `ProcessMenus` tylko przy otwartym menu.
35. [x] ZROBIONE (30 s) - **qb-smallresources `client/cleanup.lua:378`** - `GetGamePool('CObject')` co 10 s z `pcall` na każdy obiekt. Fix: 30 s, bez pcall.
36. [x] ZROBIONE (HUD 250 ms, kompas 50/100 ms, idle 250 ms, bron 100 ms) - **qb-hud `client.lua:679`** (500 ms domyślnie, 50 ms gdy gracz odznaczy "FPS mode"), `:1088` kompas 50 ms, `:1024` `Wait(0)` idle, `:927` `Wait(0)` z bronią. Fix: 250 ms na sztywno, kompas 100 ms.
37. [x] ZROBIONE (obie petle gated) - **qb-weapons `client/main.lua:138,158`** - `Wait(1)` zawsze + `Wait(0)` z bronią. Fix: jedna pętla gated na `IsPedArmed`.
38. [x] ZROBIONE (evidence/objects/heli/interactions gated) - **qb-policejob** `client/evidence.lua:217,236`, `interactions.lua:550` (Wait 1), `objects.lua:238` (6x `GetClosestObjectOfType` co 3 ms gdy jest kolczatka), `heli.lua:50` (Wait 0). Fix: gate na job/duty + `Wait(500)`.
39. [~] W WIEKSZOSCI ZROBIONE (remCombatStance, traphouse, tunerchip, streetraces, pma-voice, backitems, diving) - Mniejsze: qb-smallresources `crouchprone.lua:36` (Wait 0 na piechotę, 8 natywów), `remCombatStance.lua:2,12` (dwie identyczne pętle), qb-traphouse `:486` (Wait 3), qb-tunerchip `nos.lua:51` (`GetVehicleNumberPlateText` co 3 ms), qb-lapraces `:720,748`, qb-streetraces `:24`, pma-voice `misc.lua:5` (Wait 0, `IsPedSwimmingUnderWater` x2), qb-weathersync `client.lua:47,86`, qb-backitems `:43`, qb-diving `:413`.
40. [x] ZROBIONE (petla bez Wait zamieniona na jednorazowe sprawdzenie) - **qb-vehiclekeys `client/main.lua:370`** - `while vehicle == 0 do` bez `Wait` (działa tylko dlatego, że `GetClosestVehicle` zwraca -1). Dodać guard.

## 5. Drobne / kosmetyka

**STATUS 2026-09-02:** usuniete puste stub-foldery ([system]/[builders], [gamemodes]/[maps], [gameplay]/[examples]),
qb-scenes ma sciezki bez wiodacego `/`, martwe wpisy `files` w qb-inventory i qb-lapraces usuniete.
qb-weedplanting MA `version '1.6'` w manifescie - ostrzezenie idzie z serwera wersji, nie z braku pola.
Webhooki (MugShotWebhook, ClockinWebhook) musisz wkleic sam - to Twoje adresy Discorda.

- 9 ostrzeżeń przy każdym starcie "does not have a resource manifest": stub-foldery `[system]/[builders]/{yarn,webpack}`, `[gamemodes]/[maps]/*`, `[gameplay]/[examples]/*` - do skasowania (chat jest prebudowany, builderów nie używa).
- `qb-weedplanting`: "Unable to determine current resource version" - brak `version` w manifeście.
- Brakujące webhooki: `MugShotBase64` `Config.MugShotWebhook`, `Config.ClockinWebhook` (zdjęcia do dowodu / clock-in nie działają bez nich).
- `qb-scenes/fxmanifest.lua`: ścieżki z wiodącym `/` - działa, ale niestandardowe.
- `qb-inventory` `files 'html/images/*.jpg'`, `'html/*.ttf'` i `qb-lapraces` `'html/img/*'` wskazują na nieistniejące pliki.
- `qb-core/client/loops.lua:3`: `Wait(0)` przed zalogowaniem (tylko sprawdzenie flagi) - pomijalne.
- `chat` w `[gameplay]` dubluje zasób systemowy z artifactu - to normalne (cfx-server-data).

## 6. Sprawdzone i OK

- Wszystkie `ensure` wskazują na istniejące zasoby; brak duplikatów nazw zasobów.
- 106 manifestów pojazdów: każdy `data_file` i `files` istnieje, zero duplikatów nazw `.yft/.ytd/.ydr` między zasobami, `handlingId` <-> `handlingName` spójne (poza widmami gt63s/W463AS).
- Blok auto-generowany w `qb-core/shared/vehicles.lua`: składnia OK, idempotentny.
- qb-core `AddMoney/RemoveMoney/SetMoney` odrzucają ujemne; qb-banking, qb-crypto, qb-management (depozyt/wypłata), sklepy qb-inventory, salon (cena z `QBShared.Vehicles`), qb-adminmenu (wszystkie eventy z uprawnieniami) - poprawnie walidowane.
- PolyZone (debug wyłączony, 500 ms), qb-target (raycast tylko przy aktywnym), ps-dispatch (1 s), bob74_ipl (jednorazowo), ox_doorlock, qb-garages, qb-houses (klient), illenium-appearance - pętle gated/sleep-based.
- connectqueue sam wyłącza hardcap (`Config.DisableHardCap = true`) - brak konfliktu.
- Żaden startowany zasób nie wymaga ox_inventory/ps-inventory/es_extended bez guardu.
