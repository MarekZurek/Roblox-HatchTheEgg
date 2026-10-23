# Periodicals, kalendarz, wydarzenia i szczegółowe reguły boostów

> **Specyfikacja referencyjna po redakcji.** Zawarte przykłady nie stanowią wykonania testów implementacji HatchTheEgg. Aktualne decyzje R rozstrzyga [CURRENT_SPEC](CURRENT_SPEC.md).

## 2. Rzeczywiste wydarzenie i reguły czasu

| Pole | Wartość |
|---|---|
| identifier | event-10-20 |
| type | drone-boost |
| multiplier | 4 |
| subtitle | 4x DRONE REWARDS! |
| seconds_remaining | 70221.43421888351 |
| start_time | 1792512000 |
| duration | 86400 s |
| cc_only | false |

To snapshot z chwili odczytu, nie stałe wydarzenie. Odpowiedź i metadane. Tego publicznego wyniku nie należy traktować jako pełnego zestawu spersonalizowanych wydarzeń/Ultra.

`LiveEventManager::onCurrentEvents`, zamienia `seconds_remaining` na absolutny termin przez dodanie bieżącego zegara klienta. Kopię zapisuje lokalnie, a `reset()` potrafi ją odczytać z cache. `isEventActive`, sprawdza znalezienie typu i **deadline > now**; przy równości wydarzenie jest nieaktywne. W tej funkcji nie ma osobnej bramki `start_time` ani `cc_only`. Nie oznacza to, że można samodzielnie włączyć ofertę konta Ultra — kwalifikacja odpowiedzi serwera jest odrębną warstwą.

Sprawdzono 12 przypadków referencyjnego predykatu przy granicy czasu, różnych `start_time` i flagach `cc_only`. Czas jest oparty o zegar, a nie odjęcie `dt` od każdego eventu. Nie przenosić timera aktywnego boostu zużywalnego na wydarzenia.

### Mapowanie wszystkich 17 rozpoznanych typów

Uruchomiono oryginalny `LiveEventManager::update` dla każdego typu z kontrolowanym mnożnikiem 4. Wszystkie wartości liczbowe są używane jako **bezpośredni mnożnik wymiaru**, z konwersją przez float32; np. wyprzedaż z mnożnikiem 0.7 oznacza koszt 70%, a nie 70% rabatu. Typ `piggy-cap-boost` włącza flagę uncapped, nie mnoży limitu liczbowo.

| Typ | Zmieniany wymiar | Wynik dla wejścia 4 |
|---|---|---:|
| piggy-boost | `piggyGrowthMult` | 4.0 |
| piggy-cap-boost | `uncappedPiggyActive` | true |
| prestige-boost | `soulEggCollectionMult` | 4.0 |
| earnings-boost | `earningsMult` | 4.0 |
| gift-boost | `giftRewardMult` | 4.0 |
| drone-boost | `droneRewardMult` | 4.0 |
| epic-research-sale | `epicResearchCostMult` | 4.0 |
| research-sale | `researchCostMult` | 4.0 |
| hab-sale | `habCostMult` | 4.0 |
| vehicle-sale | `vehicleCostMult` | 4.0 |
| boost-sale | `boostCostMult` | 4.0 |
| boost-duration | `boostDurationMult` | 4.0 |
| crafting-sale | `craftingPriceMult` | 4.0 |
| mission-capacity | `artifactsMissionCapacityMult` | 4.0 |
| mission-duration | `artifactsMissionDurationMult` | 4.0 |
| mission-fuel | `missionFuelingMult` | 4.0 |
| shell-sale | `shellPriceMult` | 4.0 |

Ta lista pochodzi z `LIVE_EVENTS` w konfiguracji referencyjnej. Nieznany identyfikator typu mapuje się na sentinel 17 i jest pomijany. Lista z serwera nie jest listą już przemnożonych efektów ekonomicznych.

### Wydarzenie nowego gracza

