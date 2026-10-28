# Naprawa oczekiwań testów i dowodów mutacji — 28.10.2026

Baza: `57cd5b9348fc36d91d474c1e670767f78c74b4d0`. Zakres zlecony po review: pięć potwierdzonych luk, klasyfikacja i izolacja mutacji, bieżące opisy RCB oraz dowody FAIL→PASS dla remaining_fixes i retired_doubler. Bez zmian mechanik w src, bilansu docs17–21, danych referencyjnych, Studio, chmury lub publikacji Roblox. Użytkownik następnie zlecił commit i push testów, runnerów, dokumentacji oraz dowodów; zdalne SHA jest potwierdzane po wysłaniu.

## Wymaganie → niezależne oczekiwanie → regresja

Wszystkie źródła w tej tabeli odnoszą się do wersji bazy 57cd5b9, z pierwszeństwem aktualnych decyzji R w CURRENT_SPEC. Kwoty i progi z danych S/N są kontrolą zgodności referencyjnej, nie zatwierdzeniem cennika premiery.

| Źródło / kryterium | Fixture, obserwacja i niezależne oczekiwanie | Kontrolowany błąd |
|---|---|---|
| UI podglądów badań, upgrade_ui_2026_10_26 + docs/01 / research.json | Każde Common na 0/MAX: zbiór kluczy z niezależnego JSON, brak brakujących/obcych/zdublowanych efektów; osobno wartości current/next | Wycięte effects dla excoskeletons |
| docs/03–04, infrastruktura referencyjna | Cena kolejnego egzemplarza z surowego infrastructure.json, poza API CatalogRegistry; zakup i reszta portfela | habitatPrice zawyżone o 1% |
| docs/01: zniżki Epic | 5 poziomów ×5 p.p. → 0.75 kosztu kurnika; 4 poziomy → 0.80 kosztu badań; nie epicEffects jako oracle | Błędny habCostMult na poziomie5 |
| docs/01, progi tierów | Jawne progi 0..1655; poprawne profile punktów poniżej/na/powyżej każdego progu | Progi tier>=3 zmienione na9999 |
| top_rates_panel_2026_10_26: zachowane cele dotykowe | Rzeczywiste właściwości utworzonych DomButton44×44 i AudioToggleButton48×48 oraz IgnoreGuiInset=false | DomButton1×1, drugi przycisk44×44 nadal w pliku |
| remaining_fixes_2026_10_28: nieobsługiwane Epic | Odrzucenie komendy, brak debitu/grantu i zachowanie dawnych poziomów | Pominięta serwerowa polityka Epic |
| Ten sam kontrakt: WKRÓTCE | Brak nowej rezerwacji oraz brak nadania dawnej niezatwierdzonej rezerwacji | Osobno pominięta bramka prepare i confirm |
| docs/05 + remaining_fixes: event prestiżu | 3000000^.15 ×4 w oknie eventu, ×1 od deadline; grant i delta po wygaśnięciu | Podgląd ignoruje event |
| Decyzja R: remove_timed_doubler_2026_10_28 | Legacy timer neutralny również w publicznym API efektów; aktywacja odrzucona; brak zakupu; stare pola pozostają | Timer daje ×2, aktywacja dozwolona, badanie ponownie dostępne |
| Ta sama decyzja: zachować pass double_cash | 30 kur ×1/30 jaj/s ×$1.25 ×3s ×2 =7.5, osobno portfel i księga | Pass2× Cash wyłączony w produkcji |
| ROBLOX_TESTING_CONTRACT: kontrolowana regresja | Callback ProcessReceipt istnieje przed wywołaniem; jego brak zatrzymuje konkretną asercję | Brak zainstalowanego handlera; dawniej kończył się wywołaniem nil |
| fresh_cash_purchase_fix_2026_10_26 | Świeży dochód i zakup w jednym commicie; replay/checkpoint/reconnect bez utraty lub duplikacji | 6 istniejących błędów granicy transakcji |

## Zmiany runnerów

Wspólny tools/mutation_support.py wykonuje baseline, błąd i ponowne wykonanie po przywróceniu kopii. Kopiowane są src, testy i potrzebne dane referencyjne; pliki robocze nie są mutowane. Lune i jego SHA pochodzą z tools/toolchain.json (0.11.1). Każdy raport zawiera dokładny fault, komendy/exit, pierwszą zawodzącą asercję, hashe testu/źródła oraz ścieżki logów trzech przebiegów.

