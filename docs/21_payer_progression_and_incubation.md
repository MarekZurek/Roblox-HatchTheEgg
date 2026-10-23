# Progresja płacącego gracza i ponowna ocena inkubacji

> **Status 23.10.2026: dalsze prace odłożone na polecenie użytkownika.** Wyniki poniżej zachowano jako analizę historyczną; propozycje nie są zatwierdzone. Wznowienie wyłącznie na kolejne polecenie. Zakres: [TODO](TODO.md).

23.10.2026. **61 zintegrowanych przebiegów analitycznych**, w tym próby 28 i 90 dni, **bez implementacji gry i bez rzeczywistych zakupów**. Kierunek: [20](20_paying_player_balance_direction.md). Nowe ceny i korzyści Pro poniżej są propozycją do oceny, nie wdrożoną zmianą.

## 1. Rekomendacja

- Pozostawić robocze ceny I–IV: **25 / 340 000 / 7.8e13 / 1.1e23 gotówki**. Dla płacącego profilu nie są głównym ograniczeniem podaży po rozwoju farmy. Nie znaleziono powodu do ich podnoszenia w celu wyrównania tempa do F2P.
- Zastąpić wspólne saldo 120 propozycją **F2P 120, Pro 720 ładunków**. Tempo nadal **1 ładunek / 60 s kwalifikowanej produkcji**, koszt jednego wylęgu 1. Wariant 480 jest kompromisem, ale przy dwóch sesjach dziennie nadal marnuje znaczną część długiego offline Pro.
- **Nie przyspieszać na razie odnawiania do 30 s.** Zwiększenie pojemności jest skuteczniejszym i prostszym sposobem wykorzystania już kupionego offline. Nie dodano opcji kupowania ładunków ani płatnych losowych jaj.
- **Nie zamrażać ceny V.** Warianty 1.5e55/1.5e56/1.5e57 są nadal kandydatami. Obniżka o 100× z 19 nie jest już rekomendacją końcową dla płacącego klienta.

Proponowane 720 to zapas na 12 godzin przy obecnym tempie. To nowa korzyść projektu Roblox, której użytkownik jeszcze nie zatwierdził. Dodatkowe miejsca petów nie przyznają jej samodzielnie: oddzielamy produkt `+2 Pet Equip` od Pro.

## 2. Co rzeczywiście porównano

Wszystkie podstawowe konta zaczynają z **SE=0, PE=0, GE=0 i bez Epic Research**. Nie użyto maksymalnych badań ani zaawansowanych SE jako darmowego startu. Wariant petów ma jeden tutorialowy Pup I, zgodnie z roboczym projektem. Sesje są identyczne: **2×30 min dziennie, co 12 godzin**. Decyzje zakupowe co 30 s, budżet petów 20% zarabianej gotówki.

| Profil | Pro | Sloty petów | Zakupy GE |
|---|---|---:|---|
| F2P | Nie | 3 | Brak |
| Pro | Tak | 3 | Brak |
| Pro + pety | Tak | 5 | Brak |
| Jednorazowy zakup | Tak | 5 | 50 000 w dniu 0 |
| Regularne zakupy | Tak | 5 | Po 50 000 w dniach 0, 7, 14, 21; razem 200 000 |

Dodatkowo porównano 200 000 GE otrzymanych jednorazowo oraz 90 dni z 13 zakupami po 50 000 GE, razem **650 000 GE**, i F2P przez ten sam okres. To hipotetyczne budżety w jednostkach GE. Nie założono ceny Robux, konwersji, przychodu ani rzeczywistej gotowości klienta do wydania takiej kwoty.

Zakupy otrzymuje się dopiero podczas odpowiedniej sesji. Pełny bilans: `saldo = GE początkowe + darmowe GE + zakupy − wydatki`. Środki nie są uzupełniane po wyczerpaniu. Główna polityka przeznacza 40% otrzymanych GE na Epic/Hyperloop i 60% na boosty; jest heurystyką, nie rozwiązaniem optymalnym.

## 3. Uzupełnienia względem rozdziału 19

