# Symulacja offline i konfiguracja serwera — specyfikacja referencyjna

> **Specyfikacja referencyjna po redakcji.** Zawarte przykłady nie stanowią wykonania testów implementacji HatchTheEgg. Aktualne decyzje R rozstrzyga [CURRENT_SPEC](CURRENT_SPEC.md).

## Offline: kolejność rozliczania

1. Wrapper wylicza różnicę zegara i czasu ostatniej symulacji farmy. Ujemny czas ma osobną ścieżkę ochrony; nie jest naliczany jako dodatni dochód.
2. Dla przerwy <=60 s wybiera tryb online; powyżej 60 s wybiera away i fast-forward biegających kur. Kontrakty mogą dodatkowo ograniczyć przedział czasem zakończenia kontraktu.
3. W away ogranicza czas produkcji przez `liczba posiadanych silosów * GDR.siloSeconds()`. Pełny czas nieobecności pozostaje oddzielnym argumentem. Dla zera silosów i długiej nieobecności wywołuje kernel z czasem produkcji zero.
4. Kernel wykonuje `dt=min(remaining,0.3)` aż zużyje limit. Aktualizuje BoostManager, ArtifactsManager, LiveEventManager i buffy kontraktu. Nie dzieli automatycznie każdego kroku dokładnie na chwilę wygaśnięcia każdego bonusu.
5. Odczytuje aktualne tempo znoszenia, wartość jaja, bonus biegających kur, przepustowość i mnożniki. W away stosuje `siloQuality * earningsMultAway`; `siloQuality=0.5` bez Pro i `1` z Pro.
6. Liczy jaja z populacji na początku kroku. Przed sprzedażą obsługuje forge/paliwo/tank; resztę ogranicza transportem. Dochód obejmuje wartość sprzedanych jaj, mnożniki dochodu, RCB, away i stan podwajacza w danym kroku.
7. Odnawia ręczną wylęgarnię w odpowiednim stanie i dopiero potem aktualizuje IHR poszczególnych kurników. Nowe kury wpływają więc na produkcję następnego kroku.
8. Po rozliczeniu away aktualizuje czas farmy do bieżącego zegara. Nie można ponownie naliczyć niewykorzystanej części tej samej nieobecności po wyczerpaniu silosów.

### IHR i ułamki populacji

`GDR.internalHatcheryRate(away)` zwraca tempo na sekundę: baza/min * mnożnik /60, bonus auto-play, Calm tylko w away oraz modyfikator Eggs of Truth. W implementacji Roblox zastąpione systemy bonusów wymagają jawnej mapy wymiarów petów.

Każdy z czterech slotów ma własny ułamkowy akumulator. Kernel dodaje `rate*dt`, konwertuje część całkowitą do uint64, ogranicza ją wolnym miejscem i odejmuje faktycznie dodane kury z akumulatora. Uwzględnia także kury przypisane do kurnika, które jeszcze do niego biegną.

Przy pełnym slocie i sharing>0 wybiera `selectHabByVacancy()` i przekazuje tempo tego slotu pomnożone przez sharing do wybranego kurnika, z ograniczeniem jego miejsca. Nie dzieli każdej nadwyżki równo między wszystkie kurniki. Bez sharing/bez celu czyści akumulator pełnego slotu. Kolejność slotów i zaokrągleń ma znaczenie.

### Boosty i podwajacz

W zapisie farmy aktywny boost zawiera indeks i pozostały czas. `BoostManager::update(dt)` buduje efekty aktywnego wpisu, odejmuje `dt` i oznacza wpis jako pusty przy wyniku **<0**; zero nie spełnia tego warunku. Efekt tego wpisu został już dodany do wymiarów bieżącego kroku. Są też boosty jednorazowe i osobne reguły kontraktów/wyłączenia boostów.

Zegar aktywnych boostów jest aktualizowany przez czas faktycznie symulowany. W zwykłej ścieżce away po wyczerpaniu silosów nie następuje dodatkowe odjęcie całej pozostałej nieobecności od tych rekordów. Model wyłącznie `ExpiresAt = UnixNow + Duration` zmienia tę logikę. Termin podwajacza wideo jest natomiast sprawdzany względem czasu kroku; nie należy scalać obu zegarów.

