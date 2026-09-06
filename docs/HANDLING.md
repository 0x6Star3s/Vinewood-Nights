# handling.meta — co właściwie edytujemy

Research z 2026-09-03. Dwa źródła, oba sprawdzone:

1. **[GTAMods Wiki](https://gtamods.com/wiki/Handling.meta)** — opisy pól, jednostki, kierunek działania.
2. **`tools/vanilla/merged-handling.meta`** — 800 wpisów z GTA V, z tego **640 kołowych** i **504 osobowe** (900–3000 kg). To jest silniejsze źródło niż jakikolwiek poradnik: pokazuje, jakie wartości Rockstar faktycznie wysyła do gry.

Kolumny p1 / mediana / p99 poniżej liczone są z tych 504 aut osobowych. Wartość poza p1–p99 nie jest automatycznie błędem, ale wymaga uzasadnienia.

## Napęd i prędkość

| pole | co robi | p1 | mediana | p99 |
|---|---|---|---|---|
| `fMass` | masa w kg. Liczy się **tylko przy kolizjach** z autem lub obiektem niestatycznym — nie wpływa na przyspieszenie wprost | 900 | 1600 | 2800 |
| `fInitialDragCoeff` | opór powietrza, proporcjonalny do kwadratu prędkości. Wyżej = niższa prędkość maksymalna | 5.9 | 9.1 | 26 |
| `fDriveBiasFront` | 0.0 = tylny, 1.0 = przedni, pomiędzy = 4×4 | 0 | 0 | 1 |
| `nInitialDriveGears` | liczba biegów. **Pole całkowite** — ułamek psuje parsowanie | 1 | 5 | 8 |
| `fInitialDriveForce` | siła napędowa na kołach, `moment na kołach [Nm] / masa [kg]` | 0 | 0.29 | 0.72 |
| `fDriveInertia` | jak szybko silnik kręci na obrotach. Nie zmienia mocy, zmienia tempo dochodzenia do odcięcia | 0.3 | 1.0 | 1.1 |
| `fInitialDriveMaxFlatVel` | prędkość na odcięciu najwyższego biegu. **× 1.32 = km/h w grze**, × 0.82 = mph | 105 | 145 | 170 |
| `fClutchChangeRateScaleUpShift` | szybkość zmiany biegu w górę; 1 = 0.9 s | 1.2 | 2.2 | 9 |
| `fClutchChangeRateScaleDownShift` | to samo przy redukcji | 1.2 | 2.2 | 9 |

Mediana `fInitialDriveMaxFlatVel` 145 to **191 km/h** w grze, p99 = 170 to **224 km/h**. Szybszych aut Rockstar nie robi.

## Hamowanie i skręt

| pole | co robi | p1 | mediana | p99 |
|---|---|---|---|---|
| `fBrakeForce` | mnożnik opóźnienia. Wyżej = mocniej hamuje | 0.25 | 0.8 | 1.28 |
| `fBrakeBiasFront` | rozkład siły hamowania. 0 = tylko tył, 1 = tylko przód | 0.22 | 0.55 | 0.7 |
| `fHandBrakeForce` | siła hamulca ręcznego | 0.3 | 0.6 | 1.2 |
| `fSteeringLock` | maksymalny kąt skrętu kół w stopniach | 30 | 40 | 78 |

## Przyczepność

| pole | co robi | p1 | mediana | p99 |
|---|---|---|---|---|
| `fTractionCurveMax` | szczytowa przyczepność, **zanim** koło się przełamie | 1.53 | 2.30 | 3.3 |
| `fTractionCurveMin` | przyczepność **po** przełamaniu, w poślizgu | 1.25 | 2.05 | 3.3 |
| `fTractionCurveLateral` | kształt krzywej bocznej; szczyt przyczepności wypada przy `wartość / 2` stopni znoszenia | 14.5 | 22.5 | 29.5 |
| `fTractionSpringDeltaMax` | maks. ugięcie boku opony w metrach | 0.02 | 0.15 | 0.18 |
| `fLowSpeedTractionLossMult` | utrata przyczepności przy niskiej prędkości; 0 = brak buksowania przy ruszaniu | 0 | 1.0 | 1.7 |
| `fTractionBiasFront` | rozkład przyczepności. **0.01 = tylko tył, 0.99 = tylko przód** — wyżej znaczy mniejsza nadsterowność | 0.45 | 0.49 | 0.512 |
| `fTractionLossMult` | jak mocno nawierzchnia wpływa na przyczepność | 0 | 1.0 | 1.2 |
| `fCamberStiffnesss` | **w vanilla ZAWSZE 0.000, we wszystkich 640 autach.** Nie ruszać | 0 | 0 | 0 |

Różnica `Max − Min` to gwałtowność przełamania. Mała różnica = auto łagodnie zjeżdża w poślizg i da się je złapać. Duża = grip znika nagle.

`fTractionBiasFront` ma **najwęższy zakres z całego pliku**: 0.45–0.512. Zmiana o 0.02 to dużo.

## Zawieszenie i przechyły

| pole | co robi | p1 | mediana | p99 |
|---|---|---|---|---|
| `fSuspensionForce` | siła sprężyn; `1 / (Force × liczba kół)` = granica zerowej siły przy pełnym wyprężeniu | 1.0 | 2.1 | 2.95 |
| `fSuspensionCompDamp` | tłumienie przy ściskaniu. Wyżej = sztywniej | 0.7 | 1.3 | 2.0 |
| `fSuspensionReboundDamp` | tłumienie przy odbiciu | 0.9 | 2.1 | 4.3 |
| `fSuspensionUpperLimit` | ile koło może iść w górę od pozycji z modelu | 0.025 | 0.09 | 0.25 |
| `fSuspensionLowerLimit` | ile w dół | −0.26 | −0.11 | −0.05 |
| `fSuspensionRaise` | podniesienie nadwozia względem kół | 0 | 0 | 0.075 |
| `fSuspensionBiasFront` | rozkład tłumienia przód/tył; >0.50 = sztywniejszy przód | 0.42 | 0.5 | 0.58 |
| `fAntiRollBarForce` | stabilizator — siła przenoszona na przeciwne koło. **Wyżej = mniejszy przechył** | 0 | 0.7 | 1.25 |
| `fAntiRollBarBiasFront` | rozkład stabilizatora; wiki: 0 = przód, 1 = tył | 0 | 0.55 | 0.85 |
| `fRollCentreHeightFront` | wysokość środka przechyłu przedniej osi, **liczona od drogi**, w metrach. Wyżej = mniejszy przechył | 0 | 0.23 | 0.67 |
| `fRollCentreHeightRear` | to samo dla tylnej osi | 0 | 0.22 | 0.6 |

## Pola wektorowe

| pole | co robi | p1 | mediana | p99 |
|---|---|---|---|---|
| `vecCentreOfMassOffset` z | środek ciężkości; **dodatnie = w górę**, czyli większy przechył. Skrajne minusy (−10) rozwalają fizykę | −0.42 | **0.00** | 0.25 |
| `vecInertiaMultiplier` z | opór przed obrotem wokół osi pionowej. Wyżej = auto wolniej się obraca, ale i wolniej przestaje | 1.0 | 1.55 | 2.0 |

Mediana `comZ` to dokładnie **0.00** — Rockstar praktycznie nie rusza tego pola, przechyły stroi stabilizatorem i wysokością środka przechyłu.

## Pułapki, na które już wpadliśmy

**Pola `n*` są całkowite.** `nInitialDriveGears value="8.000000"` nie parsuje się poprawnie — auto dostaje śmieciową liczbę biegów, wpada na ogranicznik w pierwszym i stoi na 70–80 km/h. Naprawione w `handling_fix.py` (`setv`), 71 plików przeliczonych.

**Pola wektorowe nie mają atrybutu `value`.** `comZ` i `inertiaZ` siedzą jako `z="..."` w `vecCentreOfMassOffset` / `vecInertiaMultiplier`. Zwykły regex po `value="` je pomija — `TUNE` przez to długo nic z nimi nie robił.

**`fRollCentreHeight` i `comZ` są w różnych układach odniesienia** — pierwsze od drogi, drugie od środka modelu. Odejmowanie ich od siebie („ramię przechyłu") nie ma sensu. Obie zmiany w stronę mniejszego przechyłu to: `rollCentre` **wyżej** i `comZ` **niżej**.

**Powyżej 8 biegów.** Wartości 9–10 działają dopiero od buildu 1.0.1604, ale wychodzą poza tablicę przełożeń i psują redukcję. [Dokumentacja](https://gtamods.com/wiki/Handling.meta) odradza. Mamy 17 takich aut.

**Szablon klasy nie skaluje się z masą.** Te same sprężyny pod autem o 40% cięższym dają miękkie zawieszenie i przechyły. Stąd `--scale-mass` w `handling_match.py`.

## Odchylenia naszej floty od vanilla

Stan 2026-09-03, 79 aut osobowych w `[addon]`:

| pole | ile aut poza p1–p99 | najgorsze | ocena |
|---|---|---|---|
| `fInitialDriveMaxFlatVel` | **71** | 185 (limit z `handling_tune`) przy vanilla max 170 | świadome — nasze auta mają jeździć szybciej niż vanilla |
| `nInitialDriveGears` | **17** | Escalade 10, Mercedesy 9 | do zbicia na 8, patrz wyżej |
| `fDriveInertia` | 5 | 16CHARGER 1.6, AGERARS 1.6 przy vanilla max 1.1 | drobne |
| `fHandBrakeForce` | 2 | **MOBM23 = 7.3** przy vanilla max 1.2 | prawie na pewno literówka moddera |
| `fClutchChangeRateScaleUpShift` | 2 | RRST 12 | drobne |
| `fSuspensionBiasFront` | 3 | OYCS8 0.6, RS7R 0.4 | drobne |
| `fSuspensionForce` | 1 | M4C 3.02 przy p99 2.95 | skutek `--scale-mass`, 2% ponad |

## Jak to się mapuje na narzędzia

`tools/handling_fix.py` — tabela `G` to ręczne zakresy clampowania. Powinny odpowiadać kolumnom p1–p99 z tego dokumentu; brakowało w niej `fHandBrakeForce`, dlatego MOBM23 z siłą 7.3 przeszedł przez wszystkie przebiegi.

`tools/handling_tune.py` — wzory z `derive()` liczą tożsamość auta z realnych danych. Zawieszenia i przyczepności nie da się z nich policzyć, bo to nie wynika z danych fabrycznych, tylko z tego, jak Rockstar stroi fizykę.

`tools/handling_match.py` — dlatego „czucie" bierzemy z gotowego auta vanilla, a wzorami liczymy tylko to, czym auta mają się różnić.
