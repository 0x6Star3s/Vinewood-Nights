# Audyt ekonomii serwera (QBCore / ProjectTerrific) - 2026-09-02

Zakres: sklepy, bankowość i bankomaty, saldo i wypłaty, wszystkie źródła dochodu, koszty życia, wyliczenie czasu do "bogactwa".
Metoda: przegląd configów i handlerów serwerowych, skrypt porównujący sprzedawane itemy z `qb-core/shared/items.lua`, statystyka cen z `vehicles.lua` (785 pojazdów).
Serwera nie uruchamiano. Wartości $/h to **szacunki** z configów (dystanse w linii prostej przy ~60 km/h, losowe zakresy jako średnia).

---

## 1. Werdykt w jednym zdaniu

Ekonomia jest niezbalansowana i miejscami zepsuta: sklepy działają, ale cena idzie z klienta; przelew w banku nie działa; bankomat wypłaca z cudzego konta; 13 miejsc niszczy pieniądze przy płatnościach dla firm; napady na banki nie wymagają policji i dają 50x więcej niż praca; kilkadziesiąt sprzedawanych itemów nie istnieje.

## 2. Saldo gracza i wypłaty

| Co | Wartość | Źródło |
|---|---|---|
| Start nowej postaci | **$500 gotówki + $5 000 bank**, 0 crypto | `qb-core/config.lua:9` |
| Startowe itemy | dowód + prawo jazdy (um-idcard); **telefonu brak** (`GiveStarterItems` nigdy nie wołane) | `qb-multicharacter/server/main.lua:5-26,104,110` |
| Wypłata | co **10 min**, tylko na służbie, z powietrza (`PayCheckSociety=false`) | `qb-core/config.lua:11-12`, `server/functions.lua:313-343` |
| Bezrobotny | $10 / 10 min = **$60/h** | `jobs.lua:4` |
| Prace 5-stopniowe (taxi, policja, EMS, mechanik, nieruchomości) | $50/75/100/125/150 = **$300-900/h** | `jobs.lua` |
| Bus, trucker, laweta, hotdog, winnica, reporter, prawnik | $50 = $300/h; sędzia $100 = $600/h | `jobs.lua` |
| qb-paycheck (ped z odbiorem wypłaty) | **martwy, zawsze $0**: klient wysyła niezarejestrowany event `qb-paycheck:server:increase_moeny` | `qb-paycheck/client_main.lua:2`, `server_main.lua:116` |
| Zapis salda | autosave co 5 min + przy wyjściu | `qb-core/server/events.lua:15,170` |
| Ujemne saldo | **bank może zejść poniżej zera** (`DontAllowMinus = {cash, crypto}`) | `qb-core/config.lua:10` |
| Głód/pragnienie | 100 -> 0 w ~2 h (4.2 i 3.8 pkt co 5 min); jedzenie kosztuje $2 | `qb-core/config.lua:15-16` |

## 3. Bankowość i bankomaty

| Przepływ | Status | Dowód |
|---|---|---|
| Otwarcie banku (8 stref qb-target, NUI) | **działa** | `qb-banking/client/main.lua:82-100`, `server/main.lua:237-261` |
| Wpłata / wypłata w banku | działa; wypis (statement) wstawiany PRZED sprawdzeniem salda | `server/main.lua:294-340` |
| **Przelew w banku** | **nie działa** - handler `initiateTransfer` w całości zakomentowany | `server/main.lua:99-184` |
| Przelew w telefonie | działa przez callback `CanTransferMoney` (sprawdza saldo, obsługuje offline) | `qb-phone/server/main.lua:542-572` |
| Event `qb-phone:server:TransferMoney` | **bez sprawdzenia salda**; NUI go nie używa, ale każdy klient może go wywołać -> bank w minus | `qb-phone/server/main.lua:835-863` |
| Konto oszczędnościowe | działa (numer konta wyświetla nil) | `useraccounts.lua:319-322,391-399` |
| Karta debetowa | działa, darmowa; PIN w metadanych itemu jawnym tekstem; `updatePin` po `record_id` z klienta = zmiana cudzego PIN-u | `server/main.lua:265-292,342-350` |
| **Bankomat** (qb-atms, jedyny aktywny; ATM-y qb-banking nie są podpięte) | **działa, ale wypłaca z DOWOLNEGO konta**: `data.cid` z NUI, PIN sprawdzany tylko po stronie klienta; brak wpłaty; limit $4 999/h; ścieżka offline crashuje (`json.decode` na tabeli) | `qb-atms/server/main.lua:64-87,101-107,174` |
| Faktury (policja/mechanik) | działa, 10% prowizji dla mechanika; `RemoveMoney('bank')` bez sprawdzenia salda | `qb-phone/server/main.lua:294-323` |
| **Konta firmowe** | **13 miejsc niszczy pieniądze**: gracz płaci, potem `exports['Renewed-Banking']` rzuca błąd, firma nic nie dostaje (szpital $2 000, mandaty, salon, nieruchomości) | `qb-ambulancejob:27,45,59,72,87`, `qb-policejob:441,445,837`, `qb-vehicleshop:325,341,397,418`, `qb-houses:240` |
| Tabele w bazie | wszystkie wymagane tabele są w `docker/mariadb/init/01-projectterrific.sql`; brakuje **kolumn** `bank_accounts.account_number/sort_code`, więc konta firmowe/gangowe qb-banking (`createbusinessAccount`) wywalają SQL error | `business.lua:151`, init sql:37-50 |
| Zamykanie banku podczas napadu | qb-bankrobbery wysyła `qb-banking:server:SetBankClosed`, nikt tego nie obsługuje | `qb-bankrobbery/sv_config.lua:17,27` |

