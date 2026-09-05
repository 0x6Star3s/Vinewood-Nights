---
name: fivem-handling-generator
description: >
  Znajdź dane techniczne dowolnego samochodu w internecie i natychmiast przelicz je na
  kompletny, gotowy plik handling.meta dla GTA V / FiveM. Użyj tego skilla gdy użytkownik
  poda nazwę samochodu i chce handling do FiveM, powie "zrób mi handling dla X", "wygeneruj
  handling.meta dla X", "chcę dodać X na serwer FiveM", "przelicz dane techniczne X na
  handling", "handling dla [marka] [model]", lub wspomni o fizyce pojazdu w kontekście
  FiveM/GTA. Skill automatycznie wyszukuje dane techniczne, przelicza wszystkie parametry
  RAGE według wzorów matematycznych i zwraca gotowy XML + wyjaśnienie każdego parametru.
  Nie pytaj użytkownika o dane — znajdź je sam w internecie. Triggeruj nawet dla ogólnych
  próśb jak "pomóż mi z handlingiem" w kontekście FiveM.
---

# FiveM Handling Generator

Skill do automatycznego generowania plików `handling.meta` dla GTA V / FiveM na podstawie
nazwy samochodu. Skilla wyszukuje dane techniczne, przelicza je na parametry silnika RAGE
i zwraca gotowy XML z komentarzami.

## Przepływ pracy (wykonaj w tej kolejności)

```
KROK 1: Rozpoznaj pojazd i zbierz dane
KROK 2: Określ klasę i profil
KROK 3: Oblicz parametry RAGE (wzory matematyczne)
KROK 4: Wygeneruj XML handling.meta
KROK 5: Wyjaśnij każdy parametr
```

Szczegóły każdego kroku → patrz sekcje poniżej.

---

## KROK 1: Rozpoznaj pojazd i zbierz dane techniczne

### 1a. Parsowanie nazwy pojazdu

Z wypowiedzi użytkownika wyodrębnij:
- **Markę** (Toyota, BMW, Ford…)
- **Model** (Supra, M3, Mustang…)
- **Generację / rok** jeśli podano (A90, E92, 2023…)
- **Wariant silnika** jeśli podano (3.0T, V8, AMG…)

Jeśli użytkownik nie podał roku/generacji — wybierz **najpopularniejszą / najbardziej
ikoniczną wersję** (np. dla "Supra" → A80 MKIV 2JZ lub A90 GR, zależnie od kontekstu).
Poinformuj krótko którą wersję wybrałeś i dlaczego.

### 1b. Wyszukiwanie danych technicznych

Wykonaj `web_search` w następującej kolejności źródeł:

**Priorytet 1 — auto-data.net**
```
Query: "[marka] [model] [rok/generacja] specifications site:auto-data.net"
Przykład: "Toyota GR Supra A90 2020 specifications site:auto-data.net"
```
Jeśli wynik zawiera link — użyj `web_fetch` na URL auto-data.net żeby pobrać pełne dane.

**Priorytet 2 — Wikipedia + oficjalny producent**
```
Query: "[marka] [model] [generacja] curb weight torque top speed specifications"
```
Przeszukaj wyniki w poszukiwaniu: masy, momentu, prędkości max, napędu, liczby biegów.

**Priorytet 3 — dimensions.com (wymiary fizyczne)**
```
Query: "[marka] [model] [generacja] wheelbase dimensions site:dimensions.com"
```
Potrzebne: rozstaw osi (wheelbase mm), szerokość toru (track width mm).

**Dane które MUSISZ znaleźć (obowiązkowe):**

| Parametr | Jednostka | Źródło |
|---|---|---|
| Masa własna (curb weight) | kg | auto-data.net / Wikipedia |
| Prędkość maksymalna | km/h | auto-data.net / spec sheet |
| Moment obrotowy silnika | Nm | auto-data.net / Wikipedia |
| Moc silnika | KM/HP | auto-data.net |
| Typ napędu | RWD/FWD/AWD | Wikipedia / spec sheet |
| Liczba biegów | liczba | spec sheet |

