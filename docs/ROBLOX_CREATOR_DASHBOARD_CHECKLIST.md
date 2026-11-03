# Roblox Creator Hub — Kompletna Checklist Przedpublikacyjna (HatchTheEgg)

Dokument stanowi oficjalny, operacyjny przewodnik wdrożeniowy dla gry **HatchTheEgg** na platformie **Roblox Creator Hub** (`create.roblox.com`) przed oficjalnym otwarciem gry dla graczy (Go-Live).

---

## 1. Podstawowe Informacje (Experience Overview & Basic Info)

* [ ] **Nazwa Doświadczenia (Title):**
  * Rekomendacja: `Hatch the Egg 🥚 [SIMULATOR]` lub `Hatch the Egg! 🐣`
  * Limit: do 50 znaków. Tytuł powinien zawierać emoji oraz jednoznaczny gatunek.
* [ ] **Opis Doświadczenia (Description):**
  * Opis pętli gry: Wylęgaj kurczaki, rozbudowuj kurniki, zarządzaj flotą transportową, odkrywaj nowe jaja, łącz legendarne pety i odradzaj się w systemie Prestiżu!
  * Sekcja społecznościowa:
    * `👍 ZOSTAW LAJKA DLA NOWYCH KODÓW I AKTUALIZACJI!`
    * `🎁 KOD NA START: RELEASE (wpisz w grze, aby odebrać 100 Diamentów!)`
  * Słowa kluczowe (SEO): *Simulator, Idle, Incremental, Farm, Tycoon, Pets, Hatching, Prestige*.
* [ ] **Właściciel gry (Creator Entity):**
  * **KRYTYCZNE:** Doświadczenie powinno być przypisane do **Grupy Roblox** (Group-Owned), a nie profilu osobistego. Zapewnia to:
    * Bezpieczny podział przychodów (Group Payouts) i automatyczną kwalifikację do DevEx.
    * Bezpieczne zarządzanie uprawnieniami programistów i moderatorów bez udostępniania konta głównego.
* [ ] **Gatunek (Genre):**
  * Ustawienie: **Simulation** (lub **Roleplay / Adventure** jako alternatywa).

---

## 2. Wytyczne Wiekowe i Zgodność Prawna (Experience Questionnaire & Age Guidelines)

