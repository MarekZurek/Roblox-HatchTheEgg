# Progi badań, ręczny wylęg, RCB i nowe konto

24.10.2026. Uzupełnienie [30 — F01](30_first_farm_manifest_and_technical_choices.md) na podstawie dostępnych materiałów referencyjnych. **N/S — reguły i wartości referencyjne; P — ich planowane mapowanie w Roblox.** Nie tworzy konfiguracji wydania, nie zatwierdza liczb jako R i nie rozpoczyna implementacji. Obowiązują [CURRENT_SPEC](CURRENT_SPEC.md), [27](27_numbers_time_and_player_state_contract.md), [28](28_modules_and_client_server_contract.md) oraz granica bilansu 17–21.

## 1. Punkty i progi Common — U01 rozstrzygnięte

Punkty badań Common są sumą **aktualnych poziomów wszystkich Common**. Jeden kupiony poziom zwiększa sumę o jeden, niezależnie od ceny, tieru, rodzaju efektu i sposobu zakupienia poziomu. Epic mają odrębną sumę; nie odblokowują tierów Common. Wydatek gotówki i suma maksymalnych poziomów nie są bieżącym licznikiem punktów.

`commonPoints = sum(commonLevel[id])`

`tierUnlocked(t) = commonPoints >= tierThresholds[t]`

| tier_raw | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Próg | 0 | 30 | 80 | 160 | 280 | 400 | 520 | 650 | 800 | 980 | 1185 | 1390 | 1655 |

Porównanie jest inkluzywne. Przy 29 punktach tier_raw=1 zablokowany, przy 30 dostępny; analogicznie 79/80 dla tier_raw=2. ID i indeks tieru muszą należeć do katalogu; nie używać zachowania indeksu poza tabelą jako ukrytego tieru.

W manifeście siedmiu badań z 30 trzy pozycje tier_raw=0 mają łącznie maksymalnie 105 poziomów. To **dowód osiągalności samych progów 30 i 80**, bez konieczności sprzedawania pozostałych badań tego tieru. Nie dowodzi, ile czasu zajmie zdobycie wymaganej gotówki. Wyższe tiery pozostają wyłączone w tym fragmencie. Sprawdzanie bramki następuje przed nowym zakupem; po sukcesie suma poziomów i nowy poziom są spójne, replay nie dodaje punktu ponownie.

## 2. Bazowy ręczny wylęg — U02 rozstrzygnięte

**Jedno zaakceptowane naciśnięcie próbuje wypuścić dokładnie jedną kurę.** W zwykłym stanie wymaga zapasu wylęgarni >=1 oraz wolnego miejsca po uwzględnieniu kur przypisanych w drodze. Nieudana próba nie pobiera jednej sztuki zapasu. Udana próba wybiera cel, rezerwuje miejsce, odejmuje 1 zapasu i rozpoczyna bieg. Wyjątek nieograniczonego wylęgu jest odrębnym efektem, poza pierwszym neutralnym fragmentem.

**Nie istnieje ustalona tymi materiałami uniwersalna baza „3 ręcznie wypuszczane kury/s”.** 3/s oznacza bazowy **refill**. Zapas 250 może pozwalać chwilowo wypuszczać szybciej niż refill. Dawne analityczne `max(3, holdRate)` nie jest źródłem reguły wejścia i nie należy go przenosić do gry; nie zmieniamy odłożonych analiz 17–21.

Hold to Hatch dostarcza odrębne tempo powtórzeń: przy zerowym badaniu i bez innych efektów rate=0; każdy poziom Epic dodaje 2 próby/s, do 30/s przy poziomie 15. Mechanizm powtórzeń działa, gdy rate>0.1. Akumulator czasu jest float32; dopóki jego wartość jest **ściśle większa** od `1/rate`, odejmuje okres i wykonuje jedną próbę. Równość nie uruchamia powtórzenia. Sam stopień odnowienia intencji sieciowej nie nadaje prawa do powtarzania; Auto-Hatch jest jeszcze innym uprawnieniem i pozostaje poza pierwszym fragmentem.

### Zastosowanie w protokole P

28 uzupełniono o `HatchPress`: pojedynczy sygnał wejścia, bez liczby kur, ceny lub klientowskiego dt. Strumień wejścia ma numer porządkowy; duplikat nie wypuszcza drugiej kury. `HatchInput` start/refresh/stop obsługuje intencję przytrzymania. Przy rate=0 przytrzymanie **nie** generuje bezpłatnego ciągu prób; UI rozróżnia naciśnięcie od podtrzymywania.

