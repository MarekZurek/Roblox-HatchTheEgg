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

Poprawka [#56 — rzeczywiste operacje przycisków](docs/workflow/action_wiring_56.md) usuwa lokalne sukcesy i dodaje [testy oczekiwanego zachowania](tests/game_behavior/README.md). Pełne sprawdzenie wraz z siedmioma mutacjami: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Ograniczenia wydania nadal obejmują brak konfiguracji funkcji odłożonych i odbioru S/D/H. Wynik L nie oznacza gotowości całej gry.


[Kalendarz #62 — pełne 28 dni](docs/workflow/calendar_rewards_62.md): usunięto blokadę gotówki i Shell Scripts. Serwer rozlicza procent aktualnego FV farmy domowej i dokładny trwały licznik. Testy pełnych cykli oraz stare/nowe mutacje są częścią wspólnego runnera. Historyczna blokada #62 została usunięta; pozostałe ustalenia audytu to #57–61. Bilans i dane referencyjne nadal bez zmian.


[Awaria DataStore #57](docs/workflow/persistent_startup_57.md): produkcja wymaga trwałego storage, bez fallbacku do pamięci. Lokalny tryb wymaga Studio i jawnej flagi; płatności są w nim wyłączone. Testy obejmują rzeczywisty Main.server, start, wejście gracza, receipt, restart i zachowanie stanu po potwierdzonym retry. Kolejne ustalenia audytu opisano w późniejszych dostawach; bilans nadal odłożony.


[Polityka Pro #58](docs/workflow/pro_policy_58.md): +10 p.p. tylko przy aktualnej kwalifikacji konta; inne korzyści pozostają. 34 zestawy / 80 126 asercji L i 20 mutacji PASS. Bez testów Studio i rzeczywistych usług.


[Reset grup #59](docs/workflow/reset_group_ids_59.md): licznik hatch:N zachowany przy zmianie jaja i prestiżu, bez ponownego użycia identyfikatorów.


[Zakres weryfikacji #60](docs/workflow/release_evidence_60.md): lokalny PASS nie zatwierdza wydania. S/D/H niezweryfikowane per scenariusz. Narzędzie zapisuje PASS_LOCAL_CHECKS oraz releaseCandidateReady=false.


[Wydarzenia dochodu #61](docs/workflow/earnings_event_time_61.md): czas aktywności ważony wewnątrz kroku, bez dodatkowych faz IHR/boostów. Zakres lokalny L; brak zaliczenia S/D/H i zatwierdzenia wydania.


[Poprawki #63–65](docs/workflow/session_prestige_rcb_63_65.md): bez kolizji nowych zakupów po reconnect, event kolekcji SE przy prestiżu i aktywne RCB w produkcji/HUD. Pozostałe #66–70; bilans bez zmian i brak odbioru S/D/H.
