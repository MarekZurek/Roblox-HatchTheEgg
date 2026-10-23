# Symulacja progresji farmy i korekta cen inkubatorów

> Nowsze porównanie: [21. Płacący gracz i inkubacja](21_payer_progression_and_incubation.md). Rekomendacja V=1.5e55 z tego etapu pozostaje wariantem, nie zamrożonym cennikiem. Nowy model z RCB i dodatkowymi nagrodami ma własną, większą wrażliwość SE na krok; błędu 0.54% poniżej nie należy przenosić na jego wyniki.

23.10.2026. Przeprowadzono **40 przebiegów zintegrowanego modelu ekonomii**, obejmujących badania, transport, populację, awanse jaj, prestiż, ograniczone środki GE, boosty i pety. To narzędzie analityczne w materiały robocze, bez implementacji gry Roblox. Model wykonuje pełny badany okres i własne strategie gracza; nie jest uruchomieniem całej referencyjnej gry ani dowodem zgodności wszystkich jej systemów 1:1.

## 1. Wniosek i aktualna propozycja cen

Wyniki uzasadniają pozostawienie I–IV jako wariantu do testów i **obniżenie ceny V o 100×**. Rekomendacja nadal wymaga wspólnych ładunków inkubacji: 1/60 s kwalifikowanej produkcji, koszt 1/otwarcie, limit salda 120. Sama stała gotówka nie stabilizuje podaży petów po rozwoju farmy.

| Inkubator | Odblokowanie | Poprzednia propozycja | Aktualna propozycja |
|---|---|---:|---:|
| I | Edible | 25 | 25 |
| II | Superfood | 340 000 | 340 000 |
| III | Fusion | 7.8e13 | 7.8e13 |
| IV | Tachyon | 1.1e23 | 1.1e23 |
| V | Universe | 1.5e57 | **1.5e55** |

Waluta: gotówka farmy. Rozkład V pozostaje Pup 22%, Rooster 22%, Chick 27%, Cow 15%, Hawk 9%, Phoenix 4%, Alien 1%. Siły, receptury i sumowanie z 16–18 nie zostały zmienione. dokumentacja referencyjna jest zapisem **propozycji analitycznej**, nie wdrożoną konfiguracją gry.

Nowe mechaniki z 17–18, w tym ładunki, gotówka jako waluta wylęgu, wariant Rainbow 3.5× premii Normal i tutorialowy Pup, nadal nie są wcześniejszymi decyzjami użytkownika. Eksperyment ocenia ten konkretny wariant, nie zatwierdza go automatycznie.

## 2. Dane i zakres modelu

Źródła: ceny wszystkich poziomów Common/Epic Research, kurników i pojazdów z dokumentacji referencyjnej, progi jaj i testy FV/SE z dokumentacji referencyjnej, ceny/gate SE boostów ze snapshotu serwera, odtworzony kalendarz oraz zasady 16.

Nowo odczytane dane referencyjne: dokumentacja referencyjna:

- Progi 13 tierów: **0, 30, 80, 160, 280, 400, 520, 650, 800, 980, 1185, 1390, 1655** punktów Common Research. Wykonano 50 wywołań referencyjnego predykatu na progach i ich granicach.
- Efekt **każdego z 2998 poziomów badań Common/Epic**, wywołany w funkcji referencyjnej izolowanej. Nie interpolujemy liniowo między poziomem 1 a maksimum. Wyniki na końcach porównano również ze wcześniejszą ekstrakcją.
- Cena silosu zwykłej farmy przy n już posiadanych: `100000*n^(n+15)`; referencyjne wykonania dla n=0,1,2. Pierwszy silos jest bezpłatny, drugi kosztuje 100 000. Zakres Pro do 10 jest modelem konfiguracji tego samego wzoru, nie dodatkowym zestawem referencyjnych wykonań wszystkich cen.

Model obejmuje:

