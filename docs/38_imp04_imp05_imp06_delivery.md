# IMP-04, IMP-05 i IMP-06 — matematyka pierwszej farmy

24.10.2026. Wykonano równolegle czyste moduły produkcji/badań, IHR oraz ręcznego wylęgu/RCB. Kod działa lokalnie w Lune, bez uruchamiania farmy, fizyki sceny, RPC i DataStore. Bilans 17–21 i referencyjne JSON-y pozostały bez zmian. Modele i techniczne formaty mają status P; nie zatwierdzają konfiguracji premiery.

## IMP-04 — badania, pojemność, produkcja i sprzedaż

[production_research](../src/server/FarmMath/production_research.luau) tworzy się przez new(codec,catalog,{mode=INTERNAL_TEST_ONLY}). Składa siedem wybranych Common z katalogu, sumuje ich bieżące poziomy i używa inkluzywnych progów. Nie waży punktów ceną i nie dopisuje Epic. Nie udaje pełnego katalogu 56 badań: nieobsługiwane ID są jawnie odrzucone, także przy poziomie 0. canResearch rozdziela blokadę tieru od maxLevel, lecz nie kupuje badań.

Pojemność jest zaokrąglana ceil osobno dla każdego kurnika. Transport to suma przepustowości pojazdów w jajach/min przeliczona na sekundy. productionStep przyjmuje populację zasiedloną jako kanoniczny uint64; dla pierwszego zakresu jawnie sprawdza bezpieczną konwersję i wybraną pojemność. Nie odcina nadmiaru kur ani nie usuwa danych nieobsługiwanego profilu.

Krok dt w zakresie 0–0.3 s zwraca wyprodukowane i sprzedane jaja, dochód i tempa. Najpierw liczy ilości producedRate*dt i shippingRate*dt, potem min, a gotówkę jako sold*eggValue*activeRCB. Samo cashRate*dt nie zastępuje tej kolejności. Tylko zasiedlone kury produkują; running/in-transit nie jest drugą populacją znoszącą. Dochód nie jest Farm Value ani zmianą salda. Zegar, zakupy i koordynacja kroku są przyszłymi zadaniami. [API i źródła](workflow/imp04_notes.md).

## IMP-05 — IHR i dokładna pojemność

[ihr](../src/server/FarmMath/ihr.luau) udostępnia new(codec,populationMath).step(habitats,ratePerHabSecond,dt,sharing,drawSource). Wejście to cztery sloty: capacity/population/assignedInTransit jako kanoniczny uint64 oraz fractionalIHR jako nieujemny skończony binary64. Wynik zmienia wyłącznie kopie slotów; produkcja ma już być wykonana przez przyszłego koordynatora.

Dodaje rate*dt, wyodrębnia część całkowitą, ogranicza ją wolnym miejscem i odejmuje **faktycznie dodane** kury. Rezerwacje kur w drodze zmniejszają vacancy. Pełny slot z sharing wybiera jeden ważony cel; nie dzieli nadwyżki równo. Bez sharing/bez celu czyści akumulator pełnego źródła, puste sloty nie produkują i nie przekazują tempa. Kolejność 1–4 jest zachowana. Przy dt=0 następuje walidowany no-op. [Dokładne zachowanie i testy](workflow/imp05_notes.md).

**Naprawa walidacji zapisu:** dotychczasowy ProfileSchema wymagał fractionalIHR<1. To nie pasowało do reguły odejmowania faktycznych dodatków: przy 249/250 kur i 3 należnych kurach dodaje się jedną, a carry wynosi 2. Teraz schema dopuszcza nieujemne skończone carry>=1; nadal odrzuca wartości ujemne i NaN/Inf. Sprawdzono zarówno bezpośrednią walidację, jak i rzeczywisty wynik IHR przekonwertowany do wire profilu. Nie zmieniono wzoru, cen ani ilości należnej produkcji.

## Wspólny PopulationMath

