# Bilans petów — wariant roboczy 0.1

> **Nowsza kalibracja:** [18. Ceny i tempo inkubacji](18_incubator_prices_and_acquisition_pacing.md) zawiera konkretne kotwice cenowe, zmianę rozkładu V i rekomendowany wspólny zasób inkubacji. Poniższe czasy oraz rozkład opisują historyczny wariant 0.1. Zasady siły i ewolucji pozostają propozycją, bez implementacji.

> [19. Symulacja progresji farmy](19_integrated_farm_progression_simulation.md) weryfikuje wariant w przebiegach obejmujących zakupy, transport, prestiż i finansowanie boostów. Aktualna rekomendacja V: 1.5e55, z ładunkami inkubacji. Nowy gracz w badanych strategiach nie dochodzi do Universe w 28 dni; testy V używają jawnych profili zaawansowanych.

Data: 23.10.2026. **Propozycja projektu do oceny, nie zatwierdzony balans wydania** Bez implementacji. Obowiązujące miejsca włączenia efektów opisuje [16](16_pet_stacking_offline_and_package_schedule.md).

## 1. Waluta i koszty

Proponowana waluta standardowego wylęgu: **gotówka aktualnej farmy**. Wyprodukowane i sprzedane jaja nie stanowią drugiego salda. Pety oraz odblokowane inkubatory pozostają po prestiżu. Starszy inkubator można kupić na dowolnej późniejszej farmie; nie wymaga powrotu do gatunku jaja.

Cena jest stałą danego inkubatora w konfiguracji, nie funkcją bieżącego dochodu, wyposażenia czy salda. Zdejmowanie petów nie obniża ceny. Wyznaczamy ją przez `C[t]=T[t]*R_ref[t]`, gdzie R_ref to dochód/s z określonej referencyjnej farmy przy odblokowaniu. Scenariusz referencyjny musi określać populację, badania, SE/PE i transport, bez petów, wydarzeń i boostów. Tabela R_ref oraz wynikowe kwoty pozostają do kalibracji pełnej progresji; same czasy nie stanowią jeszcze gotowego cennika.

| Inkubator | Odblokowanie | T: sekundy dochodu referencyjnego / otwarcie | Siła premii s |
|---|---|---:|---:|
| I | Edible | 30 | 1 |
| II | Superfood | 60 | 1.15 |
| III | Fusion | 120 | 1.30 |
| IV | Tachyon | 180 | 1.50 |
| V | Universe | 300 | 1.75 |

Koszt jest wydatkiem z portfela; nie cofa przychodu już naliczonego do prestiżu. Nie dopisujemy samym zakupem żadnego przychodu. Pierwszy wylęg warto zapewnić jako jednorazową nagrodę samouczka, aby zakup nie blokował pierwszych badań. Na tym etapie bez losowych jaj za GE/Robux i bez ekspedycji generujących kolejne waluty; ich starsze opisy nie są częścią tego wariantu bilansu.

## 2. Rozkład i siły

Każdy wylęg daje dokładnie jednego peta. Wariant ma siedem wyników na inkubator, bez niezależnego drugiego losowania rarity. Rzadkość jest etykietą wyniku. Tier inkubatora jest częścią tożsamości peta.

| Pet | Etykieta | I | II | III | IV | V | Bazowa premia b przed s i ewolucją |
|---|---|---:|---:|---:|---:|---:|---|
| Farm Pup | Common | 55% | 45% | 35% | 28% | 22% | +50% wartości jaj |
| Rooster | Rare | 25% | 27% | 27% | 25% | 23% | +20% znoszenia |
| Speedy Chick | Rare | 15% | 20% | 24% | 27% | 28% | +30% IHR |
| Heavy Cow | Epic | 4% | 6% | 9% | 12% | 15% | +10% pojemności |
| Drone Hawk | Epic | 0.9% | 1.7% | 4% | 6% | 9% | +100% bazowej szansy elity, czyli samodzielnie 2× |
| Cosmic Phoenix | Legendary | 0.1% | 0.3% | 0.9% | 1.8% | 2.7% | +200% przychodu prestiżowego |
| Alien Clucker | Mythic | 0% | 0% | 0.1% | 0.2% | 0.3% | +50% siły aktywnych boostów |

Każda kolumna sumuje się do 100%. Alien jest niedostępny w I–II. To świadome ograniczenie wczesnego dostępu do wzmacniania boostów. Zero oznacza brak możliwości wylosowania, bez ukrytej szansy.

Końcowa premia `b_final=b*s*e`; mnożnik wyposażenia `P=1+sum(b_final)`. Nie ma dodatkowego globalnego mnożnika rarity. Siły rosną umiarkowanie; premię daje również lepszy rozkład, a stare pety nadal mogą uzupełniać zestaw. Pup, Rooster i Chick nie są równoważnymi premiami dochodu: Rooster przegrywa przy pełnym transporcie, Chick przy pełnych kurnikach.

## 3. Ewolucja

