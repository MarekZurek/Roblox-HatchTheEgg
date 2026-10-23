# Etapy HatchTheEgg i rzeczywiste zależności

**P — plan przyszłej realizacji, żadnego etapu implementacji nie rozpoczęto tym dokumentem.** Bilans nadal odłożony. Zlecenie planowania nie jest zleceniem kodowania, Studio ani uruchamiania chmury.

## Dwa osobne warunki gotowości

- **Gotowość reguł i produktu:** D01–D07, [25](../25_approved_product_structure.md) i [26](../26_approved_launch_scope_and_pro_availability.md) określają zachowania oraz zakres wydania.
- **Gotowość ekonomii wydania:** ceny, szanse, liczby materiałów, próg gwarancji, siły, liczby miejsc, inkubacja i parametry produktów nadal niezatwierdzone. Implementacja niezależnej logiki może powstać po zleceniu, ale nie wolno wydać nierozstrzygniętej ekonomii jako gotowej.

Kontrolowane parametry w testach to fixture, nie produkcyjny balans. Fixture nie może wyciec do dostępnego graczom sklepu lub zapisu produkcyjnego. Na obecnym etapie nie tworzymy nawet tych fixture — opisujemy tylko przyszłą granicę.

## Kolejność rezultatów

| Etap | Wynik i zakres | Rzeczywista zależność | Kryterium odbioru po realizacji | Relacja do bilansu |
|---|---|---|---|---|
| **0. Przygotowanie techniczne** | Krótka mapa domeny, reprezentacja kwot/liczników i zasad zaokrągleń, podział odpowiedzialności serwera/klienta, kontrakt przechowywania i testów, sposób dostarczenia źródeł do Studio. Zapisać potrzebne decyzje techniczne z uzasadnieniem; korzystać z szablonu ADR ECC. | Zlecenie konkretnego etapu; bieżąca specyfikacja. Nie zależy od instalacji całego ECC. | Wiadomo, co jest stanem autorytatywnym, jak testować czystą logikę i jakie narzędzia rzeczywiście istnieją. Brak fikcyjnego generatora/runnera lub wyboru biblioteki bez oceny. Nie wymaga arbitralnej liczby ADR. | Możliwe bez nowej kalibracji. |
| **1. Matematyka i bezpieczeństwo stanu** | Czyste funkcje produkcji/transportu, FV/SE i konwersji, zegar jako kontrolowane wejście. Minimalne granice zapisu, sesji i operacji z ID/wynikiem. | Ustalony kontrakt liczb i stanu z etapu 0. | Wyniki Luau porównane z odpowiednimi istniejącymi referencjami. Warunki jednej sesji, powtórki i nieznanego zapisu sprawdzone pod harness/mock; jawnie bez deklaracji chmury. FV i dochód są osobnymi testami. | Używać potwierdzonych wejść lub jawnych testowych parametrów, nie wznawiać symulacji 17–21. |
| **2. Pierwsza grywalna farma** | Jedno jajo, ręczna wylęgarnia kurczaków, IHR, cztery sloty kurników, transport, podstawowe badania, minimalne czytelne UI i działka. Klient obrazuje, serwer rozlicza. | Etap 1 w zakresie produkcji i bezpiecznej mutacji; uzgodniony przepływ żądań. | W Studio gracz może wykluć kury, kupić badanie/kurnik/pojazd, zobaczyć ograniczenie transportu i właściwy dochód. Sprawdzono izolację stanów graczy w deklarowanej konfiguracji. Przebieg zapisu testować na właściwym poziomie, nie nazywać mocka trwałością chmury. | Rdzeń źródłowych danych nie wymaga ustalenia cen petów/Robux. |
| **3. Awans farmy i prestiż** | Warunki FV dla jaj, księgowanie sesji prestiżu, SE/PE, właściwy reset i zasoby trwałe. Ścieżka 19 jaj, zachowanie wpisów boostów/podwajacza w stanie. | Matematyka, źródła badań i pierwsza pętla farmy; kontrakt czasu trwających efektów. | Testy zmiany jaja i prestiżu porównują stare/nowe pola. Nie kasują trwałych petów/liczników/boostów. Zachowanie wpisu odróżnione od aktywnego efektu. Pełne działanie boostów domknąć po etapie 4, petów po 5. | Bez potrzeby kalibracji inkubacji. Grywalne tempo całej ścieżki nadal nie jest potwierdzone. |
| **4. Czas: offline, boosty i eventy** | Produkcja przed wzrostem, limit silosów, away, pozostały czas boostów, absolutny termin VD, historyczne okna wydarzeń. Najpierw model czasu i istniejące typy eventów, dopiero potem prezentacja rotacji. | Stan/czas i matematyka 1, pętla 2, reset 3 w zakresie integracji. | Sprawdzone granice 60 s, wyczerpanie silosów i różne rodzaje deadline. Event dochodu ważony zgodnie z 16; VD zachowuje własną regułę końca kroku. Boosty przeżywają reset; Enlightenment wyłącza/pauzuje właściwe efekty. | Nie ustalamy nowej rotacji, siły eventów ani kosztów VD. |
| **5. Pety i ewolucja** | Ekwipunek, wyposażenie, poprawne warstwy P, blokady, tier×cel, chroniony bazowy, zużycie kopii, gwarancja i premium; Rainbow końcowe v1. | Etap 1 transakcje, etap 4 efekty/czas, bieżące D01–D03 i 26. | Testy samej logiki możliwe na jawnych fixture. Obejmują brak podmiany materiałów, zdjęcie/odblokowanie, reset i powtórki. Nie deklarować naturalnej progresji lub gotowego inkubatora bez zatwierdzonych parametrów. | **Bramka liczb:** rzeczywiste pozyskiwanie/siły/łączenie w wydaniu czekają na zatwierdzony balans. Brak tej bramki nie blokuje niezależnego UI/testów kontraktów. |
| **6. Nagrody i onboarding** | Drony, 2+1 paczek, zapisane oferty/rezerwacje, kalendarz, konwersje Epic/Piggy, trofea i samouczek. Samouczek i retroaktywne trofea w jednym spójnym kontrakcie. | Etap 1 trwałe operacje; 2 działka; 3 źródła PE; 4 czas/eventy. Nie zależy logicznie od ukończenia wydaniowego inkubatora etapu 5. | Jednorazowy odbiór, PE ze źródeł bez podwójnego liczenia, oferta zachowuje wynik i slot, tutorial nie blokuje przy ponownym wejściu. Sprawdzać nowy kod, nie audytować ponownie modelu referencyjnego. | Część źródłowa i reguły R niezależne; nowe koszty i podaż zostają odłożone. |
| **7. Produkty i przepływ zakupów** | Pro, osobny Buy MAX, GE, warunkowy Piggy; wariant A i jasna zawartość przed zakupem; płatne VD/prezenty. Auto-Hatch/VIP poza v1. | Transakcje 1 oraz system konkretnej kupowanej korzyści. Pro adapter może być przygotowany wcześniej jako kontrakt, bez realnego produktu lub domyślnego nadawania uprawnień. | Własność gamepassów rozdzielona od zakupów powtarzalnych. Powtórzone/nieznane/opóźnione operacje nie gubią korzyści ani nie naliczają drugi raz. Test dostępności +10 p.p., rezerwacji i granicy UTC. Realna walidacja platformy oznaczona oddzielnie od mocka. | **Bramka wydania:** brak zatwierdzonych cen/pakietów/parametrów blokuje uruchomienie produktu, nie samo projektowanie kontraktów. Piggy może pozostać wyłączone. |
| **8. Zintegrowane DEV i kandydat wydania** | Kontrole całego złożonego przebiegu, rzeczywistego zapisu i współbieżności, urządzeń mobilnych, zasobów, migracji i odzyskiwania po błędach. | Tylko faktycznie wydawane systemy, zatwierdzony balans wydania i odrębnie ustalone środowisko/testy platformy. | Wyniki odnoszą się do identyfikowanej wersji; nie ma debugowych przywilejów w konfiguracji wydania. Playtest człowieka osobno. Znane ryzyka zapisu/ekonomii nie są maskowane przez ogólny PASS. | Bilans musi zostać wznowiony i przyjęty przed deklaracją gotowości do publikacji; ten plan tego nie robi. |