Wejście na przycisk 3D lub naciśnięcie kontrolki może zgłosić pojedynczy press, a dalsza obecność/przytrzymanie wyłącznie intencję hold. Warunki interakcji i limity antyspamowe ustala serwer. Nie definiujemy teraz nowego tempa balansowego lub liczbowego cooldownu. Input nie jest trwałym zakupem z osobnym operationId na każdą kurę; wynikowy stan i checkpointy nadal spełniają 27–28. Po reconnect nie odgrywa się starego bufora wejścia.

## 3. Aktywne RCB i przejścia populacji — rdzeń U03 rozstrzygnięty

Nie używać wzoru maksymalnego RCB z FV jako aktywnego bonusu dochodu. Dla jawnych wejść:

- `n`: liczba autorytatywnie biegających kur, nie liczba wyrenderowanych modeli;
- `c`: końcowy współczynnik wykładniczy; neutralna baza 1;
- `K`: końcowy limit przed końcowym mnożnikiem; neutralna baza 5;
- `M`: końcowy mnożnik RCB; neutralna baza 1.

`q = min(c^n, K)`

`RCB = q*M, gdy q>1; w przeciwnym razie RCB=q`.

Mnożnika M nie stosuje się bezwarunkowo do neutralnego q=1. Dla c=1, K=5, M=2 wynik nadal wynosi 1. Dla c=1.1, n=10, K=5, M=2 wynik wynosi około 5.1874849202; dla n=30 limit daje 10. Nie podwajać niezależnie tego samego źródła bonusu. Siedem Common z 30 nie zawiera badań współczynnika RCB, więc w neutralnym fragmencie przy poziomach pozostałych badań 0 samo bieganie nie podnosi c ponad 1. To ograniczenie zestawu testowego, nie usunięcie RCB z gry.

### Cel i moment zaliczenia kury

1. Wolne miejsce slotu h: `v[h]=max(0, capacity[h] - settledPopulation[h] - assignedInTransit[h])`. Pusty slot ma v=0. Łączna wolna pojemność V=sum(v).
2. Gdy V=0, nie przydzielać kury i nie obciążać zapasu. Wybór celu używa losowego wyniku całkowitego modulo V i kolejnych przedziałów długości v[h]. To wybór ważony wolnymi miejscami, **nie argmax najpustszego kurnika**. Zachować kolejność slotów. Dla kontrolowanego RNG wynik jest jednoznaczny; nie deklarować idealnej jednostajności dowolnego generatora przy modulo.
   Wynik modulo r należy do [0,V−1]. Wybiera pierwszy niepusty przedział, dla którego r<v[h]; po pominiętym slocie odjąć v[h]. Zatem 0 wybiera początek pierwszego niepustego przedziału, nie ostatni slot. Numer slotu UI od 1 jest odrębną konwersją. Adapter RNG ma jawnie deklarować zakres; nie dokładać 1-based losowania i modulo bez sprawdzenia tej konwencji.
3. Udane wypuszczenie: `assignedInTransit[target]+=1`, zużycie zapasu i utworzenie autorytatywnej grupy razem; rozpoczęcie biegu zwiększa runningCount. Nie zwiększa jeszcze settledPopulation.
4. Dotarcie: dokładnie raz zmniejszyć przypisanie i runningCount oraz zwiększyć settledPopulation wskazanego kurnika. Dopiero zasiedlona kura należy do populacji znoszącej jaja. Nie dodawać jej ponownie na podstawie animacji klienta.
5. Away zamyka bieg i przenosi należne kury w drodze do właściwych kurników zgodnie z regułą fast-forward, bez podwójnego przypisania. Krótka przerwa <=60 s nie daje podstawy do zastosowania całej gałęzi away.

**Pozostaje techniczny wynik sceny:** geometria tras i autorytatywny czas dotarcia. Dostępne materiały nie uzasadniają globalnej stałej 6 sekund dla dowolnej działki Roblox. Planowany RouteProvider dostarcza identyfikowany przebieg/czas albo serwerowe zdarzenie dotarcia; kontrolowany test dostarcza jawne zdarzenie wejściowe. Nie uznawać testu z zadanym dotarciem za zaliczenie rzeczywistego ruchu w Studio. Nie zgadujemy nowych prędkości lub opóźnień w tym zadaniu.

Produkcja poprzedza wzrost IHR w kroku z 27. Zdarzenia ręcznego dotarcia są serializowane przez koordynatora: rozliczyć poprzedni należny odcinek starym stanem, zastosować dotarcie, kolejne okresy używają nowego stanu. Nie przenosić dotarcia wstecz na wcześniej rozliczoną produkcję. Jest to proponowana integracja P, nie nowy dowód rozdzielczości ruchu.