[PopulationMath](../src/server/FarmMath/PopulationMath.luau) udostępnia vacancy, vacancies, select oraz modulo. Vacancy liczy max(0,capacity-population-reserved), nie sumując najpierw dużych liczników w number. Stan ponad pojemnością pozostaje zachowany, bez dodatkowego miejsca.

Selekcja oblicza drawUInt64 modulo sumy wolnych miejsc i wybiera pierwszy przedział r<vacancy, zachowując kolejność slotów. Dzielenie bitowe unika przepełnienia 2*remainder. Nie używa tonumber całego uint64 i nie deklaruje idealnej jednostajności dowolnego RNG. Rzeczywisty generator oraz jego zakres należą do późniejszego adaptera; tutaj draw jest jawny. Suma miejsc ponad 2^64−1 kończy się błędem reprezentacji, nie zawinięciem lub przycięciem stanu. [490 niezależnych wektorów](../tests/hatching/population_vectors.luau) generuje Python int przez [osobny skrypt](../tools/generate_population_vectors.py).

## IMP-06 — wylęg, wejście i grupy

[hatching_rcb](../src/server/FarmMath/hatching_rcb.luau) wymaga codec, PopulationMath, PersistenceData i jawnego mode=INTERNAL_TEST_ONLY. Farmę i runtime wejścia przekazuje się osobno; funkcje zwracają kandydatów zamiast zapisywać lub wysyłać klientowi stan.

| API | Znaczenie |
|---|---|
| input(farm,runtime,packet,drawSource,routeProvider) | HatchPress daje jedną próbę; stock>=1 i wolne miejsce są konieczne. Udane wypuszczenie odejmuje zapas, rezerwuje slot i zwiększa running, tworząc grupę. Błędny stream/stare inputSeq nie wywołują nowego losowania lub grantu. |
| refill(stock,capacity,perSecond,dt) | Oddzielne od hold odnawianie zapasu z ograniczeniem capacity. W bazie caller przekazuje 3/s; nie oznacza to automatycznego wypuszczania 3 kur/s. Stock ponad capacity jest poza tym neutralnym zakresem i jest odrzucany, nie kasowany. |
| holdRate(epicLevel) / holdStep(...) | Jawny poziom daje 2*level, 0–30/s. Bez Epic tempo 0. Float32 jest stosowane do akumulatora i odejmowania, a warunek okresu pozostaje ścisły >1/rate. dt=0 jest no-op. |
| rcb(runningText,c,K,M) | q=min(c^n,K), M tylko gdy q>1. Zwraca także flagę dokładności konwersji n do realnego wykładnika. Skończony cap może ograniczyć przepełnioną potęgę; przepełnienie końcowego wyniku jest błędem. |
| arrive(farm,groupId,stepEndSeconds) | Zaufane serwerowe dotarcie, gdy nadszedł termin. Zmniejsza rezerwację/running i zwiększa settled raz; powtórzenie zamkniętego ID nic nie przyznaje. |
| closeInFlightForAway(farm) | Jawne zamknięcie istniejących grup raz; przyszła gałąź away decyduje o jego użyciu. Nie zastępuje pełnej symulacji offline lub progu 60 s. |

Runtime to streamId, lastInputSeq, held, holdElapsed. Nowy strumień zaczyna z lastInputSeq=0, więc pierwsze wejście ma seq>=1. Press i start/refresh/stop korzystają ze wspólnego licznika. Refresh nie wskrzesza zatrzymanej intencji; stop zeruje held i elapsed. Przy braku hold lub rate<=0.1 nie gromadzimy czasu do późniejszego wypuszczenia. Brak odświeżenia/utrata sesji mają zatrzymać intencję przez przyszły Gateway/koordynator; ten moduł nie ma zegara ani aktywnego timeoutu. Nie implementuje płatnego Auto-Hatch ani sklepu Epic.

