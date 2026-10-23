# Adaptacja: Wzorce obsługi błędów i wzorzec Result w Luau

> **Doprecyzowanie projektu — P:** przy projektowaniu sieci obowiązuje [kontrakt 28](../../28_modules_and_client_server_contract.md) wraz z [27](../../27_numbers_time_and_player_state_contract.md). Przykładowe RemoteFunction, success:boolean, błąd dla już rozliczonej operacji i stawki wywołań poniżej są szkicami, nie wybraną realizacją. Nie zastępują replay wyniku, statusów PENDING/UNKNOWN ani rozdzielenia wyniku operacji od projekcji stanu.

> **Informacja licencyjna i źródło**  
> Źródła pierwotne:  
> - [skills/error-handling/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/error-handling/SKILL.md)  
> - [rules/common/patterns.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/rules/common/patterns.md) (sekcja API Response Format)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

Kluczowe zasady obsługi błędów z ECC:
- **Fail fast and loud**: błędy zgłaszane natychmiast na granicy modułu; zakaz cichego połykania wyjątków (`never swallow errors silently`).
- **Wzorzec Result (No-throw style)**: operacje zwracają unię `{ ok: true, value: T } | { ok: false, error: E }` zamiast rzucać wyjątki.
- **Rozdzielenie komunikatów**: techniczne szczegóły i kod błędu dla dewelopera / logów serwerowych vs przyjazny komunikat dla użytkownika.
- **Ponawianie z wykładniczym opóźnieniem**: ponawianie wyłącznie operacji idempotentnych i błędów przejściowych, a nie błędów walidacji klienta.
- **Spójna koperta odpowiedzi (API Envelope)**: ujednolicony format danych zwracanych z punktów końcowych.

---

## 2. Propozycja adaptacji dla HatchTheEgg (Roblox / Luau)

W Roblox/Luau brak referencyjnego bloku `try / catch`. Błędy rzucane przez `error()` przerywają wątek coroutine, a do ich przechwytywania służy `pcall` / `xpcall`. Jednak używanie `error()` i `pcall` do zwykłej walidacji biznesowej (np. "gracz ma za mało waluty") jest nieefektywne i zaciemnia kod.

Dla HatchTheEgg wprowadzamy **wzorzec Result** oraz **kopertę sieciową** w czystym Luau.

### A. Wzorzec Result w Luau (`Result.luau`)

```lua
-- Shared/Utils/Result.luau
--!strict

export type Ok<T> = { ok: true, value: T }
export type Err<E> = { ok: false, error: E }
export type Result<T, E> = Ok<T> | Err<E>

local Result = {}

function Result.ok<T>(value: T): Ok<T>
    return { ok = true, value = value }
end

function Result.err<E>(error: E): Err<E>
    return { ok = false, error = error }
end

return Result
```

### B. Standardowa koperta sieciowa RemoteFunction (Network Envelope)

Każde zapytanie gracza przez `RemoteFunction.OnServerInvoke` zwraca ustrukturyzowaną tabelę:

```lua
export type NetworkResponse<T> = {
    success: boolean,
    data: T?,
    errorCode: string?,       -- Maszynowy kod błędu, np. "INSUFFICIENT_FUNDS"
    userMessage: string?,     -- Przyjazny komunikat lokalizowany dla UI
}
```

Dzięki temu klient nigdy nie zgaduje, dlaczego akcja się nie powiodła, a błąd serwera nie wywala wątku klienta.

### C. Standardowe kody błędów w HatchTheEgg:

| Kod błędu | Znaczenie biznesowe | Kiedy występuje |
|---|---|---|
| `SESSION_LOCKED` | Inna sesja jest aktywna lub poprzednia się nie zamknęła (D07) | Przy logowaniu / wejściu do gry |
| `SESSION_LOST` | Utrata własności tokenu blokady sesji w trakcie gry (D07) | Zatrzymanie operacji gracza |
| `INSUFFICIENT_CASH` | Brak wystarczającej gotówki | Próba zakupu Common Research / Kurnika |
| `INSUFFICIENT_GE` | Brak Złotych Jaj (Golden Eggs) | Zakup boosta / płatny podwajacz |
| `RECIPE_MISMATCH` | Niepasujące kopie przy łączeniu | Różny tier, gatunek lub wariant (D01) |
| `PET_LOCKED` | Pet nie został zdjęty lub odblokowany | Próba użycia założonego peta jako materiału (D01) |
| `CHANNEL_OCCUPIED` | Brak wolnego miejsca w dostawie paczek | Przekroczony limit 2+1 paczek (D05) |
| `OFFER_RESERVED` | Trwa oczekiwanie na autoryzację płatności | Nierozstrzygnięty zakup Robux (D04/D05) |
| `TRANSACTION_ALREADY_PROCESSED` | Transakcja została już wcześniej rozliczona (D07) | Próba powtórzenia rozliczenia |
| `DATASTORE_THROTTLED` | Przekroczony budżet zapytań Roblox DataStore | Wyczerpanie kolejki (kody 301-306) |