## 4. Sklepy i wydatki

| Miejsce | Asortyment | Ceny | Działa? |
|---|---|---|---|
| 24/7 x9, LTD x5 | 13 itemów: kanapka/woda/cola $2, piwo $7, whisky $10, wódka $12, bandaż $100 | $2-100 | tak (lotto wypada, item nie istnieje) |
| Rob's Liquor x5, bar w kasynie | alkohol | $7-12 | tak |
| Hardware x3 | 16 itemów: lockpick $200, klucz/młotek/repairkit $250, **telefon $850**, radio $250, advancedrepairkit $500 | $50-5 000 | tak (syphoningkit nie istnieje) |
| Ammunation x11 | nóż/kij $250, SNS $1 500, **pistolet $2 500**, amunicja $250, tinty $8 750-62 000 | $250-62k | tak; filtr licencji tylko po stronie klienta (`qb-shops/client/main.lua:29-70`) |
| Sea Word / Leisure | diving_gear $2 500, jerry_can $200, spadochron $2 500 | $50-2 500 | tak |
| Hunting Shop | rifle $1 500, bait $150, snp_ammo $250 | | **pół-pusty**: rifle i bait nie istnieją w items.lua |
| Pet Shop | 21 itemów keep-companion | $500-150k | **pusty**: 0/21 istnieje |
| Digital Den | laptop $10 000, gopro, vpn, camera | | tylko laptop istnieje |
| Automaty (qb-vending-machines) | 19 itemów | $2-3 | 5/19 istnieje |
| Automaty (qb-inventory) | cola, woda | $4 | tak |
| **Salon PDM** (+ Luxury, Marina, Air, Truck) | **785 pojazdów**, cena z serwera | $160 - $9.99M | tak; raty: 10% wpłaty, max 24 raty co 24h; **Import shop pusty** (0 aut z `shop='tuner'`), modele Luxury `22m5`/`gtr` nie istnieją |
| Komis (qb-vehiclesales) | rynek wtórny: sprzedający dostaje 77%, odsprzedaż 50% | | działa, bez sprawdzenia właściciela |
| **Domy** | w bazie **1 dom**: "Union Rd 1" $56 789 x1.21 = **$68 715**; meble $250-5 000 | | kupno działa, potem błąd Renewed-Banking |
| Mieszkania (qb-apartments) | 4 mieszkania | **$0, brak czynszu** | tak |
| **Paliwo** (cdn-fuel) | $3 + 15% podatku = **$3.45/L** (jedna stacja $4); bak 60 L ≈ **$207** | | działa, ale kwota z klienta; jerry can nie działa (item `jerrycan` vs `jerry_can`) |
| Urząd (qb-cityhall) | dowód $50, prawo jazdy $50, licencja na broń $50 | $50 | tak, bez żadnego sprawdzenia egzaminu |
| Ubrania / fryzjer / tatuaż / chirurg | po $100 (flat) | $100 | tak |
| Garaże | parkowanie/wyciąganie **darmowe**; depot z bazy | $0 | tak |
| Wypożyczalnia (qb-rentals) | futo $600, bison $800, sanchez $750; lotnicze $7.5-11k | | cena z klienta; item `rentalpapers` nie istnieje |
| Parkometr | $5 / 60 min | $5 | tak |
| Mechanik | naprawy za itemy (złom, plastik, stal), bez pieniędzy | $0 | tak |
| Szpital | **$2 000** przy respawnie / check-in; NPC revive $5 000 + firstaid | $2 000 | pobiera, potem błąd Renewed-Banking |
| Lotto | los $15 -> $100-200 | | los nie istnieje; event wygranej bez zabezpieczenia |
| Crypto (qbit) | start $1 000, błądzenie losowe co 10 min ±1-10%, 2% crash/boom | | działa, nie da się farmić |
| Gazeta (futte-newspaper) | $100 | $100 | **zepsute**: item `newspaper` nie istnieje, pieniądze znikają |

