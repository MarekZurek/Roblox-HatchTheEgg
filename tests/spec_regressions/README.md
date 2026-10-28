# Spec regressions and mutation evidence

Obowiązuje [kontrakt Roblox](../../docs/workflow/ROBLOX_TESTING_CONTRACT.md). Testy specyfikacji korzystają z niezależnych oczekiwań; zgodność z danymi referencyjnymi nie zatwierdza bilansu premiery.

Z katalogu repo, z Pythonem 3.10+ (w Codex można podać pełną ścieżkę do dostępnego runtime):

```powershell
python tests/spec_regressions/test_mutation_support.py
python tests/spec_regressions/mutation_check.py
python tests/spec_regressions/runner_fault_check.py
python tests/fresh_cash_purchases/mutation_check.py
python tests/game_behavior/mutation_check.py
# Pełny gate + wszystkie selektory domyślne:
./tools/test.ps1 -MutationChecks -PythonExecutable python
```

`mutation_check.py --only <nazwa>` w każdym z trzech runnerów Luau ogranicza wybór; selektor można powtarzać. Wszystkie domyślne przypadki są zarejestrowane w `tools/test.ps1 -MutationChecks`; normalny gate uruchamia też testy klasyfikatora i izolacji.

- 13 kontroli: brak deskryptora Common, cena kurnika +1%, błędny rabat Epic, błędne wysokie progi tierów, DomButton 1×1, serwerowe Epic, rezerwacja i nadanie WKRÓTCE, prestiż bez eventu, aktywny stary timer, ponowny dostęp do wycofanego badania, utrata passu 2× Cash i aktywacja wycofanego podwajacza.
- 6 kontroli świeżej gotówki i 42 istniejące kontrole zachowań korzystają ze wspólnego silnika izolacji.
- 11 testów Pythona sprawdza klasyfikację, konkretny przypadek asercji, zły baseline, timeout i izolację.
- 5 kontrolowanych błędów samej bramki sprawdzają, czy te testy naprawdę ją zatrzymają.

`KILLED` wymaga baseline exit0, negatywnego przebiegu zakończonego wskazaną asercją oraz ponownego exit0 po usunięciu błędu. Dla ogólnych komunikatów zapisano też oczekiwany numer przypadku w stacktrace; zmiana położenia/znaczenia testu wymaga review kontraktu, nie automatycznego dopasowania do nowego błędu. Pozostałe wyniki to SURVIVED/INVALID, które zatrzymują gate. Manifest przypina wersję i checksum Lune; skrypty nie pobierają narzędzi.

Raporty i pełne logi trafiają do ignorowanego `build/`; trwałe podsumowanie, źródła wymagań i ograniczenia są w [raporcie dostawy](../../docs/workflow/test_oracle_repairs_2026_10_28.md). Żaden runner nie zmienia roboczego `src/`, Studio, chmury ani płatności.