Odrębny termin w stanie konta aktywuje lokalny pakiet: **2x soulEggCollectionMult, 0.8x epicResearchCostMult, 0.8x boostCostMult, 3x piggyGrowthMult**. `update` mnoży nim odpowiednie bieżące efekty. `isNewPlayerEventActive`, używa `deadline >= now`. Zwraca więc inny wynik na samej granicy niż zwykłe `isEventActive`. Czas 86400 s znajduje się w poprzednim snapshotcie LiveConfig; nie jest regułą przedłużania eventu przy każdym logowaniu.

## 3. Kalendarz: źródło danych i zegar

dokumentacja referencyjna zawiera surowe rekordy, typy nagród, listy podtypów, listy kwot, limity i tryby skalowania. `gift_for_day`, używa **dayIndex od 0**, pozycji `dayIndex % 28` oraz cyklu `floor(dayIndex/28)`.

`onDailyGiftInfo`, przekazuje wynik do callbacku. Callback ustawia `next_daily_gift_time=now+seconds_to_next_day`, porównuje dzień serwera z `last_daily_gift_collected_day` i wybiera `next_gift` według **num_daily_gifts_collected**. W czterech wykonanych przypadkach: ten sam dzień nie kwalifikował do nagrody; nowy dzień i długa przerwa kwalifikowały do następnej pojedynczej nagrody; cofnięty dzień aktualizował zapis dnia bez przyznania nagrody. Nie naliczano pakietu wszystkich opuszczonych dni. Jest też kontrola rozbieżności dnia lokalnego o co najmniej 3 dni.

Test zatrzymuje się przed wyświetleniem/odebraniem nagrody: nie potwierdza pełnej atomowości wypłaty ani ochrony przed ponownym kliknięciem. Pola czasu, dnia serwera i liczby odebranych prezentów muszą pozostać rozdzielone.

### Tryby skalowania cyklu

Niech `m=floor(dayIndex/28)`:

Dla gotówki (typ 2) wynik liczbowy z tabeli oznacza procent **Home Farm Value**: `cash = amount/100 * getHomeFarmValue()`. Nie korzysta z FV przypadkowo oglądanej farmy kontraktowej.

### Pełne surowe parametry 28 dni

| Dzień | Typ nagrody | Lista kwot / baza | Podtypy | Tryb | cap |
|---:|---|---|---|---:|---:|
| 1 | GE | 192 | — | 3 | 6144 |
| 2 | Boost | 2, 2, 1, 1 | `jimbos_purple_v2`, `jimbos_purple_big`, `jimbos_orange`, `jimbos_orange_big` | 0 | — |
| 3 | Epic Research | 1 | `hold_to_hatch` | 0 | — |
| 4 | Gotówka (% home FV) | 50 | — | 2 | 200 |
| 5 | Poziom Piggy | 1 | — | 0 | — |
| 6 | GE | 1000 | — | 2 | 10000 |
| 7 | Soul Eggs | 5000, 250000, 5000000, 250000000 | — | 0 | — |
| 8 | GE | 396 | — | 3 | 9472 |
| 9 | Boost | 1 | `tachyon_prism_purple_v2`, `tachyon_prism_purple_big`, `tachyon_prism_orange`, `tachyon_prism_orange_big` | 0 | — |
| 10 | Shell scripts | 5, 7, 9, 12, 15, 18 | — | 0 | — |
| 11 | Epic Research | 1 | `epic_multiplier` | 1 | — |
| 12 | Soul Eggs | 10000, 1000000, 10000000, 750000000 | — | 0 | — |
| 13 | GE do Piggy | 5000 | — | 2 | 50000 |
| 14 | GE | 1500 | — | 2 | 10000 |
| 15 | Gotówka (% home FV) | 75 | — | 0 | — |
| 16 | Epic Research | 1 | `epic_hatchery`, `transportation_lobbyist` | 1 | — |
| 17 | GE | 96 | — | 3 | 12288 |
| 18 | Shell scripts | 10 | — | 0 | — |
| 19 | Soul Eggs | 25000, 1600000, 18000000, 1000000000 | — | 0 | — |
| 20 | Boost | 1 | `soul_beacon_purple_v2`, `boost_beacon_blue`, `money_printer` | 1 | — |
| 21 | GE | 792 | — | 2 | 7920 |
| 22 | Gotówka (% home FV) | 150 | — | 0 | — |
| 23 | Boost | 1 | `money_printer`, `jimbos_orange_big`, `boost_beacon_purple`, `tachyon_prism_purple_big`, `soul_beacon_orange`, `boost_beacon_blue_big`, `boost_beacon_orange` | 1 | — |
| 24 | Epic Research | 1, 3, 5 | `soul_eggs` | 0 | — |
| 25 | Soul Eggs | 100000, 2500000, 50000000, 2500000000 | — | 0 | — |
| 26 | GE | 396 | — | 3 | 6336 |
| 27 | GE do Piggy | 10000 | — | 3 | 40000 |
| 28 | Prophecy Egg | 1 | — | 0 | — |

