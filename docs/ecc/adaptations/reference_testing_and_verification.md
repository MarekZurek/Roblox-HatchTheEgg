# Adaptacja: Testy referencyjne i pętla weryfikacji w Luau

> **Informacja licencyjna i źródło**  
> Źródła pierwotne:  
> - [skills/tdd-workflow/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/tdd-workflow/SKILL.md)  
> - [skills/verification-loop/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/verification-loop/SKILL.md)  
> - [rules/common/testing.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/rules/common/testing.md)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

W ECC proces TDD i weryfikacji opiera się na:
- **RED/GREEN/Refactor**: test poprzedza implementację, reprodukuje brakującą funkcjonalność lub defekt, a kod tworzony jest pod spełnienie asercji.
- **Wymóg 80%+ pokrycia (Coverage)**: sztywny próg dla całego projektu w testach jednostkowych, integracyjnych i E2E (Playwright).
- **TDD Evidence Report**: ustrukturyzowany raport utrwalający dowody wykonania testów i zachowane gwarancje.
- **Verification Loop**: sekwencyjna pętla weryfikacyjna przed zatwierdzeniem prac.

---

## 2. Propozycja adaptacji dla HatchTheEgg (Roblox / Luau)

---

## 3. Pętla weryfikacji etapu (Roblox Verification Loop)

Przed zakończeniem implementacji dowolnego modułu lub Story weryfikacja obejmuje 5 kroków:

1. **Analiza statyczna i składnia**: Uruchomienie lintera Luau (np. Selene) lub wbudowanego analizatora typów Roblox Studio w trybie ścisłym (`--!strict`). Zero błędów typowania na granicach modułów.
2. **Wykonanie testów referencyjnych**: Uruchomienie skryptu testowego Luau (np. z użyciem TestEZ lub dedykowanego runnera asercji). Wszystkie wektory matematyczne z dokumentacji muszą zwrócić wynik zgodny z referencją w zdefiniowanych granicach tolerancji zmiennoprzecinkowej $\varepsilon$.
3. **Audyt serwer-klient (Security)**: Weryfikacja, czy żaden `RemoteEvent` ani `RemoteFunction` nie przyjmuje liczb określających saldo, cenę, ilość waluty ani przyznawane przedmioty.
4. **Przegląd różnic (Diff Review)**: Upewnienie się, że zmiany nie modyfikują zatwierdzonego bilansu ani chronionych plików dokumentacji (`docs/17–21`, materiały robocze, `docs/CURRENT_SPEC.md`).
5. **Weryfikacja idempotencji i zapisu**: Sprawdzenie, czy ponowienie operacji po przerwaniu połączenia nie powoduje podwójnego rozliczenia ani ponownego losowania wyniku (D07).

---

## 4. Szablon raportu weryfikacji etapu (Evidence Report Template)

> [!IMPORTANT]
> **Zasada uczciwości raportowania**: Szablon poniżej służy do wypełnienia **po** faktycznym uruchomieniu testów w przyszłości. Nie wolno wpisywać wymyślonych wyników liczbowych ani deklarować statusu `PASS` dla testów, które nie zostały jeszcze uruchomione. Domyślnym statusem przed wykonaniem jest `NIE URUCHOMIONO`.