Zachowano wcześniejsze źródłowe dane badań, tierów, transportu, FV i prestiżu. Dodano:

- **RCB:** referencyjne `min(coefficient^runningCount, cap)`, a przy wyniku >1 dodatkowo mnożnik końcowy. Sprawdzono 144 wykonania funkcji referencyjnej na kontrolowanych wejściach. Bazowy współczynnik z referencyjnych `GameDimensions::defaults` wynosi 1; rośnie przez badania. Liczby biegnących kur nie zgadujemy jako stale maksymalnego RCB.
- **Model aktywności kur:** gracz wypuszcza do `max(3, HoldToHatchRate)` kur/s, ograniczony zapasem/refillem wylęgarni i miejscem w kurnikach. Grupa wypuszczona w kroku pozostaje w modelu na ekranie 10 s. **Te 10 s to założenie eksperymentu, nie odzyskana referencyjna trasa ruchu.** Offline nie utrzymuje RCB.
- **Drony:** gotówka zależna od FV, jakości, elity, struggle i pierwiastka RCB, obok wcześniej naliczanych GE. Poprawnie rozdzielono bonus zależny od **wydanych** GE; przy snapshotcie próg podwyższonych GE wynosi 152 500 wydanych GE, nie zakupionych ani posiadanych.
- **Zwykłe paczki:** harmonogram po konfiguracji, wczesne przyspieszenie Edible/Superfood, przeterminowana pojedyncza próba po powrocie, rozkłady zależne od wydatków GE, gotówka i boosty. Odbiór jest natychmiastowy podczas sesji; nie symulujemy ruchu ciężarówki. Brak reklam/Ultra i zaległej serii prezentów za offline.
- **Ładunki:** pojemność i czas odnawiania są parametrami eksperymentu. Zapisujemy przyrost, wydane ładunki, pozostałe saldo oraz przyrost utracony na limicie.

Domowa farma, bez kontraktów, Ultra i wydarzeń. Nie zakładano stałego podwajacza. Darmowe GE i boosty pochodzą z kalendarza, dronów i uwzględnionych paczek. Snapshot konfiguracji nadal pochodzi z anonimowego zapytania z 20.10.2026; nie jest spersonalizowaną ofertą rzeczywistego konta.

## 4. Główne wyniki 28 dni

Po trzy seedy, krok 5 s, saldo inkubacji wspólne 120 i odnowienie 60 s:

| Profil | Najwyższe jajo | SE na koniec | Otwarcia petów |
|---|---|---:|---:|
| F2P | Graviton | 179 579–222 111 | 7 700–7 898 |
| Pro, 3 pety | Graviton | 244 173–251 684 | 7 749–7 855 |
| Pro, 5 petów | Graviton | 383 112–411 967 | 7 684–7 800 |
| Pro, 5 petów, 50k GE | Dilithium | 1 580 665–1 924 139 | 7 858–8 098 |
| Pro, 5 petów, 200k GE łącznie w czterech zakupach | Prodigy | 6 570 076–13 156 685 | 8 101–8 104 |

Ostatni profil wydaje **łącznie 200k**, nie 200k co tydzień. W tabeli znormalizowane sesje i strategia, ale odmienne zasoby powodują odmienne decyzje i późniejsze stany. Są to zakresy trzech prób, nie statystyczne przedziały ufności ani gwarancje dla gracza.

Płatne produkty dają dużą przewagę w rozwoju farmy, a ich efekty nie sprowadzają się do samych petów. Jednocześnie przy saldzie 120 liczba petów jest prawie taka sama dla wszystkich profili. Nie oznacza to równoważności ich siły: płacący gracz dochodzi wcześniej do mocniejszych inkubatorów i ma pięć miejsc.

## 5. Limit inkubacji ogranicza wartość Pro

| Profil przy saldzie 120 | Przyrost ładunków utracony na limicie |
|---|---:|
| F2P | 14.2–14.6% |
| Pro, 3 pety | 74.0–75.0% |
| Pro, 5 petów | 74.3–74.8% |
| Pro, 5 petów, 50k GE | 78.5–79.1% |
| Pro, 5 petów, 200k GE | 78.9–79.1% |