**Dane opcjonalne (jeśli dostępne, poprawiają dokładność):**

| Parametr | Jednostka | Wpływ na handling |
|---|---|---|
| Rozstaw osi (wheelbase) | mm | → vecCentreOfMassOffset.Y |
| Prześwit (ground clearance) | mm | → fSuspensionUpperLimit |
| Rozkład masy przód/tył | % | → fDriveBiasFront, vecCentreOfMassOffset |
| Współczynnik oporu Cd | liczba | → fInitialDragCoeff (korekta) |
| Szerokość opon (np. 255) | mm | → fTractionCurveMax |

### 1c. Konwersja jednostek

Przed obliczeniami upewnij się że wszystkie wartości są w poprawnych jednostkach:

```
Masa:    jeśli w lbs → podziel przez 2.2046 → kg
Moment:  jeśli w lb-ft → pomnóż przez 1.35582 → Nm
Prędkość: jeśli w mph → pomnóż przez 1.60934 → km/h
```

---

## KROK 2: Określ klasę pojazdu i profil jazdy

### 2a. Klasyfikacja pojazdu

Wybierz **jedną** klasę na podstawie typu nadwozia i charakteru pojazdu:

| Klasa | Przykłady | Kluczowe cechy |
|---|---|---|
| `SPORT` | Supra, M3, Cayman, NSX | Niska masa, wysoka moc, sportowe zawieszenie |
| `SUPERCAR` | Lamborghini, Ferrari, McLaren | Ekstremalna moc, aerodynamika, mid/rear engine |
| `MUSCLE` | Mustang, Camaro, Challenger, Charger | RWD, duży moment, miękkie zawieszenie |
| `SEDAN` | BMW 3, Audi A4, Mercedes C | Balans komfort/dynamika, często AWD |
| `SUV` | G-Class, Range Rover, Cayenne | Wysoki CoM, duża masa, AWD |
| `TRUCK` | RAM 1500, F-150, Silverado | Bardzo wysoki CoM, tylny napęd, długi rozstaw |
| `HYPERCAR` | Bugatti, Koenigsegg, Rimac | >800 KM, aktywna aerodynamika, AWD |

### 2b. Profil jazdy (zapytaj użytkownika LUB użyj domyślnego)

Jeśli użytkownik nie określił preferencji → użyj `GRIP` jako domyślny.

| Profil | Opis | Kiedy używać |
|---|---|---|
| `GRIP` | Precyzyjna, stabilna, mała tendencja do poślizgu | Domyślny, codzienna jazda RP |
| `NEUTRAL` | Wyważona, lekka nadsterowność | Racing serwery |
| `DRIFT` | Łatwy poślizg, głęboka nadsterowność | Drift events, fun serwery |

### 2c. Profil "GTA GOOD FEEL" na bazie sprawdzonych lokalnych handlingów

Jeśli użytkownik mówi że auto ma "fajnie jeździć", "jak tenf", "jak Audi", "lepiej niż
realistycznie" albo chce feeling GTA zamiast czystej symulacji, użyj profilu
`GTA_GOOD_FEEL`.

Wnioski z lokalnego handlingu `tenf`:

- `fDriveBiasFront 0.300-0.350` dla AWD daje rear-biased feeling: auto wychodzi z zakrętu
  dynamicznie i nie zachowuje się jak nudne FWD.
- `fInitialDriveForce 0.320-0.360` to praktyczny sweet spot dla szybkich sedanów/coupe
  w RAGE. Realny wzór często daje za mało, więc w GTA można skalować wyżej.
- `vecInertiaMultiplier` około `1.0-1.3 / 1.6 / 1.7-1.9` daje naturalny roll/yaw bez
  nerwowego "kartingu".
- `fTractionCurveLateral 19.5` jest bardzo ważne: opona szybciej komunikuje limit i auto
  robi przewidywalny, łatwy do złapania oversteer. Dla ciężkich sedanów można używać
  `19.5-20.5`.
