# Patche na zasoby zewnętrzne

Zasoby w `txData/resources/[local]/` są podmodułami git wskazującymi na repozytoria
autorów. Lokalne zmiany nie mogą być tam zacommitowane, więc leżą tutaj jako patche.

Nałożenie po sklonowaniu:

```
git submodule update --init --recursive
git -C "txData/resources/[local]/jg-vehicleindicators" apply ../../../../patches/jg-vehicleindicators-hardening.patch
```

- `jg-vehicleindicators-hardening.patch` — walidacja zdarzenia sieciowego
  `jg-vehicleindicators:server:set-state` i ograniczenie sterowania kierunkowskazami
  do kierowcy pojazdu.
