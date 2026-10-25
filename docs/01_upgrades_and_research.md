# Badania — dane źródłowe i zasady

**Status: S/N — dane konfiguracji referencyjnej i wykonane odczyty ResearchEngine.** Źródło: dokumentacja referencyjna. Znaczenie statusów: [bieżąca specyfikacja](CURRENT_SPEC.md). Dane dotyczą konfiguracji referencyjnej, nie listy automatycznie zatwierdzonej dla Roblox.

## 1. Reguły i granice

Common kosztują gotówkę i resetują się przy zmianie jaja/prestiżu; Epic kosztują GE i zachowują poziomy. W konfiguracji referencyjnej rozpoznano **56 Common w 13 tierach oraz 24 Epic** (80 identyfikatorów). Liczba wpisów nie dowodzi ich dostępności w każdym trybie/UI.

Nie stosować jednego wzoru `1+level×bonus` do wszystkich badań: część efektów jest addytywna, inne mają charakter wykładniczy lub dotyczą odrębnych kategorii. Przykład: Even Bigger Eggs daje ×2 na poziomie 1 i ×32 na poziomie 5, a nie ×6. Dla mnożnikowych wymiarów niezależne badania składają się zgodnie z właściwym agregatorem; bazy, dodatki, bramki i efekty portalowe/Hyperloop mają osobne znaczenie.

Tabele poniżej podają **zaobserwowane efekty na poziomie 1 i maksymalnym**. Nie wyprowadzają pełnej krzywej poziomów z dwóch punktów. `{}` oznacza brak zmiany wymiarów w użytym odczycie, nie dowód braku działania badania. Źródłowy JSON zachowuje parametry, wszystkie ceny i próbki efektów; wartości w Markdown są skrócone.

Tier raw w danych jest od zera, w nagłówkach od 1. Ceny Common to pierwszy i ostatni zakup poziomu, nie ich suma. Koszt Epic to suma cen zapisanych w tabeli, przed zdarzeniami i modyfikatorami. Kosztów konfiguracji referencyjnej nie mylić z ofertą LiveConfig.

Piggy ma własne ścieżki wzrostu, limity i modyfikatory; nie traktować dawnego skrótu „każdy poziom zawsze +1 GE” jako pełnego modelu. [13](13_rewards_contracts_resets_and_gift_distributions.md) opisuje konwersje nagród i bonusy Piggy, [16](16_pet_stacking_offline_and_package_schedule.md) licznik utraconych przyrostów.

## 2. Common Research

### Tier 1

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `comfy_nests` | COMFORTABLE NESTS | 50 | `{"eggLayingRateMult":1.1}` → `{"eggLayingRateMult":6.0}` | 0.5026054677 | 1534724.598 |
| `nutritional_sup` | NUTRITIONAL SUPPLEMENTS | 40 | `{"eggValueMult":1.25}` → `{"eggValueMult":11.0}` | 2.154023433 | 17917171.82 |
| `better_incubators` | BETTER INCUBATORS | 15 | `{"hatcheryRefillRateMult":1.1}` → `{"hatcheryRefillRateMult":2.5}` | 18.30607417 | 9542.875098 |
| `excitable_chickens` | EXCITABLE CHICKENS | 25 | `{"onscreenChickenMult":1.001}` → `{"onscreenChickenMult":1.025}` | 1.060570397 | 3.462596627e+11 |

### Tier 2

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `hab_capacity1` | HEN HOUSE REMODEL | 8 | `{"habCapacityMult":1.05}` → `{"habCapacityMult":1.4}` | 550.8484866 | 67995.98662 |
| `internal_hatchery1` | INTERNAL HATCHERIES | 10 | `{"internalHatcheryRate":2.0}` → `{"internalHatcheryRate":20.0}` | 1836.161622 | 266696824.9 |
| `padded_packaging` | PADDED PACKAGING | 30 | `{"eggValueMult":1.25}` → `{"eggValueMult":8.5}` | 454986.3022 | 1.024496873e+10 |
| `hatchery_expansion` | HATCHERY EXPANSION | 10 | `{"hatcheryCapacity":10.0}` → `{"hatcheryCapacity":100.0}` | 73.22429667 | 47779124.85 |
| `bigger_eggs` | BIGGER EGGS | 1 | `{"eggValueMult":2.0}` → `{"eggValueMult":2.0}` | 1351894.897 | 1351894.897 |

