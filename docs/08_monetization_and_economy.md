# Ekonomia i monetyzacja — rozdzielenie źródeł i propozycji

Stan 23.10.2026. Statusy według [CURRENT_SPEC](CURRENT_SPEC.md). **Dalszy bilans odłożony** zgodnie z [TODO](TODO.md). Ceny, limity i wyniki analiz pozostają bez zmian. Podział produktów został następnie zatwierdzony w [25](25_approved_product_structure.md).

## 1. Reguły i dane modelu referencyjnego — N/S

| Obszar | Ustalenie / źródło |
|---|---|
| Epic Research | 24 rozpoznawane ID w konfiguracji referencyjnej, z cenami poziomów; nie dawna lista 22 z dwoma fikcyjnymi badaniami petów. Widoczność w sklepie i tryby wymagają własnych bramek. [01](01_upgrades_and_research.md) |
| Hyperloop | Cena funkcji stacji 50000 GE; trwałe odblokowanie. Ewentualna promocja wymaga konkretnego modyfikatora konfiguracji, nie reguły „zawsze w weekend 25000”. [04](04_vehicles_and_shipping.md) |
| Boosty | Konkretne ceny, siły, czasy i progi postępu pochodzą z konfiguracji referencyjnej i snapshotu LiveConfig, nie dawnych ogólnych widełek. Soul Beacon wzmacnia przychód prestiżowy, nie końcowe SE. [05](05_prestige_soul_eggs_and_boosts.md), sklep w [10](10_verified_simulation_and_server_config.md) |
| Kalendarz | Pełne 28 wpisów w [11](11_periodicals_calendar_events_and_boost_rules.md), skalowanie i sumy w [15](15_calendar_gameplay_formula_and_roblox_scope.md). Dzień 1: baza 192 GE; dzień 28: PE przez 24 cykle, potem 100000 GE. Dawna tabela 250/500/2500/.../50000+PE była błędna i nie jest wariantem projektu. |
| Drony | Częstość z mieszaniny rozkładów, osobne szanse waluty i wysokości, jakość, wydane GE oraz modyfikatory. Nie ma jednej stałej stawki GE/h. [06](06_drones_silos_and_events.md) |
| Paczki i oferty | Rozkłady po filtrach w [13](13_rewards_contracts_resets_and_gift_distributions.md); chwila próby, warunki i ponowienia w [16](16_pet_stacking_offline_and_package_schedule.md). Nie gwarantują paczki dokładnie co I sekund. |
| Trofea | Wydobyte `trophyPopulations` i trzy tablice nagród per jajo w danych konfiguracji referencyjnej. Pięć progów w tej tabeli: 10M / 50M / 250M / 1B / 10B kur. Nagroda zależy od jaja i może obejmować SE, GE lub PE; dawna uniwersalna tabelka była błędna. Odczyt tabeli nie dowodzi wszystkich warunków odblokowania/odbioru trofeów. |
| Zadania | Dawne przykłady „Center→100 GE” itp. nie miały wskazanego potwierdzenia w audycie. Nie traktować ich jako opisanych nagród. Zakres zadań Roblox pozostaje otwarty. |
| Piggy | Rozróżniać surowe saldo, poziom, pełność, utracone przyrosty i końcową wypłatę. Nagroda wypełnienia ma inną gałąź niż zwykły wzrost. Bonus poziomu nie jest prostym +10% od pierwszego poziomu; dodatkowy bonus Ultra i dwa osobne obcięcia opisuje [13](13_rewards_contracts_resets_and_gift_distributions.md). |

Rakiety, Fuel Tank, crafting artefaktów i kontrakty kosmiczne nie wchodzą w zakres gry. Badania epickie `afx_mission_time` i `afx_mission_capacity` w HatchTheEgg zostały oczyszczone z tematyki kosmicznej i powiązane z logistyką i transportem floty lądowej (Szybkość Kursu Floty oraz Logistyka i Magazyn Floty).

## 2. Zatwierdzony kierunek — R

Użytkownik wybrał priorytet wartości dla gracza płacącego, zachowanie znaczenia Pro, Diamentów (Diamonds, 💎; identyfikator `profile.permanent.GE`), boostów oraz późniejszych spowolnień . Nie oznacza to zatwierdzenia konkretnego cennika Robux, rozmiarów pakietów, parametrów świnki ani płatnych losowych jaj. Rodzaje produktów Diamentów/Piggy i passów zatwierdzono osobno w 25. [20](20_paying_player_balance_direction.md) zachowuje opis kierunku, a [21](21_payer_progression_and_incubation.md) ostatnią analizę.

## 3. Zatwierdzony podział produktów — R

Pełna specyfikacja: [25](25_approved_product_structure.md).

- **Pro:** większe możliwości silosów i boostów, pełna jakość offline, dodatkowe miejsca petów i +10 p.p. do łączenia. Nie zawiera Buy MAX ani Auto-Hatch.
- **Buy MAX:** osobny gamepass zakupów badań; nie pomija kosztów i bramek postępu.
- **Auto-Hatch kurczaków:** osobny gamepass automatyzujący ręczną wylęgarnię z zachowaniem ograniczeń; nie otwiera automatycznie petów.
- **Pakiety Diamentów (Diamonds, 💎) i rozbicie Piggy:** powtarzalne zakupy (w kodzie i schemacie zapisu zachowany klucz profilu `profile.permanent.GE`), z jednokrotnym rozliczeniem każdej transakcji według D07.

D04 ustala osobno zasady podwajacza i bonusowych prezentów; nie są już otwartym pytaniem o samą dostępność.

## 4. Parametry i pozostałe propozycje — P, bilans odłożony

Ceny Robux, ilości GE, wzrost/pojemność Piggy, liczby miejsc, sloty i saldo inkubacji pozostają niezatwierdzone. Wariant A dostępności +10 p.p. oraz zakres premiery zatwierdzono w [26](26_approved_launch_scope_and_pro_availability.md). Pro/Buy MAX/GE na premierę, Piggy warunkowo po gotowym bilansie, Auto-Hatch/VIP później. Nie ustalono dat późniejszych wydań. Nie utożsamiać własnego Pro z Roblox Premium lub Ultra.

Waluta inkubacji, siły, szanse, ceny i ładunki petów nadal są propozycjami z 17–21. Nie zmieniono ich i nie przeprowadzono ponownej oceny.

Nie ma prognozy przychodów, konwersji ani retencji. Symulacje skończonych zakupów GE nie są testem prawdziwych transakcji, cen Robux ani zachowań klientów.