Płacący profil produkuje dłużej dzięki silosom i badaniom. Przy limicie na dwie godziny traci jednak większość dodatkowego przyrostu inkubacji. Nie jest to ograniczenie portfela, które naprawi kolejny pakiet GE.

Ten sam profil 200k GE, trzy seedy:

| Pojemność / odnowienie | Otwarcia w 28 dni | Utracony przyrost | Najwyższe jajo |
|---|---:|---:|---|
| 120 / 60 s | 8 101–8 104 | 78.9–79.1% | Prodigy |
| 480 / 60 s | 26 875–28 024 | 28.9–29.0% | Prodigy |
| **720 / 60 s** | **36 965–39 401** | **0%** | Prodigy |
| 480 / 30 s | 29 175–29 620 | 61.5–61.8% | Prodigy |

Wariant 720/60 daje więcej użytecznych otwarć niż 480/30 mimo dwukrotnie wolniejszego odnawiania. Pasuje do dwóch logowań dziennie, wykorzystuje kupione offline i nie wymaga zwiększania bazowej produkcji zasobu. Nie dowodzi to optymalności 720 dla każdego rozkładu sesji: przy rzadszych logowaniach albo mniejszej liczbie silosów wynik będzie inny.

Zgromadzony zapas można zużyć na wiele otwarć podczas jednej sesji. Nie jest to obietnica otwarcia co minutę bez gotówki ani sześciokrotny wzrost wszystkich przychodów farmy. Kwoty i szanse petów pozostają takie same dla gracza płacącego i F2P; zmieniają się jawne korzyści produktu.

### Czy większa pojemność pomaga również przy pierwszym zakupie

Dodatkowy test pojedynczego seeda, bez zmiany strategii boostów, z proponowanym saldem 720:

| Profil | Otwarcia | SE | Najwyższe jajo |
|---|---:|---:|---|
| Pro, 3 pety, bez zakupu GE | 27 700 | 242 294 | Graviton |
| Pro, 5 petów, bez zakupu GE | 29 461 | 404 898 | Graviton |
| Pro, 5 petów, jednorazowe 50k GE | 38 711 | 2 478 407 | Dilithium |

Samo większe saldo mocno poprawia zbieranie petów, ale nie zastępuje rozwoju badań i finansowania boostów. To korzystny kierunek dla rozdzielenia wartości produktów: Pro wykorzystuje dłuższy offline, a GE nadal daje dodatkowy postęp farmy. Nie jest to jednak prognoza, jaki odsetek graczy dokupi GE.

## 6. Ceny inkubatorów

### I–IV

Jednoseedowe dodatkowe porównanie cen I–IV ×0.1/×10, z ceną V pozostawioną bez zmian:

| Profil | Ceny ×0.1: otwarcia / najwyższe jajo | Ceny ×10: otwarcia / najwyższe jajo |
|---|---|---|
| F2P, saldo 120 | 7 937 / Graviton | 7 011 / Graviton |
| Pro + 200k GE, saldo 480 | 26 491 / Prodigy | 26 950 / Prodigy |

Droższy wariant może w pojedynczej strategii dać więcej otwarć wskutek innej kolejności inwestycji i późniejszych losowań. Nie interpretować tego jako ogólnej zasady, że podnoszenie cen poprawia postęp. Wynik pokazuje natomiast, że dla rozwiniętego płacącego profilu inkubacja jest znacznie silniejszym ograniczeniem niż te ceny.

Propozycja pozostaje 25 / 340 000 / 7.8e13 / 1.1e23. Nie podnosimy cen starych inkubatorów tylko dlatego, że bogata farma otwiera je łatwo. Gracz nadal płaci gotówką, a podaż kontrolują czas produkcji, pojemność oraz sesje.

### V: wynik nie identyfikuje właściwej ceny

W dziewięciu próbach 28 dni porównano V=1.5e55/1.5e56/1.5e57 przy saldzie 480. Wszystkie trzy ceny dawały w danym seedzie te same wyniki, ponieważ **żaden profil nie dotarł do Universe i żaden nie kupił peta V**. Nie jest to dowód, że ceny są równoważne po odblokowaniu V.