### Tier 3

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `internal_hatchery2` | INTERNAL HATCHERY UPGRADES | 10 | `{"internalHatcheryRate":5.0}` → `{"internalHatcheryRate":50.0}` | 16029661.9 | 7.00260273e+13 |
| `leafsprings` | IMPROVED LEAFSPRINGS | 30 | `{"vehicleCapacityMult":1.05}` → `{"vehicleCapacityMult":2.5}` | 3205932.38 | 1.996580955e+12 |
| `vehicle_reliablity` | VEHICLE RELIABLITY | 2 | `{"maxFleetSize":1}` → `{"maxFleetSize":2}` | 324181356.5 | 2.64555742e+13 |
| `rooster_booster` | ROOSTER BOOSTER | 25 | `{"hatcheryRefillRateMult":1.05}` → `{"hatcheryRefillRateMult":2.25}` | 4007415.474 | 1.222542459e+14 |
| `coordinated_clucking` | COORDINATED CLUCKING | 50 | `{"onscreenChickenMultMax":0.2}` → `{"onscreenChickenMultMax":10.0}` | 568732.8778 | 1.984168065e+13 |

### Tier 4

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `hatchery_rebuild1` | HATCHERY REBUILD | 1 | `{"hatcheryCapacity":50.0}` → `{"hatcheryCapacity":50.0}` | 1.869123569e+11 | 1.869123569e+11 |
| `usde_prime` | USDE PRIME CERTIFICATION | 1 | `{"eggValueMult":3.0}` → `{"eggValueMult":3.0}` | 3.231756852e+13 | 3.231756852e+13 |
| `hen_house_ac` | HEN HOUSE A/C | 50 | `{"eggLayingRateMult":1.05}` → `{"eggLayingRateMult":3.5}` | 2986195.303 | 7.523435685e+12 |
| `superfeed` | SUPER-FEEDâ„˘ DIET | 35 | `{"eggValueMult":1.25}` → `{"eggValueMult":9.75}` | 530550491.6 | 4.236574652e+13 |
| `microlux` | MICROLUXâ„˘ CHICKEN SUITES | 10 | `{"habCapacityMult":1.05}` → `{"habCapacityMult":1.5}` | 682997915.2 | 2.801041092e+12 |

### Tier 5

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `compact_incubators` | COMPACT INCUBATORS | 10 | `{"hatcheryCapacity":10.0}` → `{"hatcheryCapacity":100.0}` | 2365257046 | 3.824142983e+16 |
| `lightweight_boxes` | LIGHTWEIGHT BOXES | 40 | `{"vehicleCapacityMult":1.1}` → `{"vehicleCapacityMult":5.0}` | 6.925193254e+11 | 3.368721248e+17 |
| `excoskeletons` | DEPOT WORKER EXOSKELETONS | 2 | `{"maxFleetSize":1,"vehicleRoundTripTimeMult":1.1,"vehicleLoadingTimeMult":0.9}` → `{"maxFleetSize":2,"vehicleRoundTripTimeMult":1.2,"vehicleLoadingTimeMult":0.8}` | 8.681221363e+11 | 6.93226852e+17 |
| `internal_hatchery3` | INTERNAL HATCHERY EXPANSION | 15 | `{"internalHatcheryRate":10.0}` → `{"internalHatcheryRate":150.0}` | 2.885497189e+12 | 2.273292165e+18 |
| `improved_genetics` | IMPROVED GENETICS | 30 | `{"eggValueMult":1.15,"eggLayingRateMult":1.15}` → `{"eggValueMult":5.5,"eggLayingRateMult":5.5}` | 7.48717858e+12 | 3.209212608e+17 |

### Tier 6

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `traffic_management` | TRAFFIC MANAGEMENT | 2 | `{"maxFleetSize":1,"vehicleRoundTripTimeMult":1.1}` → `{"maxFleetSize":2,"vehicleRoundTripTimeMult":1.2}` | 5.375755439e+15 | 1.344321893e+20 |
| `motivational_clucking` | MOTIVATIONAL CLUCKING | 50 | `{"onscreenChickenMultMax":0.5}` → `{"onscreenChickenMultMax":25.0}` | 1.497174432e+11 | 7.020276947e+25 |
| `driver_training` | DRIVER TRAINING | 30 | `{"vehicleCapacityMult":1.05,"vehicleSpeedMult":1.012}` → `{"vehicleCapacityMult":2.5,"vehicleSpeedMult":1.3599999999999999}` | 1.147242895e+16 | 4.593803535e+20 |
| `shell_fortification` | SHELL FORTIFICATION | 60 | `{"eggValueMult":1.15}` → `{"eggValueMult":10.0}` | 1.47372768e+16 | 2.753186708e+22 |

