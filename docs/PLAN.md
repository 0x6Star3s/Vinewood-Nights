# Server Plan

Ten plik zbiera pomysly i kolejne kroki rozwoju lokalnego serwera FiveM.

## 1. System kluczykow do aut

Status: resource `ts_esx-CarKeys` jest pobrany do `txData/resources/[local]/ts_esx-CarKeys`, ale nie jest jeszcze wlaczony w `server.cfg`.
Powod: brakuje ESX, bazy danych i `oxmysql`.

Zeby go uruchomic, trzeba dodac:

- MySQL albo MariaDB.
- `oxmysql` jako polaczenie FiveM z baza danych.
- `es_extended` jako framework ESX.
- Tabele ESX, szczegolnie `owned_vehicles`.
- `mysql_connection_string` w `txData/server.cfg`.

Kolejnosc startu po instalacji zaleznosci:

```cfg
ensure oxmysql
ensure es_extended
ensure ts_esx-CarKeys
```

Jak to dziala:

- Gracz wciska domyslnie `I`.
- Skrypt szuka najblizszego auta.
- Serwer sprawdza tablice auta w tabeli `owned_vehicles`.
- Jesli auto nalezy do gracza, drzwi sa zamykane albo otwierane.

## 2. Skrypt bagażnika

Cel: dodac mozliwosc otwierania bagaznika auta i ewentualnie przechowywania przedmiotow.

Rozdzielamy to na dwa typy skryptow:

- `trunk inventory` - bagażnik jako schowek na itemy, np. `esx_trunk` albo system oparty o `ox_inventory`.
- `hide in trunk` - chowanie siebie albo innego gracza w bagażniku.

Kandydat do chowania graczy:

- `Carry and Hide In Trunk`: [Cfx.re forum release](https://forum.cfx.re/t/standalone-carry-and-hide-in-trunk/5197423)
- Funkcje: noszenie graczy, chowanie siebie w bagażniku, chowanie innego gracza w bagażniku.
- Typ: standalone / ESX / QB-Core.
- Wymagania: `ox_target` albo `qb-target`.
- Dla tego serwera lepszy kierunek to `ox_target`, bo nie wymaga przechodzenia na QB-Core.
- Status: nie zainstalowany, bo trzeba najpierw miec paczke resource'a od autora/Tebex.

Do ustalenia:

- Czy bagażnik ma byc tylko animacja/otwieranie klapy, czy prawdziwy inventory/storage.
- Czy serwer ma isc w ESX, bo wtedy bagażnik najlepiej spiac z ESX inventory.
- Czy bagażnik ma dzialac tylko dla wlasciciela auta, czyli razem z systemem kluczykow.
- Czy chowanie gracza w bagażniku ma byc dostepne dla wszystkich, tylko dla wlasciciela auta, czy np. tylko gdy auto jest otwarte.

Proponowana kolejnosc:

1. Najpierw uruchomic baze danych, `oxmysql` i ESX.
2. Wlaczyc i przetestowac `ts_esx-CarKeys`.
3. Dodac `ox_target`, jesli wybieramy `Carry and Hide In Trunk`.
4. Dodac skrypt `hide in trunk` do chowania graczy.
5. Wybrac osobny skrypt `trunk inventory`, jesli bagażnik ma przechowywac itemy.
6. Spiac dostep do bagażnika z wlascicielem pojazdu albo kluczykami.
7. Przetestowac auta addon z obecnej listy `vMenu/config/addons.json`.

## 3. Obecne znane ograniczenia

- Aktualnie serwer jest bardziej vMenu/free-roam niz ESX/RP.
- Bez ESX skrypty typu kluczyki, garaz, bagaznik i inventory nie beda mialy gdzie zapisywac danych.
- Warningi o ciezkich assetach modeli aut zostaja do osobnej optymalizacji.

## 4. Garaze

Cel: dodac system garazy, zeby gracze mogli zapisywac i odbierac swoje pojazdy z wybranych miejsc na mapie.

Kandydat do testow:

- `lachee-garage`: [GitHub](https://github.com/Lachee/fivem-garage/blob/master/README.md)
- Typ: Simple ESX Garage.
- Funkcje: garaze w roznych lokalizacjach, przechowywanie pojazdow, odzyskiwanie pojazdu za oplata, opcjonalne holowanie/teleport auta z ulicy.
- Wymagania: ESX, baza danych, SQL z folderu `sql/`.
- Status: pobrany do `txData/resources/[local]/lachee-garage`, ale nie wlaczony.
- Uwaga techniczna: ten resource uzywa `mysql-async`, a nie `oxmysql`, wiec przed uruchomieniem trzeba wybrac `mysql-async` albo przerobic/wymienic garage na zgodny z `oxmysql`.
- Uwaga: jesli na serwerze bedzie stare `esx_garage`, trzeba je usunac albo wylaczyc, zeby nie dublowac systemu garazy.

Proponowana kolejnosc:

1. Najpierw uruchomic MySQL/MariaDB, `oxmysql` i `es_extended`.
2. Pobrac `lachee-garage` do `txData/resources/[local]`.
3. Uruchomic plik SQL z paczki garazu.
4. Dodac `ensure lachee-garage` po ESX w `server.cfg`.
5. Przetestowac zapis/odbior pojazdow oraz zgodnosc z systemem kluczykow.

## 5. Kierunkowskazy w samochodach

Cel: dodac kierunkowskazy dla pojazdow z wygodnymi bindami na klawiaturze.

Kandydat do testow:

- `jg-vehicleindicators`: [GitHub](https://github.com/jgscripts/jg-vehicleindicators)
- Typ: standalone, bez ESX/QB-Core.
- Funkcje: lewy kierunkowskaz, prawy kierunkowskaz, awaryjne.
- Synchronizacja: server synced przez state bags, inni gracze powinni widziec kierunkowskazy.
- Wymagania: OneSync Infinity.
- Domyslne bindy: `Left Arrow`, `Right Arrow`, `Up Arrow`.
- Bindy mozna zmienic w grze: `Escape -> Settings -> Key Bindings -> FiveM -> jg-vehicleindicators`.
- Status: zainstalowany w `txData/resources/[local]/jg-vehicleindicators` i wlaczony w `server.cfg`.

Założenie:

- Lewy kierunkowskaz pod `strzalka w lewo`.
- Prawy kierunkowskaz pod `strzalka w prawo`.
- Awaryjne pod osobny klawisz, np. `strzalka w dol` albo `H`.
- Alternatywne bindy pod zwykle klawisze, gdy strzalki beda kolidowaly z innymi funkcjami.

Do ustalenia:

- Czy kierunkowskazy maja dzialac standalone, bez ESX.
- Czy maja dzialac tylko dla kierowcy pojazdu.
- Czy stan kierunkowskazow ma byc widoczny dla innych graczy przez synchronizacje sieciowa.
- Czy uzyc gotowego resource'a typu `vehicle indicators` / `car indicators`, czy napisac prosty lokalny skrypt.

Proponowany minimalny resource:

- Client script rejestruje key mappingi przez `RegisterKeyMapping`.
- Lewy/prawy/awaryjne wlaczaja odpowiednie swiatla kierunkowskazow.
- Server event synchronizuje stan z innymi graczami, zeby kazdy widzial miganie.
