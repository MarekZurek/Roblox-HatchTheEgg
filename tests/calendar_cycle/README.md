# Pełne cykle kalendarza

`build_oracle.py --check` sprawdza osobno wygenerowaną tabelę 280 oczekiwanych pozycji z docs/11/13/15 i rewards.json. Nie importuje kalkulatora produkcyjnego. `run.luau` wykonuje dziesięć pełnych 28-dniowych scenariuszy przez rzeczywiste ServerBootstrap, ClientTransport, ProtocolSchemas, koordynatora i zapis. Testuje nie tylko odpowiedź, lecz salda, ekwipunek, Epic, Piggy, znaczniki, widoki i ponowienia po każdym odbiorze.

Zegar, storage i początkowy profil są kontrolowanymi portami; nie zastępuje się domeny callbackiem sukcesu. Zerowe okno offline jest jawnym przypadkiem brzegowym izolującym kalendarz, bez zmiany bazowego silosu gry. Codzienne wyjście/wejście rzeczywiście zwalnia i pozyskuje sesję, zachowując stan poprzedniego dnia.

Oracle FV to uproszczone równanie z dokumentacji dla pustej farmy, bez wywołania testowanego kalkulatora. Dodatkowe przypadki obejmują zmianę jaja, księgowanie prestiżu, exact uint64, starsze profile i brak częściowych skutków awarii. Scenariusze z późnych cykli startują od jawnych fixture'ów; nie są udawaną symulacją całej wcześniejszej progresji.

Uruchomienie: `.tools/lune-0.11.1/lune.exe run tests/calendar_cycle/run.luau`; pełny zestaw z mutacjami: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Wynik lokalny w build/calendar-cycle-results.json. [Zakres dostawy i ograniczenia](../../docs/workflow/calendar_rewards_62.md).