### Tier 7

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `egg_loading_bots` | EGG LOADING BOTS | 2 | `{"maxFleetSize":1,"vehicleLoadingTimeMult":0.92}` → `{"maxFleetSize":2,"vehicleLoadingTimeMult":0.84}` | 3.878982169e+21 | 9.042635667e+25 |
| `super_alloy` | SUPER ALLOY FRAMES | 50 | `{"vehicleCapacityMult":1.05}` → `{"vehicleCapacityMult":3.5}` | 1.449311842e+20 | 6.028423778e+25 |
| `even_bigger_eggs` | EVEN BIGGER EGGS | 5 | `{"eggValueMult":2.0}` → `{"eggValueMult":32.0}` | 2.860882737e+19 | 1.67886596e+30 |
| `internal_hatchery4` | INTERNAL HATCHERY EXPANSION | 30 | `{"internalHatcheryRate":25.0}` → `{"internalHatcheryRate":750.0}` | 3.300939454e+17 | 1.24466085e+27 |

### Tier 8

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `quantum_storage` | QUANTUM EGG STORAGE | 20 | `{"vehicleCapacityMult":1.05}` → `{"vehicleCapacityMult":2.0}` | 5.08999561e+23 | 5.504673431e+33 |
| `genetic_purification` | GENETIC PURIFICATION | 100 | `{"eggValueMult":1.1}` → `{"eggValueMult":11.0}` | 1.120268245e+20 | 1.13021986e+35 |
| `internal_hatchery5` | MACHINE LEARNING INCUBATORS | 250 | `{"internalHatcheryRate":5.0}` → `{"internalHatcheryRate":1250.0}` | 1.451706835e+23 | 1.684753415e+34 |
| `time_compress` | TIME COMPRESSION | 20 | `{"eggLayingRateMult":1.1}` → `{"eggLayingRateMult":3.0}` | 3.447618046e+22 | 3.944613915e+32 |

### Tier 9

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `hover_upgrades` | HOVER UPGRADES | 25 | `{"vehicleCapacityMultHover":1.05}` → `{"vehicleCapacityMultHover":2.25}` | 1.224071076e+27 | 1.46705938e+37 |
| `graviton_coating` | GRAVITON COATING | 7 | `{"eggValueMult":2.0}` → `{"eggValueMult":128.0}` | 7.831673245e+28 | 3.391754598e+43 |
| `grav_plating` | GRAV PLATING | 25 | `{"habCapacityMult":1.02}` → `{"habCapacityMult":1.5}` | 2.45384748e+31 | 6.581045869e+36 |
| `chrystal_shells` | CRYSTALLINE SHELLING | 100 | `{"eggValueMult":1.25}` → `{"eggValueMult":26.0}` | 2.460605351e+29 | 1.641400628e+40 |

### Tier 10

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `autonomous_vehicles` | AUTONOMOUS VEHICLES | 5 | `{"maxFleetSize":1}` → `{"maxFleetSize":5}` | 5.139038655e+32 | 5.948250996e+40 |
| `neural_linking` | NEURAL LINKING | 30 | `{"internalHatcheryRate":50.0}` → `{"internalHatcheryRate":1500.0}` | 7.020276947e+26 | 6.934412421e+54 |
| `telepathic_will` | TELEPATHIC WILL | 50 | `{"eggValueMult":1.25}` → `{"eggValueMult":13.5}` | 4.222082191e+36 | 9.121992286e+45 |
| `enlightened_chickens` | ENLIGHTENED CHICKENS | 150 | `{"onscreenChickenMultMax":2.0}` → `{"onscreenChickenMultMax":300.0}` | 1.094267085e+40 | 4.217156458e+62 |

### Tier 11

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `dark_containment` | DARK CONTAINMENT | 25 | `{"vehicleCapacityMult":1.05}` → `{"vehicleCapacityMult":2.25}` | 3.948627521e+36 | 1.020000294e+54 |
| `atomic_purification` | ATOMIC PURIFICATION | 50 | `{"eggValueMult":1.1}` → `{"eggValueMult":6.0}` | 4.338361629e+44 | 5.965201428e+58 |
| `multi_layering` | MULTIVERSAL LAYERING | 3 | `{"eggValueMult":10.0}` → `{"eggValueMult":1000.0}` | 2.239194053e+50 | 3.514297048e+63 |
| `timeline_diversion` | TIMELINE DIVERSION | 50 | `{"eggLayingRateMult":1.02}` → `{"eggLayingRateMult":2.0}` | 2.359538628e+43 | 1.361763745e+57 |

