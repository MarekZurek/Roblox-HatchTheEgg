# Review zmian Gemini — dokumentacja, progresja i UI, 28.10.2026

**Wynik: wymaga poprawy.** Nie zamieniono operacji prestiżu z awansem jajka na serwerze, ale UI ma błędne podglądy obu mechanik. Część ofert i badań nie ma pełnej implementacji korzyści. To review, bez poprawek ocenianego kodu, publikacji lub zamykania zgłoszeń.

## Wersja i dowody

Baza Git: `701d087` (dostawa81–82). Oceniono bieżący niezatwierdzony diff oraz wskazane nowe pliki. Autorstwa poszczególnych lokalnych zapisów nie da się udowodnić z Git; przypisanie Gemini wynika ze zlecenia użytkownika. Nie traktowano starego raportu dostawy701d087 jako dowodu dla dzisiejszego diffu. Hashowany zakres zapisano lokalnie w `build/review_gemini_2026_10_28/scope.json`.

- Pełny `tools/test.ps1` z Pythonem z przypiętego runtime: **50 zestawów / 83 071 asercji Luau, 11 testów Python PASS**. Rojo **41 modułów +2 entrypointy PASS_STATIC_BUILD**. Wyniki te nie wykrywają niżej opisanych luk; nie oznaczają odbioru wydania.
- Niezależne reprodukcje na rzeczywistych modułach w Lune: `build/review_gemini_2026_10_28/repro.luau`, `repro-results.json`. To sztuczne profile/pamięć i symulowane potwierdzenia, bez prawdziwych zakupów lub DataStore. Pierwsze uruchomienie helpera zatrzymało się na błędnej nazwie `syncEntitlement`; poprawiono wyłącznie helper na faktyczne `grantEntitlement` i ponowiono wszystkie przypadki.
- Studio zastano w Play i pozostawiono uruchomione. Wykonano tylko odczyty GUI i źródeł. PlaceId0, UseLocalMemoryStore=true. Normalizowane SHA256 pięciu wybranych skryptów (HUD, Main klienta, Bootstrap serwera, ViewProjector, ProgressActions) zgadzają się z plikami. Nie dowodzi to zgodności całej sceny ani klikania wszystkich funkcji.
- W trakcie review kontrola hashy nie wykazała zmiany ocenianych plików. Nie zmieniono docs17–21, danych referencyjnych ani źródeł gry. Testy zapisały swoje zwykłe artefakty w build.

## Najważniejsze ustalenia

### F01 — P1: potwierdzenie zakupu badania za Robux nie nadaje badania

`src/client/HUD.luau:2516` wysyła tylko `epic_tier_1..4`, bez identyfikatora wybranego badania. `src/server/platform/products.luau:442` ma dla tej grupy pustą gałąź, po której zaznacza operację/potwierdzenie jako wykonane. Reprodukcja `preparePurchase`→`confirmPurchase` dla epic_tier_1 zwróciła success=true i zapisała processedReceipts, podczas gdy permanent.epic pozostało identyczne.

To lokalna reprodukcja niepełnej ścieżki, **nie dowód obciążenia prawdziwego konta**. Aktualny Main mapuje tylko pro_permit,buy_max i dwa pakietyGE (`Main.server.luau:100`), więc brak mapowania jest dodatkową przeszkodą zakupów Epic. Przed podłączeniem produktów trzeba związać zakup z badaniem, poziomem i jednokrotnym nadaniem albo jawnie wyłączyć tę ofertę.

### F02 — P1: 2× Cash zmienia podgląd, ale nie wypłatę

`ViewProjector.luau:225` mnoży widoczne cashIncomePerSecond przez2. `TimelineSimulation.luau:187` nalicza właściwe pieniądze bez tego uprawnienia. Kontrolowane30 kur,3s, brak innych premii:

|double_cash|Podgląd/s|Gotówka po3s|Akumulator zarobku|
|---|---:|---:|---:|
|false|0.5|1.5|1.5|
|true|1|1.5|1.5|

