# Wzory matematyczne silnika RAGE — wyprowadzenia i uzasadnienia

## Wzory obowiązkowe (zawsze stosuj)

### 1. Prędkość maksymalna
```
fInitialDriveMaxFlatVel = V_max_kph × 0.75

Uzasadnienie: Silnik RAGE interpretuje tę wartość w jednostkach wewnętrznych,
gdzie przelicznik wynosi 0.75. Użycie wartości rzeczywistej (np. 250) zamiast
przeliczonej (187.5) spowoduje że auto osiągnie tylko ~190 km/h.

Przykład: BMW M3 V-max = 290 km/h → fInitialDriveMaxFlatVel = 217.500000
```

### 2. Siła napędowa
```
fInitialDriveForce = T_Nm / (m_kg × 9.81)

Gdzie:
  T_Nm = maksymalny moment obrotowy silnika w Nm
  m_kg = masa pojazdu w kg
  9.81 = przyspieszenie grawitacyjne [m/s²]

Fizyczne uzasadnienie: Reprezentuje stosunek siły napędowej do siły grawitacji
działającej na pojazd. Wyższy wynik = szybsze przyspieszenie.

Przykład: Supra A90 → 500 / (1443 × 9.81) = 500 / 14155.83 = 0.035325

⚠️ Jeśli wynik > cap klasy: użyj cap. Zbyt wysoka wartość powoduje
   nierealistycznie gwałtowne przyspieszenie i problemy z fizyką.
```

### 3. Krytyczne tłumienie zawieszenia
```
fSuspensionCompDamp = fSuspensionForce / 2

Jest to warunek krytycznego tłumienia układu sprężyna-amortyzator.
Przy tej proporcji pojazd wraca do pozycji neutralnej w dokładnie jednym
cyklu wahnięcia — bez oscylacji.

fSuspensionReboundDamp = fSuspensionForce × 0.55
(Odbicie zawsze nieco wolniejsze od kompresji — standard inżynierski)

⚠️ NIGDY nie ustawiaj CompDamp ≠ Force/2. Naruszenie powoduje:
   - zbyt niski CompDamp: auto "skacze" jak piłka na nierównościach
   - zbyt wysoki CompDamp: koła tracą kontakt z podłożem po uderzeniu
```

### 4. Bezpieczna siła hamowania (zapobieganie blokadzie kół)
```
fBrakeForce_max = fTractionCurveMax / 4

Jeśli fBrakeForce > fTractionCurveMax / 4:
  → koła blokują się przy hamowaniu
  → pojazd traci sterowność
  → efekt ABS nieobecny = katastrofa w RP

Przykład: TractionMax = 2.85 → BrakeForce max = 2.85/4 = 0.7125
  Dla klasy SPORT używamy 1.20 — SPRAWDŹ: 1.20 ≤ 0.7125? NIE!
  
Korekta: dla SPORT z TractionMax=2.85, BrakeForce musi być ≤ 0.7125
Lub: podnieś TractionMax żeby BrakeForce/4 ≥ 1.20 → TractionMax ≥ 4.80 (nierealne)
Praktycznie: użyj fBrakeForce=0.70 dla TractionMax=2.85

⚠️ Tabela w SKILL.md zawiera wartości PRZED weryfikacją — ZAWSZE sprawdzaj.
```

### 5. Prędkość zmiany biegu
```
fClutchChangeRateScale = 1 / t_shift_sekundy

Przykłady:
  Supercar DCT (0.05s):  → 20.0 (ale cap=13.0, więc używaj 13.0)
  Sportowy (0.10s):      → 10.0
  Standardowy (0.20s):   → 5.0
  Wolny diesel (0.40s):  → 2.5

⚠️ MAX = 13.0. Powyżej = skrzynie biegów "znikają" z animacji,
   dźwięk się rozjeżdża, fizyka się psuje.
```

### 6. Środek ciężkości Y (rozkład masy)
```
Jeśli znasz stosunek masy przód/tył (np. 52F/48R):

vecCentreOfMassOffset.Y = (%F - 50) / 100 × 0.15

Przykłady:
  50/50 → (50-50)/100 × 0.15 = 0.000000 (perfekcyjny balans)
  52/48 → (52-50)/100 × 0.15 = +0.030000 (cięższy przód)
  55/45 → (55-50)/100 × 0.15 = +0.075000 (znacznie cięższy przód — FWD/sportowe FWD)
  48/52 → (48-50)/100 × 0.15 = -0.030000 (cięższy tył — RWD sportowe)
```

### 7. Korekta gripu na podstawie szerokości opony
```
fTractionCurveMax_final = fTractionCurveMax_base × współczynnik_opony

Tabela współczynników:
  Szerokość < 205mm:    × 0.92
  205–224mm:            × 0.96
  225–254mm:            × 1.00 (baza)
  255–274mm:            × 1.04
  ≥ 275mm:              × 1.08

Skąd wziąć szerokość opony? Z danych technicznych pojazdu.
Przykład: Supra A90 tylna opona 255/35 R19 → 255mm → × 1.04
  Base SPORT = 2.85 × 1.04 = 2.964 → zaokrąglij do 2.960000
```

---

## Tabela konwersji jednostek

| Z | Na | Mnożnik | Przykład |
|---|---|---|---|
| lbs → kg | kg | ÷ 2.2046 | 3181 lbs ÷ 2.2046 = 1443 kg |
| lb-ft → Nm | Nm | × 1.35582 | 369 lb-ft × 1.35582 = 500 Nm |
| mph → km/h | km/h | × 1.60934 | 155 mph × 1.60934 = 249 km/h |
| hp → kW | kW | × 0.7457 | 382 hp × 0.7457 = 285 kW |
| kW → hp | hp | × 1.3410 | 285 kW × 1.3410 = 382 hp |
| PS → hp | hp | × 0.9863 | 387 PS × 0.9863 = 382 hp |
| in → mm | mm | × 25.4 | 97.2 in × 25.4 = 2469 mm |

---

## Zależności między parametrami (mapa wpływów)

```
Zmiana fMass → wymaga korekty:
  fInitialDriveForce (bo: Torque / (masa × 9.81))
  fBrakeForce (bo: zmiana bezwładności przy hamowaniu)

Zmiana fTractionCurveMax → wymaga korekty:
  fBrakeForce (musi być ≤ TractionMax/4)
  fTractionCurveMin (= TractionMax × 0.72)

Zmiana fSuspensionForce → wymaga korekty:
  fSuspensionCompDamp (musi być = Force/2)
  fSuspensionReboundDamp (= Force × 0.55)

Zmiana vecCoM.Z (w górę) →
  Zwiększ fAntiRollBarForce o 0.2 na każde +0.05 CoM.Z
  Zwiększ fRollCentreHeightFront/Rear proporcjonalnie

Zmiana fDriveBiasFront →
  Korekta vecCoM.Y (FWD = przesunięcie do przodu)
  Korekta fTractionBiasFront (domyślnie 0.475 — przy silnym FWD daj 0.520)
```