### Tier 12

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `wormhole_dampening` | WORMHOLE DAMPENING | 25 | `{"portalCapacityMult":1.02}` → `{"portalCapacityMult":1.5}` | 9.398726633e+48 | 4.011299842e+61 |
| `eggsistor` | EGGSISTOR MINIATURIZATION | 100 | `{"eggValueMult":1.05}` → `{"eggValueMult":6.0}` | 1.791355242e+49 | 2.463098592e+63 |
| `micro_coupling` | GRAVITON COUPLING | 5 | `{"hyperloopMaxTrainLength":1}` → `{"hyperloopMaxTrainLength":5}` | 3.961575519e+43 | 1.890551307e+65 |
| `neural_net_refine` | NEURAL NET REFINEMENT | 25 | `{"vehicleCapacityMult":1.05,"vehicleSpeedMult":1.012}` → `{"vehicleCapacityMult":2.25,"vehicleSpeedMult":1.3}` | 2.603016977e+44 | 4.401146338e+63 |

### Tier 13

| ID | Nazwa | Max | Efekt lvl 1 → max | Pierwsza cena | Ostatnia cena |
|---|---|---:|---|---:|---:|
| `matter_reconfig` | MATTER RECONFIGURATION | 500 | `{"eggValueMult":1.01}` → `{"eggValueMult":6.0}` | 1.583019748e+52 | 2.176639017e+66 |
| `timeline_splicing` | TIMELINE SPLICING | 1 | `{"eggValueMult":10.0}` → `{"eggValueMult":10.0}` | 1.656310707e+67 | 1.656310707e+67 |
| `hyper_portalling` | HYPER PORTALLING | 25 | `{"hyperloopCarCapacityMult":1.05}` → `{"hyperloopCarCapacityMult":2.25}` | 7.829012184e+56 | 2.085644866e+66 |
| `relativity_optimization` | RELATIVITY OPTIMIZATION | 10 | `{"eggLayingRateMult":1.1}` → `{"eggLayingRateMult":2.0}` | 1.447390677e+55 | 1.41791348e+65 |

Graviton Coupling (`micro_coupling`) zwiększa długość pociągu Hyperloop, nie liczbę miejsc floty. Wymiary transportowe stosować do odpowiednich typów pojazdów, według [04](04_vehicles_and_shipping.md).

## 3. Epic Research