```markdown
# Raport weryfikacji: [ID Story / Nazwa Modułu]

**Data wykonania**: [YYYY-MM-DD lub NIE URUCHOMIONO]
**Środowisko wykonania**: [np. Roblox Studio / Standalone Luau CLI / TestEZ / NIE URUCHOMIONO]
**Testowany moduł**: `ServerScriptService/...`
**Osoba / Asystent**: ...
**Status wdrożenia**: PROPOZYCJA TECHNICZNA (P) — NIE URUCHOMIONO

## 1. Tabela testów referencyjnych

| Identyfikator testu | Status źródła (N / S / R) | Konkretny plik i sekcja referencyjna | Dane wejściowe testu | Wartość referencyjna oczekiwana | Wartość uzyskana z kodu Luau | Dopuszczalna tolerancja (ε) | Status wykonania |
|---|---|---|---|---|---|---|---|
| TC-FV-01 | N | dokumentacja referencyjna (`farm_value` case 0) & `docs/02_eggs_and_farm_value.md#2` (runner: dokumentacja referencyjna) | Parametry farmy Edible (i=0): pop=0, hab=250, ship=5000 | 13732.00679132647 (snapshot z modelu referencyjnego modelu referencyjnym) | <wartość z modułu Luau> | 1e-6 względna | NIE URUCHOMIONO |
| TC-SE-01 | N | dokumentacja referencyjna (`prestige` cases) & `docs/05_prestige_soul_eggs_and_boosts.md#2` (runner: dokumentacja referencyjna) | Przychód prestiżowy wejściowy (np. 1e6, 1e21, 1e60) | Wartość SE z funkcji przedziałowej modelu referencyjnym | <wartość z modułu Luau> | Dokładna (double IEEE 754) | NIE URUCHOMIONO |
| TC-OFFLINE-01 | N | dokumentacja referencyjna (case 0) & `docs/10_verified_simulation_and_server_config.md` (runner: dokumentacja referencyjna) | duration=1.0s, away=true, ihr=1, cap=100000, ship=6000 | Wynik symulacji (krok dt=0.3s): cash, eggs, pop z modelu referencyjnego | <wartość z modułu Luau> | 1e-12 względna | NIE URUCHOMIONO |
| TC-CAL-01 | S | dokumentacja referencyjna (`monthlyRows`) & `docs/15_calendar_gameplay_formula_and_roblox_scope.md` (skrypt: dokumentacja referencyjna) | Cykl: <c>, Dzień: <d> | min(cap, base * 2^m) wg tabeli konfiguracji referencyjnej | <wartość z modułu Luau> | Dokładna całkowita | NIE URUCHOMIONO |
| TC-HAWK-01 | R | `docs/22_gameplay_rules_for_approval.md` (D02) [Brak zewn. pliku JSON — reguła adaptacji Roblox] | pBase: <p>, Suma bonusów: <b> | min(1, pBase * (1 + sum(b))) | <wartość z modułu Luau> | 1e-9 | NIE URUCHOMIONO |
| TC-FUSION-01 | R | `docs/22_gameplay_rules_for_approval.md` (D01) [Brak zewn. pliku JSON — reguła adaptacji Roblox] | Próba zakończona porażką | Pet bazowy nienaruszony, kopie usunięte, licznik gwarancji +1 | <stan po operacji> | Logiczny warunek | NIE URUCHOMIONO |
| TC-IDEMP-01 | R | `docs/22_gameplay_rules_for_approval.md` (D07) [Brak zewn. pliku JSON — reguła adaptacji Roblox] | Podwójne żądanie z tym samym TxnId | Pierwsze: wykonano; Drugie: zwrócono ten sam wynik bez naliczenia | <odpowiedź serwera> | Brak podwójnej wypłaty | NIE URUCHOMIONO |

## 2. Bramka jakościowa (Verification Checklist)

- [ ] Analiza statyczna Luau (--!strict): [WYMAGANE PRZED COMMITEM / STATUS: NIE URUCHOMIONO]
- [ ] Walidacja wejść RemoteEvent / RemoteFunction: [WYMAGANE / STATUS: NIE URUCHOMIONO]
- [ ] Determinizm i czystość callbacku UpdateAsync: [WYMAGANE / STATUS: NIE URUCHOMIONO]
- [ ] Brak modyfikacji plików chronionego bilansu (docs/17–21, analysis): [WYMAGANE PRZED COMMITEM / STATUS: NIE SPRAWDZONO]

## 3. Udokumentowane gwarancje zachowania modułu
- [Opis konkretnych gwarancji biznesowych potwierdzonych przez powyższe testy po ich pomyślnym wykonaniu]
```3. **Źródła oczekiwanych wyników**: N/S oznaczają specyfikację obliczeń oraz tabele referencyjne, nie wykonanie testów gry. Wzór FV opisuje dokument 02, SE dokument 05, offline dokument 10, kalendarz dokumenty 11 i 15. Decyzje R, w tym D01–D07, określa dokument 22 i bieżąca specyfikacja. Przyszłe testy Luau muszą korzystać z niezależnie określonych oczekiwań, z jawnymi wejściami i tolerancją. Projekt testu ma status P do czasu wykonania; nie zakładaj istnienia gotowego runnera lub zestawu danych.


## Dostępne tabele referencyjne

[Katalog danych](../../reference_data/README.md) wskazuje pełne ceny/efekty badań, krzywe i nagrody. Są danymi do projektowania testów, bez deklaracji istniejącego runnera lub wykonania Luau. Przykłady rozkładów obejmują jawnie ograniczony zestaw wejść.