### Koniec wypłat Prophecy Eggs

`gift_for_day` ma osobną regułę: dla typu PE i **dayIndex > 672** wybiera **100 000 GE**. W praktyce daje to po jednym PE dnia 28 przez pierwsze **24 cykle**; od 25. cyklu dzień 28 daje 100 000 GE. Sześć wykonań funkcji z pominiętymi wyłącznie tekstami/ikonami potwierdziło wynik przed i po granicy: dokumentacja referencyjna.

Poprzednia propozycja stałych „50 000 GE + PE dnia 28” była błędna: tabela zawiera jedną nagrodę PE, a później zastępującą ją nagrodę GE. Warstwę `collectReward`, w tym maksymalny poziom wylosowanego badania, sprawdzono później w [13](13_rewards_contracts_resets_and_gift_distributions.md).

## 4. Boosty: kompozycja, timer i aktywacja

### Sumowanie i Boost Beacon

Referencyjny `BoostManager::update`, sumuje siły wpisów tej samej kategorii. Po normalizacji pusta kategoria ma mnożnik neutralny 1. Przykłady wykonania funkcji referencyjnych:

| Zestaw | Wynik |
|---|---:|
| Jimbo 50 + Jimbo 50 | 100x dochodu |
| Jimbo 50 + Jimbo 10 | 60x dochodu |
| Jimbo 50 + Beacon 50 | 2500x dochodu |
| Jimbo 50 + Beacon 50 + Beacon 50 | 5000x dochodu |
| Tachyon 1000 + Beacon 50 | 50000x IHR |
| Soul Beacon 500 + Beacon 50 | 25000x prestige earnings |
| sam Beacon 50 | 1x dochodu/IHR/prestige earnings |

Boost Beacony sumują się między sobą, a następnie mnożą aktywną kategorię Jimbo/Tachyon/Soul Beacon. Metody `earningsMult`, `internalHatcheryMult` i `prestigeEarningsMult` stosują GDR.boostBoostMult tylko gdy własny mnożnik kategorii jest **>1**. GDR składa ten wymiar przez mnożenie wkładów providerów; dodatkowy bonus artefaktu/peta nie powinien sam aktywować pustej kategorii. Testy używają jawnego wejścia GDR, składającego wymiar managera i kontrolowany mnożnik zewnętrzny.

Soul Mirror jest oddzielną flagą mechaniki kontraktu, nie Jimbo ani Soul Beacon. Test wyżej potwierdza brak zwiększenia tych trzech kategorii przez sam Mirror; **nie testuje** końcowego przeliczenia bonusu współgracza w kontrakcie.

### Boosty gotówkowe jednorazowe

`subsidy_application`, `blank_check`, `money_printer` mają w tabeli czas 0 i współczynniki **0.1 / 1 / 5**. W `update` wystawiają odpowiednio `earningsAdditionPOFV`; SimEngine wypłaca tę wartość pomnożoną przez bieżący FV jako dochód non-EPS. Wykonanie managera potwierdziło te współczynniki i brak zwiększenia 5 przez Beacon 50. Wymaga to osobnego jednorazowego przebiegu, a nie czasowego mnożnika zwykłego dochodu. [Późniejszy test integracji](13_rewards_contracts_resets_and_gift_distributions.md) potwierdził wpływ tej gotówki na prestiż i dodatkowy akumulator w kolejnym update.

### Wygaśnięcie i wyłączenie

