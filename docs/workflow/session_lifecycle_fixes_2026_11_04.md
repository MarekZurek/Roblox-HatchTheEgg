# Zamykanie sesji i handshake po offline — 04.11.2026

Naprawa QA-DATA-01/02 z [pierwszego odbioru chmury](private_qa_datastore_2026_11_04.md). Baza `db557b18fdaa869c20322aec34bb8ba3896ef788` + zmiany źródeł identyfikowane SHA256 w [dowodach JSON](session_lifecycle_fixes_2026_11_04.evidence.json). Ceny, katalogi, profil/schemat zapisu i balans pozostają bez zmian.

## Przyczyny i zmiany

- `playerLeaving` ignorował wyniki checkpoint/drain/release, usuwał aktora mimo niepotwierdzonej trwałości i pozwalał, by PlayerRemoving oraz BindToClose równolegle kończyły tę samą sesję. Teraz wywołania współdzielą wynik zamknięcia, czekają na aktywnego writera i serializują checkpointy. Oczekująca rewizja jest odczytywana po zakończeniu wcześniej przyjętych operacji. Zwolnienie następuje dopiero po potwierdzonym APPLIED checkpoint i RELEASED repozytorium. Niepewny zapis pozostawia aktora do odzyskania i zwraca błąd. Wspólny budżet oczekiwania przy shutdown wynosi 25 s; nie jest gwarancją działania API przy awarii chmury.
- Departing/closing zatrzymuje kolejne ticki, prezenty i przyjmowanie komend. Main ostrzega o niepotwierdzonym zamknięciu; komunikat „All player sessions saved and released” wymaga sukcesu wszystkich pozostałych sesji.
- Bootstrap wysłany podczas rozliczania zaległego czasu trafiał na SESSION_NOT_READY i nie był ponawiany. Main zachowuje jeden poprawny handshake na gracza i wysyła go po READY. Nie dodano pętli ponawiania zakupów ani nowego remote. Wspólna ścieżka aktualizuje także model właściwej farmy, zachowując izolację czterech działek.

Zmiany produkcyjne: `src/server/Bootstrap.luau`, `src/server/Main.server.luau`, `src/server/GiftDrops.luau`. Warstwa klienta, formuły offline i kwoty nagród nie zmieniły się.

## Regresje FAIL → PASS

`tests/session_lifecycle/run.luau` wykonuje rzeczywisty Main/Bootstrap z kontrolowanym DataStore i schedulerem. Przed naprawą trzy niezależne scenariusze zawiodły: brak oczekiwania na zapis, usunięcie aktora po awarii i brak odpowiedzi na pierwotny bootstrap. Po naprawie **33 asercje PASS**:

- Celowo zawieszony zapis + jednoczesne PlayerRemoving i BindToClose: oba czekają; saldo zachowane, owner/lease zwolnione; brak symulacji i nowych komend podczas zamykania.
- Awaria checkpointu albo samego release: wynik jest błędem, aktor pozostaje, brak fałszywego komunikatu sukcesu.
- Zajęty writer: ograniczony czas oczekiwania, potem poprawny retry po zakończeniu zapisu.
- Offline przekraczający jeden budżet: oryginalny bootstrap dochodzi dokładnie raz po READY, bez drugiego żądania klienta.

Pełny `tools/test.ps1 -PythonExecutable <lokalny Python 3.14>`: **exit 0, 58 suit Lune**, kontrole Python/oracles, Rojo 48 modułów + 2 entrypointy i końcowy verify_release PASS_LOCAL_CHECKS. Testy ujawniły pominięcie aktualizacji modelu farmy w nowej ścieżce bootstrapu; poprawiono je i ponownie uzyskano farm_islands 64 PASS. Końcowy skan wykrył też brak literalnej rejestracji nowej suity w runnerze; poprawiono rejestrację i powtórzono pełny runner. Mobilne UI 234 PASS. Nie zmieniano oczekiwań sald w celu uzyskania PASS.

Pełny runner zawierał 32 asercje nowej suity. Następnie, bez dalszych zmian kodu produkcyjnego, wzmocniono scenariusz zawieszonego writera: fixture musi mieć dodatni, jeszcze niezapisany dochód zamiast zerowego salda. Ponowiona suita ma 33 asercje PASS; oba zestawy hashy testów zachowano w dowodach.

## Ponowny test prywatnego QA

Universe `10774701473`, place `110937489000525`, konto `theZuraz`, limit 4. Main.UseLocalMemoryStore=false, runtime **PERSISTENT**, rzeczywisty `HatchTheEgg_PlayerProfile_v1`, GetAsync z UseCache=false i wersjami rekordu. Jeden klient/serwer Studio, kolejne sesje tego samego profilu; brak resetowania, przyznawania środków, płatności i ręcznego ponawiania handshake.

Czyste źródła wysłano do istniejącego niepublicznego QA: **wersja 5**, potwierdzona w Creator Hub po zaznaczeniu „Pokaż tylko opublikowane”. Sondy dodano dopiero potem lokalnie i nie publikowano ich. Prywatność i limit graczy nie były zmieniane w tej naprawie.

- Długi powrót po 989.317 s: serwer przechodził przez SETTLING; klient początkowo CONNECTING, następnie sam READY z aktualnym saldem. Populacja 250, sequence 250, nutritional_sup=1 i GE 10 zachowane.
- Stop i ponowne wejście: następna generacja 7 uzyskana bez SESSION_BUSY. Pierwszy odczyt po samym poleceniu Stop był za wczesny — Studio wraca do Edit przed zakończeniem asynchronicznego BindToClose. Nie traktujemy go jako dowodu końca zapisu; kontrolę uzupełniono odczytami trwałego stanu.
- Kolejny Stop: working cash **19289.453593233968**; końcowy rekord chmury ma dokładnie tę samą kwotę, revision 54, ownerToken pusty, endsAtMs=0. Dwa odczyty uchwyciły kolejno zapis checkpointu z właścicielem i finalne zwolnienie blokady.
- Następny krótki reconnect: generacja 8, klient READY, brak SESSION_BUSY i brak ręcznej naprawy profilu.

Kontrolowany offline po czystym Stop: 89.736 s, oczekiwany przyrost F2P **467.375 Cash**. Oczekiwany cash `20415.84942656731`, rzeczywisty `20415.849426567314` (różnica 3.64e-12, tolerancja 1e-8). Klient sam READY. Po kolejnym Stop reconnect 7.08 s naliczył wyłącznie ONLINE: oczekiwany i rzeczywisty cash `20720.599426567318`; wcześniejsze offline nie zostało naliczone ponownie. Oczekiwania wyliczono niezależnie jako 250/30 × 1.25 Cash/s oraz połowa tej wartości offline, bez użycia TimelineSimulation do ustalenia wyniku testu.

Ostatni Stop: obserwowany working cash `20967.339009900665`, końcowy zapis `20972.724426567333` po ostatniej produkcji; ownerToken pusty i endsAtMs=0. Sondy/atrybuty usunięte, 50/50 źródeł zgodnych z checkoutem, zero rozbieżności, Studio Edit/PERSISTENT. Kod i sondy są rozdzielone: opublikowana wersja 5 zawiera czyste poprawki, diagnostyka była wyłącznie lokalna.

**Wynik: QA-DATA-01 i QA-DATA-02 PASS w opisanym zakresie.** Zakres odbioru nie obejmuje zakupów Roblox, konfliktów dwóch hostowanych serwerów, awarii API w chmurze, realnych limitów 6h/18h, testu czterech klientów ani całego release. Testy awarii i przeplotów są lokalne, deterministyczne. Niezależnego review nie wykonano.