Ponadto `grantEntitlement('double_cash')` zwraca UNKNOWN_ENTITLEMENT (`Bootstrap.luau:1250`), a normalna synchronizacja własności Main sprawdza tylko Pro/BuyMAX (`Main.server.luau:202`). Auto-Hatch również ma flagę/kartę, ale nie ma konsumenta uruchamiającego automatyczny wylęg. Włączono go availableAtLaunch=true mimo zasady „późniejsze wydanie” w docs26. Potrzebne są pełne korzyści i synchronizacja albo wyłączenie niegotowych ofert; samo OWNED nie wystarcza.

### F03 — P1: płatne badania „floty” nadal dotyczą nieobsługiwanych ekspedycji

Zmieniły się nazwy/opisy, nie reguły efektów. `docs/01_upgrades_and_research.md:173` stwierdza pełną adaptację, ale tabela nadal zawiera artifactsMissionFTLDurationResearchMult/artifactsMissionCapacityResearchMult. Runtime nie konsumuje ich jako parametrów farmowej floty.

Reprodukcje BuyEpicResearch przez Bootstrap: afx_mission_time oraz afx_mission_capacity otrzymały APPLIED i poziom1, pobrały odpowiednio5 000 i50 000 Diamentów, lecz kontekst progresji i shippingPerMinute pozostały identyczne (5 000). Nie jest to tylko brak odświeżenia etykiety. Co najmniej video_doubler_time,hold_to_research,epic_silo_quality i warp_shift również nie mają konsumenta realizującego ich efekt; pełna lista zakupu nie może oznaczać pełnej listy działających efektów.

Potrzebne: jawna macierz obsługiwanych efektów i blokada nieobsługiwanych badań. Ewentualne nowe znaczenie badań ekspedycyjnych to decyzja produktu, a nie podmiana nazwy w dokumentacji.

### F04 — P1: nowy podgląd prestiżu używa portfela zamiast przychodu sesji

`HUD.luau:4782` czyta farm.cash, a4791–4792 odtwarza wzór i wykonuje floor. Serwer (`ProgressActions.luau:137`) używa archived+current+extra, uwzględnia event prestiżu i zachowuje Real64 bez dodatkowego floor. Po wydaniu pieniędzy lub zmianie jajka różnica może być znaczna.

Reprodukcja: portfel100, trzy akumulatory po1 000 000. UI pokazuje **+1 kryształ**, prawdziwy Prestige nadaje **9.366302678733723**. Podgląd bonusu przy4795 pomija też wpływ PE/prophecy_bonus. Potrzebna autorytatywna projekcja nagrody i EB, zamiast odtwarzania części reguł na kliencie.

### F05 — P2: awans jajka ma błędne FV w UI — istniejąca luka zachowana

`HUD.luau:755` liczy uproszczone FV bez SE, pełnych badań/IHR i innych składników. Następnie interfejs na tej podstawie opisuje gotowość awansu. Przy kontrolowanym SE=10^12 serwer wyliczył FV=2 746 401 358 292 758 i zezwolił na kolejne jajko, a UI pokazało27.46K oraz „WYMAGANE WIĘKSZE FARM VALUE”. Przycisk pozostaje aktywny: to błędna informacja i kolor, nie serwerowa blokada. Zwykły klik może wtedy awansować mimo komunikatu. Źródłem powinna być projekcja FV/eligibility serwera.

Ta uproszczona funkcja istniała już w701d087; nie jest nową regresją Gemini, ale nadal psuje ocenę progresji po prestiżu.

### F06 — P1: opis Pro sprzedaje inne zachowanie niż kod i zatwierdzony kontrakt

Nowe opisy (`HUD.luau:700`, `products.luau:291`) mówią o7 dniach,6 silosach,+20% tempa i randzeVIP. Produkt pozostaje gamepassem z trwałym bool/znacznikiem nadania, bez terminu wygaśnięcia. Zatwierdzony kontrakt docs25–26 opisuje inny zestaw korzyści i nie zatwierdza takiej nowej czasowej oferty. Korzyść +20% refill nie jest naliczana przez aktualny kontekst produkcji: reprodukcja online1s od pustego zapasu daje3 kurczaki zarówno bez Pro, jak i z Pro. Nie należy komunikować zmiany warunków produktu samym nowym tekstem. Potrzebna zgodna oferta/implementacja albo osobna decyzja produktu, bez automatycznej kalibracji bilansu.

