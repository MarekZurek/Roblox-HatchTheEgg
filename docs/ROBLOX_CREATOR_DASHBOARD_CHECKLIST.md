# Roblox Creator Hub — Kompletna Checklist Przedpublikacyjna (HatchTheEgg)

Stan sprawdzony z kodem: **04.11.2026**. Lista czynności przed publikacją; odhaczenie punktów wymaga dowodu z docelowego środowiska. Dokument nie zatwierdza wydania ani nowych cen. Dotychczasowe propozycje cen zachowano bez zmian; końcowa cena jest widoczna w oknie Roblox.

---

## 1. Podstawowe Informacje (Experience Overview & Basic Info)

* [ ] **Nazwa Doświadczenia (Title):**
  * Rekomendacja: `Hatch the Egg 🥚 [SIMULATOR]` lub `Hatch the Egg! 🐣`
  * Limit: do 50 znaków. Tytuł powinien zawierać emoji oraz jednoznaczny gatunek.
* [ ] **Opis Doświadczenia (Description):**
  * Angielski opis pętli gry: `Hatch chickens, expand your farm, upgrade your fleet, discover new eggs, and prestige!`
  * Sekcja społecznościowa:
    * `👍 LIKE THE GAME FOR MORE UPDATES!`
    * Nie reklamować kodu `RELEASE`, nagrody ani innych funkcji bez potwierdzonej implementacji i odbioru.
  * Słowa kluczowe (SEO): *Simulator, Idle, Incremental, Farm, Tycoon, Pets, Hatching, Prestige*.