Etapy grupują zakres, nie są łańcuchem wszystkich zadań. Każdy konsument zależy od konkretnego wyniku, nie od „akceptacji całej poprzedniej fazy”. W razie autoryzowanej współpracy można przygotowywać niezależne kontrakty, UI i testy równolegle; współdzielone interfejsy mają jednego właściciela.

Publikacja, tworzenie produktów, koszty i użycie prawdziwej chmury nie wynikają z tabeli. Ich realne wykonanie musi mieścić się w osobnym aktualnym poleceniu i uprawnieniach.

## Najważniejsze zmiany wobec szkicu ECC

- Zapis i transakcje są fundamentem, a nie doklejonym dodatkiem po gotowej ekonomii.
- Historyczna semantyka eventów wchodzi razem z offline; etap końcowy nie zmienia po fakcie już utrwalonych naliczeń.
- Samo porównanie FV nie jest testem calculateIncome.
- Nie udajemy działania ograniczeń petów w fazie, w której nie ma jeszcze systemu ich efektów; pełne kryterium ma wskazaną zależność.
- Nie ma „placeholder values” jako domyślnej konfiguracji inkubatora. Jawna konfiguracja testowa nie jest zatwierdzonym bilansem i nie dopuszcza realnych płatności.
- Mobile/readability zaczynają się w pierwszej grywalnej farmie, a końcowy etap sprawdza całość; nie odkładamy wszystkich problemów UI do ostatniego tygodnia.
- Pro i Buy MAX nie tworzą jednego produktu. Auto-Hatch nie otwiera petów i nie wraca do v1. Piggy jest warunkowe, nie obowiązkowe mimo braku bilansu.