## 4. Nowe konto a reset — U04: ustalony stan podstawowej farmy

Materiały inicjalizacji nowej gry łączą brak wcześniejszego stanu z odbudową farmy Edible, a następnie osobno napełniają wylęgarnię do jej maksymalnego zapasu. Dzięki temu poniższy stan nie wynika już wyłącznie z analogii do resetu.

| Wielkość referencyjna S/N | Stan nowego konta, bez zakupów i efektów |
|---|---|
| Jajo / portfel gotówki | Pierwsze jajo, indeks projektu 0; cash=0 |
| Kurniki i populacja | Jeden COOP w pierwszym slocie, pozostałe sloty puste; populacja, ułamki i przypisania 0 |
| Flota | Jeden TRIKE; **bazowy limit floty 4**, a nie jeden posiadany pojazd lub 17 maksymalnych miejsc |
| Silosy | **1 posiadany silos**; bazowy czas 3600 s, referencyjna jakość away bez Pro 0.5 |
| Ręczna wylęgarnia | **Pełny zapas 250** po inicjalizacji; refill 3/s; brak aktywnej intencji, holdRate=0 |
| Badania / przychód | Common=0, Epic=0; pusta historia przychodu nowej sesji i neutralne efekty |
| GE | Referencyjny licznik zarobionych GE=10, wydanych=0, dostępne=max(0,earned-spent)=10. Nie przyznaje to automatycznie 10 GE w konfiguracji Roblox. |
| SE/PE, odblokowania, aktywne bonusy | Neutralny brak wcześniejszego postępu; brak kupionego Pro/Buy MAX/Hyperloop i aktywacji. Nie dziedziczyć uprawnień z konta testowego. |

Techniczne meta/ownership/operation IDs generuje nowy system, nie kopiuje się ich z referencji. Kalendarz, trofea, oferty i Piggy są poza pierwszym fragmentem: brak implementacji ich inicjalizatorów nie może wyzerować tych sekcji istniejącemu graczowi. Pełny onboarding i konfiguracja produktów nie stają się wykonane przez powyższą tabelę.

**Status dla Roblox: P oparty na S/N, nie nowe zatwierdzenie bilansu.** Profil TEST_ONLY z 30 celowo miał zero silosów i limit floty 1; pozostaje osobnym testem brzegowym i nie jest już kandydatem do opisu referencyjnego nowego konta. Test nowego konta powinien otrzymać osobny manifest wejść oparty na tabeli, z jawnym zatwierdzeniem konfiguracji przed wydaniem.

## 5. Weryfikacja i granice

Wykorzystano zachowane zestawy granic progów, 144 przykłady RCB z kontrolowanymi c/K/M/n oraz materiał opisujący inicjalizację, odczyt poziomów i przejścia kur. Sprawdzono ponownie wartości i interpretację danych, **bez uruchamiania symulacji progresji lub testów gry**. Materiały techniczne pochodzenia pozostają poza projektem; dokument publikuje wyłącznie reguły użytkowe, bez prywatnych ścieżek i narzędzi.

Przyszłe kryteria odbioru: suma Common bez Epic/kosztu; próg−1/próg/próg+1; press przy zapasie 0/0.999/1; brak miejsca; brak bezpłatnego hold przy rate=0; ścisła równość okresu; RCB przy q=1 i przy limicie; wybrany przedział wolnego miejsca; podwójne dotarcie; nowy profil vs ponowne wczytanie. To specyfikacja, **NIE URUCHOMIONO** w HatchTheEgg.

Zamknięto referencyjną semantykę U01/U02 oraz matematyczny i stanowy rdzeń U03 i start podstawowej farmy U04. Do realizacji pozostają: mapowanie trasy/dotarcia w scenie, adaptery U05/U06 i właściwe testy. Nie oznacza to gotowości wykonanej implementacji lub przyjęcia konfiguracji wydania.

## Uzupełnienie techniczne PRE-03

[35](35_pre03_routes_and_arrivals.md) wybiera projekt P: geometryczny termin oznacza gotowość, a dotarcie stosuje się w fazie po produkcji na końcu obejmującego go kroku, przed refill/IHR. Nie powstaje dodatkowy krok i nie przeliczamy wcześniej wypłaconej produkcji. To doprecyzowanie proponowanej integracji, nie nowy dowód domenowy; geometria/prędkość i test S nadal należą do IMP-13/15.
