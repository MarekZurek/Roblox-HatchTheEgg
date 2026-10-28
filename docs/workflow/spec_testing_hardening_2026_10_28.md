# Niezależne oczekiwania i dowód regresji — 28.10.2026

Na zlecenie użytkownika wzmocniono test komunikatu FV oraz instrukcje testowania Roblox. Baza:cf383dc. Użytkownik następnie zlecił commit i push testów, skilli i dokumentacji; zdalne SHA jest potwierdzane po publikacji. Bez zmian kodu gry i publikacji Roblox.

## FV: wymaganie i dowód

Źródło: zatwierdzone zachowanie z `remaining_fixes_2026_10_28.md`, sekcja Zachowanie, opublikowane w cf383dc. Przy braku homeFV panel pokazuje brak wyceny i blokuje akcję; potwierdzone zero jest prawidłową wartością, a nie brakiem danych. Wartość sześciu milionów ma być widoczna jako6M i pozwalać na dostępny awans.

Dodano osiem asercji w tests/ui/run.luau. Oczekiwania są zapisane z wymagania, bez wywoływania badanego formattera lub lokalnego wzoru FV do obliczenia oczekiwanego wyniku.

- Izolowana zmiana `homeFV absent -> nil` na `homeFV absent -> 0`: **FAIL, exit1**, na konkretnej asercji `Missing FV is shown as unknown`.
- Ta sama wersja testu z poprawnym HUD: **PASS, exit0,452 asercje UI**.
- Stały przypadek `fv_missing_projection_invents_zero` dodano do istniejącego tests/game_behavior/mutation_check.py. Selektor `--only` pozwala uruchomić go bez powtarzania innych historycznych kontroli. Narzędzie odczytuje Lune i hash z tools/toolchain.json, zapisuje dokładny fault oraz hashe testu/źródła i sprawdza również pozytywny przebieg. Brak zamierzonej asercji lub nieprzechodzący baseline oznacza INVALID.
- Wykonane polecenie: Python z dostępnego runtime → `tests/game_behavior/mutation_check.py --only fv_missing_projection_invents_zero`. Wynik: **1/1 wybrana mutacja KILLED**, bez twierdzenia o pełnym mutation coverage. Dowód:build/game-behavior-mutations.json; wcześniejsza para FAIL/PASS:build/fv_contract_hardening_results.json.

## Skille i konfiguracja

Wspólny [kontrakt testowania Roblox](ROBLOX_TESTING_CONTRACT.md) określa pochodzenie wymagań i niezależnych oczekiwań, rozróżnienie testu specyfikacji od zgodności z katalogiem oraz obowiązkową regresję FAIL→PASS. Fault SURVIVED lub brak właściwego FAIL daje niepełny dowód; import/syntax failure i timeout nie są dowodem wykrycia błędu.

Zaktualizowano sześć workflow:dev-story,qa-plan,test-evidence-review,regression-suite,smoke-check,test-setup, wraz z właściwymi referencjami i test-standards. Kopie .agents/.claude są identyczne. Natywny hte-review-change również odsyła do kontraktu. Nie przebudowywano pozostałych skilli niezwiązanych z testowaniem.

Obsługa Roblox obejmuje tests/<suite>/run.luau, rejestrację w tools/test.ps1, istniejące przypadki do/for oraz przegląd pliku/issue/diff bez wymyślania story files. Usunięto ocenianie jakości według arbitralnej liczby asercji na helper i samej wzmianki o wzorze w komentarzu. Wymagane są obserwowalne kryteria, źródło oczekiwań i wynik negatywnej kontroli.

Konfiguracja project.yaml, AGENTS i lokalna referencja wersji zgadzają się z tools/toolchain.json:Rojo7.7.1/Lune0.11.1. Usunięto nieistniejące polecenie sync_studio.py; native Play i replikacja pozostają osobnym workflow Studio. Numeric-only smoke nie jest pełnym odbiorem gry.

## Weryfikacja i granice

- Sprawdzono podstawową strukturę siedmiu zmienionych entrypointów, sześć par kopii i referencje,43 lokalne linki oraz istnienie narzędzi wybranych z manifestu:PASS. Parser Pythona dla zmienionego mutation_check:PASS.
- Systemowy skill-creator quick_validate nie uruchomił się z powodu braku PyYAML w dostępnym runtime. Nie instalowano zależności; wykonano powyższe kontrole zastępcze. To sprawdzenie struktury i spójności, nie certyfikacja zachowania wszystkich modeli lub74 skilli.
- Pełny tools/test.ps1: **52 zestawy Luau +11 Python PASS, exit0**; UI452 asercje, Rojo **42 moduły +2 entrypointy PASS_STATIC_BUILD**. Log:build/spec_testing_hardening_full.log. Lune/fixture i statyczny build pozostają osobne od native Studio, pełnego strict typechecku oraz chmury.
- Bez zmian src, danych referencyjnych i odłożonego bilansu17–21. Wyniki ze starej wersji RCB nie stanowią wymagania przywrócenia wycofanej mechaniki.
