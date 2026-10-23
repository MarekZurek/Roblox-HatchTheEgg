# Adaptacja: Wersjonowanie DataStore, migracje i blokada sesji (Session Lock)

> **Informacja licencyjna i źródło**  
> Źródła pierwotne:  
> - [skills/database-migrations/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/database-migrations/SKILL.md)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

W ECC proces migracji bazy danych i spójności opiera się na:
- **Zasada forward-only**: w środowisku produkcyjnym każda migracja idzie w przód; rollback to nowa migracja w przód.
- **Wzorzec Expand-Contract**: dodanie nowych pól z bezpiecznymi wartościami domyślnymi (Expand), wdrożenie kodu korzystającego z nowej struktury (Migrate), bezpieczne wygaszenie starych pól (Contract).
- **Niezmienniki spójności**: zapobieganie race conditions, znoszenie konfliktów jednoczesnego zapisu.

---

## 2. Architektura DataStore w Roblox — stan faktyczny i limity

Roblox DataStore jest rozproszonym magazynem klucz-wartość (dokumenty JSON per klucz). Nie jest to relacyjna baza danych (brak operacji `ALTER TABLE` czy transakcji wielodokumentowych).

### Aktualne zasady budżetów i limitów platformy:
> Źródło: [Roblox Creator Hub — Data Stores Error Codes and Limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) (sprawdzone: 2026-10-23).

- **Budżety dynamiczne per-serwer**: Platforma nie operuje sztywnym, uniwersalnym limitem „60 zapytań/minutę” dla wszystkiego. Każdy serwer posiada budżety operacji, które skalują się w czasie rzeczywistym z liczbą graczy na serwerze (Concurrent Users) oraz posiadają startowy burst przy uruchomieniu instancji.
- **Sprawdzanie dostępnego budżetu**: Dostępność żądań sprawdza się programistycznie za pomocą `DataStoreService:GetRequestBudgetForRequestType(requestType)`.
- **Charakterystyka `UpdateAsync`**: `UpdateAsync` jest operacją typu read-then-write (pobiera najnowszą wartość z chmury, przekazuje ją do callbacku transformującego i zapisuje zaktualizowany stan). W API platformy jej limit weryfikuje się przekazując identyfikator `Enum.DataStoreRequestType.UpdateAsync` do `GetRequestBudgetForRequestType`. Nazwa tego enuma określa typ żądania w interfejsie API budżetów platformy — nie oznacza to obciążania jakiejś trzeciej, odrębnej puli ponad koszty operacji.
- **Kolejkowanie i odrzucanie (Throttling & Dropped Requests)**:
  - Roblox zniósł dawne, sztywne 6-sekundowe ograniczenie odstępu między zapisami do tego samego klucza.
  - Zamiast tego nadmiarowe zapytania trafiają do kolejek serwerowych (maksymalnie 30 zapytań w kolejce dla danego typu).
  - Po przepełnieniu kolejki kolejne żądania są natychmiast odrzucane z kodami błędów z zakresu `301–306`.
- **Wielkość danych i klucze**: Maksymalna długość nazwy klucza wynosi 50 znaków. Maksymalny rozmiar pojedynczego wpisu to 4 194 304 znaków (około 4 MB tekstu UTF-8).

---

## 3. Wzorzec migracji dokumentu zapisu (Data Migration Pipeline)

Zapis gracza stanowi pojedynczy słownik Luau serializowany do JSON. Każdy dokument posiada obowiązkowy nagłówek metadanych:

```lua
-- Szkic struktury metadanych zapisu gracza
export type PlayerSaveData = {
    _schemaVersion: number,      -- Monotoniczna wersja schematu: 1, 2, 3...
    _lastSavedUtc: number,       -- os.time()
    _sessionLock: {
        sessionToken: string,    -- Unikalny identyfikator generacji/sesji (UUID/GUID)
        serverJobId: string,     -- Identyfikator instancji serwera Roblox
        lockedAtUtc: number,     -- Timestamp ostatniego odnowienia
        leaseDurationSec: number,-- Długość dzierżawy (np. 120-180 s)
    }?,
    
    -- Dane gry
    farm: { ... },
    inventory: { ... },
    processedTransactions: { [string]: any }, -- Rejestr idempotencji D07
}
```