### F07 — P2: okno prestiżu omija responsywną rodzinę okien

`HUD.luau:3379` tworzy stałe460×420 i nie wywołuje _fitWindow. Na szerokości320 daje lewą krawędź−70; na landscape o wysokości360 przekracza wysokość ekranu. W obecnym desktopowym Play odczyt potwierdził460×420 bez UIScale, ale nie zmieniano rozdzielczości użytkownika. To kontrola geometrii, nie nowy test dotyku na telefonie. Przycisk wejścia z lewego dołu ma ponadto26px wysokości, poniżej nowych zasad44px.

## Czy prestiż pomylono z kolejnym jajkiem?

**Nie w komendach i skutkach serwera.**

|Operacja|Wejście z UI|Skutek serwera|
|---|---|---|
|Następne jajko|UpgradeEggButton→onUpgradeEggRequested→client.upgradeEgg→UpgradeEgg|Wyższy eggIndex, reset infrastruktury/Common/portfela, archiwizacja zarobków; SE pozostaje bez zmiany.|
|Prestiż|RebirthClickButton/PrestigeFromEggButton otwiera osobne okno; PrestigeActionButton→onPrestigeRequested→client.prestige→Prestige|Naliczanie SE, powrót do eggIndex0, reset akumulatorów sesji.|

Main klienta wiąże obie akcje osobno w176/179. Stacja Badawcza Jaj w świecie otwiera EggUpgradeModal, nie wykonuje prestiżu. W niezależnym teście UpgradeEgg zmieniło0→1, pozostawiło SE=10^12 i poprawnie przeniosło10 000 do20 000 zarchiwizowanych (razem30 000). Prestige osobno nadałSE i wrócił do0. Zmiana jajka też resetuje farmę zgodnie z docs02, więc sam reset nie jest dowodem pomyłki. Problemy F04/F05 mogą natomiast wyglądać dla gracza jak pomieszanie tych mechanik.

## Macierz podpięcia funkcji do UI

„Podpięte” oznacza prześledzoną ścieżkę i odpowiednie lokalne testy, nie pełny odbiór wszystkich stanów w Studio/chmurze.