### Itemy sprzedawane, których nie ma w items.lua (sklep pokazuje puste sloty)
qb-shops: `lotto`, `syphoningkit`, `weapon_huntingrifle`, `huntingbait`, 13x `keepcompanion*`, `petfood`, `collarpet`, `firstaidforpet`, `petnametag`, `petwaterbottleportable`, `petgroomingkit`, `gopro`, `vpn`, `camera`.
qb-vending-machines: `latte-machiatto`, `espresso`, `crisps`, `egochaser`, `nachos`, `meteorite-bar`, `twix`, `cola`, `sprunk`, `orang-o-tang`, `cranberry`, `ecoladiet`, `sprunklight`, `water_bottle2`.
Inne: `jerrycan` (cdn-fuel), `rentalpapers` (qb-rentals), `newspaper` (futte-newspaper), `meatdeer/meatpig/...` (keep-hunting), `weedplant_seedm/f`, `plant_tub`, `weedplant_package` (qb-weedplanting), `recyclablematerial`, `pokebox` + 7 kart (qb-dumpsters).

### Ceny pojazdów (785 szt., `qb-core/shared/vehicles.lua`)
- Najtańszy: BMX $160; najtańsze auto **Asea $2 500**, Panto $3 200; najtańsze sportowe Issi Rally $10 000
- Mediana sedanów $40 500; **mediana wszystkich $52 000**; mediana sportowych $110 000; mediana super $232 000
- Top: Tyrant $2.1M, Taipan $1.85M; wyjątki Rocket Voltic $9.83M, Oppressor $9 999 999
- Auta z generatora [addon] mają ceny domyślne wg klasy (Sports $250 000, Super $500 000, SUV $160 000 itd.)

## 5. Źródła dochodu (szacunki $/h)

