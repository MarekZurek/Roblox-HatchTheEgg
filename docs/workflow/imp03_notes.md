# IMP-03 — schematy protokołu pierwszej farmy

24.10.2026. Dostarczono czysty moduł [ProtocolSchemas](../../src/shared/ProtocolSchemas.luau) i [testy](../../tests/protocol/run.luau), zgodnie z kontraktami [27](../27_numbers_time_and_player_state_contract.md), [28](../28_modules_and_client_server_contract.md), [manifestem 30](../30_first_farm_manifest_and_technical_choices.md) oraz [31](../31_research_hatching_rcb_and_new_account.md). Konkretne nazwy pól i limity wire v1 są **P — decyzją techniczną implementacji**, nie nowymi mechanikami R lub zatwierdzeniem bilansu.

## API i zakres

`ProtocolSchemas.new(NumericCodec)` wymaga codec v1 i zwraca `validateClient(value)` oraz `validateServer(value)`. Obie funkcje zwracają `(true, nil)` albo `(false, "INVALID_REQUEST")`. Moduł nie zmienia wejścia, nie dekoduje go do profilu, nie zawiera RPC, zegara, usług platformy ani efektów ekonomicznych. Zależność jest wstrzykiwana; ten sam moduł można importować przez Lune i później przez ModuleScript.

Walidacja poprawności struktury **nie potwierdza uprawnienia, katalogu, własności, aktualności quote, salda lub istnienia operacji**. Gateway i koordynator nadal muszą sprawdzić te warunki na zaufanym stanie. Moduł nie implementuje ograniczeń częstotliwości ani kolejki. Pomyślne parsowanie nie jest przyjęciem wykonania.

## Klient → serwer

Każda wiadomość ma `protocolVersion=1`, `requestId` oraz `kind`. Kierunki są rozłączne; nie ma ogólnego wywołania metody ani dowolnego patcha.

| kind | Pozostałe wymagane pola |
|---|---|
| Bootstrap / RefreshState | Brak. Serwer wybiera własny stream i stan. |
| OperationStatus | `operationId`; tylko odczyt własnej operacji przez przyszły adapter. |
| QuoteRequest | `target={kind,args}` dla jednego z trzech zakupów; args jak poniżej, bez quoteId. |
| BuyResearch | `operationId`, `expectedRevision`, `args={researchId,mode="single",quoteId}`. |
| BuyHabitat | `operationId`, `expectedRevision`, `args={slotId,habitatId,quoteId}`. |
| BuyVehicle | `operationId`, `expectedRevision`, `args={slotId,vehicleId,quoteId}`. |
| HatchPress | `streamId`, `inputSeq`; pojedyncza próba, bez liczby kur. |
| HatchInput | `streamId`, `inputSeq`, `state=start/refresh/stop`; osobna intencja hold, nie prawo do tempa 3/s. |

Press i hold korzystają z tego samego przyszłego strumienia/deduplikacji inputSeq; nie wymagają trwałego operationId przy każdym wejściu. Moduł sprawdza reprezentację numeru, **nie** kolejność względem wcześniejszych pakietów. To zadanie adaptera/koordynatora. Podobnie requestId jest korelacją transportu, a operationId stabilną tożsamością operacji. Zmiana requestId albo expectedRevision nie generuje nowego operationId.

`expectedRevision` to tekst ExactUInt trwałej commitRevision; nie jest viewSeq. Schemat nie porównuje go z profilem i nie odrzuca starego replay. Właściciel sprawdza trwały operationId i znaczenie argumentów przed expectedRevision/wygaśnięciem quote. Ten sam ID ze zmienionym celem/quote wymaga wykrycia konfliktu poza tym modułem.

## Serwer → klient

| kind | Schemat i znaczenie |
|---|---|
| StateSnapshot | requestId, streamId, viewSeq, commitRevision, serverObservedAt, protocolVersion, numericCodecVersion, viewSchemaVersion, configRevision, calculationVersion i `view={audience,farm}`. |
| StateDelta | Te same wersje/stream/czas, bez requestId; `baseViewSeq`, rosnący `viewSeq` i `changes={audience,farm}`. Zgodność base z lokalnym store oraz odrzucenie starego streamu są późniejszą odpowiedzialnością klienta. |
| QuoteView | requestId, quoteId, expectedRevision, target, cashCost, currency="cash", configRevision, calculationVersion, numericCodecVersion, expiresAt, available; opcjonalny blockedReason. Dla badania nextLevel, dla infrastruktury resultIndex. Nie tworzy kosztu ani rezerwacji. |
| CommandResult | requestId, operationId, status, currentCommitRevision, streamId, serverObservedAt. APPLIED/REJECTED/REPLAYED dodatkowo mają resultRevision i allowlistowany result; resultRevision nie przekracza currentCommitRevision. |
| Admission | requestId, opcjonalne operationId, admission="NOT_ACCEPTED", errorCode. Bez terminalStatus, trwałego wyniku albo dowodu anulowania wcześniejszej próby. |