- `fTractionCurveMin > fTractionCurveMax` jest celowym arcade-trickiem, nie realizmem.
  Daje efekt samostabilizacji w poślizgu. Używaj ostrożnie, np. `Max 2.95-3.05` i
  `Min 3.20-3.60`, jeśli użytkownik chce auto "jak tenf".
- `fBrakeForce` ekstremalnie wysokie (`10+`) jest nierealistyczne, ale w GTA daje bardzo
  pewne hamowanie. Dla lepszego, mniej zepsutego wariantu używaj `2.5-4.5`; tylko gdy
  użytkownik chce dokładnie feeling `tenf`, można iść wyżej.
- `fSteeringLock 36-40` daje responsywny skręt w mieście i ciasnych zakrętach. Dla ciężkich
  sportowych sedanów dobry zakres to `36-38`.
- `fClutchChangeRateScaleUpShift/DownShift 6/6` daje płynne, szybkie zmiany biegów bez
  szarpania.
- `fPercentSubmerged` w standardowych handlingach GTA/FiveM jest procentem, zwykle
  `85.000000`. Nie używaj `0.850000`, bo auto może zachowywać się błędnie na wodzie.

`GTA_GOOD_FEEL` ma pierwszeństwo nad czysto matematycznymi walidacjami typu
`fBrakeForce <= fTractionCurveMax/4` i `fTractionCurveMin = Max * 0.72`, ale tylko wtedy,
gdy użytkownik wyraźnie chce arcade/GTA feeling. Zawsze zaznacz w komentarzu lub opisie,
że są to celowe ustawienia pod feeling RAGE, a nie pełen realizm.

---

## KROK 3: Obliczenia parametrów RAGE

Wykonaj **wszystkie obliczenia** poniżej i zapisz wyniki. Szczegółowe tabele wartości
dla każdej klasy → patrz `references/class-presets.md`.

### 3a. Parametry silnika i prędkości

```
fMass = masa_kg (bezpośrednio)

fInitialDriveMaxFlatVel = vmax_kph × 0.75
  Przykład: 250 km/h × 0.75 = 187.500000

fInitialDriveForce = moment_Nm / (masa_kg × 9.81)
  Przykład: 500 / (1443 × 9.81) = 0.035325
  
  ⚠️ CAP PER KLASA (nie przekraczaj):
  HYPERCAR:  max 0.60
  SUPERCAR:  max 0.48
  SPORT:     max 0.42
  MUSCLE:    max 0.38
  SEDAN:     max 0.32
  SUV:       max 0.28
  TRUCK:     max 0.22
  
  Jeśli obliczona wartość > cap → użyj cap i zanotuj to w komentarzu XML.

fInitialDragCoeff = bazowa_wartość_klasy × korekta_Cd
  Bazy: HYPERCAR=2.0, SUPERCAR=2.8, SPORT=3.2, MUSCLE=5.5, SEDAN=5.0, SUV=8.5, TRUCK=11.0
  Jeśli znasz Cd pojazdu: korekta = Cd_rzeczywiste / 0.30 (0.30 = średnia referencyjna)
  Bez danych Cd: użyj wartości bazowej bez korekty.
```

### 3b. Układ napędowy

```
fDriveBiasFront:
  RWD  → 0.000000
  FWD  → 1.000000
  AWD równy (50/50) → 0.500000
  AWD front-bias (60F/40R) → 0.600000
  AWD rear-bias (40F/60R) → 0.400000
  
  ⚠️ Silnik RAGE zaokrągla: >0.90 = pełne FWD, <0.10 = pełne RWD

nInitialDriveGears = liczba_biegów (z danych technicznych)
  ⚠️ Tuning skrzyni biegów w grze dodaje +1 bieg do tej wartości.

fDriveInertia:
  Wolnoobrótowy diesel/V8:  0.80
  Standardowy benzynowy:    1.00
  Sportowy silnik 4-cyl:    1.30
  High-revving (>7000 RPM): 1.60

fClutchChangeRateScaleUpShift = 1 / czas_zmiany_w_sekundach
fClutchChangeRateScaleDownShift = 1 / czas_redukcji_w_sekundach
  Szybki sport (0.1s): → 10.0
  Standardowy (0.2s):  → 5.0
  Wolny diesel (0.4s): → 2.5
  ⚠️ MAX = 13.0 (≈0.077s). Nie przekraczaj.
```

