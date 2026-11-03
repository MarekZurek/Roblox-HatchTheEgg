# Samouczek Progressive Disclosure i Reaktywny Wskaźnik Kalendarza — Raport Dostawy (03.11.2026)

## 1. Zakres dostawy i kontekst

Dostawa obejmuje pełną przebudowę samouczka onboardingowego nowego gracza w architekturze **Progressive Disclosure** (stopniowe odkrywanie interfejsu), rozwiązanie konfliktów przestrzennych z oknami modalnymi (Krok 4 vs przycisk odbioru nagród) oraz wdrożenie w pełni reaktywnego cyklu życia wskaźnika powiadomień (`!`) przy kalendarzu nagród dziennych.

---

## 2. Zrealizowane funkcjonalności i zmiany techniczne

### 2.1. Samouczek Onboardingowy: Wzorzec Progressive Disclosure
* **Zastąpienie starego baneru:** Dawny statyczny pasek tekstowy nad górnym panelem stawek (`TutorialBannerLabel`) został zastąpiony dużą, responsywną kartą celu (`TutorialObjectiveCard`, bazowy rozmiar 600×110 px z `AnchorPoint = (0.5, 0)`).
* **Ukrywanie elementów nieaktywnych:** Na świeżym profilu elementy HUD, które nie dotyczą bieżącego etapu, są całkowicie ukryte (`Visible = false`), a odblokowują się sekwencyjnie w miarę realizacji celów:
  * **Krok 1 (Wylęg):** Widoczny wyłącznie wskaźnik zapasu wylęgarni (`HatcheryFrame`). Gracz instruowany jest o wejściu na czerwoną płytę wylęgarni na środku farmy (tempo do 30 kurczaków/s).
  * **Krok 2 (Badania):** Odkrycie licznika gotówki (`CashLabel`), górnego paska tempa (`TopRatesPanel`) oraz przycisku `Badania` w prawym docku z podświetloną złotą ramką celu.
  * **Krok 3 (Infrastruktura):** Odkrycie przycisków `Kurniki` i `Flota` w prawym docku oraz wskaźnika kurników farmy.
  * **Krok 4 (Dziennik Nagród):** Odkrycie przycisku `Nagrody` (kalendarz i trofea) z dedykowaną ramką naprowadzającą.
  * **Krok 5 (Pełny interfejs):** Odkrycie przycisków `Sklep`, `Epickie`, `Prestiż`, portfela Diamentów oraz trwałe ukrycie karty samouczka.
* **Oczyszczenie tekstów samouczka:**
  * Usunięto całkowicie z pamięci i kodu samouczka przestarzałe odniesienia do „Wygodnych gniazd” (`comfy_nests`).
  * Zaktualizowano instrukcję wylęgu na wskazanie czerwonej płyty na środku farmy.

### 2.2. Rozwiązanie konfliktu: Krok 4 a okna modalne
* **Ukrywanie karty samouczka przy otwartych modalach:** W [`src/client/HUD.luau`](../../src/client/HUD.luau) dodano metody `isAnyModalOpen()` oraz `_updateTutorialCardVisibility()`. Podpięto nasłuchiwanie zdarzeń `:GetPropertyChangedSignal("Visible")` pod wszystkie 10 okien modalnych gry (`habitatsModal`, `vehiclesModal`, `shopFrame`, `petsModal`, `petHatchModal`, `shopModal`, `calendarModal`, `eggUpgradeModal`, `epicResearchModal`, `prestigeModal`).
* **Zasada pierwszeństwa modalnego:** Kiedy jakiekolwiek okno modalne zostaje otwarte, `TutorialObjectiveCard` jest automatycznie ukrywane (`Visible = false`), dzięki czemu nie przysłania przycisku `ClaimDailyGiftButton` ani żadnych innych elementów funkcyjnych. Po zamknięciu modala karta celu płynnie wraca na ekran.
* **Hierarchia głębokości (ZIndex):** W [`src/client/ui/StudUi.luau`](../../src/client/ui/StudUi.luau) podniesiono bazowy `ZIndex` kontenerów modalnych do poziomu `50` (nagłówki `52`, przyciski akcji `52–54`), eliminując jakiekolwiek ryzyko kolizji z elementami HUD (bazowy ZIndex 1–10).
* **Pozycjonowanie przycisku kalendarza:** Przycisk `CalendarMenuButton` przeniesiono z dolnego klastra pod odznakę farmy gracza w lewym górnym rogu ekranu (`UDim2.new(0, 16, 0, 96)`), co gwarantuje separację od dolnych paneli informacyjnych.
* **Responsywność i Safe Area:** Szerokość karty samouczka jest dynamicznie ograniczana wzorem `math.clamp(rootW - 190, 280, 560)`, co zapewnia min. 95 px marginesu z każdej strony na ekranach mobilnych.