KILLED wymaga pierwszego błędu ze wskazanego zestawu, oczekiwanego komunikatu i — dla starszych ogólnych komunikatów — konkretnego miejsca wywołania asercji. Obca asercja, wywołanie nil, składnia/import, timeout albo zły baseline nie stanowią dowodu. SURVIVED/INVALID zatrzymuje gate. 11 testów Pythona obejmuje te warunki i sprawdza, że źródło robocze pozostaje nietknięte. Pięć mutacji samego runnera stanowią dodatkową kontrolę FAIL→PASS.

Podczas kontroli nowy błąd timera początkowo przetrwał retired_doubler: Bootstrap usuwa historyczny timer z wejścia do obliczeń. Test rozszerzono więc o bezpośrednie publiczne API efektów i odrzucenie aktywacji, zachowując integracyjny wynik 7.5 i pass2× Cash. Nie zmieniono kodu gry.

## RCB

Opisy w rcb_income, session_prestige_rcb i README odpowiadają docs/31 §3: dochód ma stały mnożnik badań, niezależny od runningCount, również away. Dotarcia zwiększają przyszłą produkcję przez zasiedlenie. Usunięto nieaktualne opisy wzrostu RCB do limitu, powrotu neutralnego mnożnika po dotarciu oraz martwe if true/else w teście. Historyczne nazwy plików, pól i API pozostają dla ciągłości.

## Wykonanie i dowody

Polecenia odtwarzania: [tests/spec_regressions/README.md](../../tests/spec_regressions/README.md). Lokalny Python: C:/Users/Marek/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe; Lune0.11.1 i Rojo7.7.1 z manifestu.

Wyniki końcowe:

- Pełny tools/test.ps1: **52 zestawy Luau PASS**, 11 testów Python raportowania PASS, Rojo **42 moduły +2 entrypointy PASS_STATIC_BUILD**, exit0. Końcowy zestaw testów samego runnera: **11/11 PASS** (odrębne uruchomienie po dodaniu kontroli identycznego komunikatu z innego miejsca).
- Nowe kontrole wskazanych luk i brakujących dowodów: **13/13 KILLED**, baseline0 → mutant1 na zamierzonej asercji → corrected0. W tym wszystkie pięć wcześniej przepuszczanych błędów.
- Świeża gotówka: **6/6 KILLED** w kopiach, bez zmiany źródła roboczego; transakcja, postęp, retry, checkpoint i replay nadal sprawdzone.
- Istniejące zachowania: **42/42 KILLED**, z kontrolowaną asercją braku ProcessReceipt zamiast dawnego wywołania nil.
- Sam runner: **5/5 celowych błędów wykrytych** — zła lokalizacja asercji, crash uznany za kill, obca asercja, zły baseline oraz zapis do źródła roboczego.
- verify_evidence.py: **61 mutacji semantycznych +5 mutacji bramki PASS**. Weryfikator ponownie sklasyfikował wszystkie logi finalnym klasyfikatorem, łącznie z numerami przypadków, i porównał hash całego src oraz właściwych fixture/wsparcia/danych referencyjnych z użytymi kopiami. Pierwszy przebieg42 rozpoczął się przed zaostrzeniem kontroli miejsca wywołania; końcowa weryfikacja zastosowała nową kontrolę do każdego zachowanego błędu.

Trwały [zapis dowodów](test_oracle_repairs_2026_10_28.evidence.json) zawiera fault, asercję, exit0/1/0, hashe i komendy. Pełne logi są lokalne; skrypty pozwalają odtworzyć kontrolę. Python3.12.14, Lune0.11.1, Rojo7.7.1. To wybrane mutacje, nie pełne mutation coverage gry. Logi lokalne: build/test_oracle_repairs_full.log, build/spec_regression_repair_run.log, build/fresh_mutation_repair_run.log, build/behavior_mutation_repair_run.log i build/runner_fault_repair_run.log.

To dowody Lune/Python i statycznego buildu Rojo. Przechwycenie właściwości nagłówka nie jest natywnym renderem, pomiarem tekstu ani odbiorem telefonu w Studio. Brak nowego S/D/H, realnego DataStore lub płatności; wydanie niezatwierdzone.
