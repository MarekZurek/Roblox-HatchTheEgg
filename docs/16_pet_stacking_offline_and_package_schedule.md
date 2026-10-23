# Pety, boosty, wydarzenia, offline i harmonogram prezentów

> **Status mieszany:** sekcja 1 wskazuje decyzje użytkownika R, referencyjne testy mają status N/S, a projektowe limity paczek i niezatwierdzone parametry petów — P. Mapa i statusy: [CURRENT_SPEC](CURRENT_SPEC.md). Bilans z 17–21 pozostaje odłożony.

## 1. Uzgodnione zasady petów

Użytkownik potwierdził:

1. **Bonusy petów do tej samej statystyki sumują się.** Dwa pety +50% dają `1+0.5+0.5=2`, a nie `1.5²`.
2. Wynik jest mnożony z innymi źródłami **we właściwym wymiarze**: badaniami, boostami i wydarzeniami. Nie tworzymy jednego globalnego mnożnika wszystkich nagród.
3. **Drone Hawk zachowuje bonus do szansy elity.** Jest to świadoma zmiana względem Neodymium Medallion, który zwiększa częstość dronów.
4. **Wydarzenia offline rozliczamy historycznie**, tylko za rzeczywisty okres ich trwania. To zatwierdzona poprawka adaptacji, opisana w sekcji 3.

Dla wymiaru d:

```text
P[d] = 1 + suma bonusów b_i[d] wyposażonych petów
```

Bonus +50% zapisujemy jako b=0.5. Gdy opis używa „2× szansy elity”, b=1; „5×” oznacza b=4. Neutralna jedynka występuje raz na wymiar, nie raz na zwierzaka. Przykład pięciu petów +50%: P=3.5.

Istniejące 3 miejsca oraz rozszerzenie do 5 z rozdziału 09 pozostają decyzją projektu. Dodatkowe miejsca petów **nie oznaczają automatycznie** Pro Permit, pięciu miejsc boostów ani lepszej wydajności silosów.

### Mapowanie do potwierdzonych wzorów

| Archetyp | Wymiar peta | Włączenie do obliczeń |
|---|---|---|
| Farm Pup / Farmer Dog | `eggValueMult` | Wartość sprzedawanego jaja ×P; nie podmieniamy researchEggValueMult w Farm Value |
| Rooster King / Robo-Cock | tempo znoszenia | `layingRate` ×P **przed** ograniczeniem transportem |
| Speedy Chick / Golden Pecker | `internalHatcheryMult` | Tempo IHR ×P, także offline; Calm tylko w away |
| Heavy Cow / Mega Rooster | `habCapacityMult` | Pojemność kurnika ×P; zachować końcowe `ceil` potwierdzone w GDR |
| Drone Hawk | własny `eliteChanceMult` | `pElite=min(1,pBase×P)`; pBase z referencyjnej reguły progresji. Nie zmienia odstępu ani nagrody drona |
| Cosmic Phoenix | `prestigeEarningsMult` | Przychód wejściowy prestiżu ×P; **nie** końcowa liczba SE |
| Alien Clucker | `boostBoostMult` | Siła aktywnych kategorii Jimbo/Tachyon/Soul Beacon; zastosować raz, według reguły poniżej |

Nie przyznajemy drugim torem bonusów referencyjnych artefaktów, które pety zastępują. Podwójne uwzględnienie tego samego wyposażenia zmieniłoby ekonomię. Badania i modyfikatory pozostawione w adaptacji nadal działają w swoich wymiarach.

**Farm Value ma własny zestaw wejść.** Zweryfikowany wzór z rozdziału 02 używa tempa znoszenia, wartości i IHR z ResearchEngine; nie podmieniamy ich pełnymi mnożnikami petów/boostów. Także `getFarmValue` wywołuje `totalHabCapacityOf(..., true)`, wybierając pojemność z badań. Referencyjny test z kontrolowaną pojemnością research=100 i GDR=250 dał odpowiednio 100 dla true i 250 dla false. Samo założenie Pupa/Chicka/Cow nie daje dodatkowego, bezpośredniego przemnożenia FV tym bonusem. Pety mogą wpływać na FV pośrednio przez rzeczywiście zwiększoną populację i dalszy postęp. Dodanie ich premii wprost do FV byłoby kolejną zmianą projektu, której tutaj nie wprowadzamy.