1. Zakupy legalnych poziomów badań, progi tierów i ich efekty; Epic Research finansowane GE i zachowywane po resetach.
2. Cztery kurniki, osobne pojemności, IHR, ułamki, sharing, ręczne dodawanie kur; transport ogranicza sprzedaż jaj.
3. Rozbudowę floty, badania transportu oraz Hyperloop po wydaniu 50 000 GE, ceny wagonów i ich limit. Nie każdy przebieg finansuje Hyperloop — brak zakupu jest wynikiem strategii, nie darmowym odblokowaniem.
4. FV z wejściami badań, bez bezpośredniego dodawania petów wartości/IHR/pojemności; awans na najwyższe jajo dostępne według FV. Można pominąć pośrednie jaja.
5. Zmianę jaja z resetem gotówki/badań Common/populacji; zachowanie petów, SE/PE, Epic Research i boostów. Prestiż dodaje wynik funkcji przedziałowej i rozpoczyna nowy cykl przychodu. Wydatki nie odejmują już zarobionego przychodu prestiżowego.
6. Inwentarz boostów, zakupy za dostępne GE, gate SE i limity 2/5 aktywnych boostów według Pro. Same 5 slotów petów nie daje Pro. Efekty boostów, Beacon/Alien i przyszłe przyrosty prestiżowe Phoenix działają w osobnych warstwach.
7. Produkcję offline z pojemnością silosów, jakością 0.5/1, Calm, zatrzymaniem zużycia boostów po wyczerpaniu produkcji i saldem ładunków.
8. Codzienny kalendarz: GE, badania/konwersje, SE/PE, boosty i gotówka zależna od bieżącego FV. Kwoty gotówki z wcześniejszych testów na kontrolowanym FV=1e8 zostały przeskalowane na rzeczywisty FV modelu, a nie przepisane jako stały prezent.
9. Losowanie petów, automatyczne łączenie 5→1 i 3→1, wyposażenie oraz sumowanie premii. Saldo kopii zachowuje się przy ewolucji: Golden odpowiada 5 Normal, Rainbow 15 Normal.

## 3. Strategie i jawne założenia

**Nowe konto:** SE=PE=GE=0, brak Epic Research. Farma startuje bez gotówki i kur, z jednym Coopem, jednym Trike i zapasem ręcznej wylęgarni 250. Wariant z petami otrzymuje jeden deterministyczny Normal Pup I; nie jest to darmowe losowanie przy każdym prestiżu.

- „Aktywny” jest testem granicznym **24 h działania dziennie**, a nie realistyczną deklaracją czasu spędzanego przez człowieka w grze.
- „Sesyjny” działa 2×30 minut dziennie, co 12 godzin. Zakupy i odbiór prezentów tylko podczas sesji. Offline nie otwiera jaj automatycznie.
- Decyzje co 30 s. W modelu można kupić do 500 kolejnych legalnych ulepszeń na decyzję, wybierając najtańsze i przeplatając je potrzebną rozbudową. To umowna strategia zakupów, nie nadanie graczowi płatnego przycisku MAX ani oszacowanie szybkości klikania.
- 20% zarobionej gotówki zasila budżet petów; środki nadal muszą istnieć w portfelu. Pozostały budżet nie jest dodatkową walutą. Zakupy infrastruktury mogą konkurować o gotówkę; niewykorzystany portfel/budżet znika przy resecie farmy.
- Prestiż po braku awansu przez co najmniej 30 minut, minimum 30 minut od poprzedniego prestiżu i zysk co najmniej `max(10,25% posiadanych SE)`. To heurystyka, **nie strategia optymalna**.
- Wyposażenie dobiera heurystyka korzyści z wartości, znoszenia, IHR, pojemności, Hawka, Phoenix i Aliena, z uwzględnieniem wąskich gardeł. Automatyczna ewolucja może przejściowo pogorszyć zestaw. Nie rozwiązano globalnego problemu optymalnego wyposażenia i momentu łączenia.
- GE pochodzą z rzeczywistej tabeli kalendarza oraz złotych nagród z modelu dronów. Gracz trafia 25% napotkanych dronów podczas sesji; szansa elity zależy od progresji i Hawka. Nie zakładamy reklam, Robux ani nieskończonych darmowych boostów.
- Scenariusze są bez wydarzeń i bez aktywnego podwajacza. Zatwierdzona historyczna polityka offline nie została cofnięta; tu nie zadano historii wydarzeń. Nie włączono pakietu nowego gracza jako dodatkowego eventu.

