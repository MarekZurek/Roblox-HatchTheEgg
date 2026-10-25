# Zakres dowodów i raportowanie — #60

Stan: 25.10.2026. Korekta deklaracji weryfikacji, bez zmian reguł gry, konfiguracji lub bilansu.

## Przyczyna i naprawa

Lokalny runner acceptance deklarował L/S/D, a release_candidate zapisywał releaseCandidateReady=true i zbiorcze gatesVerified. Narzędzie verify_release wymagało tego true, choć sprawdzało lokalne pliki, wybrane tokeny i deklaracje. To utożsamiało przejście testów z zatwierdzeniem wydania i dowodami z innych środowisk.

Oba runnery deklarują teraz wyłącznie L, z jawnymi studioTested/dataStoreTested/humanAcceptanceTested=false. Acceptance zapisuje wynik i wymagane poziomy każdego A01–A16. Zapis raportu nie jest już ukryty w pcall: błąd zapisu zatrzymuje test zamiast pozostawiać pozornie aktualny wynik. Release_candidate zapisuje releaseCandidateReady=false i dokładny zakres lokalnego wiringu, bez zbiorczych zaliczeń bramek. Jego 12 etapów pozostaje kompozycją domen, a nie pełnym odbiorem runtime.

verify_release sprawdza spójność raportów i kompletną macierz wymagań z 29. Odrzuca przypisywanie lokalnemu runnerowi S/D/H, zatwierdzanie wydania, pomijanie scenariuszy i procent pokrycia wyprowadzany z asercji. Wynik PASS_LOCAL_CHECKS z releaseCandidateReady=false opisuje wyłącznie te kontrole. Skan wybranych tokenów nie dowodzi braku wszystkich uprzywilejowanych handlerów; statyczny build nie dowodzi replikacji. Nie jest to system kryptograficznego poświadczania wiarygodności dowolnych zewnętrznych raportów.

## Dowody per scenariusz

L: lokalny odpowiednik w tests/acceptance/run.luau, wyniki w build/acceptance-results.json. Wiersze A15 i A16 mają dodatkowy lokalny odpowiednik, który nie zastępuje wymaganych S/H. Dla każdego wiersza S/D/H są **NOT_VERIFIED**: brak zarejestrowanego dowodu odbioru danego scenariusza w tym środowisku. Wzmianki o synchronizacji Studio i zamknięte Issues nie stanowią takiego dowodu. Nie twierdzimy, że Studio nigdy nie uruchamiano.

| Scenariusz | Poziomy wymagane przez 29 | Dowód lokalny | S / D / H |
|---|---|---|---|
| A01 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A02 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A03 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A04 | L | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A05 | L | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A06 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A07 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A08 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A09 | L, S, D | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A10 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A11 | L, D | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A12 | L, S, D | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A13 | L, D | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A14 | L, S | PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A15 | S | dodatkowy PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |
| A16 | S, H | dodatkowy PASS L | NOT_VERIFIED / NOT_VERIFIED / NOT_VERIFIED |

Do zaliczenia wyższych poziomów potrzebny jest osobno zlecony odbiór: scenariusz, wersja kodu/sceny, środowisko i narzędzia, wejście, obserwowany wynik oraz zapis dowodu (dla H także oceniający). Nowy runner i jego walidacja muszą opisywać rzeczywiście wykonane środowisko. Samo przestawienie flag w lokalnym JSON jest odrzucane.

## Regresje i granice

11 testów Python w tests/release_reporting/test_reporting.py sprawdza rzeczywiste wygenerowane raporty oraz ich celowo błędne warianty. Są częścią tools/test.ps1. Nowe testy release_candidate wykonują rzeczywisty Main.server, Bootstrap, gateway/koordynator i zapis przez kontrolowany port: bootstrap, jednorazowy kalendarz, replay po restarcie i brak wypłaty za niewydanego drona. To wybrane ścieżki produkcyjnego wiringu, bez deklaracji pełnego pokrycia. Usługi zewnętrzne, scheduler i prezentacja świata są kontrolowane. Dotychczasowe persistence_startup/pro_policy również wykonują Main, nadal wyłącznie na L.

Poprawiono bieżące deklaracje w 32, 40, 41 i indeksach. Liczby historycznych dostaw zachowano jako historyczne L; wcześniejsze JSON-y w docs/workflow pozostają bez zmian, nawet jeśli zawierały nadmierne deklaracje. Nowe wyniki nie są przypisywane dawnym commitom.

Otwarte #61 oraz brakujące konfiguracje funkcji pozostają poza zakresem tej naprawy. Żaden PASS lokalny ich nie zamyka. Nie wykonywano Studio, rzeczywistego DataStore, zakupów ani odbioru urządzenia mobilnego. Bilans 17–21 i dane referencyjne bez zmian. [Weryfikacja dostawy](release_evidence_60_verification.json).

Wynik dostawy: **34 zestawy Luau / 80 251 asercji PASS L**, dodatkowo **11 testów raportowania Python PASS**, **22/22 wybrane mutacje wykryte**. Build statyczny: 39 modułów / 2 entrypointy. Po usunięciu ukrywania błędu zapisu ponownie uruchomiono acceptance i testy raportowania; zakres i liczba asercji bez zmian. Są to wyniki wykonanych sprawdzeń, bez procentowego pokrycia wymagań i bez zatwierdzenia wydania.