|Funkcja|UI→klient→serwer|Stan / luka|
|---|---|---|
|Wylęg przyciskiem, hold, płyta30/s|Tak|Autorytatywne grupy/rezerwacje; lokalne regresje przechodzą.|
|Produkcja, sprzedaż, transport, RCB|Tak|Metryki i ekonomia powiązane; wyjątek nowy2×Cash(F02).|
|Common, zakup pojedynczego poziomu|Tak|QuoteRequest→BuyResearch, świeży dochód i replay sprawdzone.|
|BuyMAX / przytrzymanie kupowania|Niepełne|Pass jest ofertą, ale protokół BuyResearch dopuszcza tylko mode=single (ProtocolSchemas102/107), brak akcji MAX. Luka wcześniejsza.|
|Badania Epic za Diamenty|Częściowo|Nowy callback i BuyEpicResearch są połączone; część efektów niezaimplementowana(F03).|
|Badania Epic za Robux|Niekompletne|Brak związania z badaniem, puste nadanie i mapowanie produktów(F01).|
|Kurniki i pojazdy|Tak|Przyciski→wyceny→mutacje, serwerowe ceny/Tier.|
|Silosy / odblokowanie Hyperloop|Brak pełnej ścieżki zakupu|Model ma siloOwned/hyperloop i blokadę HYPERLOOP_LOCKED; brak osobnej akcji/protokołu/UI zakupu. Luka wcześniejsza, nie wdrażać ceny z propozycji bilansu.|
|Awans jajka|Tak, błędny podgląd|Oddzielna mutacja działa, FV w UI niepełne(F05).|
|Prestiż|Tak, błędny podgląd|Oddzielna mutacja działa; F04/F07.|
|Pety: equip/unequip/lock/fusion|Ścieżki są|Serwer weryfikuje własność, recepturę i politykę; dostępność zależy od konfiguracji, nie od widoczności panelu.|
|Inkubacja peta|Żądanie jest, funkcja ograniczona|Main/Client przekazują HatchPetEgg; Bootstrap1387 bez jawnej polityki testowej zwraca FEATURE_UNAVAILABLE. To jawna granica dotychczasowej implementacji/bilansu.|
|Daily / trofea|Tak|ClaimDailyGift/ClaimTrophy, protokół i naliczanie obecne; kontrolowane testy przechodzą.|
|Boosty: zakup|Tak|BuyBoost dodaje sztuki do inventory.|
|Boosty: użycie / VD|Nie|Brak UI i komend ActivateBoost/ActivateDoubler w gateway/protokole; moduł efektów nie zastępuje dostępnej akcji gracza. Luka wcześniejsza.|
|Pakiety Diamentów|Warunkowo|Przygotowanie/prompt/potwierdzenie działa dla skonfigurowanych ID; w bieżącym Studio memory realne płatności są wyłączone.|
|Pro|Częściowo|Własność i istniejące korzyści są, nowy opis niezgodny(F06).|
|2×Cash / Auto-Hatch|Niepełne|F02; Auto-Hatch tylko flaga, dodatkowo konflikt z zakresem premiery.|
|Piggy|Warunkowo wyłączone|Karta i obsługa istnieją, ale bez zatwierdzonego bilansu nie uznawać oferty za gotową.|
|Dron/prezent/parasol, paczki|Ścieżki są|Render/klik/dotyk→serwerowy claim; nie klikałem w grze użytkownika. Nowy licznik15s na ziemi nie bazuje na expiresAtMs: przy2.5s opadania i15s TTL może zniknąć ok.2.5s przed końcem wyświetlanego licznika.|

## Luki dokumentacji i dowodów

1. docs01 twierdzi pełną adaptację badań floty, mimo braku efektu(F03). TODO[x] nie jest dowodem poprawności.
2. Auto-Hatch jest availableAtLaunch=true, lecz docs26 nadal odsuwa go na później. Pro7-dniowe nie wynika z zatwierdzonego kontraktu.
3. Zmieniono realny bilans: bazowe pierwsze jajo0.25→0.50, próg drugiego10M/68M→1M/5M, również w reference_data/infrastructure.json i generowanym katalogu. To więcej niż rebranding; trzeba oddzielić adaptację gry od historycznej referencji N/S i jednoznacznie zapisać status decyzji. Review nie przesądza, czy użytkownik wcześniej zatwierdził te liczby poza tym chatem, ani nie cofa ich automatycznie.
4. Nowe AGENTS/pinned docs wskazują Lune0.8.9/Rojo7.4.4, a tools/toolchain.json i wykonany runner używają0.11.1/7.7.1. Nowe wymogi strict/lokalizacji nie są wdrożone przez sam import zasad: większość kodu nadal ma nocheck i teksty inline; runner nie wykonuje analizy strict. Nowe katalogi workflow/skills to w dużej mierze struktura procesu, nie implementacja funkcji gry.
5. Pełny runner PASS nie obejmuje zgodności podglądu SE z księgowością, rzeczywistej korzyści2×Cash, nadania konkretnego badania po Robux ani sensu efektów przemianowanych na flotę. Dodane testy Epic potwierdzają część poprawnego protokołu/zakupu, nie wszystkie obietnice produktowe.

## Zalecana kolejność

Najpierw zabezpieczyć niekompletne oferty Robux i kosztujące Diamenty badania bez efektu; następnie dopiąć korzyści/własność passów i zgodność Pro. Potem przenieść FV/podgląd prestiżu do autorytatywnej projekcji oraz poprawić mobile. Osobno ustalić realizację pozostałych luk UI i status zmienionych parametrów, bez wznawiania docs17–21. Ten raport nie uruchamia implementacji, nowych zakupów ani publikacji.