Plan nie ustala bibliotek, liczby modeli, branchy, terminów lub budżetu sprzętu. Tych szczegółów nie należy kopiować z obcego projektu.

## Materiał przygotowany do etapu 0

[27 — liczby, czas i model profilu](../27_numbers_time_and_player_state_contract.md) opisuje część kontraktów jako P. Nie zamyka całego etapu 0: narzędzia dostarczania źródeł, adaptery liczb/zapisu, retencja i harness nadal wymagają konkretnego zadania. Etap 1 nie został uruchomiony.

## Kontrakt modułów i protokołu do etapu 0

[28](../28_modules_and_client_server_contract.md) uzupełnia 27 o moduły, komendy, podglądy, projekcje i odtwarzanie komunikacji. Jest P i nie zamyka całego etapu 0. Właściwy transport, runtime, zapis, budżety i harness pozostają do przygotowania w zleconych później zadaniach.

## Konkretny pierwszy fragment — plan 29

[29 — podstawowa farma](../29_first_farm_implementation_plan.md) rozbija fragment etapów 0–2 na F01–F09 i A01–A16. Nie wymaga wcześniejszej realizacji FV/SE, petów lub płatności. Obejmuje minimalne rozliczenie powrotu w neutralnym stanie, żeby nie odkładać poprawności czasu i zapisu do pełnej integracji etapu 4; nie zastępuje zakresu boostów/eventów tego etapu. F01 ustala manifest/start i potrzebne adaptery, F03 oraz F04 mają niezależne wyniki, F05 łączy czas z zapisem, a zakupy i UI konsumują konkretne interfejsy. Wszystkie zadania pozostają niewykonane; nie zmienia się bilans ani zakres premiery.

Aktualizacja: dokumentacyjną część F01 zawiera [30](../30_first_farm_manifest_and_technical_choices.md). Wybrane ID i kierunki techniczne są P; U01–U06 pozostają konkretnymi zależnościami, bez blokowania niezależnych części samego codec lub matematyki na kontrolowanych wejściach. Nie wykonano zadań implementacyjnych, nie zatwierdzono inicjalizacji nowego konta ani adaptera trwałości.

## Rozbicie do niezależnej realizacji — 24.10.2026

[31](../31_research_hatching_rcb_and_new_account.md) rozstrzyga rdzeń U01–U04, bez konfiguracji wydania; [32](../32_parallel_delivery_backlog.md) rozbija etapy na zadania z właścicielem obszaru, konkretnymi zależnościami i portami testowymi. Dotyczy wszystkich przygotowanych warstw, nie uruchamia kodowania. Matematyka nie wymaga koordynatora, UI nie czeka na prawdziwy transport, integracja konsumuje komplet właściwych wyników.
