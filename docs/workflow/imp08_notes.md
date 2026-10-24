# IMP-08 — PlayerCoordinator

24.10.2026. Dostarczono wewnętrzny moduł i testy L. Bez Studio, rzeczywistego DataStore, publikacji gry i zmian odłożonego bilansu. Źródła reguł: [27](../27_numbers_time_and_player_state_contract.md), [28](../28_modules_and_client_server_contract.md), [34](../34_pre02_sessions_and_retention.md), istniejący [adapter sesji](../37_imp02_imp03_imp07_delivery.md).

## Granica odpowiedzialności

`PlayerCoordinator.new(deps)` wymaga `mode="INTERNAL_TEST_ONLY"`, NumericCodec, PersistenceData, SessionRepository, potwierdzonego acquired handle, zegara `utcNowMs`/`elapsedNowSeconds`, jawnego technicznego `maxQueue` oraz dwóch wstrzykniętych portów. Import nie uruchamia tasków ani usług. Host wywołuje `drain` w swoim workerze; nie wolno równolegle mutować przekazanego handle z pominięciem koordynatora.

Port `simulation.advance(profile, request)` zwraca `{profile, complete}`. Profil jest pełnym, serializowalnym agregatem, a request musi identyfikować docelowy okres/cursor: ponowne rozliczenie nie może interpretować tego samego czasu jako nowego przyrostu. Konwersję modelu obliczeniowego TimelineSimulation na zapis oraz jego neutralny zakres zapewnia jawny adapter integracyjny. Koordynator nie zgaduje parametrów petów, wydarzeń lub boostów.

Port `domain.apply(profile, operation)` zwraca `{profile, result, terminalStatus?, validate}`. `terminalStatus` to APPLIED lub REJECTED. Walidator otrzymuje świeżą trwałą bazę i czas serwera; odpowiada za warunki konkretnego planu z uwzględnieniem przygotowanego rozliczenia. Nie jest implementacją FarmActions. Domena i symulacja nie mogą yieldować ani zmieniać ownership, meta lub ledger; wejścia są kopiowane. Operacja może zmieniać pola sekcji domenowych, ale nie usuwać całych sekcji/pól. Kasowanie zasobu wymaga jawnego nowego stanu pola, np. pustego ekwipunku.

## Kolejka i trwałość

- `submit(op, simulationRequest?)`, `tick(request)`, `checkpoint(op)`, `renew()` i `release()` trafiają do jednego właściciela `drain(maxJobs?)`. Repozytorium może czekać na storage, ale drugi drain jest w tym czasie odrzucony. Callbacki domeny/symulacji pozostają bez yield.
- `submit` używa formatu SessionRepository: operationId, kind, args, expectedRevision, opcjonalne quoteId i validUntilMs. PENDING oznacza istniejący śledzony job, a nie potwierdzoną wypłatę ani trwałą kolejkę. Kolejka ma jawny limit techniczny; błędny profil wejścia, brak gotowości i pełna kolejka dają NOT_ACCEPTED bez utworzenia jobu.
- Replay i konflikt treści ID sprawdzane są przed gotowością, expectedRevision i deadline. expectedRevision odnosi się do trwałej bazy. Tick w pamięci nie zwiększa revision i nie unieważnia sam zakupu; wspólny commit może objąć wcześniejszą symulację i akcję.
- Trwały profil (`snapshots().durable`) i kandydat online (`working`) są oddzielne. Koszt, korzyść, cursor i wynik ID zapisywane są wspólnie przez SessionRepository. UNKNOWN zamyka dalsze mutacje i ukrywa working. Nie potwierdza się wtedy korzyści klientowi.
- Zwykłe odrzucenie domenowe zapisuje sam wynik odrzucenia. Zachowuje wcześniej rozliczony, lecz jeszcze nietrwały postęp w working, aby późniejszy checkpoint go utrwalił. Nie gubi produkcji i nie traktuje odrzucenia jako przyznania korzyści.
- Niepełny tick pozostawia tryb settling. Nowe komendy są blokowane, ale kolejny tick i checkpoint częściowego kursora pozostają dostępne. Zakończony tick ustawia gotowość. Niepełne przygotowanie samej komendy daje NOT_APPLIED bez wykonania domeny; ponowienie musi być jawne.
- `setReady` jest portem hosta, nie wejściem klienta. Nie może przywrócić gotowości po UNKNOWN lub utracie sesji. `resultOf` odczytuje lokalny job, `query` sprawdza ledger i nie wykonuje operacji. Brak wpisu dla nieznanego ID pozostaje UNKNOWN, nie wiecznym PENDING ani automatycznym NOT_APPLIED.
- `recover(id)` stosuje istniejący SessionRepository.recover: nowy claim/fence po wygaśnięciu sesji. Dopiero potwierdzony nowy właściciel rozstrzyga utracone queued ID jako zapisany wynik albo NOT_APPLIED. Nie powtarza domeny. Gotowość po recovery wymaga ponownego rozliczenia przez hosta/tick.

Zegar koordynatora jest tym samym portem co w repozytorium. Każda lokalna mutacja sprawdza stan sesji i potwierdzony deadline. Najpóźniej 20 s przed końcem lease zatrzymuje postęp i przechodzi do odzyskiwania; rollback UTC/elapsed lub różnica zmian ponad 5 s daje CLOCK_UNCERTAIN. Replay pozostaje dostępny. To techniczna polityka ostrożnego zatrzymania z 34, a nie nowy limit ekonomiczny. Host nadal odpowiada za terminowe odnowienia; nie dodano schedulera 30 s.

## Dowody i ograniczenia

`tests/coordinator/run.luau`: **221 asercji PASS**. Rzeczywisty SessionRepository z kontrolowanym storage: callback odroczony, przerwa coroutine podczas zapisu, utracona odpowiedź po commit, fence blokujący późny callback, replay i konflikt ID przed gotowością, revision trwała vs online, odrzucenie z nieutrwaloną produkcją, checkpoint częściowego okresu, wygasły lease i skok zegara, brak yield w portach, limit kolejki i wspólne renew/release oraz odnowienie rzeczywiście wydłużające lease między tickiem w pamięci a komendą/checkpointem. Wynik lokalny: `build/coordinator-results.json`.

Testy integracyjne z rzeczywistymi modułami liczenia, TimelineSimulation, codec i schematem profilu są odrębnym dowodem `tests/integration89/run.luau`; ten dokument nie deklaruje ich wyniku. Kod nie implementuje Remotes, publicznej projekcji, UI, FarmActions, zakupów platformy, fizyki tras ani automatycznego uruchamiania. Nie deklaruje produkcyjnej rezerwacji rozmiaru dowolnych planów przyszłych domen ani nieograniczonej trwałej kolejki. Repozytorium nadal sprawdza konkretny rozmiar przed zapisem i nie obcina historii ID.