Drone Hawk nie zmienia bazowej reguły progresji: standardowe pBase=0.08; przed pierwszym prestiżem przy maxEggReached<=4 jest to 0.005×maxEggReached. Na bazowym p=8% dwa Hawki 5× dają 72%, a trzy 5× osiągają limit 100%. Dla bazowej szansy zero wynik pozostaje zerem. To konkretna konsekwencja zatwierdzonego sumowania premii; końcowe siły gatunków wymagają bilansu.

### Ewolucja i zdejmowanie petów

Na wejście P trafia **końcowa premia danego peta po ewolucji**, a nie pełny mnożnik wraz z neutralną jedynką. Przykład: podwojenie premii +50% daje +100%, czyli samodzielnie ×2, nie ×3. Wartości „Golden +100% / Rainbow +250%” w rozdziale 09 wymagają traktowania jako zmian premii; sam algorytm stackowania nie określa jeszcze tabel każdego gatunku i tieru.

Przed zmianą wyposażenia należy rozliczyć upływ czasu ze starym zestawem. Nowy zestaw działa od zmiany, również po powrocie z offline; nie przelicza wstecz całej nieobecności. Zdjęcie peta pojemności nie usuwa kur z już zapełnionego kurnika; blokuje dalszy wzrost do powstania wolnego miejsca. Szczegóły gatunków, tierów i bilansu pozostają odłożoną konfiguracją projektu.

## 2. Boosty i wydarzenia — właściwe warstwy

Nie sumować premii petów z surową siłą boostu. Referencyjny manager sumuje **pełne siły boostów** danej kategorii: Jimbo 50 + Jimbo 50 =100, a nie 99 ani 2500. Beacony też sumują się ze sobą.

```text
B = suma sił aktywnych Boost Beacon; przy braku Beacon: 1
Q = P[boostBoostMult]
category = 1, gdy kategoria jest pusta
category = suma sił kategorii × B × Q, gdy jej surowy mnożnik >1
```

Q nie aktywuje pustej kategorii. Sam Alien lub Alien + sam Beacon nie dają dodatkowego dochodu/IHR. Bezpośredni pet IHR działa osobno od tej bramki.

Źródłem wydarzeń są ich **wynikowe wymiary**, nie lista ikon wyświetlanych w HUD. W docelowej konfiguracji określamy jeden wynikowy mnożnik na typ wydarzenia w danej chwili; nie mnożymy ponownie duplikatów tego samego wpisu. Pakiet nowego gracza pozostaje osobnym źródłem: np. jego ×2 collection i wydarzenie prestiżu ×4 dają ×8 na końcowej warstwie SE, bez zmiany warstwy Phoenix/Soul Beacon.

Przykłady dla dwóch Pupów +50%, Aliena +50%, Jimbo 50, Beacon 50 i eventu dochodu ×3:

- P wartości jaj =2; Q=1.5.
- Jimbo z Beaconem i Alienem daje 3750× na warstwie boostów dochodu.
- Wartość jaja ×2 i wydarzenie dochodu ×3 dają razem z nimi **22500× dochodu ze sprzedaży**, przed pozostałymi niezależnymi czynnikami i limitem sprzedawanych jaj.
- Aktywny podwajacz ×2 daje 45000×. Podwajacz reklamowy i Ultra Pro nie składają się do ×4; ich wspólny efekt pozostaje ×2.
- Pet IHR ×2, Tachyon 1000, Beacon 50 i Alien +50% dają razem ×150000 IHR, przed Calm i innymi pozostawionymi wymiarami.

**Money Printer i pozostałe jednorazowe dodatki oparte na FV nie są wzmacniane Beaconem ani Alienem.** Pety mogą wpływać na nie pośrednio, jeśli ich wcześniejsze działanie zmieniło faktyczne wejścia FV, np. populację. Nie dopisujemy do FV mnożników petów z produkcji i nie mnożymy ponownie gotowej kwoty prezentu.

### Prestiż

Cosmic Phoenix musi mieć opis „premia do przychodu prestiżowego”. Pety Phoenix i Soul Beacon łączą się na tej warstwie przychodów. Następnie działa funkcja przedziałowa z rozdziału 05; dopiero jej wynik mnożą `soulEggCollectionMult`, np. wydarzenie prestiżu.

Peta +1000% nie wolno przedstawiać jako gwarantowane 11× końcowych SE. Nie wzmacnia on również bezpośrednich SE z kalendarza/prezentów. Zwiększenie jego siły nie mnoży już zgromadzonego historycznego przychodu prestiżu wstecz; kolejne przyrosty rozlicza potwierdzony mechanizm dodatkowego przychodu.