Nie usuwać wygasłych boostów przed odtworzeniem ich skutku historycznego. Dla zgodności numerycznej zachować double i kroki 0.3 s; model analityczny wymaga własnych porównań z modelem referencyjnym, zwłaszcza przy ułamkach, limicie kurników i granicach bonusów.

### Przykłady referencyjne offline

Przykłady referencyjne obejmują tryby online/away, wzrost, zapełnienie kurnika, ograniczenie transportu i wygaśnięcie podwajacza. Wejścia: 100 kur, 1/30 jaja/kura/s, jajo 0.25, away income 0.5, Calm=3.

| Przypadek | Wynik modelu referencyjnego |
|---|---|
| 1 s away, IHR=1/s online | 102 kury, ułamek 0.9999999999999997, cash 0.41875 |
| 1 s online, IHR=1/s | 100 kur, ułamek 0.9999999999999999, cash 0.8333333333333333 |
| 1 s away, pojemność 102 | 102 kury, cash 0.4225 |
| 1 s away, transport 60 jaj/min | cash 0.125 |
| 1 s away, podwajacz kończy się po 0.5 s | cash 0.54375 |

Nie zaokrąglać ułamka do pełnej kury „dla poprawności”: to zmieni wynik modelu referencyjnego. Dodatkowe 6 wykonań wrappera potwierdziło próg 60 s, limit silosów i osobne przekazywanie pełnej nieobecności: dokumentacja referencyjna.

Te testy zastępują managerów/bonusy kontrolowanymi wartościami. Nie potwierdzają pełnej integracji wszystkich rodzajów boostów, petów, kontraktów i zapisów.

### Co może zmieniać serwer

- `BoostsConfig`: cena GE, tokeny kontraktowe, wymagane SE dla identyfikatora boostu; cooldown boostów gotówkowych.
- `GiftConfig`: ilości i progi losowania prezentów, harmonogram paczek/wideo, flagi resetu przy idle, progi wydatków/mnożniki prezentów. Stare pola `gift_mu_*` są czytane także przez kod nagród dronów.
- `MiscConfig`: m.in. procent chicken run, próg ligi kontraktów, długość eventu nowego gracza i dostępność funkcji.
- `get_periodicals`: osobna odpowiedź zawierająca m.in. wydarzenia, sprzedaże, kontrakty, prezenty i kolejne `LiveConfig`.

Nie znaleziono w tym schemacie `LiveConfig` pól zmieniających wzory Farm Value, progi wykładników prestiżu czy cenę stacji Hyperloop. Nadpisywanie oferty boostów nie oznacza nadpisania ich siły/czasu — te pochodzą z tabeli konfiguracji referencyjnej i odpowiednich wymiarów.

`onLiveConfig` aktualizuje BoostManager i EventManager tylko, gdy odpowiednia sekcja występuje. Parametry odstępów paczek/wideo EventManager ogranicza od dołu do 100 s. **Doprecyzowanie z rozdziału 16:** po przekazaniu obecnej sekcji GiftConfig funkcja EventManager odczytuje wszystkie osiem odstępów oraz flagi resetu, bez osobnego has-field dla każdego z nich. Brak pola odstępu daje domyślne zero konfiguracji i po clampie 100 s, a nie poprzednią wartość. Brak całej sekcji jest odrębnym przypadkiem. Nie uogólniać zasad obecności między różnymi sekcjami.

### Odczytane parametry

| Parametr | Wartość |
|---|---:|
| cash_boost_cooloff_time | 30 s |
| package_interval / contract / piggy_full / piggy_extra_full | 250 / 290 / 330 / 400 s |
| video_offer_interval / contract / piggy_full / piggy_extra_full | 300 / 330 / 360 / 360 s |
| package_reset_on_idle / video_reset_on_idle | false / false |
| gift_mu_min_spent / max_spent / overall_mult | 5000 / 300000 / 1 |
| chicken_run_boost_percentage | 0.05 |
| contracts_expert_league_min_soul_power | 11 |
| new_player_event_duration | 86400 s |