Result APPLIED zawiera actionKind oraz wyłącznie ID zakupionego badania z nowym poziomem albo slot/ID zakupionej infrastruktury. Result REJECTED zawiera terminalStatus i errorCode. REPLAYED zachowuje pierwotny terminalStatus (również REJECTED). PENDING/UNKNOWN/NOT_APPLIED nie mogą mieć resultRevision/result i nie są sprowadzane do success=false. Status operacji jest zwracany przez CommandResult, nie oddzielną interpretację z tym samym kind co zapytanie klienta.

Własny farm DTO: lifecycle, eggIndex, cash; cztery rekordy habitats (slotId, opcjonalny habitatIndex, population, reservedInTransit, capacity); hatchery (stock/capacity/refillPerSecond); fleet (vehicles slotId/vehicleIndex i shippingPerMinute); producedEggsPerSecond, soldEggsPerSecond, cashIncomePerSecond; common (researchId/level/available, opcjonalny blockedReason). Brak habitatIndex oznacza pusty slot. Spójność pustego slotu z jego zerowymi wartościami pozostaje obowiązkiem projektora. Publiczny farm DTO zawiera wyłącznie eggIndex, zagregowaną population oraz widoczne sloty/typy kurników i pojazdów. Brak prywatnych sald i operacji.

Delta zastępuje całe wskazane sekcje farm, a pominiętą sekcję zachowuje. Pusta tablica common/vehicles jawnie usuwa jej wszystkie elementy; usunięcie pojedynczego wpisu następuje przez kompletną listę bez niego. Habitats zawsze ma cztery sloty, więc opróżnienie slotu oznacza rekord bez habitatIndex z odpowiednimi wartościami, nie ukryty patch. Fleet jest jedną sekcją. To ograniczony format jawnych usunięć z 28; brak ścieżek `cash.amount`, nil-sentinel lub arbitralnego profilu. Zmiana audience wymaga nowego snapshotu w przyszłym store.

W wire v1 `calculationVersion=1` jest małą liczbą, tak samo jak `meta.calculationVersion=1` profilu. Nie jest aliasem string `"v1"` ani konwersją z ID konfiguracji. Inna wersja obliczeń jest odrzucana do czasu jawnego rozszerzenia schematu i testów.

## Typy i ograniczenia techniczne P

ExactUInt (revisions, viewSeq, inputSeq, populacje) jest kanonicznym tekstem uint64, dekodowanym NumericCodec bez tonumber całego zakresu. Kwoty i nieujemne Real64 są tekstem round-trip, dokładnie w postaci `codec.encode(codec.decode(text))`; nie przyjmujemy liczb JSON, niekanonicznego -0 ani ozdobników formatu. Poziomy badań, indeks jaja/typu są SmallIndex number 0–65535. Sloty pierwszej farmy to 1–4; poziomy/ID muszą potem przejść dokładną walidację katalogu. Instant jest całkowitym number ms Unix 0–2^53−1. Nie mieszamy go z Duration ani nie przyjmujemy czasu klienta.

Identyfikatory mają 1–96 bajtów ASCII z alfabetu liter/cyfr i `_ : . -`. Preflight odrzuca instancje/userdata, funkcje, buffer, metatabele (także ukryte), niepoprawny UTF-8, cykle i współdzielone referencje tabel. Tablice muszą być gęste, bez kluczy tekstowych; sloty i researchId są unikalne w swoich tablicach. Nieznane pola na dowolnym poziomie są odrzucane. Brak tokenów, ledgeru, surowego profilu oraz klientowskich cen/playerId/praw/czasu.

Limity parsera: głębokość 10, 4096 odwiedzonych węzłów (w tym klucze), 65 536 konserwatywnie szacowanych bajtów JSON i 256 bajtów pojedynczego tekstu. Współdzielona referencja jest celowo odrzucana; na wire nie jest potrzebna. Są to budżety techniczne pojedynczej wiadomości, nie tempo wylęgu, pojemność farmy, limit operacji ekonomicznych czy aktywny bilans. Tablice Common maksymalnie 56, habitatów/pojazdów maksymalnie 4 (własne habitats dokładnie 4). Rozszerzenie na późniejsze systemy wymaga jawnej aktualizacji protokołu.

## Weryfikacja

Lune 0.11.1: **745 asercji PASS**, raport lokalny `build/protocol-results.json`. Testy obejmują dodatnie przykłady wszystkich kierunków/komend, obce pola, wymagane quote, niezależne requestId/operationId, uint64 >2^53, niekanoniczne liczby i niefinitywne wartości, błędne sloty/tryb max, prywatne pola w publicznym DTO, terminalne/replay/unknown/admission, delty/usunięcia, cykle/metatabele/instancje i budżety struktury. Instancja jest reprezentacją Lune; nie uruchamiano Studio, RPC ani prawdziwego zapisu. Zaliczenie schematu nie jest dowodem wykonania D07, poprawności stream store lub autoryzacji.

Bilans 17–21, referencyjne JSON-y i NumericCodec pozostają bez zmian. Testy są techniczne i nie kalibrują progresji.
