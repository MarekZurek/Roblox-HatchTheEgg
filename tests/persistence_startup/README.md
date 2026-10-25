# Regresje startu i płatności przy awarii zapisu

`run.luau` wykonuje rzeczywisty Main.server przez luau.load oraz sprawdza Bootstrap w środowisku runtime. Podmienione są usługi platformy, zegar/scheduler i wizualny WorldBuilder, aby nie wykonywać sieci, zakupów lub pętli renderowania. Serwer domeny, native adapter, koordynator i repozytorium pozostają rzeczywiste. Nie modyfikuje się tekstu Main, by pomijać jego gałęzie.

Oczekiwania wynikają z D07 i kontraktu zapisu: bez trwałego portu brak gotowego konta; błąd odczytu nie zeruje konta; niepotwierdzony zapis nie nadaje prawa do PurchaseGranted; zapisany sukces można odtworzyć raz. Testy obejmują wejście przed/po awarii, rzeczywistą obsługę receipt Main, restart i wyraźny lokalny tryb Studio bez płatności. Osobny test runtime nie ufa samemu deps.isStudio=true.

Uruchomienie: `.tools/lune-0.11.1/lune.exe run tests/persistence_startup/run.luau`. Pełny runner z mutacjami: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Raport lokalny: build/persistence-startup-results.json. Są to testy L z symulacją usług, bez Studio/chmury. [Zakres dostawy](../../docs/workflow/persistent_startup_57.md).