| ID | Nazwa | Max | Efekt lvl 1 → max | Suma cen GE |
|---|---|---:|---|---:|
| `hold_to_hatch` | HOLD TO HATCH | 15 | `{"holdToHatchRate":2.0}` → `{"holdToHatchRate":30.0}` | 3825 |
| `epic_hatchery` | EPIC HATCHERY | 20 | `{"hatcheryRefillRateMult":1.1}` → `{"hatcheryRefillRateMult":3.0}` | 10011 |
| `epic_internal_incubators` | EPIC INT. HATCHERIES | 20 | `{}` → `{}` | 100491 |
| `video_doubler_time` | VIDEO DOUBLER TIME | 12 | `{"videoDoublerHours":0.5}` → `{"videoDoublerHours":6.0}` | 30595 |
| `epic_clucking` | EPIC CLUCKING | 20 | `{"onscreenChickenMult":1.001}` → `{"onscreenChickenMult":1.02}` | 100991 |
| `epic_multiplier` | EPIC MULTIPLIER | 100 | `{"onscreenChickenMultMax":2.0}` → `{"onscreenChickenMultMax":200.0}` | 502451 |
| `cheaper_contractors` | CHEAPER CONTRACTORS | 10 | `{"habCostMult":0.95}` → `{"habCostMult":0.5}` | 20246 |
| `bust_unions` | BUST UNIONS | 10 | `{"vehicleCostMult":0.95}` → `{"vehicleCostMult":0.5}` | 20246 |
| `cheaper_research` | LAB UPGRADE | 10 | `{"researchCostMult":0.95}` → `{"researchCostMult":0.5}` | 40496 |
| `epic_silo_quality` | SILO QUALITY | 40 | `{}` → `{}` | 5081 |
| `silo_capacity` | SILO CAPACITY | 20 | `{"siloSeconds":360.0}` → `{"siloSeconds":7200.0}` | 20050 |
| `int_hatch_sharing` | INTERNAL HATCHERY SHARING | 10 | `{"internalHatcherySharing":0.1}` → `{"internalHatcherySharing":1.0}` | 12997 |
| `int_hatch_calm` | INTERNAL HATCHERY CALM | 20 | `{"internalHatcheryMultAway":1.1}` → `{"internalHatcheryMultAway":3.0}` | 102491 |
| `accounting_tricks` | ACCOUNTING TRICKS | 20 | `{"valuationMult":1.05}` → `{"valuationMult":2.0}` | 100991 |
| `hold_to_research` | HOLD TO RESEARCH | 20 | `{"holdToResearchMult":1.25}` → `{"holdToResearchMult":6.0}` | 249991 |
| `soul_eggs` | SOUL FOOD | 140 | `{"soulEggBonus":0.01}` → `{"soulEggBonus":1.4000000000000001}` | 384931 |
| `prestige_bonus` | PRESTIGE BONUS | 20 | `{"soulEggCollectionMult":1.1}` → `{"soulEggCollectionMult":3.0}` | 219991 |
| `drone_rewards` | DRONE REWARDS | 20 | `{"droneRewardQualityMult":1.1}` → `{"droneRewardQualityMult":3.0}` | 20491 |
| `epic_egg_laying` | EPIC COMFY NESTS | 20 | `{"eggLayingRateMult":1.05}` → `{"eggLayingRateMult":2.0}` | 502491 |
| `transportation_lobbyist` | TRANSPORTATION LOBBYISTS | 30 | `{"vehicleCapacityMult":1.05}` → `{"vehicleCapacityMult":2.5}` | 78736 |
| `warp_shift` | WARP SHIFT | 16 | `{}` → `{}` | 41995 |
| `prophecy_bonus` | PROPHECY BONUS | 5 | `{"eggOfProphecyBonus":0.01}` → `{"eggOfProphecyBonus":0.05}` | 2750000 |
| `afx_mission_time` | FTL DRIVE UPGRADES | 60 | `{"artifactsMissionFTLDurationResearchMult":0.99}` → `{"artifactsMissionFTLDurationResearchMult":0.4}` | 6149971 |
| `afx_mission_capacity` | ZERO-G QUANTUM CONTAINMENT | 10 | `{"artifactsMissionCapacityResearchMult":1.05}` → `{"artifactsMissionCapacityResearchMult":1.5}` | 5249996 |

`videoDoublerHours` w tabeli jest wkładem badania: baza GDR 2 h +0.5 h/poziom, do 8 h. `siloSeconds` także jest dodatkiem do bazy, nie pełną długością silosu. Puste próbki Epic Internal Incubators/Silo Quality nie uzasadniają usunięcia tych mechanik; pełne złożenie IHR/away opisuje [10](10_verified_simulation_and_server_config.md).

Dawne `pet_mission_time` / `pet_mission_capacity` nie są identyfikatorami konfiguracji referencyjnej. Przemianowanie badań rakiet na rozwój ekspedycji petów jest **P — propozycją**, bez zatwierdzonych kosztów i bez implementacji. Zakres ekspedycji pozostaje otwarty.

## 4. Propozycja interfejsu Roblox

**R:** Buy MAX to osobny trwały gamepass poza Pro, według [25](25_approved_product_structure.md). Nie pomija kosztów ani warunków odblokowania badań. **P:** szczegółowy układ MAX / MAX TIER i gesty sterowania. Cena pozostaje w odłożonym bilansie; nie rozpoczęto implementacji.

## Dane referencyjne w projekcie

Pełne ceny i efekty wszystkich poziomów są w [research.json](reference_data/research.json); indeksy i zakres opisuje [katalog danych](reference_data/README.md). Tabele Markdown pokazują skrót, nie pełne wektory.

## Progi Common — doprecyzowanie 24.10.2026

Punkty Common to suma aktualnych poziomów wszystkich Common; jeden poziom daje jeden punkt, koszt nie jest wagą. Epic mają osobny licznik. Tier jest dostępny przy points >= tierThresholds[tier_raw]. Pełna tabela, granice i osiągalność siedmiu wybranych badań: [31](31_research_hatching_rcb_and_new_account.md). Nie zmienia to cen lub bilansu.

[Integracja zniżek #73](workflow/entitlement_farm_fixes_71_74.md): quote, wydatek i świeża walidacja uwzględniają istniejące efekty Cheaper Research, Cheaper Contractors oraz Bust Unions. Bez zmiany tabel cen.