Manager najpierw dodaje efekt wpisu do wymiarów bieżącego kroku, następnie odejmuje `dt`. Usuwa wpis przy wyniku **<0**, nie przy `==0`. Dla pozostałego czasu 0.1 s i kroku 0.3 s efekt działa w tym kroku, a zapisany czas staje się ujemny i wpis pusty. Przy 0.3−0.3 wpis pozostaje z czasem 0 do kolejnego kroku. Nie dzielić tego kroku analitycznie na 0.1 i 0.2 bez uznania zmiany numerycznej względem klienta.

Gdy `boostsEnabled()` jest false, `update` ustawia neutralne efekty, **nie odejmuje czasu aktywnym wpisom** i nie wykonuje dalszej części księgowania tego managera. Sam `GameController::boostsEnabled`, wyłącza boosty na domowym Enlightenment i farmach Virtue; tryby innych farm mają osobną gałąź. Nie usuwać wpisów tylko dlatego, że aktualnie nie działają.

### Czas ustalany przy aktywacji

Potwierdzona funkcja aktywacji zapisuje:

```text
remainingSeconds = BOOSTS[id].durationSeconds * GDR.boostDurationMult()
inventory[id] -= 1
```

Mnożnik czasu, w tym wydarzenia i odpowiedniego wyposażenia, jest odczytywany **w momencie aktywacji**. `update` później odejmuje dt od zapisanej liczby — nie mnoży jej ponownie przez aktualny bonus czasu. 12 wykonań fragmentu aktywacji potwierdziło zapis czasu oraz odjęcie jednej sztuki; dźwięk/UI zatrzymano po tej mutacji.

### Dostępność, tokeny, limity i zakup

- `maxActiveBoosts`,: 2 przy permit_level=0, 5 dla niezerowej licencji. Fizyczna tablica 10 wpisów nie oznacza 10 miejsc dostępnych graczowi.
- `attemptActivateBoost`, wymaga załadowanego LiveConfig, zapasu przedmiotu i miejsca. W kontrakcie sprawdza tokeny i odrzuca kategorię Soul Beacon (dimension_raw=9). Soul Mirror ma osobną kontrolę obecności drugiego aktywnego Mirror, a Quantum/Dilithium Bulb osobną kontrolę wzajemnego wykluczenia. Te bramki odczytano statycznie; nie przeprowadzono wszystkich dialogów i scenariuszy wyścigu stanu.
- `coolOffTime`,: dla boostów gotówkowych zwraca `lastCashBoostTime + configuredCooloff − now`, a dla pozostałych 0. Nie zaciska wyniku do zera. Snapshot serwera podaje cooldown 30 s. Ścieżka aktywacji na home farmie ma własną kontrolę czasu.
- `onPrestige`, zeruje bazę księgowania przychodów managera. Późniejszy [audyt całego resetu kontrolera](13_rewards_contracts_resets_and_gift_distributions.md) potwierdził zachowanie aktywnych boostów i ich czasu przy zmianie jaja i prestiżu.
- Cena jednej sztuki: cena aktualnego wpisu po LiveConfig × `GDR.boostCostMult()`. Zakup pakietu w `attemptPurchaseBoost`, mnoży cenę przez **4** i dodaje **5** sztuk (20% zniżki na pakiet). Sprawdzenie stanu używa warunku `inventory > 10000` przed zakupem; nie jest ścisłym limitem końcowym 10000. To odczyt statyczny, nie pełna walidacja płatności ani filtrowania ofert legacy.

## 5. Podwajacz dochodu: wynik kolejnego etapu

[Audyt podwajacza i pięciu wpisów kalendarza](12_calendar_scaling_and_video_doubler.md) potwierdza callback: sukces zapisuje `videoEnd=nowAtCallback+3600*GDR.videoDoublerHours()`, **nadpisując** poprzedni termin. Reklamę można rozpocząć przy czasie pozostałym <7200 s. Długość z badań wynosi 2..8 h; gałąź bez reklam/ograniczeń wieku zapisuje now+3600. Ultra Pro i reklama dają razem 2× dochodu. Szczegóły, granice, powtórzenia i 120 nowych scenariuszy podwajacza są w rozdziale 12.

