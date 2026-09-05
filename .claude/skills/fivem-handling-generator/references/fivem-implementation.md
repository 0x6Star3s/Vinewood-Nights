# Implementacja handling.meta na serwer FiveM

## Struktura zasobu (resource)

```
/[nazwa_pojazdu]/
├── fxmanifest.lua          ← manifest zasobu
├── stream/
│   ├── [model].yft         ← model 3D pojazdu
│   └── [model].ytd         ← tekstury
└── data/
    ├── handling.meta       ← fizyka pojazdu (TU WKLEJASZ XML)
    ├── vehicles.meta       ← metadane pojazdu
    ├── carcols.meta        ← kolory i livery
    ├── carvariations.meta  ← warianty
    └── vehiclelayouts.meta ← pozycje siedzeń/kamer
```

## fxmanifest.lua (kompletny szablon)

```lua
fx_version 'cerulean'
game 'gta5'

lua54 'on'

files {
    'data/**/*.meta'
}

data_file 'HANDLING_FILE'          'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE'  'data/**/vehicles.meta'
data_file 'CARCOLS_FILE'           'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE'   'data/**/vehiclelayouts.meta'
```

## Kompletna struktura handling.meta

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CHandlingDataMgr>
  <HandlingData>
    <Item type="CHandlingData">
      <!-- TUTAJ WKLEJ WYGENEROWANY XML -->
    </Item>
  </HandlingData>
</CHandlingDataMgr>
```

## Krytyczny warunek: unikalny handlingName

handlingName w handling.meta MUSI być identyczny z handlingId w vehicles.meta.

```xml
<!-- handling.meta -->
<Item type="CHandlingData">
  <handlingName>SUPRA_A90_V1</handlingName>
  ...
</Item>

<!-- vehicles.meta — sekcja pojazdu -->
<Item type="CVehicleModelInfo__InitDataList">
  <modelName>supra</modelName>
  <handlingId>SUPRA_A90_V1</handlingId>
  ...
</Item>
```

Zasady nazewnictwa handlingName:
- MAX 14 znaków
- Tylko: A-Z, 0-9, _ (podkreślenie)
- Tylko WIELKIE LITERY
- Musi być UNIKALNY na całym serwerze

Zalecana konwencja: `[MARKA]_[MODEL]_V[N]`
Przykłady: SUPRA_A90_V1, BMW_M3_E92_V2, FORD_GT500_V1

## Procedura testowania po zmianie handlingu

⚠️ Dane handling są intensywnie buforowane przez FiveM.

Prawidłowa procedura (ZAWSZE):
1. `ensure [nazwa_zasobu]` w konsoli serwera
2. Usuń pojazd ze świata gry (/dv lub przez menu)
3. Poczekaj 3-5 sekund
4. Zespawnuj pojazd od nowa

NIE wystarczy: tylko ensure bez usunięcia pojazdu.
NIE wystarczy: tylko usunięcie bez ensure.

## Diagnoza problemów

| Objaw | Przyczyna | Rozwiązanie |
|---|---|---|
| Auto się nie pojawia / crash | Błąd składni XML | Sprawdź zagnieżdżenie tagów, brakujące cudzysłowy |
| Fizyka z innego auta | Konflikt handlingName | Zmień na unikalną nazwę w OBU plikach |
| Auto unosi przód przy gazie | fInitialDriveForce za wysoki | Zmniejsz o 0.05 |
| Auto wywraca się w zakrętach | CoM.Z za wysoki lub AntiRoll za niski | Obniż CoM.Z, podnieś AntiRollBarForce |
| Auto "skacze" na nierównościach | CompDamp ≠ Force/2 | Ustaw CompDamp = SuspensionForce/2 |
| Blokada kół przy hamowaniu | fBrakeForce > TractionMax/4 | Zmniejsz BrakeForce |
| Auto tonie bez zatrzymania silnika | fPercentSubmerged = 0 lub brak | Ustaw na 0.850000 |
| Zmiana biegów nie działa | fClutchChangeRate > 13.0 | Obniż do max 13.0 |
| Auto "teleportuje się" przy ruszaniu | fLowSpeedTractionLossMult za wysoki | Zmniejsz do max 1.0 |

## Optymalizacja tekstur (nie związana z handlingiem ale ważna)

Jeśli plik .ytd > 16 MB → gracze będą mieli błędy "Low Texture Memory".
Rozwiązanie: przeskaluj tekstury z 4K do 2K lub 1024×1024 używając OpenIV / Texture Toolkit.