W tym snapshotcie nowe `random_gift_mu_config` i `video_gift_mu_config` nie występują. Nie wolno traktować surowych `randMin/randMax` jako niezależnych końcowych prawdopodobieństw: wymagają logiki wyboru prezentów, progresji, filtrowania i normalizacji. Tabela wag znajduje się w snapshotcie. Na tym etapie nie przeprowadzono testu dystrybucji; późniejsze wykonania samplera i filtrów opisuje [13](13_rewards_contracts_resets_and_gift_distributions.md), a harmonogram [16](16_pet_stacking_offline_and_package_schedule.md).

### Oferta boostów zwrócona przez serwer

Tabela pokazuje zwrócone wpisy, również legacy — obecność w odpowiedzi nie dowodzi widoczności w aktualnym UI. Ceny bazowe konfiguracji referencyjnej, zniżki, wyprzedaże i koszt zakupów pakietowych są odrębnymi warstwami.

| boost_id | Cena GE | Tokeny | Wymagane SE |
|---|---:|---:|---:|
| jimbos_blue_v2 | 50 | 0 | 0 |
| jimbos_purple_v2 | 150 | 1 | 0 |
| jimbos_purple_big | 750 | 1 | 1 |
| jimbos_orange | 2500 | 2 | 100 |
| jimbos_orange_big | 7500 | 3 | 100 |
| subsidy_application | 200 | 1 | 0 |
| blank_check | 750 | 1 | 100000 |
| money_printer | 2500 | 2 | 5000000 |
| tachyon_prism_blue_v2 | 50 | 0 | 0 |
| tachyon_prism_blue_big | 500 | 0 | 0 |
| tachyon_prism_purple_v2 | 1000 | 2 | 0 |
| tachyon_prism_purple_big | 5000 | 2 | 100 |
| tachyon_prism_orange | 12000 | 4 | 2500 |
| tachyon_prism_orange_big | 25000 | 4 | 100000 |
| soul_beacon_blue_v2 | 200 | 0 | 10000 |
| soul_beacon_purple_v2 | 1000 | 0 | 1000000 |
| soul_beacon_orange | 10000 | 0 | 10000000000 |
| boost_beacon_blue | 1000 | 1 | 1000 |
| boost_beacon_purple | 8000 | 4 | 100000 |
| boost_beacon_blue_big | 15000 | 3 | 500000 |
| boost_beacon_orange | 50000 | 8 | 100000000 |
| soul_mirror_blue | 100 | 1 | 1000 |
| soul_mirror_purple | 500 | 2 | 1000 |
| soul_mirror_orange | 2000 | 3 | 10000 |
| quantum_bulb | 10 | 0 | 0 |
| dilithium_bulb | 1000 | 0 | 100000 |
| jimbos_blue | 50 | 1 | 0 |
| jimbos_blue_big | 100 | 1 | 0 |
| jimbos_purple | 250 | 2 | 0 |
| tachyon_prism_blue | 200 | 1 | 0 |
| tachyon_prism_purple | 1000 | 3 | 0 |
| soul_beacon_blue | 200 | 0 | 10000 |
| soul_beacon_purple | 1000 | 0 | 1000000 |

## Model danych dla HatchTheEgg

Zachować osobno: czas ostatniej symulacji farmy, rzeczywiście posiadane silosy, jakość silosów/pozwolenie, populacje czterech kurników i ich ułamki, przypisane biegające kury, typ każdego pojazdu i długość każdego pociągu, pozostały czas każdego boostu, termin podwajacza, sumę wydanych GE oraz snapshot konfiguracji i warunki aktywnych wydarzeń.

Serwer Roblox powinien rozliczać stan i nagrody. Klient nie podaje FV, kwoty drona ani dowolnego czasu nieobecności. Trwały zapis powinien pozwalać odtworzyć przebieg czasu bez dwukrotnej wypłaty po ponownym wejściu.


## Dane referencyjne w projekcie

Przywrócone parametry silosów i precyzyjny wyjątek dronów: [drone_and_silo_rules.json](reference_data/drone_and_silo_rules.json); opis silosów w [06](06_drones_silos_and_events.md).
