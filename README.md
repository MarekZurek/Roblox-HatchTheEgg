# HatchTheEgg

Projekt gry Roblox. Wykonano i odebrano **IMP-01–15 oraz QA-01: kompletna podstawowa farma domowa (warsztat, NumericCodec, katalog, protokół, repozytorium sesji, produkcja, IHR, wylęg/RCB, koordynator, neutralna symulacja czasu, zakupy, gateway, projekcja widoków, transport i store klienta, trasy 3D, HUD, bootstrap oraz odbiór A01–A16)**. Łącznie 21 914 asercji PASS.

- [Bieżące uruchomienie i odbiór pierwszej farmy](docs/40_first_farm_completion_delivery.md)
- [Poprzednia dostawa IMP-08/09](docs/39_imp08_imp09_delivery.md)
- [NumericCodec](docs/36_imp01_numeric_codec_delivery.md)
- [Specyfikacja](docs/CURRENT_SPEC.md)
- [Indeks docs](docs/README.md)
- [Backlog](docs/32_parallel_delivery_backlog.md)
- [Issues i zależności](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/1)
- [Workflow i skills](docs/workflow/README.md)

W PowerShell: ./tools/bootstrap.ps1, następnie ./tools/test.ps1 -PythonExecutable python (Python 3.10+, stdlib). Narzędzia trafiają lokalnie do ignorowanego .tools, wyniki do build. Weryfikacja L nie oznacza testów Studio lub DataStore.

REFERENCE_ONLY nie jest konfiguracją wydania. Bilans pozostaje odłożony. Issue nie jest automatycznym zleceniem realizacji lub publikacji gry. [Zakres kopii publicznej](PUBLIC_EXPORT.md).

Poprawka [#56 — rzeczywiste operacje przycisków](docs/workflow/action_wiring_56.md) usuwa lokalne sukcesy i dodaje [testy oczekiwanego zachowania](tests/game_behavior/README.md). Pełne sprawdzenie wraz z siedmioma mutacjami: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Ograniczenia wydania nadal obowiązują: #57–61 i brak konfiguracji funkcji odłożonych. Wynik L nie oznacza gotowości całej gry.


[Kalendarz #62 — pełne 28 dni](docs/workflow/calendar_rewards_62.md): usunięto blokadę gotówki i Shell Scripts. Serwer rozlicza procent aktualnego FV farmy domowej i dokładny trwały licznik. Testy pełnych cykli oraz stare/nowe mutacje są częścią wspólnego runnera. Historyczna blokada #62 została usunięta; pozostałe ustalenia audytu to #57–61. Bilans i dane referencyjne nadal bez zmian.