### 3c. Układ hamulcowy

```
fBrakeForce:
  Oblicz: max_bezpieczna = fTractionCurveMax / 4
  Wartości klasy: SUPERCAR=1.40, SPORT=1.20, MUSCLE=0.85, SEDAN=1.00, SUV=1.00, TRUCK=0.80
  ⚠️ WARUNEK KRYTYCZNY: fBrakeForce ≤ fTractionCurveMax / 4
     Naruszenie = blokowanie kół, utrata sterowności.

fBrakeBiasFront:
  SUV/TRUCK:  0.55  (przeniesienie masy przy hamowaniu jest większe)
  MUSCLE:     0.58
  SEDAN/SPORT: 0.62
  SUPERCAR:   0.65
```

### 3d. Opony i przyczepność

```
fTractionCurveMax (maksymalny grip):
  HYPERCAR: 3.20
  SUPERCAR: 2.95
  SPORT:    2.85
  MUSCLE:   2.15
  SEDAN:    2.40
  SUV:      2.25
  TRUCK:    1.90
  
  Korekta szerokości opony (jeśli znana):
  Opona <205mm:  × 0.92
  Opona 205-225: × 0.96
  Opona 225-255: × 1.00 (baza)
  Opona 255-275: × 1.04
  Opona >275mm:  × 1.08

fTractionCurveMin = fTractionCurveMax × 0.72  (grip podczas uślizgu)

fTractionCurveLateral (kąt max. gripu bocznego w stopniach):
  GRIP profil:
    SUPERCAR/SPORT: 18.0   (precyzyjna, wąskie okno uślizgu)
    MUSCLE/SEDAN:   22.5   (standardowe)
    SUV/TRUCK:      26.0   (szersze okno, łatwiejsze prowadzenie)
  DRIFT profil:
    Wszystkie:      28.0–32.0 (szeroki uślizg, łatwy drift)

fTractionLossMult (utrata gripu poza asfaltem):
  SPORT/SUPERCAR: 1.50  (bardzo słaby off-road)
  MUSCLE/SEDAN:   1.20
  SUV:            0.45  (dobry off-road)
  TRUCK:          0.35  (terenowy)

fLowSpeedTractionLossMult (buksowanie przy ruszaniu):
  GRIP:  0.0   (brak buksowania)
  NEUTRAL: 0.3
  DRIFT: 0.8   (łatwe burnout)

fCamberStiffnesss:
  GRIP:    0.000000
  NEUTRAL: 0.000000
  DRIFT:  -0.500000 (progresywna nadsterowność)
```

### 3e. Zawieszenie

```
fSuspensionForce (sztywność sprężyn):
  SUPERCAR/HYPERCAR: 3.80
  SPORT:             3.20
  MUSCLE:            1.80
  SEDAN:             2.40
  SUV:               2.10
  TRUCK:             1.60

⚠️ WARUNEK KRYTYCZNY: fSuspensionCompDamp = fSuspensionForce / 2
   Zapewnia optymalne tłumienie — nie zmieniaj tej proporcji.

fSuspensionReboundDamp = fSuspensionForce × 0.55

fSuspensionUpperLimit (skok góra, metry):
  SUPERCAR: 0.05   SPORT: 0.08   MUSCLE: 0.15   SEDAN: 0.12   SUV: 0.22   TRUCK: 0.28

fSuspensionLowerLimit (skok dół, metry, wartość ujemna):
  SUPERCAR: -0.06  SPORT: -0.09  MUSCLE: -0.13  SEDAN: -0.12  SUV: -0.18  TRUCK: -0.22

fSuspensionRaise = 0.000000 (korekta prześwitu — zostaw 0 chyba że model 3D wymaga inaczej)
```