Dodatkowy przebieg od zera przez **90 dni**, jeden seed:

- F2P: Terraform, około 111.3 mln SE.
- Pro + pięć petów + 13 zakupów po 50k GE: Antimatter, około 877.1 mln SE, łącznie 650k zakupionych GE.
- Cena V=1.5e55 lub 1.5e57 nie zmieniła przebiegu płatnego konta; nadal zero otwarć V.

To wynik **tej polityki wydawania i prestiżu**, nie twierdzenie, że zakup 650k GE musi w realnej grze kończyć się na Antimatter. Nie wyceniono Robux ani nie oszacowano realnych wydatków człowieka. Dane te nie wystarczają do rozstrzygnięcia ceny V. Wcześniejsze testy z 19 na gotowych zaawansowanych kontach pozostają testami określonych stanów, a nie historią zakupów od nowego gracza.

Zamiast arbitralnej obniżki albo podwyżki pozostawiamy V otwarte. Potrzebna jest obserwacja etapu V przy sprawdzonej strategii lub konkretnej historii rozwiniętego płacącego konta. Nie ma podstaw, aby nazywać zmianę ceny nieodwiedzonego inkubatora optymalizacją płacącego klienta.

## 7. Strategia i czas zakupów

200k GE jednorazowo, przy saldzie 480: około 5.58–7.64 mln SE. Ta sama łączna kwota w czterech tygodniowych transakcjach: około 10.62–15.16 mln SE. Nie oznacza to, że wcześniejsze otrzymanie środków jest z natury gorsze. Heurystyka potrafi wydać je wcześniej na słabiej dobrane ulepszenia, zamiast zachować na późniejszy zestaw.

W podstawowej polityce szczyt aktywnych boostów wynosił 2 dla F2P/Pro bez GE oraz 3 dla płatnych pakietów. Samo ustawienie limitu pięciu nie wykorzystywało całej korzyści Pro. Osobno zbadano więc finansowanie legalnych duplikatów do pięciu miejsc — sumowanie pełnych sił w kategorii zgodnie z referencyjną zasadą, bez darmowych aktywacji.

Ta obserwacja jest ważniejsza niż kosmetyczna korekta cen inkubatorów: sensowne przygotowanie zestawu, oszczędzanie GE i wybór chwili prestiżu wpływają na wartość zakupu. Nie można przewidywać satysfakcji klienta wyłącznie z rozmiaru pakietu GE.

### Rzeczywiste wykorzystanie pięciu boostów

Dodatkowa polityka wypełnia wolne miejsca Pro legalnymi duplikatami: małym Soul Beaconem po odblokowaniu, wcześniej małym feedem. Każda sztuka pochodzi z inwentarza albo jest kupiona z zachowanego, skończonego budżetu GE. Maksimum aktywnych wpisów w tych próbach faktycznie wyniosło **5**.

Przy tych samych czterech zakupach po 50k GE i trzech seedach:

| Saldo | Otwarcia | SE | Najwyższe jajo |
|---|---:|---:|---|
| 480 | 27 773–28 024 | 10.02–19.56 mln | Prodigy |
| 720 | 38 615–39 419 | 12.79–17.04 mln | Prodigy |

Nie każdy seed poprawił SE względem polityki z niewykorzystanymi miejscami: dodatkowe małe boosty zużywają GE, które mogły zostać przeznaczone na późniejszy duży zestaw. **„Zawsze zapełniaj pięć miejsc” nie zostało wykazane jako optymalna strategia.** Produkt daje możliwość, ale wartość zależy od dobrania zestawu i fazy farmy.

Kontrola tej polityki, saldo 720, seed=1, pełne 28 dni z krokiem **0.3 s**: **20 917 342 SE, 38 615 otwarć, Prodigy**, 200k zakupionych GE i pięć wykorzystywanych miejsc boostów. Dla porównania kontrolny F2P przy 0.3 s uzyskał 237 473 SE i 7 559 otwarć. To porównanie całych pakietów korzyści oraz strategii, nie przypisanie całego ilorazu jednemu zakupowi.

