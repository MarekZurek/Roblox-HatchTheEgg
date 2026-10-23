# Drony, silosy i zdarzenia

> **Status N/S:** specyfikacja i dane referencyjne, nie testy implementacji. Zatwierdzone zasady aktywacji podwajacza i prezentów rozstrzyga D04 w [22](22_gameplay_rules_for_approval.md). [Statusy](CURRENT_SPEC.md).

Dokument opisuje referencyjne reguły dronów, silosów i wydarzeń. Symulację offline opisuje [10](10_verified_simulation_and_server_config.md). Nie jest to raport testów kodu HatchTheEgg.

## Drony: częstość i typ

`EventManager::update` ustala czas do następnego drona jako mieszaninę dwóch rozkładów jednostajnych: z prawdopodobieństwem 25% **2–8 s**, z prawdopodobieństwem 75% **12–47 s**. Wynik dzieli przez `GDR.droneFrequencyMult()`; Virtue dodatkowo mnoży go przez 1.5. Średnia bazowa to 23.375 s. Po inicjalizacji/braku prawidłowego timera kod ustawia termin za 10 s. Spawn jest uzależniony od `dronesEnabled`.

W `spawnDrone` bazowe prawdopodobieństwo elitarnego drona wynosi **8%**. Dla gracza z zerową liczbą prestiżów i najwyższym osiągniętym indeksem jaja `maxEggReached <= 4` wynosi **0.005 * maxEggReached**. To wewnętrzny indeks od 0; nie jest nim numer konfiguracji od 1 ani koniecznie aktualne jajo. Identyfikację pola potwierdzają `EggData::isUnlocked` i aktualizacja maksimum w `resetHomeFarm`. Ta ścieżka została odczytana statycznie; nie testowano całej animacji lotu.

## Losowanie rodzaju nagrody

```text
jeśli GDR.droneGoldGuaranteed(): GE
w przeciwnym razie jeśli GDR.droneCashGuaranteed(): gotówka
w przeciwnym razie:
    GE, jeśli u1 * droneCashChanceMult / droneGoldChanceMult <= 0.3
    gotówka w pozostałych przypadkach
```

Bez modyfikatorów: 30% GE / 70% gotówki. Bonus szansy na GE zmienia próg ilorazem; nie normalizuje się go jako wagi `gold/(gold+cash)`. Gwarancja GE ma pierwszeństwo przed gwarancją gotówki.

## Losowanie wysokości GE

`q = GDR.droneRewardQualityMult()`. Epic **Drone Rewards** daje `1 + 0.1 * level`, maksymalnie 3 przy 20 poziomach. Kolejność warunków jest istotna:

```text
jeśli q > 1.5 i u2 < 0.01: baseGE = 24
w przeciwnym razie jeśli u2 < 0.1*q: baseGE = 12
w przeciwnym razie jeśli u2 < 0.7*q: baseGE = 6
w przeciwnym razie: baseGE = 3
```

| Jakość q | 3 GE | 6 GE | 12 GE | 24 GE |
|---:|---:|---:|---:|---:|
| 1 | 30% | 60% | 10% | 0% |
| 1.5 | 0% | 85% | 15% | 0% |
| 2 | 0% | 80% | 19% | 1% |
| 3 | 0% | 70% | 29% | 1% |

To prawdopodobieństwa warunkowe po wylosowaniu GE, przed modyfikatorem wydatków. Elitarny dron zamienia bazową nagrodę na `max(48, 8*baseGE)`, czyli 48, 96 lub 192 GE.

### Wydane GE i konfiguracja serwera

```text
progress = float32(overallMult * clamp((totalGESpent-minSpent)/(maxSpent-minSpent), 0, 1))
jeśli progress >= 0.5*overallMult:
    regularGE = max(24, 2*baseGE)
    eliteGE = 2*max(48, 8*baseGE)
```

Przy pobranej konfiguracji `minSpent=5000`, `maxSpent=300000`, `overallMult=1`, próg wynosi **152 500 wydanych GE**. Liczy się licznik wydatków, nie saldo GE. Dlatego również zwykły dron może otrzymać podwyższoną minimalną nagrodę 24 GE. Wynik mnoży się przez `GDR.droneRewardMult()` i przy zapisie do licznika GE konwertuje do liczby całkowitej.

## Nagroda gotówkowa

Po wylosowaniu gotówki kolejny próg wybiera współczynnik `b`:

```text
b = 0.5,  jeśli u2 < 0.03*q
b = 0.1,  jeśli u2 < 0.1*q
b = 0.02, w pozostałych przypadkach

regularCash = FV * b / 50 * struggleModifier
eliteCash   = FV * 10 / 50 * min(struggleModifier, 10)
cash        = wybranaKwota * droneRewardMult * sqrt(onscreenChickenMultiplier)
```