### 3f. Środek ciężkości i bezwładność

```
vecCentreOfMassOffset (X, Y, Z) w metrach:

X (lewo/prawo): prawie zawsze 0.000000
  Wyjątek: silnik z boku (niektóre egzotyki) → ±0.02

Y (przód/tył, + = przód, - = tył):
  Napęd PRZEDNI (FWD):  +0.05  (cięższy przód)
  Napęd TYLNY (RWD):   -0.05  (cięższy tył)
  AWD 50/50:            0.00
  Rozkład masy z danych: jeśli znasz %F/%R:
    Y = ((%F - 50) / 100) × 0.15
    Przykład 52/48: Y = (52-50)/100 × 0.15 = +0.030000

Z (góra/dół, - = niżej):
  SUPERCAR/SPORT:  -0.08  (niska sylwetka)
  MUSCLE:          +0.02  (klasyczne nadwozie)
  SEDAN:            0.00
  SUV:             +0.05  (wysoko)
  TRUCK:           +0.08  (bardzo wysoko)

vecInertiaMultiplier (X, Y, Z):
  X (pitch — kiwanie przód/tył):
    SPORT: 1.20  SUV: 1.60  inne: 1.30
  Y (roll — przechył boczny):
    SPORT: 1.60  SUV: 2.00  inne: 1.80
  Z (yaw — odchylenie, reakcja na kierownicę):
    SUPERCAR:   1.40  (ostra odpowiedź)
    SPORT:      1.60
    MUSCLE:     2.00  (ospała jak prawdziwy muscle)
    SEDAN:      1.80
    SUV/TRUCK:  2.20  (ociężała)
    ⚠️ Minimalna wartość Z: 1.40. Poniżej = nienaturalna hiperaktywność skrętu.
```

### 3g. Stabilizatory i geometria

```
fAntiRollBarForce (zapobiega wywrotce w zakrętach):
  HYPERCAR/SUPERCAR: 1.60
  SPORT:             1.40
  MUSCLE:            0.50  (pozwala na przechył — klasyczny feeling)
  SEDAN:             0.80
  SUV:               1.00  (⚠️ minimum dla SUV żeby nie wywracać)
  TRUCK:             0.70

fAntiRollBarBiasFront:
  Neutral/GRIP:   0.55  (lekki bias przód dla stabilności)
  DRIFT:          0.40  (więcej swobody tył)

fRollCentreHeightFront / fRollCentreHeightRear:
  SPORT/SUPERCAR: 0.25 / 0.20
  MUSCLE:         0.10 / 0.08
  SEDAN:          0.20 / 0.18
  SUV:            0.40 / 0.38  (⚠️ minimum ≥0.35 dla stabilności)
  TRUCK:          0.45 / 0.40

fSteeringLock (kąt skrętu kół, stopnie):
  SPORT/SUPERCAR: 30.0
  MUSCLE/SEDAN:   35.0
  SUV:            38.0
  TRUCK:          42.0
```

### 3h. Parametry dodatkowe (stałe lub rzadko zmieniane)

```
fCollisionDamageMult:   standardowy serwer RP = 0.500000
fWeaponDamageMult:      1.000000
fDeformationDamageMult: 0.600000
fEngineDamageMult:      0.500000  (zmniejszone dla trwałości RP)
fPercentSubmerged:      85.000000  (standard GTA/FiveM; wartość procentowa)
fDownforceModifier:
  SUPERCAR/SPORT z aerodynamiką: 12.5
  Zwykłe auta:                    0.0
fPopUpLightRotation:    0.000000
fSeatOffsetDistX/Y/Z:   0.000000 / 0.000000 / 0.000000
nInitialDriveForceMultiplier: 1.000000
```

---