### Czas i wygaśnięcia

- Długość boostu jest ustalana **raz przy aktywacji** jako czas bazowy × aktualny `boostDurationMult`, np. wydarzenie długości boostów. Późniejszy koniec eventu nie skraca zapisanego czasu.
- Siła peta jest efektem bieżącego wyposażenia. Zmiana zestawu wpływa na przyszłe kroki aktywnego boostu, nie na już naliczone przychody.
- Aktywne boosty są zachowane przy zmianie jaja i prestiżu. Tryby wyłączające boosty nadal korzystają z właściwej bramki, nie z kasowania ekwipunku.
- Nie utożsamiać szansy elity, jakości nagrody, częstości dronów, ilości prezentów i czasu boostów. Każda ma osobny wymiar.

## 3. Offline i testy łączenia

Podstawą pozostaje kolejność z rozdziału 10: najpierw efekty kroku, następnie produkcja z populacji na początku kroku, limit transportu i dochód, a dopiero potem przyrost populacji. Krok referencyjny ma najwyżej 0.3 s.

```text
laid = populationAtStepStart × layingRate × dt
sold = min(laid, shippingPerSecond × dt)
cash = sold × eggValue × earningsFactors × videoFactor × awayFactor
IHR = basePerMinute/60 × P[ihr] × boostIHR × pozostałe czynniki
```

Calm działa tylko w away. Obowiązuje pojemność każdego kurnika, ułamkowe akumulatory i oryginalny sharing. Większa liczba kur wpływa na następny krok. Pety wartości/znoszenia nie omijają transportu. Po wyczerpaniu czasu produkcji z silosów dalsza nieobecność nie produkuje pieniędzy ani kur.

Zegary pozostają rozdzielone:

- **Boost zużywalny:** pozostały czas zużywany przez symulowany czas produkcji; w zwykłej gałęzi nie odejmować dodatkowo całej nieobecności po wyczerpaniu silosów. Efekt trafia do kroku przed usunięciem wpisu przy remaining<0.
- **Podwajacz:** absolutny termin, sprawdzany względem czasu kroku; nie zapisujemy go jako kolejnego boostu w ekwipunku.
- **Wydarzenie:** własny absolutny harmonogram. Referencyjny predykat sprawdza zegar platformy. W 12 nowych testach `LiveEventManager::update` podanie różnych wartości argumentu double nie zastępowało tego zegara: event był nieaktywny po deadline niezależnie od tego argumentu.

**Zatwierdzona decyzja adaptacji: historyczne rozliczanie eventów dochodu.** Użytkownik wybrał naliczanie bonusu tylko za faktyczny czas wydarzenia podczas nieobecności. Nie deklarujemy, że model referencyjny sam historycznie dzieli bonus eventu na całą nieobecność. To świadoma zmiana względem odczytanego lokalnego predykatu.

W docelowej specyfikacji:

- Własna konfiguracja przechowuje początek, koniec i uprawnienia wydarzenia. Nie stosujemy obecnego eventu do całej nieobecności ani nie gubimy bonusu, który skończył się przed powrotem.
- Zachowujemy bazowe kroki produkcji i boostów do 0.3 s. Dla eventu dochodu przecinającego krok używamy średniego mnożnika ważonego rzeczywistym czasem: przy evencie ×3 przez 0.1 s kroku 0.3 s jest to `(0.1×3+0.2×1)/0.3`. To świadoma poprawka tylko warstwy wydarzenia, bez zmiany kolejności wzrostu kur czy ponownego odejmowania timerów boostów.
- Ograniczenie silosów nadal obowiązuje. Event trwający dopiero po wyczerpaniu czasu produkcji niczego za ten czas nie dopisuje.
- Wydarzenie prestiżu działa na końcową kolekcję przy faktycznym prestiżu; nie jest mnożnikiem wszystkich przychodów offline. Wyprzedaże i event długości boostów działają przy odpowiedniej czynności. Nie uśredniamy ich w dochodzie farmy.
- Eventy prezentów/dronów dotyczą rzeczywistych nagród tych systemów. Brak ich generowania offline oznacza brak zaległych wypłat z historycznym mnożnikiem.

