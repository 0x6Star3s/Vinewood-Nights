# Presety klasowe — szczegółowe tabele wartości

## Spis treści
- [Presety klasowe — szczegółowe tabele wartości](#presety-klasowe--szczegółowe-tabele-wartości)
  - [Spis treści](#spis-treści)
  - [SPORT / Supercar](#sport--supercar)
  - [HYPERCAR](#hypercar)
  - [Classic Muscle](#classic-muscle)
  - [Sedan / Hatchback](#sedan--hatchback)
  - [SUV / Crossover](#suv--crossover)
  - [Truck / Pickup](#truck--pickup)
  - [Tabela porównawcza](#tabela-porównawcza)

---

## SPORT / Supercar

**Przykłady:** Toyota GR Supra, BMW M3/M4, Porsche 911, Nissan GT-R, Honda NSX,
Chevrolet Corvette, Audi R8

**Filozofia handlingu:** Precyzja i bezpośrednia odpowiedź. Mała tendencja do
nadsterowności, wysokie limity przyczepności, sztywne zawieszenie.

| Parametr | GRIP | NEUTRAL | DRIFT | Uwagi |
|---|---|---|---|---|
| fInitialDragCoeff | 3.20 | 3.20 | 3.50 | Wyższy drag = niższa V-max |
| fDownforceModifier | 12.50 | 8.00 | 5.00 | Dynamic downforce |
| fDriveInertia | 1.30 | 1.20 | 1.40 | Szybka reakcja silnika |
| fClutchUp / Down | 8.0 / 7.0 | 6.0 / 5.5 | 10.0 / 8.0 | |
| fBrakeForce | 1.20 | 1.10 | 0.90 | ≤ TractionMax/4 |
| fBrakeBiasFront | 0.620 | 0.620 | 0.580 | |
| fSteeringLock | 30.0 | 32.0 | 35.0 | Ostry skręt |
| fTractionCurveMax | 2.85 | 2.70 | 2.40 | |
| fTractionCurveMin | 2.05 | 1.94 | 1.73 | = Max × 0.72 |
| fTractionCurveLateral | 18.0 | 22.5 | 28.0 | Niski = precyzyjny |
| fTractionLossMult | 1.50 | 1.30 | 1.20 | Słaby off-road |
| fLowSpeedTractionLoss | 0.00 | 0.30 | 0.80 | |
| fCamberStiffnesss | 0.000 | 0.000 | -0.500 | |
| fSuspensionForce | 3.20 | 2.80 | 2.50 | |
| fSuspensionCompDamp | 1.60 | 1.40 | 1.25 | = Force / 2 |
| fSuspensionReboundDamp | 1.76 | 1.54 | 1.38 | = Force × 0.55 |
| fSuspensionUpperLimit | 0.080 | 0.090 | 0.100 | Metry |
| fSuspensionLowerLimit | -0.090 | -0.100 | -0.110 | Metry, ujemne |
| fAntiRollBarForce | 1.40 | 1.00 | 0.60 | |
| fAntiRollBarBiasFront | 0.550 | 0.530 | 0.420 | |
| fRollCentreHeightFront | 0.250 | 0.220 | 0.180 | |
| fRollCentreHeightRear | 0.200 | 0.180 | 0.150 | |
| vecCoM.Z | -0.080 | -0.060 | -0.050 | Niska sylwetka |
| vecInertia.Z | 1.60 | 1.70 | 1.50 | |

---

## HYPERCAR

**Przykłady:** Bugatti Chiron/Veyron, Koenigsegg Agera/Jesko, McLaren P1,
Lamborghini Revuelto, Ferrari LaFerrari, Pagani Huayra, Rimac Nevera

**Filozofia:** Ekstremalne osiągi, aktywna aerodynamika, najwyższy grip.

| Parametr | Wartość | Uwagi |
|---|---|---|
| fInitialDragCoeff | 2.00 | Najlepsza aerodynamika |
| fDownforceModifier | 25.0–120.0 | Dynamic lub New-style |
| fDriveInertia | 1.60 | Bardzo szybka reakcja |
| fClutchUp / Down | 12.0 / 10.0 | Niemal natychmiastowa zmiana |
| fBrakeForce | 1.60 | Ceramiczne hamulce |
| fBrakeBiasFront | 0.650 | |
| fTractionCurveMax | 3.20 | Najwyższy grip |
| fTractionCurveLateral | 16.0 | Bardzo wąskie okno — precyzja |
| fSuspensionForce | 3.80 | Twarde jak kamień |
| fSuspensionCompDamp | 1.90 | = 3.80 / 2 |
| fSuspensionUpperLimit | 0.050 | Minimalny skok |
| fAntiRollBarForce | 1.80 | Minimalizacja przechyłów |
| vecCoM.Z | -0.100 | Najniższy CoM |
| vecInertia.Z | 1.40 | Najbardziej bezpośrednia odpowiedź |

---

## Classic Muscle

**Przykłady:** Ford Mustang GT/Shelby, Dodge Challenger/Charger, Chevrolet Camaro,
Pontiac GTO, Dodge Viper, Chrysler 300C

**Filozofia:** Duży moment obrotowy, tylny napęd, miękkie zawieszenie, łatwy poślizg.
Auto "żywe" na tylnej osi, klasyczny American muscle feel.

| Parametr | GRIP | NEUTRAL | DRIFT | Uwagi |
|---|---|---|---|---|
| fInitialDragCoeff | 5.50 | 5.50 | 6.00 | Wyższy opór = bardziej realistyczny |
| fDownforceModifier | 0.50 | 0.30 | 0.10 | Minimal downforce |
| fDriveInertia | 0.90 | 0.85 | 1.00 | Ciężkie koło zamachowe |
| fClutchUp / Down | 4.0 / 3.5 | 4.0 / 3.5 | 5.0 / 4.0 | Wolna zmiana |
| fBrakeForce | 0.85 | 0.80 | 0.70 | Słabsze hamulce |
| fBrakeBiasFront | 0.580 | 0.560 | 0.540 | |
| fSteeringLock | 35.0 | 36.0 | 38.0 | Szerszy skręt |
| fTractionCurveMax | 2.15 | 2.00 | 1.80 | Niższy grip = łatwiejszy poślizg |
| fTractionCurveMin | 1.55 | 1.44 | 1.30 | |
| fTractionCurveLateral | 25.5 | 27.0 | 30.0 | Szeroki kąt = drift-friendly |
| fTractionLossMult | 1.20 | 1.10 | 1.00 | |
| fLowSpeedTractionLoss | 0.30 | 0.60 | 1.00 | Łatwy burnout |
| fCamberStiffnesss | 0.000 | -0.200 | -0.600 | |
| fSuspensionForce | 1.80 | 1.70 | 1.60 | Miękkie zawieszenie |
| fSuspensionCompDamp | 0.90 | 0.85 | 0.80 | = Force / 2 |
| fSuspensionReboundDamp | 0.99 | 0.94 | 0.88 | |
| fSuspensionUpperLimit | 0.150 | 0.160 | 0.170 | Duży skok |
| fSuspensionLowerLimit | -0.130 | -0.140 | -0.150 | |
| fAntiRollBarForce | 0.50 | 0.40 | 0.25 | Duże przechyły — charakter muscle |
| fAntiRollBarBiasFront | 0.520 | 0.480 | 0.420 | |
| fRollCentreHeightFront | 0.100 | 0.090 | 0.080 | |
| fRollCentreHeightRear | 0.080 | 0.070 | 0.060 | |
| vecCoM.Y | +0.050 | +0.050 | +0.030 | Cięższy przód (duży silnik z przodu) |
| vecCoM.Z | +0.020 | +0.015 | +0.010 | Lekko wyższy CoM |
| vecInertia.Z | 2.00 | 1.90 | 1.80 | Ociężały yaw |

---

## Sedan / Hatchback

**Przykłady:** BMW 3-series/5-series, Audi A4/A6, Mercedes C/E-class,
VW Golf GTI/R, Honda Civic Type R, Subaru WRX/STI, Mitsubishi Evo

**Filozofia:** Balans komfort/dynamika. Przewidywalne zachowanie, dobry dla RP.

| Parametr | FWD | RWD | AWD | Uwagi |
|---|---|---|---|---|
| fInitialDragCoeff | 5.00 | 5.00 | 5.20 | |
| fDriveInertia | 1.00 | 1.00 | 1.10 | Standardowy |
| fClutchUp / Down | 5.0 / 4.5 | 5.0 / 4.5 | 5.5 / 5.0 | |
| fBrakeForce | 1.00 | 1.00 | 1.05 | |
| fBrakeBiasFront | 0.630 | 0.610 | 0.620 | |
| fTractionCurveMax | 2.40 | 2.35 | 2.50 | AWD = więcej gripu |
| fTractionCurveLateral | 22.5 | 22.5 | 22.5 | Standardowy kąt |
| fTractionLossMult | 1.20 | 1.30 | 0.90 | AWD lepszy off-road |
| fSuspensionForce | 2.40 | 2.20 | 2.40 | |
| fSuspensionCompDamp | 1.20 | 1.10 | 1.20 | |
| fSuspensionUpperLimit | 0.120 | 0.120 | 0.110 | |
| fSuspensionLowerLimit | -0.120 | -0.120 | -0.110 | |
| fAntiRollBarForce | 0.80 | 0.75 | 0.90 | |
| fRollCentreHeightFront | 0.200 | 0.200 | 0.210 | |
| vecCoM.Z | 0.000 | -0.020 | 0.000 | |
| vecInertia.Z | 1.80 | 1.80 | 1.90 | |

---

## SUV / Crossover

**Przykłady:** Mercedes G-Class, Range Rover, Porsche Cayenne, BMW X5/X6,
Jeep Grand Cherokee, Land Rover Defender, Toyota Land Cruiser

**Filozofia:** Wysoki środek ciężkości wymaga kompensacji. Kluczowe:
antiRollBarForce ≥ 1.0 i rollCentreHeight ≥ 0.35 żeby nie wywracać.

| Parametr | Road SUV | Off-road | Sport SUV | Uwagi |
|---|---|---|---|---|
| fInitialDragCoeff | 8.50 | 10.0 | 7.00 | Wysoki opór |
| fDownforceModifier | 0.10 | 0.00 | 2.00 | |
| fDriveInertia | 1.10 | 0.90 | 1.20 | |
| fClutchUp / Down | 4.5 / 4.0 | 3.5 / 3.0 | 5.0 / 4.5 | |
| fBrakeForce | 1.00 | 0.90 | 1.10 | |
| fBrakeBiasFront | 0.550 | 0.520 | 0.570 | Niższy = stabilniejszy tył |
| fTractionCurveMax | 2.25 | 2.10 | 2.50 | |
| fTractionCurveLateral | 26.0 | 28.0 | 22.0 | Szerszy = łatwiejszy w terenie |
| fTractionLossMult | 0.70 | 0.35 | 0.90 | |
| fSuspensionForce | 2.10 | 1.80 | 2.40 | Soft dla terenu |
| fSuspensionCompDamp | 1.05 | 0.90 | 1.20 | = Force / 2 |
| fSuspensionUpperLimit | 0.220 | 0.320 | 0.180 | Duży skok terenowy |
| fSuspensionLowerLimit | -0.180 | -0.260 | -0.150 | |
| fAntiRollBarForce | 1.00 | 0.70 | 1.30 | ⚠️ Min 1.0 dla road SUV |
| fRollCentreHeightFront | 0.400 | 0.450 | 0.380 | ⚠️ Min 0.35 |
| fRollCentreHeightRear | 0.380 | 0.430 | 0.360 | |
| vecCoM.Y | 0.000 | +0.020 | -0.020 | |
| vecCoM.Z | +0.050 | +0.080 | +0.030 | Wysoki CoM |
| vecInertia.Z | 2.20 | 2.40 | 2.00 | Ociężały skręt |

---

## Truck / Pickup

**Przykłady:** Ford F-150/F-250, RAM 1500/2500, Chevrolet Silverado,
Toyota Tundra, Dodge Ram, GMC Sierra

| Parametr | Light Truck | Heavy Truck | Uwagi |
|---|---|---|---|
| fInitialDragCoeff | 11.0 | 14.0 | Bardzo wysoki opór |
| fDriveInertia | 0.80 | 0.70 | Wolne diesle |
| fBrakeForce | 0.80 | 0.70 | |
| fBrakeBiasFront | 0.520 | 0.500 | |
| fTractionCurveMax | 1.90 | 1.80 | Niski grip |
| fTractionLossMult | 0.60 | 0.45 | Dobry off-road |
| fSuspensionForce | 1.60 | 1.40 | Miękkie |
| fSuspensionCompDamp | 0.80 | 0.70 | |
| fSuspensionUpperLimit | 0.280 | 0.320 | |
| fSuspensionLowerLimit | -0.220 | -0.260 | |
| fAntiRollBarForce | 0.70 | 0.60 | |
| fRollCentreHeightFront | 0.450 | 0.480 | |
| vecCoM.Z | +0.080 | +0.100 | Bardzo wysoki CoM |
| vecInertia.Z | 2.40 | 2.60 | Bardzo ociężały |

---

## Tabela porównawcza

Szybkie odniesienie — wartości dla profilu NEUTRAL każdej klasy:

| Parametr | HYPERCAR | SPORT | MUSCLE | SEDAN | SUV | TRUCK |
|---|---|---|---|---|---|---|
| fInitialDragCoeff | 2.0 | 3.2 | 5.5 | 5.0 | 8.5 | 11.0 |
| fTractionCurveMax | 3.20 | 2.85 | 2.15 | 2.40 | 2.25 | 1.90 |
| fTractionCurveLateral | 16.0 | 18.0 | 25.5 | 22.5 | 26.0 | 28.0 |
| fSuspensionForce | 3.80 | 3.20 | 1.80 | 2.40 | 2.10 | 1.60 |
| fAntiRollBarForce | 1.80 | 1.40 | 0.50 | 0.80 | 1.00 | 0.70 |
| vecCoM.Z | -0.10 | -0.08 | +0.02 | 0.00 | +0.05 | +0.08 |
| vecInertia.Z | 1.40 | 1.60 | 2.00 | 1.80 | 2.20 | 2.40 |
| fInitialDriveForce cap | 0.60 | 0.42 | 0.38 | 0.32 | 0.28 | 0.22 |