* [ ] **Wypełnienie Kwestionariusza Doświadczenia (Experience Questionnaire):**
  * **Przemoc i Krew (Violence & Blood):** Zaznaczyć `None` (brak przemocy, kreskówkowa oprawa).
  * **Strach / Horror:** Zaznaczyć `None`.
  * **Alkohol, Tytoń, Niebezpieczne substancje:** Zaznaczyć `None`.
  * **Hazard i Płatne Elementy Losowe (Paid Random Items):**
    * *Uwaga prawna dotycząca inkubatorów petów:* W *HatchTheEgg* pety są losowane z inkubatorów za Diamenty (walutę premium kupowaną za Robux). W rozumieniu polityki Roblox (oraz przepisów w Korei Płd., Holandii i Belgii) jest to mechanika **Paid Random Items**.
    * Zaznaczyć obecność płatnych elementów losowych w kwestionariuszu.
    * Potwierdzić, że gra zawiera wbudowane zabezpieczenie regionalne (`paidRandomAllowed` i polityka z `docs/26` / `docs/31` #58 w [`src/server/platform/products.luau`](../src/server/platform/products.luau)), które wyłącza płatne losowe modyfikatory dla graczy z krajów o zaostrzonych regulacjach.
* [ ] **Kwalifikacja wiekowa:** Gra powinna uzyskać rekomendację **All Ages** (dla każdego) lub **9+**.

---

## 3. Monetyzacja — Przepustki i Produkty (Creator Hub -> Monetization)

Wszystkie produkty zdefiniowane w architekturze gry ([`src/server/platform/products.luau`](../src/server/platform/products.luau) oraz [docs/25](../docs/25_approved_product_structure.md)) muszą zostać utworzone w Creator Hub, a ich unikalne numeryczne identyfikatory wprowadzone do kodu gry.

### 3.1. Przepustki Jednorazowe (Game Passes)
Tworzone w: *Creator Hub -> Experiences -> HatchTheEgg -> Monetization -> Passes*

| Identyfikator w kodzie | Nazwa w Creator Hub | Sugerowana cena | Ikona (512×512) | Opis dla gracza |
|---|---|---|---|---|
| `pro_permit` | **Przepustka PRO 👑** | **399–799 R$** | Korona VIP / Złote pióro | 18h produkcji offline (zamiast 6h), 100% zysków offline, 5 slotów na boosty, +10 p.p. do fuzji petów! |
| `buy_max` | **Buy MAX Research ⚡** | **149–299 R$** | Błyskawica MAX | Odblokowuje przycisk natychmiastowego zakupu maksymalnej liczby badań jednym kliknięciem! |
| `double_cash` | **2x Cash (Podwójna Kasa) ⭐** | **299–499 R$** | Worek monet 2x | Trwale podwaja wszystkie zyski gotówki ze sprzedaży jaj i farmy! |
| `auto_hatch` | **Auto-Wylęg (Egg Bot) 🤖** | *v1.1 (wkrótce)* | Robot / Jajko | Automatycznie wylęga kurczaki bez konieczności stania na płycie. |

### 3.2. Produkty Dewelopera — Zakupy Wielokrotne (Developer Products)
Tworzone w: *Creator Hub -> Experiences -> HatchTheEgg -> Monetization -> Developer Products*

| Identyfikator w kodzie | Nazwa w Creator Hub | Kwota Diamentów / Rola | Sugerowana cena |
|---|---|---|---|
| `ge_pack_small` | **Mała Paczka Diamentów 💎** | 1,000 Diamentów | **99 R$** |
| `ge_pack_large` | **Duża Paczka Diamentów 💎** | 10,000 Diamentów (+50% bonus) | **799 R$** |
| `piggy_break` | **Rozbicie Skarbonki Diamentów 🐷** | Wypłata zawartości Skarbonki | *Zależna od balansu* |
| `epic_tier_1` | **Badanie Epickie — Szybki Zakup (Tier 1)** | Bezpośrednie odblokowanie poziomu | **19 R$** |
| `epic_tier_2` | **Badanie Epickie — Szybki Zakup (Tier 2)** | Bezpośrednie odblokowanie poziomu | **49 R$** |
| `epic_tier_3` | **Badanie Epickie — Szybki Zakup (Tier 3)** | Bezpośrednie odblokowanie poziomu | **99 R$** |
| `epic_tier_4` | **Badanie Epickie — Szybki Zakup (Tier 4)** | Bezpośrednie odblokowanie poziomu | **199 R$** |

### 3.3. Krok Krytyczny w Kodzie po Utworzeniu Produktów:
* [ ] Pobrać wygenerowane przez Roblox numeryczne ID i zaktualizować tabele mapowania w [`src/server/platform/products.luau`](../src/server/platform/products.luau):
  ```luau
  local PRODUCT_ID_TO_CATALOG_ID = {
      [TWOJE_ROBLOX_ID_GE_SMALL] = "ge_pack_small",
      [TWOJE_ROBLOX_ID_GE_LARGE] = "ge_pack_large",
      [TWOJE_ROBLOX_ID_PRO_PERMIT] = "pro_permit",
      [TWOJE_ROBLOX_ID_BUY_MAX] = "buy_max",
      [TWOJE_ROBLOX_ID_DOUBLE_CASH] = "double_cash",
      -- ...
  }
  ```

---

## 4. Bezpieczeństwo i Konfiguracja Uprawnień (Security & Game Settings)

W *Creator Hub -> Experience Settings -> Security* lub *Roblox Studio -> Game Settings -> Security*:

* [ ] **`Allow HTTP Requests`:** **WŁĄCZONE (True)**
  * Wymagane dla logowania telemetrycznego, webhooków Discorda i synchronizacji.
* [ ] **`Enable Studio Access to API Services`:** **WŁĄCZONE (True)**
  * Wymagane, aby deweloperzy mogli testować bazy danych `DataStoreService`, mechanizm sesji `ProfileService` i `MemoryStoreService` w Studio.
* [ ] **`Third-Party Teleports`:** **WYŁĄCZONE (False)** (zwiększa bezpieczeństwo przed nieautoryzowanym przekierowaniem graczy).
* [ ] **`Third-Party Sales`:** **WYŁĄCZONE (False)** (zapobiega nieautoryzowanym zakupom przedmiotów spoza uniwersum gry).

---

## 5. Konfiguracja Serwerów i Wydajności (Places & Server Limits)

W *Creator Hub -> Places -> Start Place -> Configuration*:

* [ ] **Limit graczy na serwerze (Max Players):**
  * Ustawić na: **8–12 graczy** (maksymalnie 15).
  * *Uzasadnienie wydajnościowe:* Każdy gracz posiada osobną trójwymiarową farmę z 4 kurnikami, stanowiskami floty transportowej, animacjami do 32 biegających kurczaków oraz inkubatorami. Utrzymanie limitu 8–12 graczy gwarantuje stałe 60 FPS na urządzeniach mobilnych (ponad 50% bazy graczy).
* [ ] **Wypełnianie serwerów (Server Fill):**
  * Ustawić na: **Roblox optimizes server fill** (rekomendowane dla symulatorów, sprzyja spotykaniu innych graczy).
* [ ] **Prywatne serwery (Private Servers / VIP Servers):**
  * Zezwolić na prywatne serwery: **WŁĄCZONE (True)**.
  * Cena: **Darmowe (0 R$)** lub symboliczne **50 R$** (gracze gier typu idle/tycoon bardzo cenią możliwość spokojnej gry na prywatnym serwerze).

---

## 6. Obsługiwane Urządzenia (Access & Supported Devices)

W *Creator Hub -> Experience Settings -> Audience / Places*:

* [ ] **Komputery (Computer / Desktop):** ✅ **Włączone** (wsparcie myszy i skrótów klawiaturowych).
* [ ] **Telefony (Mobile / Phone):** ✅ **Włączone** (UI zoptymalizowane pod ekrany dotykowe, safe area, klastry walut pionowe dla ekranów <920px).
* [ ] **Tablety (Tablet):** ✅ **Włączone** (responsywne skalowanie interfejsu StudUi).
* [ ] **Konsole (Console / PlayStation / Xbox):** ⚠️ **Wyłączone na premierę v1.0** (włączenie wymaga certyfikacji nawigacji Gamepadem i dedykowanych podpowiedzi D-Pad/ButtonA).
* [ ] **Gogle VR:** ⚠️ **Wyłączone**.

---

## 7. Materiały Wizualne i Marketingowe (Assets & Branding)

W *Creator Hub -> Experience Settings -> Basic Settings*:

* [ ] **Ikona Gry (Game Icon):**
  * Wymiary: **512×512 px** (kwadrat, format PNG).
  * Wytyczne: Jasne, nasycone kolory, centralnie umieszczone jajo ze złotym pęknięciem i wykluwający się kurczak; wysoki kontrast wyróżniający się w wyszukiwarce Roblox.
* [ ] **Miniatury (Thumbnails):**
  * Wymiary: **1920×1080 px** (proporcje 16:9).
  * Przygotować min. 3–5 profesjonalnych miniatur:
    1. *Miniatura Główna:* Wielki kurnik, dziesiątki kurczaków i hasło „Zbuduj największą fermę!”.
    2. *Pety i Fuzja:* Prezentacja rzadkich petów Rainbow/Golden wykluwających się z inkubatora.
    3. *Flota i Kosmos:* Pojazdy transportowe oraz stacja rakietowa „Egg to the Moon 🚀”.
    4. *System Prestiżu:* Efektowna infografika korzyści po odrodzeniu farmy.
* [ ] **Odznaki dla Graczy (Badges):**
  * Tworzone w: *Monetization -> Badges* (ikony 512×512 px wpisujące się w koło):
    1. 🐣 *Witaj na Farmie!* (Za wylęg pierwszego kurczaka).
    2. 🚜 *Pierwszy Transport* (Za zakup pierwszego pojazdu).
    3. 🔬 *Naukowiec* (Za odblokowanie 10 badań).
    4. 🐱 *Właściciel Peta* (Za wyklucie pierwszego peta z inkubatora).
    5. 🌟 *Pierwsze Odrodzenie* (Za wykonanie pierwszego Prestiżu).
    6. 💰 *Jajeczny Magnat* (Za zgromadzenie pierwszego miliona monet).

---

## 8. Lokalizacja i Języki (Localization)

W *Creator Hub -> Audience -> Localization*:

* [ ] **Język podstawowy (Source Language):** `Polski (pl)` lub `English (en-US)`.
* [ ] **Automatyczne tłumaczenia (Auto-Localization):** **WŁĄCZONE (True)**.
  * Roblox automatycznie przetłumaczy teksty UI na języki: angielski, hiszpański, portugalski, francuski, niemiecki, japoński, koreański i wietnamski.
* [ ] **Weryfikacja kluczowych pojęć w słowniku:**
  * Upewnić się, że terminy takie jak *Diamenty (Diamonds)*, *Gotówka (Cash)*, *Wylęgarnia (Hatchery)*, *Prestiż (Prestige)* nie są błędnie tłumaczone przez translator automatyczny.

---

## 9. Analityka i Monitorowanie (Creator Analytics)

Po publikacji gry regularnie weryfikować metryki w *Creator Hub -> Analytics*:

* [ ] **Retencja (Retention):** Cel D1 >= 35–40%, Cel D7 >= 12–15%.
* [ ] **Średni czas sesji (Average Session Time):** Cel >= 12–18 minut.
* [ ] **Stabilność i Crashe (Performance -> Crash Rates):**
  * Client Crash Rate < 1.0%.
  * Średnie zużycie pamięci klienta < 1.2 GB (ochrona przed wyłączeniem aplikacji na telefonach z 2–3 GB RAM).

---

## 10. Procedura Uruchomienia Produkcyjnego (Go-Live Step-by-Step)

1. [ ] **Przełączenie bazy danych z pamięci na DataStore:**
   * W `src/server/Main.server.luau` upewnić się, że flaga `UseLocalMemoryStore` wynosi `false` (w trybie produkcyjnym używany jest zaufany `DataStoreService` z ProfileService).
2. [ ] **Synchronizacja sceny i skryptów:**
   * Zbudować finalny plik gry: `rojo build default.project.json --output build/HatchTheEgg.rbxlx`.
   * Otworzyć i opublikować w Roblox Studio: *File -> Publish to Roblox as...* pod oficjalny Place gry.
3. [ ] **Testy w trybie niepublicznym (Soft Launch / Friends & QA):**
   * Ustawić *Access* na: **Private** lub **Friends / Specific Users**.
   * Przetestować na urządzeniu mobilnym i PC: wylęg na czerwonej płycie, zakup badań, otwarcie kalendarza, odbiór nagród, zakup gamepassa w trybie testowym.
4. [ ] **Oficjalne otwarcie (Public Go-Live):**
   * W *Creator Hub -> Experience Settings -> Access* przełączyć status na: **Public (Publiczna)**.