## 8. Dokładność i ograniczenia

Model powtarza pięć kontrolowanych przypadków modelu referencyjnego produkcji, 144 przypadki RCB, 30 cen opartych na PriceCurve oraz wcześniejsze 70 wzorów FV i 18 końcowych wyników SE. Te kontrole nie są wykonaniem całego referencyjnego managera świata.

Kontrola 28 dni, seed=1, kroki 5/1/0.3 s:

| Profil | SE: 5 s | SE: 1 s | SE: 0.3 s | Otwarcia: 5/1/0.3 s |
|---|---:|---:|---:|---|
| F2P, saldo 120 | 179 982 | 224 896 | 237 473 | 7 770 / 7 633 / 7 559 |
| Pro + 200k GE, saldo 480 | 14 703 212 | 16 266 853 | 18 129 617 | 26 875 / 27 410 / 27 925 |

Najwyższe jaja nie zmieniły się między krokami. W porównaniu 5 vs 0.3 s liczba otwarć różni się o około 2.8% dla F2P i 3.8% dla płatnego profilu. **SE różnią się znacznie mocniej: około 24.2% i 18.9%.** Nie przenosimy więc wcześniejszego błędu 0.54% z modelu 19 na model z RCB i dodatkowymi nagrodami.

Krok zmienia m.in. czas widoczności grup kur, momenty dronów, premie przy wygaśnięciu boostów i kolejne decyzje finansowe. Szerokie serie z krokiem 5 s służą porównaniom kierunku oraz wąskich gardeł. Nie są precyzyjnym cennikiem „ile dni kupuje pakiet”. Różnice między 120 a 720 ładunkami są dużo większe od obserwowanej wrażliwości liczby otwarć.

W dodatkowej polityce pięciu boostów przy saldzie 720 liczba otwarć była identyczna dla 5 i 0.3 s: 38 615. SE wyniosły odpowiednio 17 038 205 i 20 917 342, czyli różniły się o około 18.5% względem drobnego kroku. Wniosek o pojemności pozostaje stabilniejszy niż dokładna prognoza SE.

Pozostałe granice: heurystyczny dobór wyposażenia i automatyczne łączenie; umowny dziesięciosekundowy ruch kur; brak pełnej sceny transportu i czasu dostawy paczek; brak eventów i podwajacza, trofeów/questów oraz SE/PE z tych źródeł; uproszczona kolejność części jednorazowych rozliczeń względem managera prestiżu. Nie symulowano pełnej księgowości Piggy ani jego rozbijania — tylko konkretne zakupy GE. Losowania używają jawnie seedowanego generatora Pythona i odtworzonych rozkładów, nie stanu referencyjnego `hq_rand` konkretnego konta. Trzy seedy nie wyznaczają ogona rozkładu ani retencji. Symulacja nie mierzy konwersji, ARPPU, przychodu w Robux ani wpływu na rekomendacje Roblox.

Wynik nie uzasadnia dodatkowego spowalniania F2P. Pokazuje realną przewagę zakupów i konkretne ograniczenie wartości Pro: zbyt mały zapas inkubacji. Nadal bez implementacji gry.

## 9. Wyniki i odtworzenie

- Model płatnych profili, główne wyniki, limity inkubacji.
- Ceny V, ceny I–IV, 90 dni od zera.
- Czas zakupów, pięć boostów, drobny krok pięciu boostów, pierwszy Pro.
- Kontrola kroków, wyłączone RCB/nagrody, referencyjne RCB.
- Podsumowanie, kontrole finansów i kopii petów, propozycja v3, manifest.

Kontrole potwierdzają bilanse wszystkich 61 przebiegów, brak przedwczesnego kredytowania zakupów, limity Pro/F2P i zachowanie kopii przy ewolucji. Status PASS oznacza spełnienie tych kontroli i odtworzenie wskazanych funkcji na fixtures, **nie pełną zgodność gry 1:1 ani zweryfikowaną prognozę przychodów**. Źródłowa biblioteka pozostaje niezmieniona.