## KROK 4: Generuj XML handling.meta

Użyj szablonu poniżej i podstaw wszystkie obliczone wartości.
**Wszystkie wartości float: dokładnie 6 miejsc po przecinku.**
**handlingName: max 14 znaków, WIELKIE LITERY, tylko A-Z 0-9 _**

```xml
<Item type="CHandlingData">
  <handlingName>HANDLING_ID</handlingName>
  <fMass value="MASA.000000"/>
  <fInitialDragCoeff value="DRAG.000000"/>
  <fDownforceModifier value="DOWNFORCE.000000"/>
  <fPopUpLightRotation value="0.000000"/>
  <fSeatOffsetDistX value="0.000000"/>
  <fSeatOffsetDistY value="0.000000"/>
  <fSeatOffsetDistZ value="0.000000"/>
  <fPercentSubmerged value="85.000000"/>
  <vecCentreOfMassOffset x="0.000000" y="COM_Y" z="COM_Z"/>
  <vecInertiaMultiplier x="INERTIA_X" y="INERTIA_Y" z="INERTIA_Z"/>
  <fDriveBiasFront value="DRIVE_BIAS"/>
  <nInitialDriveGears value="GEARS"/>
  <fInitialDriveForce value="DRIVE_FORCE"/>
  <fDriveInertia value="DRIVE_INERTIA"/>
  <fClutchChangeRateScaleUpShift value="CLUTCH_UP"/>
  <fClutchChangeRateScaleDownShift value="CLUTCH_DOWN"/>
  <fInitialDriveMaxFlatVel value="FLAT_VEL"/>
  <fBrakeForce value="BRAKE_FORCE"/>
  <fBrakeBiasFront value="BRAKE_BIAS"/>
  <fHandBrakeForce value="0.600000"/>
  <fSteeringLock value="STEERING_LOCK"/>
  <fTractionCurveMax value="TRACTION_MAX"/>
  <fTractionCurveMin value="TRACTION_MIN"/>
  <fTractionCurveLateral value="TRACTION_LAT"/>
  <fTractionSpringDeltaMax value="0.140000"/>
  <fLowSpeedTractionLossMult value="LOWSPEED_TRACTION"/>
  <fCamberStiffnesss value="CAMBER"/>
  <fTractionBiasFront value="0.475000"/>
  <fTractionLossMult value="TRACTION_LOSS"/>
  <fSuspensionForce value="SUSP_FORCE"/>
  <fSuspensionCompDamp value="SUSP_COMP"/>
  <fSuspensionReboundDamp value="SUSP_REBOUND"/>
  <fSuspensionUpperLimit value="SUSP_UPPER"/>
  <fSuspensionLowerLimit value="SUSP_LOWER"/>
  <fSuspensionRaise value="0.000000"/>
  <fSuspensionBiasFront value="0.500000"/>
  <fAntiRollBarForce value="ANTIROLL"/>
  <fAntiRollBarBiasFront value="ANTIROLL_BIAS"/>
  <fRollCentreHeightFront value="ROLL_FRONT"/>
  <fRollCentreHeightRear value="ROLL_REAR"/>
  <fCollisionDamageMult value="0.500000"/>
  <fWeaponDamageMult value="1.000000"/>
  <fDeformationDamageMult value="0.600000"/>
  <fEngineDamageMult value="0.500000"/>
  <fPetrolTankVolume value="65.000000"/>
  <fOilVolume value="5.000000"/>
  <fFaultTolerance value="0.000000"/>
  <vecGravityFactor x="0.000000" y="0.000000" z="1.000000"/>
  <fFullPassFrictionMult value="1.000000"/>
  <fUnkFloat1 value="0.000000"/>
  <fUnkFloat2 value="0.000000"/>
  <fUnkFloat3 value="0.000000"/>
  <nInitialDriveForceMultiplier value="1.000000"/>
  <fBuoyancy value="1.000000"/>
</Item>
```

---

## KROK 5: Wyjaśnij parametry użytkownikowi

