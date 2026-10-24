# IMP-09 — TimelineSimulation: neutralna podstawowa farma

24.10.2026. Wykonano czysty moduł i testy Lune. Bez adaptera zegara Roblox, sceny, RPC, chmury i zatwierdzenia konfiguracji produkcyjnej. [27](../27_numbers_time_and_player_state_contract.md), [28](../28_modules_and_client_server_contract.md), [29](../29_first_farm_implementation_plan.md), [31](../31_research_hatching_rcb_and_new_account.md), [33](../33_pre01_toolchain_and_clocks.md), [35](../35_pre03_routes_and_arrivals.md) i [38](../38_imp04_imp05_imp06_delivery.md) wyznaczają zakres; odłożonego bilansu i danych referencyjnych nie zmieniono.

## API i model

`TimelineSimulation.new(codec,production,hatching,ihr,data,{mode="INTERNAL_TEST_ONLY"})` przyjmuje rzeczywiste moduły obliczeń z IMP-04–06 oraz PersistenceData. `begin(state,targetMs,config)` zamraża okres i kopiuje wejście. `advance(checkpoint,maxPhases)` wykonuje co najwyżej podaną liczbę jednostek pracy. Nie czyta zegara; autorytatywny targetMs dostarcza koordynator. Konfiguracja zawiera wyłącznie revision, siloCapacityLevel i pro, jest zachowana w checkpoint i nie jest pobierana ponownie podczas wznowienia.

Model obliczeniowy zawiera `settledWallThrough` w ms, `farm` i `accounting`. Farm zawiera cash, habitats (capacity/population/assignedInTransit jako uint64 tekst, fractionalIHR jako binary64), hatcheryStock, runningCount, hatchGroupSequence, groups, commonLevels, vehicleTypes i siloOwned. Pojemności są sprawdzane z katalogiem, a grupy z faktycznymi rezerwacjami. Nie jest to pełny wire profilu; adapter koordynatora dokonuje jawnej konwersji.

Ten zakres obejmuje tylko wybrane siedem Common, neutralny RCB=1, brak Epic Calm/sharing/hold, petów, aktywnych boostów, VD i eventów. Nie generuje wejścia ręcznego podczas nadrabiania okresu. Jawnie przekazane w tym modelu pola efektów i nieobsługiwane klucze konfiguracji są odrzucane. Adapter pełnego profilu musi zweryfikować jego neutralność przed wyodrębnieniem tego modelu; samo pominięcie aktywnego efektu w adapterze byłoby błędem integracji. Brak sharing oznacza brak losowań i potrzeby odtwarzania stanu RNG w tym zakresie.

## Fazy i wznowienie

Siatka używa `dt=min(remaining,0.3)` i odejmowania zużytego dt od remaining. Końcowy krótszy krok zachowuje pozostałość binary64; nie zaokrąglamy do ms i nie wymuszamy sumy ułamków IHR do pełnej kury.

Jednostki pracy to:

1. `BETWEEN_STEPS` → neutralna faza managera i produkcja ze starej populacji, transport, księgowanie → `AFTER_PRODUCTION`; checkpoint zachowuje zamrożone stepDt, już wypłacony dochód i niezmieniony cursor ukończonych kroków.
2. `AFTER_PRODUCTION` → dotarcia o terminie <= końca kroku (kolejność termin, groupId), refill i IHR → `BETWEEN_STEPS`; dopiero teraz zmieniają się elapsedSeconds, remainingSeconds i stepIndex.

Wznowienie po produkcji nie wykonuje jej drugi raz. Dotarcia gotowe już na początku dodatniego okresu online są stosowane przed pierwszą produkcją; pozostałe po produkcji kroku obejmującego termin, przed IHR. Techniczny podział pracy nie zmienia gałęzi online/away, startu, celu ani dt. Parametr maxPhases jest budżetem obliczeń, nie limitem należnego czasu. Chroniony jest brak postępu czasu w reprezentacji liczbowej. Kontrola spójności elapsed+remaining ma wyłącznie walidacyjny limit błędu sumowań binary64; nie koryguje wartości, nie zmienia granic terminów i nie dodaje epsilon do logiki produkcji.

Checkpoint `encodeCheckpoint`/`decodeCheckpoint` zachowuje wszystkie liczby przez Real64 round-trip w jawnych węzłach oznaczonych `__hteTimelineReal64`. Zwykły tekst uint64 pozostaje tekstem; to również obejmuje duration/snapshot trasy. Klucz znacznika jest zarezerwowany i odrzucany w wejściu pamięciowym. Format jest wewnętrznym, wersjonowanym formatem checkpointu; nie jest DTO klienta, podpisem kryptograficznym lub dowodem integralności niezaufanego payloadu. Do trwałego zapisu należą wspólnie cały stan ekonomii i checkpoint, zgodnie z SessionRepository; sam zapis cursora jest niewystarczający.

## Away i księgowanie

Przerwa <=60 s pozostaje online bez limitu silosów. Dłuższa przerwa wybiera away, raz zamyka grupy w drodze i ogranicza czas produkcji do `siloOwned*(3600+360*siloCapacityLevel)`. Mnożnik dochodu away wynosi 0.5 bez Pro albo 1 z Pro. Przy zerze silosów grupy są zamykane, produkcja wynosi zero, lecz cały okres jest rozliczony. Po zakończeniu settledWallThrough obejmuje zamrożony pełny target, również czas po limicie; dodatkowy czas po tym celu wymaga osobnego okresu. Ujemna różnica zegara nie cofa cursora i nie przyznaje dochodu, a wynik oznacza clockDiscrepancy.

Dochód zwiększa oddzielnie farm.cash, accounting.currentFarmCash i accounting.lastCashEarned. currentFarmCash jest akumulatorem przychodu, nie aliasem pozostałego portfela: wcześniejszy zakup nie cofa zarobionej kwoty. W neutralnej fazie managera **przed** produkcją lastBaseEarnings jest odświeżane jako prestigeSessionArchivedCash+currentFarmCash. prestigeSessionArchivedCash i prestigeExtraEarnings nie zmieniają się (mnożnik prestiżowy 1). Nie dodano fikcyjnego uniwersalnego lifetime licznika; nieznane dane stanu są zachowane, ale nie mają nowo zgadywanej semantyki. Reset/prestiż i inne nagrody pozostają osobnymi operacjami.

## Dowody

`tests/timeline/run.luau` uruchamia rzeczywiste produkcję, IHR, Hatching i PopulationMath. Obejmuje niezależne działania arytmetyczne, dokładny wynik refill 2.9999999999999996 po 1 s, fazę po produkcji z JSON round-trip, dzielenie pracy po każdej fazie vs pełne wykonanie bitowo, threshold 60/60.001 s, 3600 s limitu i cały dłuższy okres, zero silosów, Pro, gotowe i graniczne dotarcia, produkcję przed IHR, rozdzielenie portfela od przychodu oraz błędne cursory/formaty. Wykonano 58 asercji PASS. To dowód L, nie S/D ani dowód fizycznego ruchu lub zapisu chmurowego. Pełna integracja koordynatora ma odrębny test i raport dostarczenia.