**Zaawansowane konta** to oddzielne próby wrażliwości: 1e12 albo 1e18 SE, 25 PE, maksymalne Epic Research i 100 000 początkowych GE. Te zasoby są jawnym założeniem początkowym, **nie wynikiem rozwoju od zera w 14 dni**. Grają sesyjnie, bez Pro, przy 3 albo 5 miejscach petów.

## 4. Wyniki 28 dni od zera

Główna seria, seed=1, krok produkcji 5 s:

| Wariant | Najwyższe jajo | Prestiże | Otwarcia petów |
|---|---|---:|---:|
| Aktywny, bez petów, bez boostów | Dilithium | 35 | 0 |
| Aktywny, pety, bez boostów | Dilithium | 46 | 39 808 |
| Sesyjny, pety, bez boostów | Graviton | 9 | 7 328 |
| Sesyjny, pety, tanie/otrzymane boosty, 3 sloty | Graviton | 11 | 7 427 |
| Ten sam wariant, 5 slotów petów | Graviton | 12 | 7 566 |
| Sesyjny, bez ładunków inkubacji | Graviton | 11 | **1 199 757** |

Ostatni wariant ma dodatkowy techniczny limit analizy: maksymalnie 1000 otwarć na decyzję co 30 s. Nie jest to reguła projektowanej gry; wynik jest dolnym ograniczeniem podaży przy całkiem nieograniczonej obsłudze zakupów. Wcześniejszy limit 10 000/dec. w eksploracyjnym przebiegu dawał jeszcze większą podaż; nie używamy go do finalnych tabel.

**Wniosek:** pety wyraźnie zwiększają liczbę SE i zmieniają tempo, ale nie usuwają wszystkich barier rozwoju. Pięć slotów nie oznacza automatycznie przejścia o kilka jaj dalej w tym okresie. Bez ładunków liczba petów jest około 162× większa, mimo budżetu gotówkowego 20%.

Żaden z nowych profili tej serii nie dotarł do Universe w 28 dni. Nie wolno zatem opisywać testu ceny V jako wyniku nowego konta po miesiącu. Do jej weryfikacji służą oddzielne zaawansowane profile i ich droga od Edible przez awanse do Universe.

### Rzeczywiste momenty ewolucji w jednym przebiegu

Dla sesyjnego wariantu z boostami i trzema slotami:

- Pierwszy Golden Pup I: około 6.5 minuty czasu od startu.
- Pierwszy Rainbow Pup II: przy drugim logowaniu, godzina 12, po zużyciu zgromadzonych ładunków. Nie oznacza to ciągłego dwunastogodzinnego otwierania.
- Fusion: godzina 120.1; Tachyon: 276.45; Graviton: 480.
- Pierwszy Rainbow Hawk IV: około 312 h; pierwszy Alien IV: około 312.2 h; Golden Alien IV: 564 h. Brak Rainbow Aliena IV w 28 dniach.

To przykłady jednego seeda i jednej strategii, nie kwantyle rozkładu ani terminy gwarantowane. Podstawowe pety ewoluują wcześnie; rzadsze gatunki pozostają celem wielosesyjnym. W tym wariancie awans nie wymaga żadnej konkretnej ewolucji peta.

## 5. Wpływ ceny i boostów

### Ceny I–IV

Dziewięć prób: trzy seedy × mnożnik wszystkich cen 0.1/1/10, 28 dni gry sesyjnej. Każdy wariant dotarł do Graviton. Łączne otwarcia:

| Mnożnik cen | Zakres otwarć w trzech seedach |
|---|---:|
| 0.1× | 7 571–7 851 |
| 1× | 7 427–7 572 |
| 10× | 6 849–6 933 |