| Aktywność | Wymaganie | Za akcję | Czas akcji | **$/h** | Kwota z klienta? |
|---|---|---|---|---|---|
| **Trucker** | praca, kaucja $125 | $500/sklep +$100 bonus -15% = $510, 25% szansy na cryptostick (~$1 200) | ~4 min | **~$7 100 + ~$4 200 crypto** | TAK (`drops`) |
| Recykling | **żadne** (brak sprawdzenia joba) | ~12 złomu | 30 s | ~$5 000 (plastik do myśliwego po $25) / ~$3 300 (traphouse) | nie |
| Złomowisko | znaleźć auto z listy | ~105 złomu | ~3.5 min | ~$4-6k | TAK |
| Laweta | praca, kaucja $250 | ~$136 + 25% cryptostick | ~3.3 min | ~$2 300 + ~$5 100 crypto | TAK |
| Taxi NPC | praca | ~$179 + napiwek + 25% cryptostick | ~5 min | ~$2 300 + ~$3 700 crypto | TAK |
| Bus | praca | ~$25/przystanek | 50 s | ~$1 800 | nie (ale spam w 20 m) |
| Hotdog | praca, kaucja $250 | $4-12 x 1-3 | 30-60 s | ~$1 000-1 500 | TAK |
| Nurkowanie | sprzęt $2 500 + $500 | ~$300/pick | krótko + pływanie | ~$2 000-3 000 | TAK |
| Śmietniki | żadne | 33%: $21-39 | 22 s | ~$1 000 | TAK |
| Traphouse: okradanie NPC | żadne | 90%: $1-80 | 30-60 s (cooldown tylko u klienta) | ~$2 900 | TAK |
| Polowanie | rifle $1 500 | mięso $150 x mnożnik | 60 s | **$0 - itemy mięsa nie istnieją** | TAK |
| Winnica | praca | winogrona -> wino | 3 min | **$0 - wino nie ma kupca** | nie |
| Weedplanting | nasiona | $3 500-4 985/paczka | 8 h wzrost | **$0 - itemy nie istnieją** | nie |
| Cornerselling (narkotyki) | 0 policji | $15-40 x 1-15 (50% ok, 25% scam, 25% napad) | 30 s | ~$120/próbę, ograniczone zapasem | TAK |
| Dostawy narkotyków | dealer z `/newdealer` | **$1 000/brick x 1-3**, x2 per policjant online | 3-4 min | ~$30 000 | TAK |
| Napad na sklep | **2 policjantów**, lockpick | 1-3 markedbills ≈ $560 (80% w traphouse) | 2 min, reset 30 min | ~$5 600 | nie |
| **Fleeca** | **0 policjantów** | ~$5 500 | 30 min blokady | ~$50 000 | nie |
| **Paleto / Pacific** | **0 policjantów** | ~$110 000 / ~$360 000 | 90 min blokady | **$70 000-240 000** | nie |
| Jubiler | 2 policjantów, broń | ~$2 400 EV/gablotę x20 | 60 min timeout | ~$48 000/napad | nie |
| Napad na dom | 2 policjantów (sprawdzane tylko u klienta) | ~$3-5k | ~2 min | | nie |
| Napad na ciężarówkę | 2 policjantów, $500 | ~$560 | 10 min | **netto ≈ +$60** | TAK |
| Policja / EMS / mechanik / nieruchomości | praca | brak wypłaty per akcja, tylko pensja | | $300-900 | |

Markedbills spienięża się TYLKO w traphouse (80% wartości) i dopiero po przejęciu za $5 000. Sztabki złota z Pacific nie mają kupca.
Bez policji online niemożliwe: sklep, jubiler, dom, ciężarówka. **Możliwe bez policji: wszystkie trzy banki** (`qb-bankrobbery/cl_config.lua:29-32` `Minimum*Police = 0`), narkotyki, nurkowanie, traphouse.

## 6. Ile trzeba grać, żeby "niczego nie brakowało"

Koszty stałe są pomijalne: jedzenie ~$2/h, paliwo ~$70-100/h przy ciągłej jeździe, szpital $2 000 za śmierć. Liczy się tylko cel.

| Pakiet | Skład | Koszt |
|---|---|---|
| **A. Start** | Asea $2 500 + telefon $850 + dokumenty $100 + pistolet z amunicją i licencją $2 800 + ubrania/fryzjer $200 | **~$6 500** (startowe $5 500 pokrywa 85%) |
| **B. Wygodnie** | auto z mediany $52 000 + jedyny dom $68 715 + meble $3 000 + pistolet $2 800 + telefon/dokumenty $1 000 + zapas $10 000 | **~$137 500** |
| **C. Bogato** | super z mediany $232 000 + sportowe $110 000 + dom $68 715 + reszta jak wyżej + zapas $50 000 | **~$470 000** |
| **D. Wszystko** | Tyrant $2 100 000 + dom + reszta | **~$2 200 000** |

Godziny gry do celu (cel / stawka):

| Sposób zarabiania | $/h | A ($6.5k) | B ($137.5k) | C ($470k) | D ($2.2M) |
|---|---|---|---|---|---|
| Pensja bezrobotnego | 60 | 17 h | 2 290 h | 7 800 h | 36 700 h |
| Pensja, stopień 0 | 300 | 3.5 h | 458 h | 1 570 h | 7 300 h |
| Pensja, max stopień (policja/EMS 4) | 900 | 1.1 h | 153 h | 522 h | 2 440 h |
| Taxi / laweta (bez crypto) | 2 300 | 0.5 h | 60 h | 204 h | 957 h |
| Recykling (bez pracy) | 5 000 | 0.2 h | 27 h | 94 h | 440 h |
| **Trucker** | 7 100 | 0.1 h | **19 h** | **66 h** | 310 h |
| Trucker + crypto (EV) | 11 300 | | 12 h | 42 h | 195 h |
| Fleeca (0 policji) | 50 000 | | 2.75 h | 9.4 h | 44 h |
| **Pacific (0 policji)** | 240 000 | | **1 napad** | **2 napady (3 h)** | **~7 napadów (10.5 h)** |