Po wygenerowaniu XML dodaj **tabelę komentarzy** w tym formacie:

```
=== WYJAŚNIENIE KLUCZOWYCH PARAMETRÓW ===

fInitialDriveForce = [wartość]
  Obliczono: [moment] Nm / ([masa] kg × 9.81) = [raw]
  [Jeśli przycięto: "Przycięto do max [cap] dla klasy [klasa]"]
  Efekt: auto przyspiesza [słabo/umiarkowanie/agresywnie]

fInitialDriveMaxFlatVel = [wartość]
  Obliczono: [vmax] km/h × 0.75 = [wartość]
  Efekt: prędkość max w grze ≈ [vmax] km/h

fTractionCurveMax = [wartość]
  Źródło: preset klasy [klasa] [+ korekta opony jeśli była]
  Efekt: [wysoki/średni/niski] grip w zakrętach

fSuspensionForce = [wartość] → fSuspensionCompDamp = [wartość/2]
  Proporcja 2:1 zapewnia brak oscylacji zawieszenia po nierównościach.

vecCentreOfMassOffset = (0, [Y], [Z])
  Y=[wartość]: środek masy [z przodu/z tyłu] → [pod/nadsterowność]
  Z=[wartość]: [niska/wysoka] sylwetka → [stabilna/podatna na wywrotkę]

fAntiRollBarForce = [wartość]
  [Jeśli SUV: "Minimum 1.0 dla SUV — zapobiega wywrotce w zakrętach"]
  Efekt: [duży/mały] przechył nadwozia w zakrętach

=== WALIDACJA KRYTYCZNYCH WARUNKÓW ===
✓ fBrakeForce ([wartość]) ≤ fTractionCurveMax/4 ([wartość/4]) → OK / ❌ BŁĄD
✓ fSuspensionCompDamp = fSuspensionForce/2 → OK
✓ fPercentSubmerged = 85.000000 → OK
✓ handlingName ≤ 14 znaków → OK
```

---

## Obsługa błędów i przypadków brzegowych

### Brak danych w internecie

Jeśli nie możesz znaleźć masy lub momentu:

1. Spróbuj `web_search "[marka] [model] weight horsepower"` bez site:
2. Spróbuj angielskiej wersji: `"[brand] [model] curb weight specifications"`
3. Jeśli dalej brak — użyj wartości z najbliższego podobnego pojazdu i **wyraźnie zaznacz**
   że to przybliżenie. Podaj źródło użytego zamiennika.

### Elektryki i hybrydy

- Moment elektryczny jest natychmiastowy → użyj **maksymalnego momentu systemowego**
- `fDriveInertia`: elektryk = 1.80 (szybka reakcja)
- `fInitialDriveForce`: często bardzo wysoki → zawsze sprawdź cap klasy
- AWD split: jeśli przód elektryczny / tył spalinowy → `fDriveBiasFront = 0.45`

### Konflikt handlingName

Zawsze przypominaj: handlingName MUSI być unikalny na serwerze. Jeśli użytkownik ma
już inne pojazdy, sugeruj konwencję: `[MARKA]_[MODEL]_V[numer]`
Przykład: `SUPRA_A90_V1`, `BMW_M3_E92_V1`

### Pojazd fikcyjny / modowany bez prawdziwego odpowiednika

Zapytaj użytkownika: "Ten pojazd nie ma odpowiednika w realu — na jakim samochodzie
jest bazowany lub jaki charakter jazdy chcesz osiągnąć?" Następnie użyj danych
z najbliższego realnego pojazdu jako bazy.

---

## Referencje

- `references/class-presets.md` — Szczegółowe tabele wartości dla każdej klasy
- `references/math-formulas.md` — Wszystkie wzory matematyczne z wyprowadzeniami
- `references/fivem-implementation.md` — Implementacja na serwer FiveM, struktura zasobu

Czytaj plik referencyjny tylko gdy potrzebujesz szczegółów wykraczających poza SKILL.md.