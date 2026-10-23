# Adaptacja: Serwerowa walidacja i checklist bezpieczeństwa Roblox

> **Doprecyzowanie projektu — P:** przy projektowaniu sieci obowiązuje [kontrakt 28](../../28_modules_and_client_server_contract.md) wraz z [27](../../27_numbers_time_and_player_state_contract.md). Przykładowe RemoteFunction, success:boolean, błąd dla już rozliczonej operacji i stawki wywołań poniżej są szkicami, nie wybraną realizacją. Nie zastępują replay wyniku, statusów PENDING/UNKNOWN ani rozdzielenia wyniku operacji od projekcji stanu.

> **Informacja licencyjna i źródło**  
> Źródła pierwotne:  
> - [rules/common/security.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/rules/common/security.md)  
> - [rules/common/code-review.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/rules/common/code-review.md)  
> - [AGENTS.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/AGENTS.md) (sekcja Security Guidelines)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

W ECC bezpieczeństwo oparte jest na uniwersalnych zasadach inżynierii webowej/aplikacyjnej:
- **Mandatory Security Checks**: weryfikacja przed commitem (brak zahardkodowanych sekretów, walidacja wejść użytkownika, zapobieganie wstrzykiwaniom, autoryzacja każdego punktu wejścia, rate limiting, brak wycieków danych w komunikatach o błędach).
- **Zasada zerowego zaufania do danych zewnętrznych**: traktowanie każdego wejścia jako wrogiego.
- **Fail-fast and loud na granicach systemu**: błędy walidacji zatrzymują wykonanie natychmiast, z precyzyjnym logowaniem na serwerze i ogólnym komunikatem dla klienta.
- **Triggers przeglądu bezpieczeństwa**: natychmiastowe zatrzymanie i przegląd przy zmianach w autoryzacji, płatnościach, operacjach na danych trwałych.

---

## 2. Propozycja adaptacji dla HatchTheEgg (Roblox / Luau)

W Roblox model zagrożeń różni się diametralnie od aplikacji webowych:
1. **Brak SQL/XSS/CSRF**: Roblox nie korzysta z relacyjnych baz SQL ani przeglądarkowego renderowania HTML przez kod gry.
2. **Niezaufany klient (Exploiter)**: Klient Roblox może być zmodyfikowany przez gracza. Gracz ma pełny dostęp do pamięci klienta, może wywołać dowolny `RemoteEvent` / `RemoteFunction` z dowolnymi argumentami w dowolnym tempie.
3. **Autorytatywny serwer (Zasada D07)**: Żadna kalkulacja stanu, zakup, dodanie waluty, inkubacja czy losowanie nie może opierać się na danych przysłanych przez klienta.

### Kluczowe reguły bezpieczeństwa w HatchTheEgg:

#### A. Żelazna reguła RemoteEvent / RemoteFunction
- Klient przesyła wyłącznie **intencję** (np. `RequestResearchPurchase(researchId)`), nigdy **skutek** (np. `SetCash(newAmount)` czy `AddEggCount(100)`).
- Serwer weryfikuje:
  1. Czy gracz ma prawo wykonać akcję (czy sesja jest aktywna i zablokowana dla tego gracza)?
  2. Czy argumenty są poprawnego typu (`typeof(arg) == "string"`, nie `nil`, nie tabela z metatables)?
  3. Czy gracz posiada wystarczające zasoby (sprawdzane na serwerze w pamięci sesji)?
  4. Czy odblokował dane stadium (np. wymóg farmy, poziom kurnika)?
- Klient **nigdy nie podaje kwoty do odjęcia** — cenę wylicza moduł serwera na podstawie wzorów.

#### B. Rate Limiting na poziomie serwera
- Ochrona przed spamem pakietami sieciowymi (`RemoteEvent` flooding).
- Każde wywołanie zdarzenia przez danego gracza przechodzi przez bufor czasowy (np. max 10 zapytań na sekundę dla tapowania, max 2 na sekundę dla zakupów).
- Przekroczenie limitu powoduje ciche odrzucenie zapytania lub ostrzeżenie w logach serwera, bez crashowania wątku.

#### C. Tajemnice i wrażliwe zasoby
- Kod serwerowy i konfiguracja bilansu krytycznego umieszczane w `ServerScriptService` lub `ServerStorage`.
- `ReplicatedStorage` zawiera wyłącznie moduły czysto prezentacyjne i definicje struktur współdzielonych. Żadne tajne tokeny, API keys zewnętrznych serwisów (np. OpenCloud) nie mogą znaleźć się w `ReplicatedStorage`.

#### D. Płatności platformowe i monetyzacja (Robux)
Rozdzielamy dwa całkowicie odrębne mechanizmy platformy Roblox (zgodnie z zatwierdzoną strukturą produktów w `docs/25_approved_product_structure.md` i zakresem w `docs/26_approved_launch_scope_and_pro_availability.md`):