### Rurociąg migracji w przód (Forward-Only):
Podczas wczytywania stanu w `UpdateAsync` lub po pobraniu danych serwer weryfikuje `_schemaVersion`. Jeśli wersja danych jest niższa niż `CURRENT_SCHEMA_VERSION`, dane przechodzą sekwencyjnie przez zdefiniowane funkcje transformujące (np. $0 \to 1$, $1 \to 2$).
- Nowe pola zawsze otrzymują bezpieczne wartości domyślne (fallback).
- Kod gry nie może zakładać obecności nowo dodanych pól bez sprawdzenia wersji lub wartości domyślnej.

---

## 4. Blokada sesji (Session Lock) — realizacja wymogu D07

Zatwierdzona reguła **D07** wymaga: *„Jeden aktywny właściciel sesji zapisu na gracza. Ponowne wejście po utracie połączenia przejmuje sesję dopiero po bezpiecznym zakończeniu/wygaśnięciu poprzedniej; nie nadpisuje jej starszym stanem”*.

Sam `serverJobId` i czas TTL **nie stanowią wystarczającego dowodu bezpieczeństwa**, ponieważ serwer, który doświadczył chwilowego zawieszenia wątku lub opóźnienia sieciowego, mógłby po wygaśnięciu TTL wznowić działanie i nadpisać nowszy stan zapisany przez nowy serwer!

### Wymagania bezpiecznej blokady sesji:

1. **Unikalny token generacji (`sessionToken`)**:
   - Podczas udanego przejęcia blokady serwer generuje unikalny token sesji (np. unikalny ciąg `HttpService:GenerateGUID(false)` połączony z `serverJobId`).
   - Token ten jednoznacznie identyfikuje konkretną instancję aktywnej sesji tego gracza.

2. **Weryfikacja własności przy KAŻDYM zapisie, odnowieniu i zwolnieniu (Compare-And-Swap)**:
   - W każdym wywołaniu `DataStore:UpdateAsync` (zarówno okresowy autozapis, jak i zapis przy `PlayerRemoving` / `BindToClose`) funkcja transformująca **musi bezwzględnie sprawdzić**:
     ```lua
     if currentData._sessionLock and currentData._sessionLock.sessionToken == mySessionToken then
         -- Jesteśmy prawowitym właścicielem - aktualizujemy timestamp blokady i stan gry
         currentData._sessionLock.lockedAtUtc = os.time()
         -- ... aplikujemy zmiany stanu gry ...
         return currentData
     else
         -- Utrata własności! Ktoś inny przejął blokadę lub dane są uszkodzone.
         -- ZAKAZ zapisu! Zwracamy nil, co anuluje UpdateAsync bez zmian w chmurze.
         return nil
     end
     ```
   - **Stary właściciel nie może nadpisać danych ani zdjąć blokady nowej sesji**. Jeśli `sessionToken` w chmurze nie jest równy `mySessionToken`, zapis jest natychmiast odrzucany.

3. **Postępowanie przy utracie lub niepewności własności blokady**:
   - Jeżeli `UpdateAsync` zgłosi brak dopasowania tokenu lub odnowienie blokady (heartbeat) nie powiedzie się przez zdefiniowany margines bezpieczeństwa:
     - Serwer **natychmiast zatrzymuje** wszelkie operacje gracza modyfikujące stan (zakupy, ulepszenia, ewolucje).
     - Gracz zostaje bezpiecznie odłączony od gry (kick) z komunikatem: *„Sesja została otwarta w innym miejscu lub utracono połączenie z bazą danych”*.
     - Stan z pamięci tego serwera **nie jest zapisywany** do DataStore, zapobiegając nadpisaniu postępu z nowszego serwera.

4. **Przejęcie wygasłej blokady przez nowy serwer**:
   - Nowy serwer może przejąć blokadę wyłącznie wtedy, gdy:
     a) `_sessionLock == nil` (poprzedni serwer poprawnie zamknął sesję i zdjął blokadę), LUB
     b) `os.time() > _sessionLock.lockedAtUtc + _sessionLock.leaseDurationSec` (poprzedni serwer uległ awarii i minął czas dzierżawy).
   - W momencie przejęcia nowy serwer nadaje nowy `sessionToken`. Wszelkie spóźnione pakiety ze starego serwera zostaną odrzucone zgodnie z punktem 2.

*Uwaga: Na obecnym etapie specyfikacji nie wybieramy konkretnej biblioteki zewnętrznej (np. ProfileService czy Lapis) — powyższe zasady stanowią wymagania architektoniczne dla przyszłej implementacji.*

---

