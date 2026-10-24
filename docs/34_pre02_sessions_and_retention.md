# PRE-02 — sesja, zapis, retencja i odzyskiwanie

24.10.2026. **P — projekt adaptera dla wewnętrznej pierwszej farmy, dokumentacja przygotowana.** [#8](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/8). Stosuje [27](27_numbers_time_and_player_state_contract.md), [28](28_modules_and_client_server_contract.md) i [33](33_pre01_toolchain_and_clocks.md). Bez kodu, chmury i zmian bilansu. Nie jest polityką gotową do nieograniczonego działania produkcji.

## 1. Jednostka zapisu i port

Kierunek P: natywne DataStoreService/UpdateAsync, bez nowej biblioteki. Jeden klucz gracza zawiera cały agregat: ekonomię, checkpoint, własność, operacje i zapisane wyniki. Koszt, materiał, korzyść, cursor, revision oraz operationId/odpowiedź zmieniają się wspólnie. Koordynator serializuje też ticki, dotarcia i odnowienie; sam lease nie porządkuje jego lokalnych tasków.

Port rozdziela otwarcie/claim, odczyt statusu operacji, commit kandydata, renew i release. Odpowiedzi rozróżniają wykonano, wcześniejszy wynik, pewne odrzucenie, anulowanie transformacji oraz nieznany wynik zapisu. Status operacji i QueryStatus z 28 nie inicjują zakupu. Callback otrzymuje najnowszy profil, sprawdza token i generację, replay oraz warunki mutacji. Jest deterministyczny: bez yield, sieci, RNG i efektów zewnętrznych; ponowne wywołanie nie losuje ponownie.

pcall=true nie dowodzi commit, jeżeli callback zwrócił nil. Błąd wywołania nie dowodzi braku zapisu. Wymaga to oddzielnych wyników i odzyskiwania; [oficjalny opis DataStore](https://create.roblox.com/docs/cloud-services/data-stores) określa m.in. anulowanie przez nil i zakaz yield w callbacku.

## 2. Dzierżawa i utrata właściciela — parametry techniczne P

| Parametr | Pierwszy adapter P |
|---|---|
| Potwierdzona dzierżawa | 120 s według UTC serwera wykonującego zapis |
| Próba odnowienia | co 30 s; nie obietnica sukcesu |
| Lokalny stop nowych mutacji | najpóźniej 20 s przed ostatnim potwierdzonym endsAt; wcześniej przy nieznanym renew lub podejrzeniu skoku zegara |
| Przejęcie | tylko przez UpdateAsync na aktualnym rekordzie po endsAt; bez wymuszania przejęcia niewygasłej sesji |
| Fence | trwała rosnąca generacja ExactUInt i niepowtarzalny ownerToken; porównanie obu wewnątrz każdej mutacji |

Liczby te dotyczą odporności i dostępności, nie tempa gry. Renew nie zmienia generacji i przedłuża wyłącznie własny, nadal ważny lease. Nieznany wynik renew wymaga odczytu/odzyskania potwierdzenia; nie wolno zakładać nowego endsAt. Claim inkrementuje generację atomowo i zwraca dopiero potwierdzony stan. Release usuwa prawo własności tylko przy zgodnej parze token/generacja, zachowując generację i ekonomię. Stary właściciel nie usuwa nowej blokady.

Granice między serwerami wymagają UTC, nie porównania os.clock z innego procesu. Lokalne elapsed pozwala wcześniej zaprzestać działań; nie jest trwałym lease deadline. Każda mutacja sprawdza też wygaśnięcie. Clock rollback, duży skok lub niepewny zapis zatrzymuje przyjmowanie nowych działań do wyjaśnienia. Nie obiecujemy znanej maksymalnej różnicy zegarów serwerów. Fencing chroni wspólny rekord również przy przedwczesnym claim; widok klienta nie dostaje niepotwierdzonych trwałych korzyści. Badanie zachowania czasu i przejęcia należy do D.

## 3. Brak profilu, migracja i UNKNOWN

Brak odczytanego rekordu, błąd sieci i nowszy schemaVersion to różne stany. Pierwsze utworzenie jest dozwolone wyłącznie w atomowej transformacji potwierdzającej brak profilu. Używa inicjalizatora z 31, nie fixture z 30. Nowszy lub uszkodzony schemat jest zachowany i blokowany do obsługi; nie tworzymy pustego konta. Migracja ma wersję, zachowuje operacje i obce sekcje oraz commit wspólny z profilem.

Replay rozpoznaje operationId i zgodność treści przed expectedRevision i wygaśnięciem quote. Inna treść przy tym samym ID to konflikt. Nie narzuca się operationId formatu uint64 ani argsHash reprezentacji liczbowej; ExactUInt koduje się wyłącznie według 27.

Przy timeout commit: zatrzymać dalsze mutacje gracza, utrzymać ID i kandydata jako nierozstrzygnięte, odczytać świeży stan w trybie bez cache i rozstrzygnąć pod fencing. Znaleziony wynik zwraca się bez nowej opłaty. Sam brak wpisu NIE jest jeszcze NOT_APPLIED: wcześniejszy zapis może być w toku. Po restarcie nowy właściciel najpierw uzyskuje nową generację na aktualnym rekordzie. Taki atomowy fence rozstrzyga kolejność wobec starego zapisu: stary commit przed fence jest widoczny, po fence nie przechodzi. Następnie sprawdza operację w stanie z claim. Dopiero pewny brak skutku i brak możliwości późnego zapisu pozwala na NOT_APPLIED. Nowa próba wymaga jawnego polecenia według 28; QueryStatus nie wykonuje jej samo.

Jeżeli storage nadal nie pozwala ustalić wyniku albo utrwalić fence, pozostaje UNKNOWN i tryb odzyskiwania. Nie kasować ledger, nie zmieniać ID, nie wypłacać kompensacji w ciemno. To również ścieżka po utracie sesji; poprzedni właściciel nie finalizuje dalej ekonomii.

## 4. Retencja i rozmiar

| Limit P dla pierwszego adaptera | Znaczenie |
|---|---|
| Cały zakodowany profil | do **3 MiB (3 145 728 bajtów UTF-8 JSON)**, łącznie ze wszystkimi sekcjami, lease i ledger |
| W tym ledger | do **2 MiB**, nie dodatkowe 2 MiB obok profilu |
| Terminalne ID i wyniki | bez automatycznego kasowania/FIFO/TTL w tym wewnętrznym zakresie |
| Przyjęcie nowej operacji | tylko jeśli kandydat i zapisany wynik mieszczą się w obu limitach; miejsce na zakończenie już przyjętej pracy rezerwowane przed jej przyjęciem |

Platforma ogranicza wartość klucza do 4 194 304; własny niższy limit i pomiar serializacji są konserwatywnym ograniczeniem technicznym. [Oficjalne limity i błędy](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) opisują też niepewność zapisu i rozliczenie UpdateAsync w budżetach odczytu i zapisu. Nie ma tu trzeciej dodatkowej puli.

Admission mierzy wynik faktycznego codec/JSON, nie liczbę rekordów ani znaków UI. Nie przyjmuje operacji z nieograniczonym wynikiem bez określenia i zarezerwowania jego rozmiaru. Przekroczenie oznacza NOT_ACCEPTED/STORAGE_CAPACITY przed kosztem; QueryStatus, odczyt i replay istniejących wyników pozostają dostępne. UI pokazuje ograniczenie zapisu i możliwość ponowienia po obsłudze; nie oferuje płatnego odblokowania.

Nie usuwać ochrony powtórek, petów, ofert ani historii dla odzyskania miejsca. Nie rozdzielać atomowej transakcji na dwa klucze. Tylko stałorozmiarowe odnowienie, odzyskiwanie i zakończenie wcześniej zarezerwowanej pracy mogą nadal zapisywać w swoich limitach. Jeśli nawet spójny checkpoint nie mieści się, zatrzymać postęp z komunikatem; nie publikować utraconych przy restarcie korzyści. Trasa/grupy z 35 podlegają temu samemu agregatowi i admission przed zużyciem zapasu.

To skończony wariant wewnętrzny, nie obietnica nieskończonego działania. Przed wydaniem IMP-07/REL-01 muszą dostarczyć sprawdzoną politykę długotrwałego przechowywania bez utraty replay; obecny limit nie zastępuje tej bramki. Bez projektowania jej teraz kosztem bilansu lub nowych tasków.

## 5. Przyszłe scenariusze IMP-07 / F03

| Przypadek | Oczekiwany dowód |
|---|---|
| Dwa claim, renew po expiry, stary release i commit | L: kontrolowany fake; D: tylko jeden potwierdzony fence, brak utraty nowego ownera |
| Commit zapisany, odpowiedź zgubiona; retry ze starą revision/quote | Ten sam wynik i pojedynczy koszt |
| Timeout, brak wpisu, spóźniony callback, przejęcie | UNKNOWN do rozstrzygnięcia; brak automatycznej powtórki |
| Brak profilu, błąd odczytu, nowszy schemaVersion | Tylko pewna nieobecność tworzy konto |
| Granice 2/3 MiB, Unicode, odnowienie i recovery po odmowie | Mierzone bajty, brak wycinania wyników, działające odczyty |
| Cofnięcie UTC i restart elapsed | Brak wskrzeszenia uprawnień starej sesji |

**Nie wykonano L/S/D.** Dokument zamyka wybór projektu PRE-02, nie odbiór działającej trwałości.