Wariant historyczny nie został zaimplementowany ani porównany z gotowym kodem Roblox. Dotychczasowe 32 testy kernela używają stałych, kontrolowanych wymiarów wydarzenia; nie dowodzą działania przyszłego integratora czasu eventu. Oddzielne przykłady matematyczne kontrolują przecięcie okna eventu z okresem produkcji i ważenie granicznego kroku; nie są wykonaniem referencyjnego managera.

Nowa walidacja:

- **21 przypadków referencyjnego BoostManager** z kontrolowanym zewnętrznym mnożnikiem siły peta: 1/1.5/2, puste kategorie, Beacon, Jimbo, Tachyon, Soul Beacon i Money Printer.
- **32 przypadki referencyjnego SimEngine**: pety włączone/wyłączone, boost dochodu, event dochodu, online/away i wąskie gardło transportu. Uwzględniono wzrost i pojemność kurnika oraz termin podwajacza 0.5 s.
- **12 przypadków zegara wydarzenia**, z referencyjnym predykatem i update, ale kontrolowaną mapą i zegarem.

Przykłady referencyjne nie zastępują testów przyszłej implementacji HatchTheEgg.

## 4. Częstość paczek i prezentów

### Baza i losowanie

```text
nextTime = now + 0.6×I + 0.5×(I×double(U_float32))
```

To zakres **0.6I–1.1I**, nie stały odstęp I. Przy modelu jednostajnego U średnia wynosi 0.85I. Zachować kolejność rachunku double i wejście RNG float32 przy porównywaniu z biblioteką. Wcześniejszy audyt potwierdził, że float32 RNG może osiągnąć również 1.

Snapshot serwera, bez kontraktów:

| Stan | Baza paczki I | Zakres paczki | Baza oferty wideo I | Zakres oferty |
|---|---:|---:|---:|---:|
| Piggy niepełne | 250 s | 150–275 s | 300 s | 180–330 s |
| Piggy pełne | 330 s | 198–363 s | 360 s | 216–396 s |
| Dodatkowy próg pełności | 400 s | 240–440 s | 360 s | 216–396 s |

Przed wczytaniem konfiguracji konstruktor ma inne bazy: 290 s dla wszystkich wariantów paczki i 270 s dla wszystkich wariantów wideo. Potwierdzono je osobnym odczytem po referencyjnym konstruktorze. Tabela powyżej opisuje konkretny snapshot po konfiguracji, nie uniwersalne stałe klienta.

„Dodatkowy próg” wymaga precyzji: kod porównuje **`lost_piggy_increments`**, czyli utracone przyrosty po zapełnieniu, a nie surowe saldo banku. Paczki przechodzą do tego wariantu przy `isPiggyFull && lostIncrements > 2×maxPiggySize()`. Oferty wideo używają `>maxPiggySize()` i dodatkowo braku Ultra Pro; Ultra Pro pozostaje przy bazie pełnego Piggy. Równość progowi nie wystarcza.

`lost_piggy_increments` jest licznikiem utraconych przyrostów Piggy. Pełność Piggy jest osobnym warunkiem, uwzględniającym m.in. tryb bez limitu; nie wynika z samego licznika.

Przed pierwszym prestiżem **paczki** mają jeszcze mnożnik bazy: ×0.4 na Edible, ×0.8 na Superfood, ×1 na dalszych jajach. Oferty wideo nie mają tego przyspieszenia. Dla niepełnego Piggy oznacza to odpowiednio 60–110 s oraz 120–220 s. Liczy się bieżące jajo i licznik prestiżów.

### Konfiguracja — istotne doprecyzowanie

`EventManager::onLiveConfig` po przekazaniu sekcji GiftConfig **odczytuje wszystkie osiem pól odstępów** i ustawia każde na co najmniej 100 s. Nie ma w tej funkcji osobnej kontroli has-field dla każdego odstępu. Obecna sekcja z nieobecnym polem konfiguracji odczytuje jego domyślne zero, co daje 100 s — nie zachowanie poprzedniej bazy. Flagi resetu przy idle są również odczytywane z tej sekcji. Brak całej sekcji w zewnętrznym dispatcherze to inna sytuacja.

Sześć kontrolowanych wejść -1/0/99/100/101/250 sprawdziło zapis wszystkich ośmiu baz i flag. To korekta zbyt ogólnej wcześniejszej uwagi o aktualizacji „pole po polu”. W naszej konfiguracji należy jawnie podać komplet baz.

### Terminy, próby i powrót z offline