Dla `q=1`, gotówka zwykłego drona ma progi 3% / 7% / 90%. Elitarna gotówka nadpisuje wylosowany przedział: wysokość jest taka sama dla wszystkich trzech gałęzi przy pozostałych identycznych wejściach. `Drone Rewards` zwiększa jakość, a `droneRewardMult` jest osobnym mnożnikiem wysokości.

`struggleModifier` zależy od `100 * FV / PriceCurve.normal.farmValue(population)`:

| Przedział procentowy | Mnożnik |
|---|---:|
| <3 | 30 |
| [3,15) | 15 |
| [15,30) | 8 |
| [30,100) | 5 |
| [100,200) | 2 |
| [200,1000) | 1 |
| [1000,50000) | 0.75 |
| [50000,1000000) | 0.5 |
| >=1000000 | 0.25 |

Dolne granice są włączone, górne wyłączone. Wyjątek: populacja <=100 daje `double(float32(0.1))`, czyli około `0.10000000149011612`. Wariant alternatywny poza zakresem v1 używa `0.1` w double. Nie zaokrąglać tych dwóch reprezentacji do wspólnego wyniku w testach dokładności. Wyjątki rozstrzyga się przed tabelą przedziałów.

Pełna tabela maszynowa: [drony i silosy](reference_data/drone_and_silo_rules.json). Punkty krzywej używanej w mianowniku: [price_curves.json](reference_data/price_curves.json), krzywa 0.

## Silosy i offline

Bez dodatkowych modyfikatorów:

```text
secondsPerSilo = 3600 + 360 * levelSiloCapacity
productionTimeLimit = silosOwned * secondsPerSilo
```

Przy poziomie badania 20 jest to 3 h na silos; arytmetyczny przykład 10 posiadanych silosów daje 30 h. Przykład nie zatwierdza liczby miejsc Pro. Liczba dostępnych miejsc i liczba posiadanych silosów to osobne dane.

Nieobecność **powyżej 60 s** wybiera away; krótsza lub równa 60 s wybiera online. W away:

- produkcja jest ograniczona czasem posiadanych silosów;
- dochód wynosi **50% bez Pro, 100% z Pro**, z osobnym `earningsMultAway`;
- IHR uwzględnia Calm tylko w away, pojemność i sharing;
- czas aktywnych boostów zużywa symulacja; absolutny termin podwajacza jest odrębnym zegarem;
- po wyczerpaniu silosów nie nalicza się dalszej produkcji za ten sam okres nieobecności.

Kolejność produkcji, wzrost populacji i ułamkowe akumulatory: [10](10_verified_simulation_and_server_config.md). Nie zastępować algorytmu iloczynem bieżącego dochodu i czasu.

## Paczki i wydarzenia

Referencyjne interwały wejściowe zwykłej paczki wynoszą 250 s, przy pełnej śwince 330 s, a po dodatkowym progu 400 s. Nie są gwarancją paczki dokładnie co taki czas. [Katalog i parametry nagród](reference_data/rewards.json) oraz [harmonogram](16_pet_stacking_offline_and_package_schedule.md) opisują osobno zawartość, próby i warunki dostępności. Kalendarz: [11](11_periodicals_calendar_events_and_boost_rules.md) i [15](15_calendar_gameplay_formula_and_roblox_scope.md).

## Podwajacz dochodu i adaptacja Roblox

Bazowy wymiar `videoDoublerHours` wynosi 2 h. Epic Video Doubler Time dodaje 0.5 h/poziom, maksymalnie 8 h przy poziomie 12. To wymiar długości bonusu; aktywacja ma różne gałęzie. Odczytano także gałąź bez reklam z terminem now+3600. Regułę callbacku i odświeżania czasu potwierdzono w [rozdziale 12](12_calendar_scaling_and_video_doubler.md): termin jest nadpisywany, a reklama i Ultra Pro dają razem 2× dochodu. Dawne 8 h bazowo i +1 h/poziom były błędne.

Darmowa aktywacja, opłata GE lub stacja zasilania to decyzje projektu Roblox. Nie wynikają z badanego silnika. Dotyczy to także serwerowego generowania dronów, jednorazowych `DroneInstanceId`, walidacji czasu i wypłat po stronie serwera. Te zabezpieczenia należy zachować, a ich konkretne limity traktować jako konfigurację HatchTheEgg.

Końcowe rozkłady paczek/reklam, kwoty, konkretne boosty, Piggy i PRNG sprawdzono w [rozdziale 13](13_rewards_contracts_resets_and_gift_distributions.md). [Rozdział 16](16_pet_stacking_offline_and_package_schedule.md) dodaje referencyjny audyt harmonogramu: opóźnienie `I×(0.6+0.5×U)`, kwalifikację, progi utraconych przyrostów Piggy, idle, ponowienia i warunki zgłoszenia ciężarówek. Określa też stacking petów oraz własny bonus Drone Hawka do szansy elity. Rzeczywista odpowiedź konta nadal pozostaje niedostępna.