Propozycja jednoznaczna: Normal e=1, Golden e=2, Rainbow e=3.5 **względem premii Normal tego samego tieru**. Rainbow nie daje 3.5× premii Golden. Receptury: 5 identycznych Normal →1 Golden; 3 identyczne Golden →1 Rainbow; łącznie 15 Normal. Gatunek oraz tier muszą się zgadzać. Bez ryzyka niepowodzenia i bez dodatkowej opłaty GE w tym wariancie.

Łączenie wymienia 5 premii b na jedną 2b, a później trzy 2b na jedną 3.5b. Zyskiem jest oszczędność slotów; łączna premia wszystkich kopii maleje. Podgląd powinien pokazywać wynik i zmianę wyposażenia. Nie proponujemy automatycznego zużywania aktualnie wyposażonych kopii bez wyboru gracza.

## 4. Granice siły — inkubator V

Wartości dotyczą zestawu identycznych petów Rainbow. To scenariusze graniczne, nie typowy start.

| Statystyka | 3 sloty | 5 slotów | Iloraz 5/3 |
|---|---:|---:|---:|
| Wartość jaj / siła boostów | 10.1875× | 16.3125× | 1.6012× |
| Znoszenie | 4.675× | 7.125× | 1.5241× |
| IHR | 6.5125× | 10.1875× | 1.5643× |
| Pojemność | 2.8375× | 4.0625× | 1.4317× |
| Przychód prestiżowy | 37.75× | 62.25× | 1.6490× |
| Szansa elity przy bazie 8% | 100% | 100% | 1× |

Jeden Rainbow Hawk V daje 57% elity przy bazie 8%; dwa osiągają limit 100%. To skutek zatwierdzonego sumowania i proponowanej ewolucji. Dalszy Hawk po osiągnięciu limitu nie daje korzyści. Gdyby stała elita była niepożądana, trzeba zmienić siłę/evolucję Hawka — nie ukrywać innego algorytmu stackowania. Ten punkt wymaga oceny użytkownika.

Nie wolno oceniać przewagi płatnych slotów wyłącznie po kolumnie jednego wymiaru. Trzy Rainbow Pupy V dają dochód 10.1875×. Przy aktywnym Jimbo i bez ograniczania wartości jaj przez transport, podział pięciu slotów na 3 Pupy +2 Alieny daje 72.5859375× względem tego samego Jimbo bez petów. To **7.125× względem zestawu 3 Pupów**, ale nie względem najlepszego zestawu F2P: ten może wybrać 2 Pupy +1 Aliena, uzyskując 28.9453125×. Najlepszy podział Pup/Alien przy trzech slotach ma zatem 28.9453125×, a pięć slotów 72.5859375×, czyli około **2.508×**. Oba zestawy wymagają rzadkich petów i aktywnego boostu. Uzasadnia to osobne testy ceny/siły rozszerzenia slotów.

Phoenix działa przed funkcją SE. Dla pojedynczej potęgowej gałęzi z wykładnikiem 0.15–0.21 mnożnik przychodu 37.75 daje około 1.724–2.144× SE, a 62.25 około 1.858–2.381×. To przybliżenie przy dominacji tej gałęzi, nie dokładne wyliczenie przedziałowej funkcji prestiżu.

## 5. Rzadkość i czas

Bez pity szansa zdobycia przynajmniej jednej kopii po n otwarciach to `1-(1-p)^n`. Średnia liczba prób to 1/p; nie jest gwarancją. Dla Alien V p=0.003: średnia 333.33 otwarcia, mediana 231, próg 95% to 998. Rainbow wymaga średnio 15/p=5000 otwarć, czyli **416.67 godzin referencyjnego dochodu V** przy T=300 s. Rzeczywisty czas może być znacznie krótszy po wzroście farmy i z boostami.

Ten wariant nie ma jeszcze pity, wymiany duplikatów ani handlu. Nie opisujemy losowania jako gwarantowanego sukcesu po średniej liczbie prób. Alien Rainbow pozostaje celem długoterminowym; przed zamrożeniem tabel trzeba ocenić, czy tak duży ogon losowości jest pożądany. Nie dodajemy bez decyzji płatnego skracania tego ogona.

## 6. Następny krok kalibracji

1. Zbudować scenariusze referencyjne farm I–V i wyliczyć R_ref oraz stałe ceny w gotówce. Porównać zakup peta z zakupem badań, transportu i kurnika; bez tego nie można obiecać czasu progresji.
2. Ocenić wariant przy 3/5 slotach, bez boostów i w silnym zestawie boostów; uwzględnić ograniczenie transportu, pojemność oraz prestiż.
3. Rozstrzygnąć walutę, podstawę Rainbow, nasycenie Hawka i przewagę płatnych slotów. To propozycje tego dokumentu, nie wcześniejsze zgody użytkownika.
4. Ustalić działanie petów na Enlightenment przed bilansem końcowego wyzwania; nie zakładać automatycznie pełnej siły wszystkich petów w trybie blokującym referencyjne artefakty.

Nie zmieniamy wzorów referencyjnej farmy ani tabel kalendarza, aby dopasować je do proponowanej siły petów. Wyniki obliczeń: dokumentacja referencyjna. Są to obliczenia wariantu projektu, nie testy referencyjnej biblioteki ani gotowej gry.