- Terminy paczki i oferty są niezależne. Referencyjny update sprawdza **now>deadline**; równość nie uruchamia oferty.
- Deadline<1 lub leżący ponad 1000 s w przyszłości jest losowany od nowa. Zwykły przeterminowany deadline nie jest sam w sobie błędny.
- Zaległa paczka: najpierw losowany jest następny termin, potem zgłoszenie ciężarówki. Brak miejsca na ciężarówkę nie oznacza zachowania tej samej paczki do odbioru.
- Zaległe wideo: Ultra Pro zgłasza specjalną ciężarówkę. W przeciwnym razie wykonywane jest `makeVideoOffer`.
- Sukces/uznanie próby za obsłużoną powoduje losowanie nowego terminu. Wynik false przesuwa **dotychczasowy** deadline o 10 s, a nie zawsze ustawia now+10. Mocno zaległy termin może pozostać w przeszłości i być ponownie sprawdzony w następnej klatce.
- W jednym wywołaniu update jest najwyżej jedna próba każdego z tych dwóch rodzajów; nie ma pętli przyznającej prezenty za wszystkie przegapione interwały. Mogą wystąpić paczka i oferta w tej samej aktualizacji.
- `onReturnFromIdle` osobno sprawdza flagi resetu paczek/wideo. Przy true losuje nowy termin. Przy false zachowuje dotychczasowy. Snapshot ma obie flagi false.
- Nie generujemy stosu paczek, reklam ani dronów za każdą minutę offline. Offline produkuje zasoby farmy; po powrocie harmonogram może wykonać zwykłą zaległą próbę.

Referencyjna obsługa gazet może wcześniej zakończyć update po wysłaniu jednej kwalifikującej się gazety, odkładając próby paczki/wideo do kolejnej aktualizacji. To dodatkowy warunek prezentacji, nie mnożnik nagród ani szansa kategorii paczki.

### Warunki oferty i limity

`makeVideoOffer` przy ograniczeniach wieku albo wyłączonych reklamach zwraca **true bez tworzenia oferty**. Tak samo obsługuje brak kwalifikacji postępu. W badanej gałęzi bez funkcji kontraktów Edible nie kwalifikuje się; dalsze jajo wymaga populacji **co najmniej 301**. Przy pozostałych spełnionych warunkach brak gotowości dostawcy reklamy zwraca false i uruchamia powyższe przesunięcie o 10 s. Zwrócone true nie dowodzi obejrzenia reklamy ani wypłaty nagrody.

Ograniczenia transportowe są osobne od timera:

- Zgłoszenie zwykłej ciężarówki jest przyjmowane przy liczniku `pendingOrdinaryDeliveries <= 1`; przy większym jest pomijane.
- Zgłoszenie specjalnej ciężarówki jest przyjmowane przy `pendingBonusDeliveries <= 0`.
- Zgłoszenia są flagami bool; wielokrotne zgłoszenie nie tworzy licznika nieograniczonej kolejki. VehicleManager konsumuje flagę przy skierowaniu pojazdu. Liczniki nagród rosną w późniejszej fazie przy tworzeniu odpowiadających im alertów.

Nie utożsamiać tych warunków z matematyczną gwarancją dokładnie 2/1 jednoczesnych obiektów w każdej możliwej sytuacji lotu/dostawy. Nie wykonano całej sceny ruchu i wszystkich callbacków zamykania alertów. Specyfikacja zachowuje sprawdzone warunki zgłoszeń; ścisły limit oczekujących obiektów w Roblox powinien być osobną jawną konfiguracją.

**P — doprecyzowanie projektu HatchTheEgg, bez osobnego potwierdzenia użytkownika:** roboczo przyjmujemy konfigurowalny limit **2 zwykłych paczek i 1 bonusowej oferty/prezentu**. Miejsce jest zajęte od utworzenia oferty, także podczas dostawy, do odbioru albo zamknięcia/usunięcia. Pełny kanał nie powiększa kolejki i nie przyznaje nagrody; kolejne próby następują według harmonogramu. To ścisła reguła naszego projektu, nie twierdzenie o wszystkich stanach animacji referencyjnego klienta. Bonus Ultra i oferta wymagająca dostępności korzystają z tego samego bonusowego miejsca.


## Dane referencyjne w projekcie

Pełne referencyjne ilości, parametry wag i interwały: [rewards.json](reference_data/rewards.json). Nie zmieniają zatwierdzonego limitu 2+1 ani zasad trwałości ofert.