Koszt wpływa szczególnie na pierwsze zakupy po przebudowie farmy. Później większość ceny staje się mała: w przykładowym sesyjnym przebiegu mediana ceny IV wyniosła około 0.193 s aktualnego dochodu online, ale 90. percentyl około 299 s. To rozkład próbek online w tym przebiegu, **nie docelowy stały czas otwarcia**. Nie kalibrować ceny wyłącznie do bardzo krótkiej fazy po resecie ani wyłącznie do najlepiej rozbudowanej farmy.

W tym zakresie nie znaleziono powodu do dalszego podnoszenia I–IV. Podaż kontrolują głównie ładunki i dostępność sesji. Jeżeli potrzebne będzie wolniejsze zdobywanie petów, należy stroić tę warstwę, a nie podnosić stare ceny tak, żeby blokowały początkujących.

### Ograniczone GE i strategie boostów

Podstawowa strategia używa tanich prism/feed oraz posiadanych wybranych boostów. Dodatkowa strategia `FocusedFarm` oddziela 40% przychodu GE na Epic/Hyperloop i 60% na boosty, oszczędza na mocniejsze warianty i porównuje fazę wzrostu z fazą prestiżu. Uwzględnia także otrzymany Money Printer, bez bezpośredniego mnożenia jego kwoty przez Beacon/Aliena.

W sesyjnych próbach tej dodatkowej strategii powstało 7054–7528 GE, a na boosty wydano 2900–3100 GE. Użyto m.in. 13–14 Soul Beaconów ×5 i jednego kalendarzowego Money Printera; najwyższe jajo nadal Graviton. W aktywnym wariancie powstało 81 001 GE, wydano 48 100 GE na boosty; 140 małych Soul Beaconów, dwa ×50 i siedem feedów ×50 nie oznaczały nieskończonego utrzymywania legendarnego zestawu. Najwyższe jajo: Dilithium.

To pokazuje, dlaczego stały mnożnik dochodu 22500× z wcześniejszej tabeli wrażliwości nie jest wiarygodną prognozą całej drogi nowego gracza. W pełnym przebiegu trzeba najpierw sfinansować, odblokować i uruchomić boosty. Żadna z dwóch strategii nie została udowodniona jako optymalna.

## 6. Universe: dlaczego zmieniamy cenę

Profil 1e12 SE, 25 PE, maksymalne Epic Research, 100 000 GE, 3 sloty, dwie sesje dziennie. Każdy wariant zaczyna od Edible i dochodzi do Universe w około 228–228.2 h. Zmieniono **wyłącznie cenę V**; pozostałe ceny i zasady są takie same. Horyzont: 14 dni, po trzy seedy na wariant.

| Cena V | Otwarcia V do końca próby | Pierwszy jakikolwiek pet V, od początku próby |
|---|---:|---:|
| 1.5e57 | 67–112 | 276–288 h |
| 1.5e56 | 401–548 | 264 h |
| **1.5e55** | **693–753** | **240–252 h** |

Przy starej cenie pierwsze otwarcie następowało 48–59.8 h po odblokowaniu, przy nowej 12–23.8 h. Są to godziny kalendarzowe; zakupy następują tylko na sesjach. Cena 1.5e55 nadal nie daje natychmiast całej kolekcji: żaden z tych sześciu tańszych przebiegów nie uzyskał Rainbow Aliena V w 14-dniowym horyzoncie. Wynik obejmuje czas dojścia do Universe, nie pełne 14 dni otwierania V.

Dla mocniejszego profilu 1e18 SE już stara cena V była pomijalna po rozbudowie. Wejście na Universe nastąpiło po około 5.5 minuty; w 14 dni wykonano 4047 otwarć V. Pierwszy Rainbow Alien V pojawił się po 120–156.35 h kalendarzowych, czyli po około 5–6.5 dniach od startu próby. Przy trzech i pięciu slotach podaż była taka sama; różna siła zestawu nie przyspiesza odnawiania ładunków.

Nie można tego wyniku mocnego profilu przypisać nowemu graczowi. Pokazuje on natomiast, że podniesienie ceny dla bogatego konta pogorszyłoby dostęp słabszego konta, a wspólny zasób rozwiązuje ten konflikt skuteczniej.

