# Audyt pojazdów: tekstury i handling - 2026-09-02

Zakres: 106 zasobów w `txData/resources/[addon]` (90 plików `.ytd`, 746 `.yft`, 97 `handling.meta`, 103 modele w `vehicles.meta`).
Metoda: własny parser formatu RSC7 (`.ytd`) zweryfikowany co do 1 MiB z liczbami, które FXServer wypisuje w logu; parser `handling.meta` porównany
z 9 oryginalnymi handlingami Rockstara (Adder, Zentorno, Massacro, Schafter3, Cog55, Baller3, Huntley, Nightshade, Mamba) pobranymi z repozytorium
[Firecul/GTA-V-Default-Handling-Files](https://github.com/Firecul/GTA-V-Default-Handling-Files---FiveM-resource).
Niczego nie zmieniałem w zasobach. Narzędzia leżą w `tools/` (opis w `tools/README.md`).

---

## 1. Tekstury - co jest nie tak

| Miara | Wartość |
|---|---|
| Łączna pamięć tekstur 90 aut (VRAM) | **7.5 GiB** |
| Tekstur razem | 8 305 |
| **Nieskompresowane RGBA** (A8R8G8B8, 32 bit/px) | **3 305 tekstur = 4.45 GiB** (59% pamięci) |
| **Bez mipmap** (1 poziom) | **2 269 tekstur = 2.5 GiB** |
| Tekstury 4096 px i większe | 64 (w tym `21s580m` ma karoserię **8192x8192**) |
| Tekstury 2048 px | 244 |
| Pliki `.ytd` ponad 16 MiB (próg ostrzeżenia FXServer) | **84 z 90** |
| Pliki ponad 64 MiB | 55 |

Vanilla GTA: cała tekstura auta to zwykle 8-25 MiB, format DXT1/DXT5, z mipmapami. Tu pojedyncza tekstura potrafi mieć 64 MiB
(`s500w223/w223light` 4096x4096 RGBA bez mipmap). Rekordziści (MiB w VRAM): s500w223 224, agerars 196, 21s580m 196, sccjkl 192, 21bentayga 184,
r33 178, 16charger 176, pistas 174, lp750sv 172 (z czego 88 MiB to pusta rezerwa), W463AS 172, s500 168, oycs8 168, rangerover2 160, pista 155, BMWM5CS 150.

Skutki: komunikat FXServer "Oversized assets can and WILL lead to streaming issues (models not loading/rendering)" 174 razy na start,
niewidoczne lub białe auta przy kilku takich modelach w pobliżu, długie dołączanie, crashe klientów z 4-6 GB VRAM.
Brak mipmap dodatkowo powoduje migotanie ("shimmering") z daleka, bo GPU próbkuje pełną 4K teksturę na 50 pikselach.

### Skrypt: `tools/ytd_optimize.py`

Własny optymalizator, bez zewnętrznych programów (Python + numpy, oba są na tym komputerze). Czyta `.ytd` (RSC7), przelicza tekstury i zapisuje plik od nowa:

- tekstury większe niż `--max` (domyślnie 2048) - zmniejsza; jeśli tekstura ma mipmapy i jest DXT, po prostu odcina górne poziomy (bezstratnie),
- RGBA bez kompresji - koduje do DXT1 (nieprzezroczyste) albo DXT5 (z alfą lub mapa normalnych `_nm/_n/_nrm`): 4-8x mniej,
- brak mipmap - generuje pełny łańcuch (tekstura rośnie o 33%, ale przestaje migotać i streamuje się lepiej),
- reszta (ATI1/ATI2/BC7, cubemapy) przepisywana bez zmian; po zapisie plik jest ponownie parsowany i sprawdzany.

Wynik na próbie (kopie w katalogu testowym, oryginały nietknięte):

| Plik | Przed | Po (`--max 2048`) | Na dysku | Czas |
|---|---|---|---|---|
| tenf.ytd | 128 MiB | **72 MiB** | 12.3 MiB | 95 s |
| r33.ytd | 178 MiB | **116 MiB** | 12.1 MiB | 165 s |

Symulacja dla wszystkich 90 plików (bez zapisu):

| Wariant | Razem VRAM | Plików > 64 MiB | > 32 MiB | > 16 MiB |
|---|---|---|---|---|
| dziś | 7.50 GiB | 55 | 84 | 84 |
| `--max 2048` | **3.61 GiB** (-52%) | 13 | 55 | 81 |
| `--max 1024` | **2.41 GiB** (-68%) | 1 | 32 | 72 |

Po `--max 2048` najcięższe zostają: r33 121, 21s580m 99, pistas 98, 16charger 90, s500w223 90, pista 90, 21bentayga 88, oycs8 82, tenf 75.
Do 16 MiB jak w vanilla nie zejdziemy samym skalowaniem, bo te modele mają po 80-250 tekstur; to wymaga usuwania zbędnych tekstur w modelu (praca ręczna w CodeWalker/ZModeler).
Rozsądny cel: karoseria i liveries 2048, wnętrze i detale 1024.

Procedura (kolejność ma znaczenie, bo pliku po zapisie nie da się w 100% zweryfikować bez gry):

```bash
python tools/ytd_optimize.py "txData/resources/[addon]/[audi]/tenf/stream/tenf.ytd" --out test_ytd
```

1. Podmień ręcznie `tenf.ytd` na ten z `test_ytd`, `restart tenf`, połącz się ponownie, zespawnuj `tenf` i obejrzyj lakier, szyby, wnętrze, mapy normalnych w słońcu.
2. Jeśli wygląda dobrze, cała paczka (kopie zapasowe lądują w `backups/ytd-<data>/`, ok. 1-3 min na auto na rdzeń, `--workers` domyślnie połowa CPU):

```bash
python tools/ytd_optimize.py "txData/resources/[addon]" --apply
```

3. Dla aut, które nadal mają > 64 MiB, powtórz z `--max 1024` na pojedynczych plikach.

Ograniczenia: koder DXT jest prosty (range-fit), jakość minimalnie niższa niż `texconv` Microsoftu; tekstury bez mipmap rosną o 33%, więc pliki
złożone głównie z małych DXT5 bez mipmap zyskują mało. Auta streamowane z archiwów `.rpf` (np. `mustangNFS`) nie są ruszane.

Alternatywy bez pisania kodu, jeśli wolisz gotowe narzędzie:
- [Dexta Toolkit](https://github.com/thesolitudetr/fivem-toolkit) - GUI (Windows), moduł "YTD Texture Optimizer" na CodeWalker + texconv, przetwarza foldery rekurencyjnie, MIT.
- [gtax.dev bulk YTD](https://gtax.dev/optimization/ytd/bulk) - w przeglądarce, wrzucasz zip/folder, ustawiasz limit rozmiaru, kompresję i mipmapy.
- [Texture Magic](https://github.com/SiriusDevLabs/Texture-Optimization) - GUI, skalowanie i kompresja DXT1/DXT5 na plikach .ytd, kilka plików naraz.

## 2. Handling - co jest nie tak

Sprawdzone 91 aut (bez łodzi i samolotu). **W zakresach vanilla mieści się 11**: r8cabt, r8sol, m850, f822, gcmlamboultimae, amggtrr20, sl63, as_zr350, jester2, massacro2, rangerover2.

| Problem | Aut | Co to robi w grze |
|---|---|---|
| **Za szybkie**: `fInitialDriveMaxFlatVel` ponad zakres klasy | **62** | mediana odcięcia = 249 km/h, Rockstar daje supersamochodom ok. 210 (Adder 160 = 211 km/h). Sześć aut ma > 400 km/h: mobm23 528, agerars 443, mbcls21 439, gcmcharger2021re 436, porcaygt22 i rs6rabt20 429 |
| **Za mały opór powietrza**: `fInitialDragCoeff` < 6 (vanilla 6.6-10) | 28 | brak naturalnego limitu prędkości, auto "odjeżdża" z każdej górki |
| **Za duża przyczepność**: `fTractionCurveMax` ponad klasę (vanilla 2.0-2.65) | 42 | jazda "po szynach" do momentu, w którym nagle nie ma nic |
| Przyczepność za mała (< 1.9) | 10 | r33 1.16, charger69 1.1, BMWM5CS 1.0: lód |
| **Odwrócona krzywa**: `fTractionCurveMin` > `fTractionCurveMax` | 7 | tenf, gt63s, W463AS, bmwm4cs, BMWM5CS, mobm23, sccjkl: auto w poślizgu ma WIĘCEJ gripu niż przed - nienaturalne "łapanie" |
| **Hamulec = ściana**: `fBrakeForce` > 2 (vanilla 0.5-1.0) | 8 | tenf 19.55, pd 20.68, gt63s 4.2, W463AS 3.6, bmwm4cs 3.4, 22g63/22g632 2.8, police2 2.68 |
| `fInitialDriveForce` ponad klasę (vanilla 0.25-0.36) | 25 | m4f82 0.52, polaventa 0.5, 18mh5 0.49; śmieciowe 14.0 (explorer16), 5.5 (BMWM5CS) |
| `fInitialDriveForce` za mały | 14 | sccjkl 0.07 (nie rusza), F22A 0.001 |
| **Ryzyko wywrotki** | 22 | patrz niżej |
| Ujemny lub zerowy roll centre | 8 | porcaygt22 -0.27, sccjkl -0.05, brabusgt600 -0.05/-0.07, ocnauda8l22h -0.1, rs6+/rs615 0.0, charger69 0.0 |
| `fAntiRollBarForce` = 0 | 5 | m3f80, m3g80c, W463AS, banshee87, sccjkl |
| `fSteeringLock` > 45 (vanilla 35-43) | 5 | BMWM5CS 63, mobm23 60, polaventa 50, r33 46.8, 18mh5 46.4: przy prędkości = obrót i dachowanie |
| Śmieciowe wpisy (kopie z innych pojazdów) | 4 | explorer16/explorer (driveForce 14, grip 0, 1 bieg, COM 0.9 m pod podłogą), BMWM5CS, yacht4 (masa 100 000 kg jako auto) |
| `fClutchChangeRateScale` 666.9 | 1 | m4f82 |
| Zniszczalność 0 | 2 | BMWM5CS, mobm23 |

**Dlaczego się wywracają**: w RAGE dachowanie bierze się z połączenia wysokiego gripu bocznego (`fTractionCurveMax` 2.8-3.5) z brakiem stabilizatora
(`fAntiRollBarForce` 0) lub zerowym/ujemnym `fRollCentreHeight`, czasem z `vecCentreOfMassOffset.z` +0.15-0.19 (f812c21, 22g63, 21bentayga).
Rockstar trzyma SUV-y na `fAntiRollBarForce` 0.3-0.9 i `fRollCentreHeight` 0.4-0.67, a grip SUV-a na 2.0-2.1. Auta, które kompensują to
`vecCentreOfMassOffset.z` -0.5..-9.0 (explorer, sr650fly, yacht4), nie dachują, ale obracają się wokół punktu pod jezdnią i "pływają".

**Dlaczego za szybkie lub za wolne**: `fInitialDriveMaxFlatVel` to prędkość na odcięciu w ostatnim biegu (x0.82 = mph, x1.32 = km/h).
Vanilla: sedan 145-150, sport 156, super 159-160, SUV 135. Tutaj mediana 189, bo autorzy wpisują realną prędkość maksymalną w km/h (240, 300, 325)
zamiast /1.32. Do tego `fInitialDragCoeff` 1-4 zamiast 7-10 i auta nie mają górnego ograniczenia. "Za wolne" to głównie zepsute wpisy (sccjkl driveForce 0.07, banshee87 masa 170 kg z dragiem 4.5).

**Duplikaty i widma**:
- `[audi]/audi7rs/data/handling.meta` (zasób bez modeli!) zawiera **trzy** wpisy `<handlingName>tenf` skopiowane z innych aut Rockstara (masa 650 kg, 2350 kg...) plus `weevil2`, `vigero2`, `torero2`, `tenf2`.
  Który `tenf` wygra, zależy od kolejności ładowania - to prawdopodobna przyczyna "dziwnego" RS7. **Skasować cały `audi7rs`.**
- `explorer` zdefiniowany w `[ford]/exploler` i `[misc]/explorer` ([misc]/explorer ma `vehicleClass` BOAT).
- 7 modeli bez handlingu (19ranger2, W463A, g5502019, G632019, G632019X, G634X4, yz450f) - spawn z domyślnym handlingiem albo wcale.

### Wzorce Rockstara (do porównania)

| Auto | klasa | masa | drag | drvForce | flatVel | brake | steer | tMax | tMin | lat | susF | comp | reb | antiRoll | rollC F/R | COM z |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Adder | super | 1800 | 7.8 | 0.32 | 160 | 1.0 | 42 | 2.50 | 2.38 | 22.5 | 2.4 | 1.4 | 2.1 | 0.9 | 0.41/0.41 | 0 |
| Zentorno | super | 1500 | 10 | 0.354 | 159 | 1.0 | 40 | 2.65 | 2.55 | 22.5 | 2.65 | 1.5 | 2.2 | 0.9 | 0.34/0.34 | 0 |
| Massacro | sport | 1700 | 10 | 0.364 | 156 | 0.9 | 43 | 2.42 | 2.23 | 22.5 | 2.45 | 1.4 | 3.1 | 0.6 | 0.23/0.18 | 0 |
| Schafter3 | sedan | 1500 | 7.25 | 0.30 | 150 | 0.95 | 40 | 2.55 | 2.25 | 20.5 | 2.8 | 1.4 | 2.0 | 0.85 | 0.37/0.36 | 0 |
| Cog55 | sedan | 2500 | 7.75 | 0.265 | 145 | 0.57 | 40 | 2.20 | 1.75 | 22.5 | 1.8 | 1.4 | 2.0 | 0.67 | 0.20/0.20 | 0 |
| Baller3 | SUV | 2175 | 8.0 | 0.275 | 135 | 0.6 | 35 | 2.00 | 1.65 | 19.0 | 1.4 | 0.9 | 1.4 | 0.9 | 0.67/0.60 | 0 |
| Huntley | SUV | 2500 | 8.0 | 0.265 | 136 | 0.55 | 35 | 2.10 | 1.70 | 18.7 | 1.4 | 0.9 | 1.6 | 0.3 | 0.42/0.41 | +0.3 |
| Nightshade | muscle | 1400 | 10 | 0.25 | 145 | 0.6 | 41 | 2.25 | 1.85 | 20.5 | 1.9 | 1.15 | 1.7 | 0.3 | 0.12/0.11 | +0.1 |
| Mamba | sport classic | 1160 | 9.5 | 0.34 | 148 | 0.5 | 41 | 2.50 | 2.05 | 20.5 | 2.2 | 1.4 | 2.5 | 0.4 | 0.08/0.09 | +0.05 |

Wnioski z tabeli: `fInitialDriveForce` w vanilla jest prawie stały (0.25-0.36) - o przyspieszeniu decyduje masa; hamulec nigdy nie przekracza 1.0;
`fSuspensionReboundDamp` jest zawsze WIĘKSZY od `fSuspensionCompDamp`; grip sedana (2.55) bywa wyższy niż supersamochodu (2.50) i to jest w porządku.

## 3. Ocena skilla `fivem-handling-generator`

Skill jest dobry jako generator poprawnego XML (szablon, `handlingName` = `handlingId`, procedura testu, struktura zasobu). Jako źródło liczb jest szkodliwy:

1. **`fInitialDriveForce = moment / (masa x 9.81)`** daje 0.03-0.05, czyli 10x mniej niż jakiekolwiek auto Rockstara. Skill to wie, więc każe "przyciąć do capu klasy" (0.32-0.60). W praktyce wzór nic nie liczy, a capy (SPORT 0.42, SUPERCAR 0.48, HYPERCAR 0.60) są ponad vanilla (Zentorno 0.354).
2. **`fBrakeForce <= fTractionCurveMax / 4`** ("warunek krytyczny") jest wymyślony: Adder ma 1.0 przy 2.5/4 = 0.63 i hamuje normalnie.
3. **`fSuspensionCompDamp = fSuspensionForce / 2` i `Rebound = 0.55 x Force`** dają rebound < comp, a każde auto Rockstara ma odwrotnie (Adder 1.4/2.1, Massacro 1.4/3.1).
4. **`fInitialDragCoeff` 2.0-3.2** dla sportowych i 5.0-5.5 dla sedanów, gdy vanilla ma 7-10. To jest wprost przyczyna 28 aut "bez limitu prędkości".
5. Sekcja **"GTA_GOOD_FEEL na bazie tenf"** kodyfikuje dokładnie te błędy, które wyszły w audycie: hamulec 10+, `fTractionCurveMin > Max` jako "arcade trick",
   flatVel 240. Skill uczy się z pliku, który sam jest zepsuty (tenf: brake 19.55, min 3.5 > max 2.96, 317 km/h).
6. Wzór `flatVel = vmax x 0.75` jest w porządku (wiki: x0.82 = mph). Presety `fAntiRollBarForce` 1.4-1.8 i `fSuspensionForce` 3.2-3.8 są 1.5-2x ponad vanilla (deska).

Werdykt: **nie używać jego liczb**. Zamiast "przelicz dane z internetu na 40 parametrów" lepsza jest metoda Rockstara: weź handling stockowego auta tej samej klasy,
zmień 5-6 parametrów pod konkretny model i zostaw resztę.

## 4. Propozycja - jak to naprawić

Krok 0 (bugi, 10 minut): skasować `[addon]/[audi]/audi7rs`; usunąć `[misc]/explorer` albo `[ford]/exploler` (jeden z dwóch); poprawić ręcznie 4 śmieciowe wpisy
(explorer16, BMWM5CS, m4f82 clutch, yacht4) albo zastąpić je szablonem klasy.

Krok 1 (automat, tryb `clamp`): `tools/handling_fix.py` przycina każdy parametr do zakresu klasy z tabeli vanilla, naprawia odwrócone krzywe, hamulce, ujemne roll centre,
COM pod podłogą. Zachowuje charakter auta (który jest szybszy, który cięższy). Zmienia 85 z 91 aut; najczęściej: flatVel (66), tractionMax (50), tractionMin (39),
driveForce (39), drag (29), steeringLock (26), brakeForce (21). Przykład tenf: flatVel 240 -> 175 (231 km/h), tractionMax 2.96 -> 2.75, tractionMin 3.5 -> 2.55, brake 19.55 -> 1.3.

```bash
python tools/handling_fix.py "txData/resources/[addon]"            # podgląd
python tools/handling_fix.py "txData/resources/[addon]" --apply    # zapis, backup w backups/handling-<data>/
```

Krok 2 (opcjonalny, tryb `template`): parametry "czucia" (grip, hamulce, drag, stabilizator, roll centre, tłumienie, skręt, bezwładność) ustawia na szablon klasy
zbudowany na wzorcach Rockstara; zostają parametry auta (masa, biegi, napęd, prędkość i siła w zakresie klasy, skoki zawieszenia, flagi, siedzenia).
Wszystkie auta danej klasy jeżdżą wtedy spójnie i przewidywalnie; potem strojenie ręczne tylko tam, gdzie chcesz charakteru (`--only nazwa`).

Krok 3 (ręcznie, per auto, 5 parametrów z realnych danych):
- `fMass` = masa własna,
- `nInitialDriveGears` i `fDriveBiasFront` (RWD 0, AWD 0.3-0.5, FWD 1),
- `fInitialDriveMaxFlatVel` = vmax km/h / 1.32, ale nie więcej niż zakres klasy (super 175 = 231 km/h; w GTA 250 km/h to już bardzo dużo),
- `fInitialDriveForce`: 0.26-0.30 sedan/SUV, 0.30-0.36 sport, 0.34-0.42 super; wyżej tylko dla hypercarów,
- `fInitialDragCoeff` 7-10 zawsze.

Test po każdej zmianie: `restart <zasób>`, `/dv`, odczekać 5 s, spawn od nowa (handling jest cache'owany).

## 5. Czego nie zweryfikowałem

- Zachowania przebudowanych `.ytd` w grze: struktura pliku jest poprawna wg parsera, ale renderowanie trzeba sprawdzić na jednym aucie przed batchem.
- Handling oceniałem statycznie z plików; zakresy klas to 9 wzorców Rockstara plus znane wartości vanilla, nie pełna baza 700 aut.
- Modeli `.yft` (geometria, LOD-y, kolizje) nie analizowałem; `subarung_hi.yft` 17 MiB i podobne to osobny temat (brak LOD-ów).