---

## 3. Rozróżnienie kategorii błędów, ponawianie i nieznany wynik zapisu

Automatyczne, ślepe ponawianie każdej operacji w pętli jest błędem krytycznym, który w systemach z ekonomią prowadzi do duplikowania waluty, powtórnego pobierania opłat lub ponownego losowania wyników.

W HatchTheEgg wprowadzamy rygorystyczny podział na 3 kategorie błędów:

### 1. Błędy walidacji i reguł biznesowych (KATEGORYCZNY ZAKAZ PONAWIANIA)
- Przykłady: nieprawidłowe ID badania, za mało gotówki, pet nieodblokowany, niezgodny tier materiałów do łączenia, brak miejsca na paczkę (2+1).
- **Zasada**: Nigdy nie ponawiać. Natychmiast zwrócić `Result.err` z odpowiednim kodem błędu. Ponowienie tego samego zapytania nie zmieni reguł gry.

### 2. Błędy przejściowe odczytu / infrastruktury (Dopuszczalne ostrożne ponawianie)
- Przykłady: błąd sieciowy przy odczycie danych podczas wejścia gracza, chwilowa niedostępność endpointu `GetAsync`.
- **Zasada**: Dopuszczalne ponowienie z wykładniczym opóźnieniem (exponential backoff z jitterem), o ile operacja jest czystym odczytem bez skutków ubocznych i mieści się w limitach budżetowych `GetRequestBudgetForRequestType`.

### 3. Nieznany wynik zapisu (Unknown Write Outcome / Timeout) — NAJWYŻSZE RYZYKO
- Przykłady: wywołanie `UpdateAsync`, rozliczenie Developer Productu w `ProcessReceipt` lub transakcja sieciowa kończy się timeoutem lub zerwaniem połączenia w trakcie oczekiwania na odpowiedź.
- **Kluczowa zasada inżynierska**: **TIMEOUT NIE DOWODZI NIEWYKONANIA OPERACJI!**
  Żądanie zapisu mogło dotrzeć do klastra bazy danych Roblox i zostać pomyślnie zatomizowane w chmurze, podczas gdy utracony został wyłącznie pakiet odpowiedzi zwrotnej do serwera gry.
- **Wymagania obsługi nieznanego wyniku (D07)**:
  1. **Niezmienność rezultatu i identyfikatora**: Ponowiona operacja musi bezwzględnie zachować ten sam identyfikator transakcji (`transactionId`) oraz ten sam, ustalony wcześniej rezultat.
  2. **Zakaz ponownego losowania**: W przypadku ewolucji petów (D01) lub otwarcia prezentu (D04/D05) rezultat (sukces/porażka, wylosowana kwota) jest zdefiniowany w momencie powstania żądania/oferty. Nie wolno losować ponownie przy ponowieniu zapisu po timeout!
  3. **Zakaz powtórnej wypłaty**: Przed naliczeniem korzyści serwer sprawdza rejestr `processedTransactions[txnId]`. Jeśli transakcja przeszła w poprzedniej próbie (która zgłosiła timeout), serwer zwraca zapisany uprzednio wynik bez pobierania kosztu i bez ponownego przyznawania nagrody.
  4. **Spójność rozliczenia**: Zużycie zasobów, przyznanie wyniku i zapis znacznika transakcji muszą stanowić jedną, nierozłączną operację zapisu wewnątrz atomowego callbacku `UpdateAsync`.
  5. **Czystość callbacku `UpdateAsync`**: Callback przekazywany do `UpdateAsync` może być wykonany wielokrotnie przez silnik Roblox przy kolizji zapisu. Musi być funkcją czystą — nie może wywoływać `math.random()`, `RemoteEvent:FireClient()` ani zapytań zewnętrznych.