### 2.3. Kalendarz nagród: Reaktywny wskaźnik powiadomień `!` (`AlertBadge`)
* **Dynamiczny cykl życia wskaźnika:** Wcześniejszy statyczny badge z wykrzyknikiem został powiązany w `HUD.luau` jako referencja `self.calendarAlertBadge`.
* **Weryfikacja czasu serwera:** W metodzie `HUD:update()` widoczność kropki powiadomienia jest obliczana według stanu odebrania nagrody dnia UTC:
  ```luau
  local curUtc = math.floor((if isRoblox then workspace:GetServerTimeNow() else os.time()) / 86400)
  local lastDayUtc = (progress and progress.lastCalendarDayUtc) or -1
  local alreadyClaimed = (lastDayUtc >= curUtc and lastDayUtc > 0)
  if self.calendarAlertBadge then
      self.calendarAlertBadge.Visible = not alreadyClaimed
  end
  ```
* **Optymistyczne ukrycie:** W momencie kliknięcia `ClaimDailyGiftButton`, `self.calendarAlertBadge.Visible` jest natychmiast ustawiane na `false`, eliminując opóźnienia wizualne przed nadejściem potwierdzenia z serwera.
* **Informacja o odebraniu nagrody:** W oknie kalendarza dodano etykietę `CalendarClaimStatusLabel` informującą gracza o odebraniu dzisiejszej nagrody ("ODEBRANA (Wróć jutro!)"), zielony stan przycisku oraz odznaki `✓` na komórkach kalendarza.

---

## 3. Ograniczenia i rozmiary plików

* **Limit rozmiaru skryptu w Roblox Studio (200 KB):**
  * `src/client/HUD.luau`: **198 046 bajtów** (limit < 200 000 bajtów ściśle dotrzymany).
* **Izolacja kwarantanny:**
  * Pliki odłożonego bilansu (`docs/17`–`21`) nie były modyfikowane ani otwierane.

---

## 4. Dowody testowe (L) i weryfikacja w Roblox Studio

1. **Pełny zestaw testów `tools/test.ps1` (Lune 0.11.1):**
   * Rojo: `PASS_STATIC_BUILD` (45 modułów, 2 entrypointy).
   * Oracles Python: generatory akcji, katalogów, populacji i kalendarza `PASS`.
   * Testy samouczka (`tests/tutorial/run.luau`): **81 assertions PASS**.
   * Testy UI i HUD (`tests/ui/run.luau`): **481 assertions PASS**.
   * Testy zadań UI 77–80 (`tests/ui_tasks_77_80/run.luau`): **230 assertions PASS**.
   * Cykle kalendarza (`tests/calendar_cycle/run.luau`): **9812 assertions PASS** (10 cykli × 28 dni).
   * Suita akceptacyjna (`tests/acceptance/run.luau`): **264 assertions PASS across 16 scenarios**.
   * Release Candidate Suite (`tests/release_candidate/run.luau`): **124 assertions PASS**.
   * Wszystkie 54 suity testowe Lune zakończone kodem wyjścia 0.

2. **Weryfikacja w Roblox Studio DataModel:**
   * Wszystkie 47 skryptów w projekcie zsynchronizowano bezpośrednio z działającą instancją Studio (`HatchTheEgg.rbxlx`).
   * Zweryfikowano obecność logiki `self.calendarAlertBadge` i `not alreadyClaimed` w obiekcie `StarterPlayer.StarterPlayerScripts.HatchTheEggClient.HUD`.