1. **Trwałe gamepassy (Pro Permit, Buy MAX, późniejsze Auto-Hatch kurczaków)**:
   - **Nie korzystają z `ProcessReceipt`**. Uprawnienia są trwale powiązane z kontem gracza w ekosystemie Roblox.
   - Weryfikacja własności wyłącznie po stronie serwera za pomocą asynchronicznego wywołania `MarketplaceService:UserOwnsGamePassAsync(userId, passId)` w bezpiecznym bloku `pcall`.
   - Sprawdzanie uprawnień następuje przy wejściu gracza na serwer oraz opcjonalnie po zdarzeniu `MarketplaceService.PromptGamePassPurchaseFinished`.
   - **Nigdy nie ufać klientowi** w kwestii posiadania gamepassa — klient może zgłosić zakup, lecz serwer autorytatywnie potwierdza to przez API platformy.
   - **Wariant A dla Pro (D26)**: Przed aktywacją korzyści serwer sprawdza kwalifikację konta do płatnych modyfikatorów losowych. Dla kont nieuprawnionych bonus +10 p.p. do łączenia petów (D01) pozostaje niedostępny, podczas gdy pozostałe korzyści Pro (silosy, pełny dochód offline, sloty boostów i petów) działają normalnie. Przed zakupem gracz musi widzieć jasny opis rzeczywistej oferty; w v1 nie wprowadza się automatycznego zamiennika.

2. **Zakupy powtarzalne / Developer Products (Pakiety GE, rozbicie Piggy — warunkowo po bilansie)**:
   - Realizowane **wyłącznie** przez serwerowy callback `MarketplaceService.ProcessReceipt(receiptInfo)`.
   - Każda transakcja posiada unikalny identyfikator `receiptInfo.PurchaseId`. Serwer musi zweryfikować w trwałym zapisie (D07), czy dany `PurchaseId` nie został już zrealizowany.
   - Przyznanie waluty/korzyści oraz utrwalenie znacznika transakcji musi nastąpić w trwałym zapisie przed zwróceniem decyzji.
   - Dopiero po potwierdzonym trwałym zapisie serwer zwraca `Enum.ProductPurchaseDecision.PurchaseGranted`.
   - W przypadku błędu zapisu, braku pewności transakcji lub niedostępności danych serwer **musi** zwrócić `Enum.ProductPurchaseDecision.NotProcessedYet`, co informuje Roblox o konieczności ponowienia próby doręczenia receiptu.
   - Źródło dokumentacji Roblox: [Roblox Creator Hub — MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) (sprawdzone: 2026-10-23).

---

## 3. Checklist bezpieczeństwa przed scaleniem kodu (Roblox / Luau)

Przed zatwierdzeniem nowego modułu lub Remote'a w HatchTheEgg weryfikujemy:

- [ ] **Typowanie argumentów sieciowych**: Czy każdy parametr odebrany z `OnServerEvent` / `OnServerInvoke` jest rygorystycznie sprawdzany (`typeof`, sanity check długości tekstu, zakres liczb)?
- [ ] **Brak zaufania do liczb klienta**: Czy serwer sam pobiera aktualne saldo, cenę i modyfikatory, ignorując jakiekolwiek kwoty przysłane przez klienta?
- [ ] **Ochrona przed NaN / Inf**: Czy liczby przesyłane lub kalkulowane nie są `NaN` ani `math.huge` (chyba że celowo dozwolone w specyfikacji)?
- [ ] **Rate Limiting**: Czy dane zdarzenie sieciowe ma ochronę przed powtarzaniem w pętli?
- [ ] **Idempotencja nagród (D07)**: Czy powtórzenie wywołania tego samego `rewardId` lub `packageId` z tym samym identyfikatorem transakcji nie przyzna nagrody dwukrotnie?
- [ ] **Lokalizacja modułu**: Czy logika biznesowa znajduje się w `ServerScriptService` / `ServerStorage`, a nie w `StarterPlayerScripts` / `ReplicatedStorage`?
- [ ] **Rozdzielenie GamePass vs Developer Product**: Czy trwałe gamepassy (Pro, Buy MAX) są weryfikowane po stronie serwera przez `UserOwnsGamePassAsync` (z uwzględnieniem wariantu A Pro), a zakupy powtarzalne (GE, Piggy) wyłącznie przez `ProcessReceipt`?
- [ ] **Obsługa błędów pcall**: Czy wszystkie asynchroniczne wywołania serwisów platformy (`DataStoreService`, `MarketplaceService`) są owinięte w `pcall` z właściwą obsługą niepowodzenia?
- [ ] **Brak wycieków w print**: Czy logi produkcyjne nie zaśmiecają konsoli klienta wrażliwymi informacjami o sesji?
