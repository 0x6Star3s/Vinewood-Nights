# Audyt działania serwera (zapis, bank, garaże, holowanie, menu) - 2026-09-05

Zakres: to, o co pytałeś - czy wszystko się zapisuje, czy bank robi to, co ma robić, czy garaż / holowanie / warsztat działają intuicyjnie i bez bugów, oraz czy menu jest spójne w całym serwerze.
Metoda: przegląd kodu ścieżek krytycznych (qb-core zapis, qb-banking, qb-atms, qb-garages, qb-towjob, qb-mechanicjob, terrific-customs, qb-menu, qb-vehiclekeys, qb-vehicleshop) + log FXServera z 4.09 (`txData/default/logs/fxserver.log`, dwie sesje). Serwera nie uruchamiałem.
Założenie: "menu mechanika", które ma być wszędzie, to menu w stylu GTA (ScaleformUI) z `terrific-customs` (warsztat tuningowy Benny's / LS Customs).

Poprzednie audyty (AUDIT.md, AUDIT_EKONOMIA.md) zostają aktualne; ten dokument ich nie powtarza, tylko dopisuje to, co znalazłem teraz.

---

## 0. Werdykt

**STATUS 2026-09-05 wieczór: cały plan z sekcji 8 wdrożony poza pkt 9 (screenshot-basic, potrzebna zgoda na pobranie paczek npm) i 15 (ustawienie Docker Desktop). Kopie sprzed zmian: `backups/fix-all-20260905/` i `backups/garage-scaleform-20260905/`. Nie testowane w grze - serwer był wyłączony.**

Serwer chodzi bez błędów skryptów (log 4.09: zero `SCRIPT ERROR` w dwóch sesjach). Ale:

1. **Baza padła w trakcie gry 4.09** (`connect ECONNREFUSED 127.0.0.1:3307` ok. 6,5 h po starcie, hitch 26 s) - w tym oknie zapisy graczy po cichu przepadały, bo qb-core nie sprawdza wyniku zapytań.
2. **Tuning kupiony w warsztacie nie zapisuje się** dopóki auto nie trafi do garażu - restart albo despawn przed zaparkowaniem = kasa pobrana, mody znikają.
3. **Garaż ma "fallback"**, który zapisuje Twoje auto jako zaparkowane, gdy wjedziesz cudzym / NPC autem - z modami tego cudzego auta.
4. **Bank: ujemna kwota w oszczędnościach = nieskończone pieniądze** (z konsoli F8). Historia oszczędności zawsze pusta, numer konta `nil`.
5. **Bankomat**: PIN i blokada karty sprawdzane tylko w przeglądarce (NUI), serwer wypłaca każdemu, kto ma kartę w kieszeni.
6. **Menu**: trzy systemy list (ScaleformUI, qb-menu w 27 zasobach, menuv), trzy rodzaje podpowiedzi "E", dwa języki naraz. Holowanie sterowane komendami `/tow` i `/npc` bez żadnej podpowiedzi.
7. **Zużycie części w qb-mechanicjob** nigdy nie jest zapisywane.
8. **Podgląd w garażu**: szybkie przewijanie listy stackuje auta na obrotnicy, a kamera skacze między autami i nie da się jej obrócić.

---

## 1. Co pokazał log z 4.09

| Zdarzenie | Dowód | Ocena |
|---|---|---|
| 2 starty: 07:56 i 14:37, 435 "Started resource", 0 `SCRIPT ERROR` | `fxserver.log` | OK |
| Autosave co 5 min + zapis przy każdej zmianie salda banku | `qb-core/config.lua:5`, `server/events.lua:21-27` | OK, "PLAYER SAVED" spam jest celowy |
| **Baza odmówiła połączenia w trakcie sesji** (qb-crypto `UPDATE crypto`, qb-scenes `DELETE FROM scenes`), potem hitch 26 140 ms i 11 718 ms | log linie 862-878 | **Kontener MariaDB zatrzymał się / zrestartował w trakcie gry** (Docker Desktop uśpiony?). `docker-compose.yml` ma `restart: unless-stopped` + healthcheck, więc wraca sam, ale FXServer tego nie ogłasza, a `QBCore.Player.Save` (`player.lua:506`) nie sprawdza wyniku INSERT - pieniądze/ekwipunek z tego okna przepadają bez śladu |
| screenshot-basic bez `dist/` | log 234-236 | AUDIT.md pkt 2 nadal otwarty: aparat w telefonie i mugshoty nie działają |
| `[addon]/__pycache__` traktowany jako zasób | log 8, 884 | cache generatora Pythona leży w folderze zasobów - usunąć / dodać do .gitignore |
| `ganjarims` 146 ostrzeżeń, felgi po 32-56 MiB | log 1462-1465 | to samo co AUDIT.md pkt 26, tylko dla felg |
| qb-adminmenu "Missing phrase sucess.entered_vehicle" | log | literówka w locale |
| Hitch 150-700 ms co kilkadziesiąt sekund, kilka 1-4 s | log 793-861 | AUDIT.md pkt 20 (do sprawdzenia rozmiar `metadata`/`inventory` w bazie) |

---

## 2. Co się zapisuje, a co nie

| Dane | Mechanizm | Status |
|---|---|---|
| Pieniądze, metadata, praca, pozycja | `players` - autosave 5 min, przy wyjściu, przy każdej zmianie banku | OK |
| Ekwipunek | `qb-inventory:SaveInventory` przy każdym zapisie gracza | OK |
| Auto: stan, garaż, paliwo, silnik, karoseria, mods | `player_vehicles` przy parkowaniu (`qb-garages/server/main.lua:210-278`) + `qb-vehicletuning:server:SaveVehicleProps` przy zakupie w salonie | OK, ale tylko gdy zaparkujesz |
| **Tuning z warsztatu (terrific-customs): wygląd, felgi, lakier, osiągi** | `commit()` (`client/main.lua:137`) to tylko migawka po stronie klienta; żaden event nie zapisuje mods do bazy | **LUKA** - restart serwera / despawn / auto trafia do depot przed zaparkowaniem = tuning znika, pieniądze pobrane. Depot spawnuje auto z mods sprzed tuningu |
| ECU / dystanse / ABS z warsztatu | `tunes.json` per tablica | OK (plik w zasobie) |
| Punkty warsztatów | `shops.json` | OK |
| Konfiguracja garaży z panelu admina | `garages_data.json`, rozsyłana przy `PlayerLoaded` (`adminpanel.lua:128`) | OK |
| **Zużycie części (chłodnica, sprzęgło, hamulce, oś, bak) z qb-mechanicjob** | tylko RAM serwera (`VehicleStatus`); event zapisu `vehiclemod:server:saveStatus` (`server/main.lua:177`) **nie jest nigdzie wywoływany** | **LUKA** - każdy restart = wszystkie części na 100%, naprawy mechanika bez sensu |
| Klucze do aut | RAM; po restarcie właściciel dostaje je z powrotem z `player_vehicles` (`qb-vehiclekeys:server:checkPlayerOwned`) | OK; klucze przekazane innym graczom znikają po restarcie (akceptowalne) |
| Wypisy bankowe, karty, oszczędności | `bank_statements`, `bank_cards`, `bank_accounts` | OK poza historią oszczędności (pkt 3.2) |
| Auta zostawione na zewnątrz przy restarcie | `Config.AutoRespawn = false` - wszystkie lądują w "Parking Odzyskiwania Pojazdów" za $0 | działa, ale gracz myśli, że auto zniknęło |
| Itemy startowe | `GiveStarterItems` w `qb-multicharacter/server/main.lua:5` nieużywane | **Zamierzone** - telefon kupuje się w sklepie (decyzja właściciela). Martwą funkcję można zostawić |

---

## 3. Bank i bankomaty

### Co działa
- Wpłata i wypłata w 8 bankach (qb-target, "Access Bank").
- Przelew po numerze konta - numer to `charinfo.account`, ten sam co w telefonie; działa dla graczy online i offline, blokuje przelew do siebie, sprawdza saldo (`qb-banking/server/main.lua:101-160`).
- Wypis 30 ostatnich operacji konta bieżącego.
- Karta debetowa (losowo Visa / Mastercard) z PIN-em, blokada / odblokowanie, zmiana PIN-u (tylko własnej karty).
- Konto oszczędnościowe: otwarcie, wpłata, wypłata.
- Przelewy i faktury z telefonu (osobna ścieżka, poprawnie walidowana).

### Co nie działa / dziury

1. **Oszczędności: ujemna kwota daje pieniądze z powietrza.** `qb-banking:savingsWithdraw` (`server/main.lua:344-350`) sprawdza tylko `tonumber(amount) <= currentSavings`, więc `-1000000` przechodzi. `savings.RemoveMoney(-x)` w `useraccounts.lua` robi `balance - (-x)` = **dodaje** x, a `AddMoney('bank', -x)` w qb-core jest odrzucane (`player.lua:319`). Efekt: saldo oszczędności rośnie o x, potem wypłata normalna na bank. NUI tego nie wysyła, ale event jest otwarty dla F8. To samo w `savingsDeposit` (`:329-335`) tylko w drugą stronę (strata). Bez konta oszczędnościowego oba eventy rzucają błąd (`savingsAccounts[cid]` = nil).
   Fix: ten sam guard co w `doQuickWithdraw` (`amount > 0`, całkowita, `savingsAccounts[cid]` istnieje).
2. **Historia oszczędności zawsze pusta**: zapis z `account = 'Saving'` (`useraccounts.lua:339,364`), odczyt `'Savings'` (`:296`).
3. **Numer konta oszczędnościowego = nil** (`useraccounts.lua:320` zwraca `self.account`, którego nikt nie ustawia) - w UI "undefined".
4. **Bankomat nie sprawdza PIN-u ani blokady na serwerze.** `qb-atms:server:doAccountWithdraw` (`server/main.lua:74`) wymaga tylko, żeby gracz miał w kieszeni kartę z danym `citizenid` (`HasCardFor`). PIN porównywany wyłącznie w NUI (`nui/qb-atms.js:138,209`). Karta zablokowana w banku dalej wypłaca. Ukradziona karta + F8 = wypłata cudzych pieniędzy bez PIN-u (do $5 000 / h).
5. **Bankomat bez karty nic nie robi**, a gracz nie dostaje żadnej informacji, że kartę trzeba zamówić w banku. Wpłaty w bankomacie nie ma (qb-atms tylko wypłaca; ATM-y qb-banking są wyłączone przez `UseTarget`).
6. `createBankCard` (`:227`) nie waliduje PIN-u (dowolny string) i nie ma guardu na brak gracza; `toggleCard` (`:278`) i `updatePin` (`:308`) nie sprawdzają typu - string zamiast liczby = błąd SQL. Drobne.
7. **Konta firmowe i gangowe w qb-banking to martwy kod** (`wrappers/business.lua`, `gangs.lua`): prawdziwe pieniądze firm siedzą w qb-management (`management_funds`), bank ich nie pokazuje, `bank_accounts_new` w bazie to resztka po Renewed-Banking. Zamknięcie banku w czasie napadu nadal nieobsłużone (AUDIT_EKONOMIA pkt 3).
8. **UI banku po angielsku** (`nui/index.html`; są `index_de/es/...`, nie ma `index_pl`), a `locales/pl.lua` nieużywany, bo `setr qb_locale "en"` w `server.cfg`.

### "Wszystko, co zaplanowane"
W `PLAN.md` nie ma sekcji o banku - nie mam listy wymagań, z którą mógłbym to porównać. Powyżej masz pełny stan faktyczny. Jeśli bank ma robić coś więcej (wpłata w bankomacie, konta firm w UI, pożyczki), dopisz to do PLAN.md jako wymaganie.

---

## 4. Garaże (qb-garages)

### Działa
Lista aut z podglądem 3D na obrotnicy, strzałki lewo / prawo, wyciąganie, parkowanie na E przy `putVehicle`, depot, klucze przy wyjeździe, zapis mods / paliwa / uszkodzeń, panel admina `/garageadmin`, konfiguracja garaży bez restartu.

### Bugi

1. **Fallback "jedno auto na zewnątrz" zapisuje nie to auto, którym wjechałeś** (`server/main.lua:265-276`). Gdy sprawdzenie własności nie przejdzie (cudze auto, NPC, wypożyczone), a gracz ma dokładnie jedno własne auto ze `state = 0`, serwer oznacza TO auto jako zaparkowane i nadpisuje jego `mods`, paliwo, silnik, karoserię danymi auta, którym wjechał. Cudze auto zostaje skasowane z mapy. Skutki: Twoje auto "teleportuje się" do garażu ze złymi modami, można też skopiować cudzy tuning na swoje auto. Usunąć fallback (walidacja tablic i tak działa przez `TRIM`).
2. [x] ZROBIONE 2026-09-05 (`or {}`) - `doCarDamage` (`client/main.lua:806-813`) robi `pairs(data.doorStatus)` bez guardu. Dla `mods = '{}'` (świeżo kupione auto, zanim klient dośle props; auto dane przez `/givecar`) = błąd skryptu w trakcie wyciągania: menu się nie zamyka, silnik nie odpala. Fix: `data.doorStatus or {}` x3.
3. [x] ZROBIONE 2026-09-05 (garaż ma teraz menu ScaleformUI jak warsztat, jeden krok, opisy po polsku; powiadomienia dalej z locale EN) - **Menu to qb-menu** (lista NUI po prawej, `client/main.lua:965`) - to jest to "brzydkie UI". Dwustopniowe: najpierw "Available Vehicles", potem lista. Nagłówki po angielsku ("Public Garage", "State: Out", "E - Garage"), powiadomienia po polsku.
4. `Config.AutoRespawn = false` - po każdym restarcie każde auto na zewnątrz trafia do depot (za $0, ale trzeba jechać na Parking Odzyskiwania). Dla małego serwera lepsze `true` (auto wraca do garażu).
5. Po zaparkowaniu kierowca jest teleportowany na `takeVehicle` (`CheckPlayers`, `:833-870`) - szarpnięcie kamerą; działa, ale nieładnie.
6. Strefa "marker" 60 m, strefa "out" 2 m - trzeba stanąć dokładnie w punkcie, żeby dostać "E - Garage".
7. [x] ZROBIONE 2026-09-05 (licznik generacji `previewGen`) - **Auta stackują się na obrotnicy przy szybkim przewijaniu** (zgłoszone przez właściciela, potwierdzone w kodzie). Każde góra / dół w menu odpala `qb-garages:client:selectPreviewVehicle` (NUI ma debounce 140 ms, `qb-menu/html/script.js:33`), a ten woła `ShowPreviewVehicleImpl` (`client/main.lua:160-215`). Funkcja najpierw kasuje `previewVehicle`, potem **czeka na załadowanie modelu** (`LoadPreviewModel`, pętla `Wait(0)` do 5 s) i dopiero potem tworzy auto. Przy ciężkich addonach model ładuje się dłużej niż 140 ms, więc dwa, trzy wywołania nakładają się: każde zastaje `previewVehicle = nil`, każde tworzy własne auto w tym samym punkcie, a zmienna pamięta tylko ostatnie. Reszta to sieroty, których `DeletePreviewVehicle` już nie widzi. Ten sam wyścig po `StopPreview`: wywołanie, które jeszcze czeka na model, tworzy auto po zamknięciu menu i zostawia je na stałe na spawnie garażu (kolejne wyciągnięcie spawnuje auto w to auto).
   Fix (kilka linii): licznik generacji - `previewGen = previewGen + 1` na wejściu do `ShowPreviewVehicleImpl` i w `StopPreview`; po `LoadPreviewModel` `if gen ~= previewGen then return end`; przed `CreateVehicle` jeszcze raz `DeletePreviewVehicle()`.
8. [x] ZROBIONE 2026-09-05 (`DragCam` z warsztatu przez `@terrific-customs/client/dragcam.lua`, nowe `DragCam.setEntity`; tryb orbity admina F6/F7/F8 usunięty, pole previewCamPoint w panelu nieużywane) - **Kamera podglądu nieintuicyjna** (zgłoszone). `ResolvePreviewCamera` (`:135-158`) dla każdego auta osobno szuka pierwszego z 8 kątów, w którym raycast nie trafia w przeszkodę - inne auto, inny wynik, więc kamera skacze przy przewijaniu. Gracz nie może jej obrócić ani przybliżyć, bo mysz należy do NUI qb-menu (dlatego tryb orbity jest tylko dla admina i musi zamykać menu). Stały kąt (`previewCamPoint`) ustawiony jest tylko w 4 z 36 garaży.
   Fix: po przejściu menu na ScaleformUI (sekcja 7) mysz jest wolna - użyć tej samej `DragCam` co w warsztacie (`terrific-customs/client/dragcam.lua`: LPM obraca, scroll przybliża, auto stoi zamiast się kręcić). Jedna kamera w warsztacie i w garażu = spójne zachowanie. Do tego czasu: `previewCamPoint` per garaż przez `/garageadmin` ustabilizuje kąt.

---

## 5. Holowanie (qb-towjob)

### Jak to dziś działa
Praca "tow" z urzędu. HQ = qb-target "Payslip". Strefa Flatbed (`client/main.lua:145-155`): **samo wejście w strefę** otwiera qb-menu z jednym wpisem (Flatbed, kaucja $250) albo, jeśli siedzisz w lawecie, **natychmiast ją kasuje** i zwraca kaucję (`:400-412`) - niezależnie od `UseTarget`. Zlecenia NPC: komenda `/npc`. Podczepienie: komenda `/tow` albo radial menu, stojąc obok lawety (nie w niej), patrząc na auto (raycast 5 m, laweta max 11 m). Odczepienie: to samo.

### Bugi i rzeczy nieintuicyjne
1. **Brak jakiejkolwiek podpowiedzi** przy aucie do holowania. Gdy raycast nie trafi w auto, nic się nie dzieje i nie ma komunikatu (`:310-313`, dystans liczony do entity 0).
2. Wjazd lawetą w strefę = natychmiastowe usunięcie lawety bez pytania.
3. `Config.Locations[type].coords.h` zamiast `.w` (`:98`) - heading stref = nil; `[number].name` nie istnieje (`:113`).
4. `cl_towreq.lua:29` woła `exports['qb-phone']:PhoneNotification`, którego **qb-phone nie eksportuje** - "Wezwij lawetę" z impoundu policji (`qb-policejob/client/impound.lua:102`) = błąd skryptu.
5. `tow:sendTowResponse` (`sv_towreq.lua:16`) bez walidacji - każdy klient może odpowiedzieć w imieniu lawety.
6. Locale pl: `refund_to_cash = "Depozyt zapłacony gotówką"` (powinno być "zwrócony"), a zwrot idzie na bank (`server/main.lua:24`). Locale i tak nieużywane (`qb_locale en`).
7. Bonus za ponad 20 holowań nieosiągalny przez limit 20 (`server/main.lua:65-69`) - kosmetyka.
8. Menu = qb-menu, EN.

---

## 6. Warsztat i mechanik

Są dwa różne "mechaniki":

- **terrific-customs** (tuning, ScaleformUI, po polsku, kamera orbitalna) - to wzorzec menu. Działa poprawnie: ceny z jednego źródła, płatność na serwerze, podgląd cofany przy wyjściu. Jedyna luka: **brak zapisu mods** (pkt 2).
- **qb-mechanicjob** (praca LS Customs: podnośnik, naprawa części za materiały ze stasha, spawn aut służbowych):
  1. Status auta wypisywany **na czacie** (`client/main.lua:451` `chat:addMessage`) zamiast w menu.
  2. Pięć menu qb-menu (`:458-680`), po angielsku, bez `pl.lua`.
  3. `RepairPart` (`:683-714`) buduje zawartość stasha u klienta i wysyła `qb-inventory:server:SaveStashItems`. Serwer (`qb-inventory/server/main.lua:2109-2132`) czyści format, ale ufa ilościom, a zapis do `mechanicstash` jest dozwolony dla każdego z pracą mechanic - mechanik może dopisać sobie dowolne materiały.
  4. Zużycie części nie zapisywane (pkt 2).
  5. `SetVehiclePlateZones` / podnośnik działają; auto wjeżdża na płytę na E, menu na E.

---

## 7. Spójność menu, podpowiedzi i języka

### Inwentaryzacja (grep po wszystkich zasobach)

| System | Gdzie |
|---|---|
| **ScaleformUI** (styl GTA, wzorzec) | terrific-customs |
| **qb-menu** (lista NUI) | 27 zasobów: qb-garages, qb-towjob, qb-mechanicjob, qb-vehicleshop, qb-houses, qb-apartments, qb-policejob, qb-ambulancejob, qb-taxijob, qb-busjob, qb-newsjob, qb-realestatejob, qb-truckerjob, qb-management (boss / gang), qb-pawnshop, qb-prison, qb-rentals, qb-vault, qb-companion, qb-weedplanting, qb-traphouse, qb-vehiclesales, qb-smallresources, cdn-fuel, ps-signrobbery |
| **menuv** | qb-adminmenu |
| **ox_lib context** | illenium-appearance, um-idcard-menu, cdn-fuel |
| keep-menu | nikt - martwy zasób w `[standalone]` |
| Pełnoekranowe NUI (aplikacje, nie listy) | bank, bankomat, telefon, ekwipunek, MDT, panel garaży, część salonu |

Podpowiedzi "naciśnij E": `exports['qb-core']:DrawText` (garaże, mechanik, bank bez targetu) vs `lib.showTextUI` (warsztat) vs oko qb-target - trzy różne wyglądy.

Język: `setr qb_locale "en"` w `server.cfg`, więc wszystkie zasoby QB mówią po angielsku, a kod własny (warsztat, garaż, panel, komunikaty z napraw) ma polskie stringi wpisane na sztywno. Gracz widzi mieszankę w jednym menu.

### Rekomendacja: most qb-menu -> ScaleformUI (najmniejszy diff, największy efekt)

Zamiast przepisywać 27 zasobów: podmienić implementację `openMenu / closeMenu / showHeader` w `qb-menu/client/main.lua` tak, żeby z tego samego formatu danych (`header`, `txt`, `disabled`, `hidden`, `params.event/args/isServer/isCommand/isAction`, garażowe `keepOpen / navSelect / navActive`) budowała `UIMenu` ze ScaleformUI (baner i styl jak w warsztacie), a NUI qb-menu wyrzucić. Mapowanie jest 1:1: pierwszy `isMenuHeader` = tytuł, `header` = pozycja, `txt` = opis pod menu, `navSelect` = `OnIndexChange` (podgląd 3D w garażu dalej działa strzałkami góra / dół), `keepOpen` = nie zamykaj po Enter.

Efekt: garaż, laweta, mechanik, salon, domy, policja, EMS, boss menu itd. dostają menu w stylu warsztatu **bez ruszania ich kodu**. Poza mostem zostają do osobnej decyzji: qb-adminmenu (menuv), appearance / dowód (ox_lib context - można przepisać albo zostawić, to ekrany "formularzowe"), pełnoekranowe aplikacje NUI (bank, telefon, ekwipunek, MDT - te nie są listami i nie da się ich sensownie zrobić w ScaleformUI).

Do tego, w tym samym kroku:
- `exports['qb-core']:DrawText` przekierować na `lib.showTextUI` - jedna podpowiedź "E" w całym serwerze.
- `setr qb_locale "pl"` + `pl.lua` dla qb-garages, qb-mechanicjob (qb-towjob i qb-banking już mają).
- Usunąć keep-menu z `[standalone]`.

### Holowanie "intuicyjnie" (po moście)
- qb-target na aucie: "Podczep do lawety", widoczne tylko gdy gracz ma job tow / mechanic, a laweta stoi w 11 m; na lawecie: "Odczep".
- W strefie Flatbed: podpowiedź E + menu ScaleformUI: "Wypożycz lawetę ($250 kaucji)" / "Oddaj lawetę" z potwierdzeniem, zamiast automatu na wejście.
- Zlecenia NPC: pozycja "Rozpocznij / zakończ zlecenia" w tym samym menu zamiast `/npc`.
- Zwrot kaucji na gotówkę (bo z gotówki była pobierana), poprawione locale.

---

## 8. Plan napraw w kolejności

### A. Bugi i luki (małe, każdy to kilka-kilkanaście linii)
1. [x] ZROBIONE 2026-09-05 - qb-banking: guardy `amount > 0`, całkowita, `savingsAccounts[cid]` w `savingsDeposit` / `savingsWithdraw`; `'Saving'` -> `'Savings'`; walidacja PIN / toggle / updatePin.
2. [x] ZROBIONE 2026-09-05 (PIN + blokada z bank_cards po stronie serwera, PIN do NUI zawsze z bazy) - qb-atms: serwer sprawdza `cardPin` i `cardLocked` z `bank_cards` przed wypłatą; komunikat "zamów kartę w banku", gdy gracz nie ma karty.
3. [x] ZROBIONE 2026-09-05 (fallback usunięty, AutoRespawn = true) - qb-garages: usunąć fallback `:265-276`; ~~`doCarDamage` z `or {}`~~ (zrobione 2026-09-05); `AutoRespawn = true`.
4. [x] ZROBIONE 2026-09-05 (zapis w commit(), format QBCore) - terrific-customs: po każdym udanym zakupie i naprawie wysłać `qb-vehicletuning:server:SaveVehicleProps` z `lib.getVehicleProperties(veh)` (event już istnieje w qb-mechanicjob i sprawdza, czy auto jest w bazie).
5. [x] ZROBIONE 2026-09-05 (PersistStatus przy każdej zmianie części, naprawa przez serwer + eksporty GetStashItemCount/RemoveStashItem w qb-inventory, status na czacie usunięty) - qb-mechanicjob: wołać `vehiclemod:server:saveStatus` przy parkowaniu w garażu (hook w `qb-garage:server:updateVehicle`) i przy wyjściu z auta; `RepairPart` zdejmować materiały na serwerze (`qb-inventory` RemoveItem ze stasha) zamiast wysyłać listę z klienta; status auta w menu zamiast na czacie.
6. [x] ZROBIONE 2026-09-05 - qb-garages: licznik generacji w `ShowPreviewVehicleImpl` / `StopPreview` (sekcja 4 pkt 7) - koniec stackowania aut na obrotnicy.
7. [x] ZROBIONE 2026-09-05 (klient przepisany: oko qb-target na aucie i lawecie, [E] zwrot w strefie, menu wypożyczalni + zlecenia NPC, wezwanie bez martwego eksportu, kaucja wraca tam, skąd była) - qb-towjob: `.h` -> `.w`, `PhoneNotification` -> powiadomienie QBCore + mail w telefonie, walidacja `tow:sendTowResponse` (nadawca ma job tow), komunikat gdy brak auta w zasięgu, locale, zwrot kaucji na gotówkę.
8. [x] ZROBIONE 2026-09-05 - `[addon]/__pycache__` usunąć i dodać do `.gitignore`; qb-adminmenu locale `sucess.entered_vehicle`.
9. [ ] DO DECYZJI (build wymaga `yarn install` = pobranie paczek npm; node 22 i yarn 1.22 są na maszynie) - screenshot-basic: wgrać oficjalny release z `dist/` (AUDIT.md pkt 2).

### B. Spójność (2-3 wieczory)
10. [x] ZROBIONE 2026-09-05 (`qb-menu/client/main.lua` przepisany, NUI wyłączone z manifestu; showHeader = podpowiedź [E] + menu po E) - Most qb-menu -> ScaleformUI (sekcja 7).
11. [x] ZROBIONE 2026-09-05 (kopie sprzed zmiany: `backups/garage-scaleform-20260905/`; po starcie serwera: `refresh`, `restart terrific-customs`, `restart qb-garages`) - Garaż: jedno menu, podgląd 3D z kamerą `DragCam` z warsztatu, Enter = wyciągnij, Backspace = zamknij, po polsku.
12. [x] ZROBIONE 2026-09-05 - Laweta: target + menu jak w sekcji 7.
13. [x] ZROBIONE 2026-09-05 (server.cfg pl, pl.lua dla qb-garages i qb-mechanicjob, qb-core DrawText -> lib.showTextUI z ox_lib, ox_lib startuje przed qb-core, keep-menu w [disabled]) - `qb_locale "pl"`, `pl.lua` dla garaży i mechanika, DrawText -> showTextUI, keep-menu do kosza.

### C. Odporność zapisu
14. [x] ZROBIONE 2026-09-05 (pcall na await, błąd w konsoli, powiadomienie gracza, ponowna próba po 30 s) - qb-core `Player.Save`: callback / `pcall` na INSERT i głośne ostrzeżenie w konsoli + txAdmin, gdy zapis się nie uda; opcjonalnie retry po 30 s.
15. [ ] RĘCZNIE (ustawienie Docker Desktop, nie kod) - Docker Desktop: wyłączyć usypianie / "Resource Saver", żeby kontener bazy nie znikał w trakcie sesji; sprawdzić `docker logs local4word6-projectterrific-db` z 4.09 ok. 14:30.
