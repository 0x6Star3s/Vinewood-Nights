# Narzedzia do pojazdow (Python 3 + numpy)

    python tools/ytd_inspect.py  "txData/resources/[addon]"            # co siedzi w .ytd: wymiary, format, mipmapy, MiB
    python tools/ytd_optimize.py "txData/resources/[addon]"            # dry run: plan i oszczednosci
    python tools/ytd_optimize.py "txData/resources/[addon]" --apply    # przepisuje pliki, backup w backups/ytd-<data>/
    python tools/ytd_optimize.py <plik.ytd> --out test --max 1024      # kopia testowa jednego auta
    python tools/handling_audit.py                                     # tabela handlingu vs zakresy vanilla (handling_report.json)
    python tools/handling_fix.py "txData/resources/[addon]"            # dry run: co zmieni tryb clamp
    python tools/handling_fix.py "txData/resources/[addon]" --mode template --only tenf
    python tools/handling_fix.py "txData/resources/[addon]" --apply    # zapis, backup w backups/handling-<data>/
    python tools/handling_tune.py --apply                              # SPECS (masa/KM/vmax/naped/biegi/klasa) -> szablon klasy + wzory; jedna komenda, idempotentna

Po zmianie handlingu: `restart <zasob>`, usunac auto (/dv) i zespawnowac od nowa.
Po zmianie .ytd: `restart <zasob>`; gracz musi sie polaczyc ponownie (cache klienta).

Stan 2026-09-02 wieczor: ytd_optimize.py ZWERYFIKOWANY w grze na tenf (128 -> 96 MiB, auto renderuje sie poprawnie).
Reguly formatu RSC7, ktore musialy byc spelnione: stride = szerokosc * bpp/8; zadna tekstura nie przekracza strony pamieci; pole 0x40 = liczba stron 4 KiB;
gorne 4 bity flag graficznych = wersja zasobu (13). Wzorzec porownawczy: plik z gtax.dev (backups/gtax-in, Desktop/subarung.ytd).