Wnioski z liczb:
- Uczciwy gracz-trucker jest "wygodny" po ~2 wieczorach i "bogaty" po ~2 tygodniach po 4 h. To rozsądne tempo.
- Pensje są dekoracją: maksymalny policjant zarabia w 8 h tyle, co trucker w 1 h. Nikt nie będzie grał służbami dla pieniędzy.
- Napad na Pacific bez ani jednego policjanta online daje w 90 minut tyle, co trucker w 50 h. To niszczy ekonomię i to jest błąd configu (`Minimum*Police = 0`), nie zamierzenie.
- Wszystkie luki z sekcji 3 sekcji AUDIT.md (ujemne ilości w inventory, kwota z klienta) to "nieskończone pieniądze w 0 h" dla kogoś z konsolą F8.

## 7. Bugi ekonomii - lista do naprawy (od najważniejszych)

1. [x] ZROBIONE - **13 wywołań Renewed-Banking niszczy pieniądze** (szpital, mandaty, salon, nieruchomości). Fix: zamienić na `exports['qb-management']:AddMoney(society, amount)` (`qb-management/fxmanifest.lua:22` `server_exports`; tak robi `qb-phone:316`).
2. [x] ZROBIONE (qb-inventory bierze asortyment i cene z Configu przez eksporty qb-shops/qb-drugs/qb-prison + wlasny Config.VendingItem; police/hospital dalej z klienta - lista zalezy od stopnia sluzbowego) - **Cena w sklepach idzie z klienta** - `qb-inventory/server/main.lua:1284` zapisuje listę itemów przysłaną przez klienta, `:1887` pobiera `itemData.price` z niej. Dowolny item za $0. Fix: serwer bierze produkt i cenę z `qb-shops/config.lua` po nazwie sklepu i slocie.
3. [x] ZROBIONE (serwer wymaga karty z info.citizenid == cid, kwota walidowana, sciezka offline naprawiona) - **Bankomat wypłaca z dowolnego konta** (`qb-atms/server/main.lua:64-87`), PIN tylko u klienta. Fix: serwer wymaga posiadania karty z `info.citizenid == data.cid` i sprawdza `info.cardPin`; albo wyrzucić qb-atms i podpiąć `Config.ATMModels` z qb-banking pod `qb-banking:openBankScreen`.
4. [x] ZROBIONE (przelew przepisany na QBCore, numer konta = IBAN z charinfo.account, sprawdzenie salda, obsluga offline) - **Przelew w banku nie działa** (`qb-banking/server/main.lua:99-184` zakomentowany). Fix: wkleić logikę z `qb-phone:542-566` albo ukryć zakładkę.
5. [x] ZROBIONE ('bank' w DontAllowMinus, transfer w telefonie sprawdza saldo, szpital i faktury ksieguja firmie dopiero po udanym RemoveMoney) - **Bank może być ujemny**: dodać `'bank'` do `DontAllowMinus` (`qb-core/config.lua:10`), usunąć event `qb-phone:server:TransferMoney` (`:835`), sprawdzać wynik `RemoveMoney` w `PayInvoice:314`, `qb-policejob:836`, `qb-ambulancejob:26`.
6. [x] ZROBIONE (Fleeca 3, Paleto 5, Pacific 6 + sprawdzenie po stronie serwera, bylo tylko u klienta) - **Banki bez policji**: `qb-bankrobbery/cl_config.lua:29-32` ustawić np. Fleeca 2, Paleto 4, Pacific 6 (albo tyle, ilu realnie bywa online).
7. [~] CZESCIOWO (dodane `newspaper` i `lotto` do items.lua, poprawiona literowka `jerrycan` -> `jerry_can`; reszta ~40 itemow do dodania albo wyciecia z configow sklepow) - **~45 sprzedawanych itemów nie istnieje** (lista w sekcji 4). Albo dodać do `items.lua`, albo usunąć z configów sklepów. Najpilniejsze: `newspaper` (zabiera $100 i nic nie daje), `jerry_can` (literówka w cdn-fuel `fuel_sv.lua:115`), `lotto`, hunting rifle/bait.
8. [x] ZROBIONE (trucker/laweta/taxi/hotdog/smietniki/nurkowanie licza sie na serwerze albo maja twarde limity) - **Wypłaty prac z klienta**: trucker `drops`, laweta `drops`, taxi `currentFare`, hotdog `amount/price`, śmietniki `money`, nurkowanie, złomowisko. Fix: serwer liczy dostawy/kursy per gracz w tabeli po stronie serwera.
9. [x] ZROBIONE (kwota walidowana, `amount < 1` juz nie daje darmowego paliwa) - **cdn-fuel** `fuel_sv.lua:74-93`: kwota tankowania z klienta (`amount < 1` = darmowe paliwo). Fix: litry x cena z bazy x 1.15 po stronie serwera.
10. [x] ZROBIONE (qb-paycheck przeniesiony do [disabled]) - **qb-paycheck martwy** - usunąć z `[qb]` (pensja i tak idzie z qb-core).
11. [ ] NIEAKTUALNE - dealerzy sa ladowani z bazy przy starcie (`deliveries.lua`, CreateThread na koncu pliku) - **Dealerzy narkotyków nie ładują się z bazy** (`qb-drugs/server/deliveries.lua` tylko INSERT) - po restarcie dostawy i sklepy dealerów nie istnieją.
12. [ ] DO ZROBIENIA - brak kupca na wino, sztabki i mieso to decyzja projektowa (trzeba dodac skup) - **Bez kupca**: wino (winnica = $0), sztabki złota (Pacific), wszystkie itemy z polowania. Markedbills tylko w traphouse po $5 000 przejęcia.
13. [x] ZROBIONE (nie da sie kupic pojazdu `shop='none'`, raty < 1 odrzucane, salda kredytu z bazy) - **Salon**: Import shop pusty, modele Luxury `22m5`/`gtr` nie istnieją; można kupić pojazdy `shop='none'` (wojsko, samoloty) przez event (`qb-vehicleshop/server.lua:191,234`); `financeVehicle` bez `paymentAmount >= 1` = dzielenie przez zero (`:59`).
14. [ ] DO DECYZJI - egzaminy na prawo jazdy/bron to zmiana rozgrywki, nie bug - **Urząd sprzedaje prawo jazdy i licencję na broń bez sprawdzenia** (`qb-cityhall/server/main.lua:31-40`).
15. [ ] DO ZROBIENIA - dosianie domow do `houselocations` (seed SQL albo praca nieruchomosci) - **Tylko 1 dom w bazie** (`houselocations`), mieszkania darmowe bez czynszu - "dom" jako cel praktycznie nie istnieje.
16. [~] CZESCIOWO (bonus lawety naprawiony, wypis bankowy po sprawdzeniu salda, updatePin tylko do wlasnej karty, qb-paycheck wylaczony; reszta drobiazgow zostaje) - Drobne: bonus lawety nieosiągalny (`qb-towjob/server/main.lua:66-73`, `>5` przed `>10`), timeout jubilera 60 min zamiast 30 (`config.lua:4`), `RegisterEarnings` w qb-storerobbery nieużywane, ceny lombardu i nurkowania losowane raz przy starcie (`math.random` w configu), wypis bankowy przed sprawdzeniem salda (`qb-banking:329`), `updatePin` po `record_id` z klienta (`:342`), `qb-paycheck:server:AddMoneyToPayCheck` otwarty event (`server_main.lua:122`), bus bez deduplikacji przystanków (`qb-busjob/server/main.lua:14`).

## 8. Propozycja balansu (jeśli chcesz "zdrowej" ekonomii)

- Cel: legalna praca ~$2 000-3 000/h, pensja służb ~$1 500/h na max stopniu (żeby policja/EMS opłacały się finansowo): `jobs.lua` payment 150 -> 250, `PayCheckTimeOut` 10 -> 5.
- Trucker $510/sklep -> ~$200; laweta/taxi bez zmian.
- Banki: min. policja jak w pkt 6; Pacific $20 000/skrytkę -> $5 000.
- Markedbills: dodać wykup w lombardzie po 70% bez wymogu przejęcia traphouse.
- Domy: dodać 10-20 domów przez pracę nieruchomości albo seed SQL w przedziale $40 000-400 000; mieszkania $500/tydzień czynszu jeśli ma być drenaż pieniędzy.
- Salon: obniżyć domyślne ceny generatora dla klas Sports/Super (250k/500k) do poziomu stocku (mediana 110k/232k), inaczej dodony nikt nie kupi.