**Rekomendacja:** V=1.5e55. Przy tej cenie mediana kosztu na słabszym profilu to około 5.27–6.63 s aktualnego dochodu online; z budżetem 20% daje to około 26–33 s, więc po rozbudowie ograniczeniem staje się 60 s odnawiania ładunku. Bezpośrednio po resecie koszt nadal może być wysoki.

## 7. Dokładność, kontrole i granice

Wykonano kontrole:

- Zgodność 70 wcześniejszych przypadków wzoru FV i 18 przypadków końcowego SE. Maksymalny względny błąd FV względem zapisanych referencyjnych wyników: około 3.22e-16.
- Pięć przypadków populacji i gotówki z modelu referencyjnego offline, odtworzonych przez część produkcyjną modelu z krokiem 0.3 s i kontrolowanymi wejściami. Przypadek aktywnego podwajacza nie należy do tej serii bez podwajacza.
- Bilans GE wszystkich 40 przebiegów, nieujemne czasy aktywnych boostów, limit 120 ładunków, czas produkcji nieprzekraczający okresu, zachowanie liczby kopii przy łączeniu.
- 28 dni tej samej strategii, kroki **5/1/0.3 s**: najwyższe jajo Graviton, po 11 prestiży. Otwarcia odpowiednio **7427/7562/7453**, SE **163371/164628/164251**. Dla 5 vs 0.3 s różnica otwarć około 0.35%, SE około 0.54%. Przychód GE różni się o około 5.44% — ziarnistość kroku zmienia momenty dronów i późniejsze decyzje, więc wyniki nie są bitowo zgodne i nie każdy wskaźnik zbiega monotonicznie.

Krok 5 s wykorzystano dla szerokich porównań; 0.3 s dla całego 28-dniowego profilu kontrolnego. Nie wykonano każdego scenariusza i każdego seeda z krokiem 0.3 s. Trzy seedy służą wychwytywaniu wrażliwości, nie estymacji 95. percentyla całej progresji.

**Pozostałe ograniczenia:**

- Część produkcyjna ma bazowy bonus biegających kur **1×**. Ręczny wylęg modeluje działanie gracza do 3 kur/s i zapas wylęgarni; nie symuluje trasy kur w świecie ani utrzymywania maksymalnego RCB. To konserwatywny wariant dochodu.
- Drony dają w tym eksperymencie tylko losowane GE; gotówkowe drony i paczki/prezenty nie zwiększają dochodu. Kalendarzowe pieniądze oraz użyte boosty gotówkowe są uwzględnione. Brak tych dodatkowych źródeł oznacza, że rzeczywista bogatsza ekonomia może rozwijać się szybciej.
- Transport stosuje potwierdzone pojemności i właściwe mnożniki typów. Nie symuluje wizualnego ruchu, załadunku i chwilowych kolejek pojazdów.
- Dla niewidocznych w mapie `GameDimensions` efektów Epic IHR użyto odtworzonej zasady +5%/poziom z dokumentacji. Zintegrowany manager wszystkich wymiarów nie jest wykonywany jako całość.
- Brak trofeów, questów, kontraktów, Ultra, Robux, reklam i historii globalnych eventów. Brak decyzji dotyczącej petów na Enlightenment; badany cel kończy się na Universe, nie na wyzwaniu Enlightenment.
- Wybór momentu prestiżu, zakupów, boostów i łączenia ma duży wpływ na czas. Nie zbadano wszystkich strategii ani realistycznej szybkości klikania. **Nie ustalamy na tej podstawie docelowej liczby dni nowego gracza do Universe.**

Wynik jest wystarczający do odrzucenia ekonomii opartej wyłącznie na stałej gotówce i do wskazania konkretnej poprawki V. Nie dowodzi, że całe tempo gry jest ostatecznie zbalansowane.

## 8. Materiały do odtworzenia

- Model, strategia boostów, test samej ceny V.
- Wyniki główne, wrażliwość cen, profile zaawansowane, kontrola kroku, boosty, cena V.
- Podsumowanie 40 przebiegów, kontrole, manifest i hashe.