* [ ] **Właściciel gry (Creator Entity):**
  * **KRYTYCZNE:** Doświadczenie powinno być przypisane do **Grupy Roblox** (Group-Owned), a nie profilu osobistego. Zapewnia to:
    * Zarządzanie podziałem przychodów (Group Payouts).
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
    * Wypełnić według faktycznie udostępnionych funkcji. Produkcyjna fuzja i zakup boostów pozostają odłożone; sam port testowy nie dowodzi wdrożenia.
    * Przed uruchomieniem płatnego losowania sprawdzić ujawnienie wszystkich wyników i liczbowych szans oraz bieżące `ArePaidRandomItemsRestricted` dla gracza. Nie zastępować odpowiedzi API stałą listą krajów. [Oficjalne wytyczne Roblox](https://create.roblox.com/docs/production/monetization/paid-random-items).
    * Obecna kontrola polityki konta dla bonusu Pro nie jest odbiorem wszystkich przyszłych inkubatorów. Nie reklamować aktywnego bonusu fuzji przed wdrożeniem tej funkcji.
* [ ] **Kwalifikacja wiekowa:** Zapisać wynik aktualnego kwestionariusza dla rzeczywistej zawartości; nie zakładać konkretnego wyniku na podstawie tej listy.

---

## 3. Monetyzacja — Przepustki i Produkty (Creator Hub -> Monetization)

Tworzyć i włączać tylko produkty z aktualnej listy poniżej. Stałe uprawnienia to [game passy](https://create.roblox.com/docs/production/monetization/passes), a pakiety diamentów i jednostki ulepszeń Epic to [developer products](https://create.roblox.com/docs/production/monetization/developer-products). Auto-Hatch, Piggy, VIP oraz stare `epic_tier_1..4` nie są produktami do uruchomienia w tym kroku.

### 3.1. Przepustki Jednorazowe (Game Passes)

| Identyfikator w kodzie | Nazwa dla gracza | Dotychczasowa propozycja ceny | Działająca korzyść |
|---|---|---|---|
| `pro_permit` | **PRO Permit** | **399–799 R$** | 18h zamiast 6h offline, 100% zamiast 50% dochodu offline, 5 zamiast 2 aktywnych boostów. Fuzja i jej bonus +10 punktów procentowych są niedostępne w tej wersji. |
| `buy_max` | **Buy MAX Research** | **149–299 R$** | Zakup maksymalnej dostępnej liczby poziomów badań jednym kliknięciem; poziomy nadal kosztują gotówkę gracza. Osobny pass poza PRO. |
| `double_cash` | **2x Cash** | **299–499 R$** | Stały mnożnik ×2 dochodu ze sprzedaży jaj. |

### 3.2. Produkty Dewelopera — Zakupy Wielokrotne

| Identyfikator w kodzie | Nazwa / zawartość | Zachowana cena lub propozycja |
|---|---|---|
| `ge_pack_small` | **Diamond Pack — 1,000 Diamonds** | propozycja **99 R$** |
| `ge_pack_large` | **Large Diamond Pack — 10,000 Diamonds** | propozycja **799 R$** |
| `epic_upgrade_9` | Jednostka ulepszenia Epic z pierwszego pasma cenowego | cena próbna **9 R$** |
| `epic_upgrade_19` | Jednostka ulepszenia Epic z drugiego pasma cenowego | cena próbna **19 R$** |
| `epic_upgrade_39` | Jednostka ulepszenia Epic z trzeciego pasma cenowego | cena próbna **39 R$** |
| `epic_upgrade_79` | Jednostka ulepszenia Epic z czwartego pasma cenowego | cena próbna **79 R$** |

- [ ] Nie dodawać hasła „+50% bonus” do dużego pakietu: nie wynika ono z podanych ilości i proponowanych cen.
- [ ] Ceny próbne Epic pochodzą z `src/shared/EpicPricing.luau`. Nie przywracać wycofanych 19/49/99/199 R$ ze starej listy tierów. Uzgodnienie relacji cen Epic do pakietów diamentów pozostaje odłożone; ten przegląd nie zmienia cen ani balansu.
- [ ] Zakup boostów za diamenty pozostaje oznaczony SOON; aktywowanie posiadanych boostów nadal działa.
- [ ] Dzień 28 pozostaje „Mystery” z dotychczasową wypłatą według decyzji 04.11.2026. Trofea i zakup `prophecy_bonus` są zablokowane do v1.2; nie reklamować ich jako aktywnych.

### 3.3. Podłączenie ID produktów

- [ ] Utworzyć produkty we właściwym doświadczeniu, zapisać ich rzeczywiste numeryczne ID i sprawdzić typ każdego produktu.
- [ ] Na skrypcie **`ServerScriptService.HatchTheEgg.Main`** ustawić atrybuty typu **Number**, każdy z dodatnim całkowitym ID Roblox:

| Atrybut skryptu Main | Typ produktu |
|---|---|
| `pro_permit_PlatformId` | Game pass |
| `buy_max_PlatformId` | Game pass |
| `double_cash_PlatformId` | Game pass |
| `ge_pack_small_PlatformId` | Developer product |
| `ge_pack_large_PlatformId` | Developer product |
| `epic_upgrade_9_PlatformId` | Developer product |
| `epic_upgrade_19_PlatformId` | Developer product |
| `epic_upgrade_39_PlatformId` | Developer product |
| `epic_upgrade_79_PlatformId` | Developer product |

- [ ] Każde ID musi być unikalne. `Main.server.luau` czyta atrybuty przy starcie; samo edytowanie domyślnych map w `products.luau` nie konfiguruje ofert. Domyślne ID 1001/2001 itd. to wartości fixture'ów, nie ID do wdrożenia.
- [ ] Utrwalić atrybuty w procesie przygotowania miejsca i sprawdzić je po synchronizacji/buildzie. Obecny `default.project.json` nie zapisuje tych wartości; nie zakładać, że sam build Rojo zawiera konfigurację płatności.
- [ ] Uruchomić ponownie serwer po konfiguracji. Brak atrybutu pozostawia produkt nieskonfigurowany; nie omijać tej blokady.

### 3.4. Kontrola zakupów przed publikacją

- [ ] W izolowanym środowisku z trwałym zapisem sprawdzić podgląd produktu, finalną cenę w oknie Roblox, anulowanie i ponowne wejście gracza.
- [ ] Dla developer products sprawdzić jednokrotną wypłatę oraz ponowienie `ProcessReceipt` po utracie odpowiedzi. Samo zamknięcie okna zakupu nie potwierdza wypłaty.
- [ ] Dla Epic sprawdzić otrzymanie jednej jednostki, wykorzystanie jej tylko raz oraz zachowanie niewykorzystanej jednostki po reconnect.
- [ ] Dla passów sprawdzić posiadanie po reconnect oraz brak ponownego zakupu już posiadanego passa.
- [ ] Dla Buy MAX sprawdzić odrzucenie komendy bez passa i zakup za gotówkę z passem.
- [ ] Nie uznawać trybu `STUDIO_MEMORY` za test płatności lub chmury — zakupy platformowe są w nim wyłączone.

---

## 4. Bezpieczeństwo i Konfiguracja Uprawnień (Security & Game Settings)

W *Creator Hub -> Experience Settings -> Security* lub *Roblox Studio -> Game Settings -> Security*:

* [ ] **`Allow HTTP Requests`:** Ustalić według faktycznych wywołań HTTP w wydawanej wersji. Lokalny warsztat synchronizacji nie jest dowodem, że produkcyjna gra wymaga webhooków lub zewnętrznej telemetrii.
* [ ] **`Enable Studio Access to API Services`:** Skonfigurować dla izolowanego testu trwałego zapisu w Studio. Projekt korzysta z `RobloxDataStorePort` i własnej obsługi sesji; nie zakładać instalacji zewnętrznego ProfileService. Tryb pamięci lokalnej nie sprawdza DataStore.
* [ ] **`Third-Party Teleports`:** **WYŁĄCZONE (False)** (zwiększa bezpieczeństwo przed nieautoryzowanym przekierowaniem graczy).
* [ ] **`Third-Party Sales`:** **WYŁĄCZONE (False)** (zapobiega nieautoryzowanym zakupom przedmiotów spoza uniwersum gry).

---

## 5. Konfiguracja Serwerów i Wydajności (Places & Server Limits)

W *Creator Hub -> Places -> Start Place -> Configuration*:

* [ ] **Limit graczy na serwerze (Max Players):**
  * Dotychczasowa propozycja do pomiaru: **8–12 graczy** (maksymalnie 15). Nie jest to wynik wykonanego profilu wydajności.
  * *Uzasadnienie wydajnościowe:* Każdy gracz posiada osobną trójwymiarową farmę z 4 kurnikami, stanowiskami floty transportowej, animacjami do 32 biegających kurczaków oraz inkubatorami. To propozycja limitu, nie gwarancja 60 FPS; wymaga pomiaru na docelowych urządzeniach mobilnych przy pełnym serwerze.
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
    1. *Miniatura Główna:* Wielki kurnik, dziesiątki kurczaków i hasło „Build the biggest farm!”.
    2. *Rozbudowa Farmy:* Pokazać wyłącznie funkcje dostępne w wydawanej wersji; nie reklamować niedostępnej fuzji.
    3. *Flota:* Dostępne pojazdy transportowe; odłożonego „Egg to the Moon” nie przedstawiać jako działającej funkcji.
    4. *System Prestiżu:* Efektowna infografika korzyści po odrodzeniu farmy.
* [ ] **Odznaki dla Graczy (Badges) — propozycje:**
  * Nie traktować listy jako wdrożonych nagród. Włączenie wymaga przypiętych ID i sprawdzonego serwerowego przyznawania; nie reklamować brakującej funkcji.
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

* [ ] **Język podstawowy (Source Language):** `English (en-US)` zgodnie z #104.
* [ ] **Automatyczne tłumaczenia:** Nie włączać jako części tego wydania; obecny zakres to English-only. Przejrzeć teksty gry oraz opisy produktów i doświadczenia po angielsku.
* [ ] **Terminologia:** `Diamonds` = waluta premium (`GE` w zapisie), `Soul Eggs` = waluta prestiżu (`SE`), `Cash` = gotówka. Soul Beacony wzmacniają `Prestige Earnings`, nie Diamonds.

---

## 9. Analityka i Monitorowanie (Creator Analytics)

Po publikacji gry regularnie weryfikować metryki w *Creator Hub -> Analytics*. Poniższe dotychczasowe cele są propozycjami do weryfikacji, nie dowodem osiągniętej jakości:

* [ ] **Retencja (Retention):** Cel D1 >= 35–40%, Cel D7 >= 12–15%.
* [ ] **Średni czas sesji (Average Session Time):** Cel >= 12–18 minut.
* [ ] **Stabilność i Crashe (Performance -> Crash Rates):**
  * Client Crash Rate < 1.0%.
  * Średnie zużycie pamięci klienta < 1.2 GB (ochrona przed wyłączeniem aplikacji na telefonach z 2–3 GB RAM).

---

## 10. Procedura Uruchomienia Produkcyjnego (Go-Live Step-by-Step)

1. [ ] **Przełączenie bazy danych z pamięci na DataStore:**
   * W izolowanym teście Studio opublikowanego miejsca ustawić atrybut `UseLocalMemoryStore=false` na skrypcie Main. Na produkcji serwer zawsze wymaga `DataStoreService` przez `RobloxDataStorePort`; brak trwałego magazynu blokuje start zamiast przełączać grę na pamięć.
2. [ ] **Synchronizacja sceny i skryptów:**
   * Zbudować finalny plik gry: `rojo build default.project.json --output build/HatchTheEgg.rbxlx`.
   * Otworzyć wynik w Roblox Studio, ustawić i sprawdzić atrybuty produktów z §3.3 oraz zapisać skonfigurowane miejsce. Przed publikacją sprawdzić, że ponowny build/synchronizacja nie usunął atrybutów.
   * Publikować sprawdzone miejsce pod właściwym Place po testach niepublicznych, z zachowaniem konfiguracji produktów.
3. [ ] **Testy w trybie niepublicznym (Soft Launch / Friends & QA):**
   * Ustawić *Access* na: **Private** lub **Friends / Specific Users**.
   * Przetestować na urządzeniu mobilnym i PC: wylęg na czerwonej płycie, zakup badań, otwarcie kalendarza, odbiór nagród, zakup gamepassa w trybie testowym.
4. [ ] **Oficjalne otwarcie (Public Go-Live):**
   * W *Creator Hub -> Experience Settings -> Access* przełączyć status na: **Public (Publiczna)**.