Monotoniczny hatchGroupSequence jest częścią trwałej farmy i tworzy ID hatch:N. Zwiększa się przy udanym wypuszczeniu, nie przy porażce. **Nie wolno go zerować przez reconnect, zmianę jaja, prestiż lub usuwanie zamkniętych grup.** To decyzja techniczna P chroniąca przed ponownym użyciem ID. Nowy referencyjny profil wewnętrzny otrzymuje 0. Pole jest addytywne i opcjonalne w ogólnym dekodowaniu starszego profilu, lecz Hatching wymaga go przed pracą; nie odgaduje zera dla istniejącej historii. Późniejsza inicjalizacja/migracja musi rozstrzygnąć taki profil jawnie, bez resetu konta.

Grupa przechowuje slot, liczność uint64, status IN_TRANSIT, wersję i opcjonalny snapshot trasy, start UTC ms oraz Duration w sekundach. RouteProvider zwraca zaufane dane przed obciążeniem; jeżeli nie przekazuje snapshotu, musi zapewnić trwałą definicję używanej wersji według 35. Brak trasy nie zużywa zapasu. Nie ma stałej 6 s, klientowskiego Touched ani klientowskiego dt. Umieszczenie fazy dotarcia po produkcji, przed IHR, należy do IMP-09 zgodnie z 35; fake termin w teście nie potwierdza fizycznego ruchu w Studio.

Callbacki draw/route nie mogą yieldować ani wykonywać efektów zewnętrznych. Przy retry zapisu przyszły koordynator używa już przygotowanego kandydata, nie losuje i nie wypuszcza ponownie. Ochrona inputSeq nie jest trwałym ledgerem każdej kury: save/checkpoint musi atomowo utrwalić wynikowe liczniki i grupy według 27/28. Nie zaimplementowano tu integracji SessionRepository, NetworkGateway lub TimelineSimulation.

Model obliczeń nie jest gotowym wire całego profilu. Po załadowaniu adapter odkodowuje m.in. hatcheryStock, fractionalIHR i Duration grup do number; przed zapisem koduje je przez NumericCodec z round-trip według 27, zachowując uint64 jako tekst i Instant jako ms. Nie wkładać nieprzekształconego wyniku leaf do ogólnego save jako dowodu poprawnej serializacji. Test carry sprawdza rzeczywistą konwersję jednego dotkniętego pola; pełna integracja profilu pozostaje przy koordynatorze/Timeline.

## Zakres liczbowy i dowody

First-farm production przyjmuje tylko wybrany katalog i jego bezpieczne populacje; ogólne liczniki vacancy i grup zachowują uint64. IHR odrzuca część całkowitą >=2^64. Niedomiar niezerowego iloczynu do zera i niefinitywne wartości są jawne, bez epsilon przy stanie. Hold ma budżet 128 prób na wywołanie i wykrywa brak postępu odejmowania float32; przekroczenie jest błędem technicznym bez zwrotu częściowo zmienionego kandydata. W prawidłowym neutralnym kroku dt<=0.3 i rate<=30 ten budżet nie ogranicza należnych prób. Testy nie zmieniają tempa lub cen.

[Testy wylęgu](../tests/hatching/run.luau), [IHR](../tests/ihr/run.luau) i [produkcji](../tests/math/run.luau) korzystają z jawnych oczekiwań, stanów granicznych oraz niezależnych wektorów. Jest także mały test łączenia modułów: kura w drodze nie produkuje, po dotarciu produkuje, IHR wpływa na kolejne wywołanie produkcji. Nie jest to implementacja pełnego schedulera.

Wspólny runner: ./tools/test.ps1 -PythonExecutable python. Raport [math_implementation_verification.json](workflow/math_implementation_verification.json) podaje wyniki, hashe i rzeczywisty zakres QA. Nie wykonano Studio, DataStore, prawdziwych tras lub typecheckera. Stare manifesty są snapshotami swoich dostarczeń; nie przepisano ich hashy po rozszerzeniu narzędzi i poprawce ProfileSchema. Wyłącznie nowy raport opisuje bieżące wersje. Pozostałe zadania nie zostały rozpoczęte przez zamknięcie tych trzech.