## 5. Idempotencja operacji, rozstrzyganie wyników i determinizm `UpdateAsync` (D07)

### Kluczowa własność i pułapki API `UpdateAsync`:
1. **Ponawianie wywołań przez silnik Roblox**: W przypadku kolizji współbieżności platforma **może wywołać funkcję transformującą przekazaną do `UpdateAsync` wielokrotnie**, za każdym razem przekazując najświeższy stan pobrany z bazy.
2. **Żelazna reguła czystości callbacku**:
   - Callback transformujący **nie może** wykonywać żadnych zewnętrznych skutków ubocznych (zakaz wywoływania `RemoteEvent:FireClient`, zakaz zapytań HTTP, zakaz modyfikacji stanu UI).
   - Callback **nie może** generować nowych losowań (zakaz wywoływania `math.random()` dla szansy ewolucji wg D01 czy nagrody paczki wg D05). Wynik operacji musi zostać ustalony w pamięci serwera **przed** wywołaniem zapisu!
3. **Pułapka `pcall` i cichego anulowania przez `nil`**:
   - W silniku Roblox zwrócenie `nil` z callbacku `UpdateAsync` **anuluje zapis do DataStore bez rzucania błędu**.
   - Oznacza to, że `pcall(function() return store:UpdateAsync(...) end)` zakończy się sukcesem (`pcall` zwróci `true`, a wynik `UpdateAsync` to `nil`), mimo że w chmurze nie zaszła żadna zmiana.
   - **Samo `pcall == true` NIE dowodzi wykonania transakcji!**

---

### Rozróżnienie pięciu rezultatów operacji:

| Rezultat operacji | Kiedy występuje | Zachowanie w `UpdateAsync` | Działanie serwera / Odpowiedź dla klienta |
|---|---|---|---|
| **WYKONANO** | Świeża operacja: blokada sesji poprawna, transakcja nie była rozliczona, walidacja reguł na aktualnym stanie przeszła pomyślnie. | Zmniejsza saldo, dodaje przedmioty/uprawnienia, zapisuje `processedTransactions[txnId] = { resultSnapshot, completedAtUtc }`, odnawia `lockedAtUtc`. Zwraca zmodyfikowany dokument. | `pcall=true`, dokument zwrócony. Serwer powiadamia klienta o sukcesie (`Result.ok`). |
| **JUŻ_WYKONANO** | Idempotentne powtórzenie: `processedTransactions[txnId]` istnieje już w pobranym stanie dokumentu (np. ponowienie po timeout). | Nie modyfikuje salda ani ekwipunku. Zwraca nienaruszony dokument (lub odczytuje zapisany snapshot). | `pcall=true`. Serwer zwraca klientowi ten sam zapisany pierwotnie wynik (`resultSnapshot`) bez powtórnego pobierania kosztu i bez ponownego losowania. |
| **ODRZUCONO** | Odrzucenie biznesowe na aktualnym stanie chmury: brak środków, pet zajęty, brak wymaganych kopii (D01), brak miejsca na paczkę (D05). | Transformacja zostaje przerwana; zwraca `nil` (anulowanie zapisu). Żadne zasoby nie są pobierane. | `pcall=true`, wynik `nil` z kodem odrzucenia. Serwer zwraca klientowi `Result.err` (np. `INSUFFICIENT_FUNDS`, `PET_LOCKED`). |
| **ANULOWANO_TRANSFORMACJĘ** | Naruszenie blokady sesji (D07) lub brak dokumentu: `currentData == nil` lub `sessionToken ~= mySessionToken`. | Zwraca `nil`, zapobiegając nadpisaniu danych przez nieuprawniony serwer. | `pcall=true`, wynik `nil`. Serwer natychmiast odcina akcje gracza i rozłącza klienta (utrata własności sesji). |
| **NIEZNANY_WYNIK_ZAPISU** | Wyjątek platformy / błąd sieciowy: `UpdateAsync` rzuca błąd (timeout sieciowy, kod błędu DataStore 301–306, 500+). | Stan w klastrze Roblox jest nieustalony (zapis mógł zostać utrwalony tuż przed utratą połączenia). | `pcall=false`. **TIMEOUT NIE DOWODZI BRAKU ZAPISU!** Kategoryczny zakaz generowania nowego `txnId` i zakaz ponownego losowania; ewentualne ponowienie musi zachować ten sam identyfikator transakcji. |

---

### Niewykonywalny pseudokod architektoniczny transakcji:

Poniższy szkic przedstawia architektoniczne powiązanie weryfikacji blokady sesji, idempotencji, walidacji stanu i obsługi wyników (niewykonywalny pseudokod specyfikacyjny):

```lua
-- PSEUDOKOD ARCHITEKTONICZNY: Bezpieczna transakcja w UpdateAsync (szkic wymagań, nie gotowy kod)

function executePlayerTransaction(playerDataStore, playerKey, mySessionToken, txnId, txnIntent)
    -- 1. Deterministyczne wyznaczenie rezultatu operacji PRZED zapisem (zakaz losowania wewnątrz UpdateAsync!)
    local predeterminedResult = txnIntent.computeDeterministicResult()

    -- Flagi komunikacyjne między callbackiem UpdateAsync a orkiestratorem
    local outcomeStatus = nil
    local outcomePayload = nil

    -- 2. Wywołanie UpdateAsync w pcall
    local pcallSuccess, storeResult = pcall(function()
        return playerDataStore:UpdateAsync(playerKey, function(currentData)
            -- A. Bezpieczna obsługa braku dokumentu i weryfikacja blokady sesji (D07)
            if currentData == nil or currentData._sessionLock == nil or currentData._sessionLock.sessionToken ~= mySessionToken then
                outcomeStatus = "SESSION_LOST_OR_MISSING"
                return nil -- Anuluje zapis w DataStore bez błędu
            end

            -- B. Weryfikacja idempotencji wewnątrz aktualnego stanu z bazy
            if currentData.processedTransactions and currentData.processedTransactions[txnId] ~= nil then
                outcomeStatus = "ALREADY_PROCESSED"
                outcomePayload = currentData.processedTransactions[txnId].resultSnapshot
                return currentData -- Zwraca nienaruszony stan bez pobierania kosztu
            end

            -- C. Walidacja środków, własności i dostępności materiałów na AKTUALNYM stanie w chmurze
            local isValid, rejectionReason = validateBusinessConditions(currentData, txnIntent)
            if not isValid then
                outcomeStatus = "REJECTED"
                outcomePayload = rejectionReason
                return nil -- Anuluje zapis w DataStore bez pobierania środków
            end

            -- D. Atomowa mutacja: zużycie zasobów i przyznanie ustalonego wcześniej wyniku
            applyResourceDeductions(currentData, txnIntent.costs)
            applyGrantedBenefits(currentData, predeterminedResult)

            -- E. Wspólne utrwalenie rekordu transakcji i odnowienie dzierżawy sesji w tym samym dokumencie
            currentData.processedTransactions[txnId] = {
                resultSnapshot = predeterminedResult,
                completedAtUtc = os.time(),
            }
            currentData._sessionLock.lockedAtUtc = os.time()

            outcomeStatus = "EXECUTED"
            outcomePayload = predeterminedResult
            return currentData
        end)
    end)

    -- 3. Rozstrzygnięcie wyniku przez orkiestrator (pcall=true NIE oznacza jeszcze wykonania!)
    if not pcallSuccess then
        -- Timeout lub błąd sieciowy DataStore - stan w chmurze nieustalony
        return Result.err("NIEZNANY_WYNIK_ZAPISU", {
            txnId = txnId,
            predeterminedResult = predeterminedResult,
            rawError = storeResult
        })
    end

    if outcomeStatus == "SESSION_LOST_OR_MISSING" then
        return Result.err("ANULOWANO_TRANSFORMACJĘ", "Brak dokumentu lub utrata własności blokady sesji")
    elseif outcomeStatus == "REJECTED" then
        return Result.err("ODRZUCONO", outcomePayload)
    elseif outcomeStatus == "ALREADY_PROCESSED" then
        -- Zwraca zapisany pierwotnie wynik bez potrącania kosztu
        return Result.ok("JUŻ_WYKONANO", outcomePayload)
    elseif outcomeStatus == "EXECUTED" and storeResult ~= nil then
        -- Nowa transakcja pomyślnie zatomizowana w chmurze
        return Result.ok("WYKONANO", outcomePayload)
    else
        return Result.err("ANULOWANO_TRANSFORMACJĘ", "Zapis wycofany bez błędu")
    end
end
```

Dopiero po rozstrzygnięciu wyniku serwer podejmuje decyzję o powiadomieniu klienta (`RemoteFunction` / `RemoteEvent`) lub bezpiecznym rozłączeniu gracza w przypadku utraty blokady sesji.
