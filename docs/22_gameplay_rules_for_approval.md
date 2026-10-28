# Propozycje zasad przed implementacją — do zatwierdzenia

> **Decyzja użytkownika 28.10.2026 (R): czasowy podwajacz dochodu i badanie `video_doubler_time` („Dłuższe Wzmocnienia”) zostały usunięte z gry.** Dawne terminy/poziomy w profilach są zachowane wyłącznie dla zgodności i nie dają efektu ani możliwości zakupu. Poniższe wcześniejsze zasady VD, jego darmowej aktywacji i odnawiania są historyczne. Osobny pass `double_cash` (2× Cash), boosty oraz zasady bonusowych prezentów pozostają poza tą zmianą. [Zakres i testy](workflow/remove_timed_doubler_2026_10_28.md).

23.10.2026. **Status mieszany po odpowiedzi użytkownika: D02–D07 zatwierdzone (R); D01: zatwierdzony bonus premium +10 p.p. zamiast dopłat za próbę; zachowanie peta bazowego, zużycie pozostałych kopii i trwały licznik gwarancji zatwierdzone (R); definicja stopnia tier × cel oraz ochrona wyboru kopii zatwierdzone (R).** Zachowuje decyzje R z [CURRENT_SPEC](CURRENT_SPEC.md). Nie zmienia rozdziałów 17–21, ich parametrów, cen, szans, receptur ani analiz; nie wznawia bilansu. Brak implementacji.

Zatwierdzone decyzje projektu oznaczamy R. Reguły obliczeń i tabele pozostają opisem referencyjnym, a propozycje P nie stanowią konfiguracji wydania. Szczegóły systemów opisują dokumenty 11–16.

## 1. Ewolucja petów — D01 zmienione przez użytkownika

**Zatwierdzone R:** własny premium pass daje +10 punktów procentowych zamiast dopłat $/GE/Robux do każdej próby. **Kierunek wskazany przez użytkownika:** szansa ma zależeć od stopnia peta. **Zatwierdzone R:** stopień to tier pochodzenia × docelowy wariant ewolucji. Tabela bazowych szans pozostaje odłożona; akceptacja definicji nie ustala jej wartości. Wcześniejsza rekomendacja gwarantowanego powodzenia została odrzucona. Nie zachowujemy jej jako aktualnej zasady.

### Definicja stopnia przy łączeniu — zatwierdzone R

Użytkownik zatwierdził zastąpienie nieprecyzyjnego pojedynczego słowa **parą: tier pochodzenia × docelowy wariant ewolucji**. To kategoria trudności konkretnej operacji, nie dodatkowy poziom doświadczenia peta.

| Pojęcie | Znaczenie |
|---|---|
| Tier pochodzenia | Tier inkubatora I–V przypisany przy zdobyciu; nie zmienia się po ewolucji, prestiżu ani awansie farmy. |
| Wariant obecny | Normal, Golden lub Rainbow. Określa, do jakiej operacji pet może być materiałem. |
| Wariant docelowy | Golden przy Normal→Golden albo Rainbow przy Golden→Rainbow. |
| Stopień łączenia | Para tier × wariant docelowy, np. III→Golden lub III→Rainbow. |
| Gatunek | Osobny warunek zgodności kopii i klucz licznika gwarancji; nie jest ukrytym dodatkowym modyfikatorem szansy. |
| Rarity | Etykieta gatunku, bez dodatkowego mnożnika ryzyka. |

**Reguły zgodności i skutki definicji R; dodatkowe propozycje oznaczone osobno P:**

- Zgodny gatunek, tier i wariant wejściowy dla peta bazowego oraz wszystkich materiałów. Nie mieszać tierów i nie używać niższego tieru do stworzenia wyższego. Ewolucja zmienia wyłącznie wariant, nie tier/gatunek.
- Jedna tabela bazowej szansy indeksowana tierem i celem; gatunki w tej samej kategorii mają tę samą bazową szansę. Farm Pup III i Phoenix III przy Normal→Golden korzystają więc z tej samej pozycji tabeli. Różna dostępność gatunków pozostaje osobną właściwością pozyskiwania.
- **P — kierunek trudności, niezatwierdzony osobno:** przy tym samym tierze Rainbow nie ma być łatwiejsze niż Golden; przy tym samym celu wyższy tier nie ma być łatwiejszy niż niższy. To propozycja kierunku trudności, **bez ustalania wartości lub obowiązku ścisłej różnicy**.
- **R — zakres wariantów zatwierdzony w [26](26_approved_launch_scope_and_pro_availability.md):** Rainbow to ostatni wariant w pierwszej wersji. Brak Rainbow→kolejny wariant, awansu I→II przez łączenie i dodatkowego systemu XP.
- Licznik gwarancji zachowuje zatwierdzony klucz **gatunek × tier × cel**. Zmiana UID peta bazowego tego samego rodzaju nie kasuje postępu. Golden i Rainbow mają osobny postęp; sukces resetuje tylko odpowiedni licznik.
- Bonus premium +10 p.p. nakładać dopiero po sprawdzeniu prawidłowej i dostępnej receptury. Nie może otworzyć niedostępnego tieru lub niedozwolonego łączenia. Przy aktywnej gwarancji wynik ma 100%, bez drugiego dodawania premii.
- Interfejs pokazuje osobno gatunek, tier, przejście, końcową szansę, postęp gwarancji, chronioną kopię i materiały. **R — ochrona wyboru:** przed użyciem peta jako bazowego lub materiału trzeba go jawnie zdjąć i/lub odblokować. Po zmianie bazowego nie podmieniać automatycznie materiałów; stary bazowy wraca do niewybranych, a ewentualne użycie go jako materiału wymaga jawnego wyboru. Pełny wygląd UI pozostaje szkicem.

**Przykłady bez wartości bilansu:** Rooster II Normal z kopiami II Normal może tworzyć II Golden; Rooster II Golden z kopiami II Golden może tworzyć II Rainbow. Kopie Rooster I nie pasują do żadnej z tych receptur. Bieżąca farma Universe nie zamienia ich w tier V.

Definicja stopnia **tier × cel**, wcześniejsze zdjęcie/odblokowanie petów i brak automatycznej podmiany materiałów są teraz **R — zatwierdzone**. Kierunek trudności pozostaje częścią odłożonego bilansu; końcowy zakres wariantów zatwierdzono następnie w 26. Bazowe procenty, liczby kopii, siły ewolucji, próg gwarancji i ceny pozostają w odłożonym bilansie. Definicja nie wprowadza nowej waluty ani dodatkowych dopłat do prób.

**Zatwierdzone D01 — premium pass:** własny pass gry daje stale **+10 punktów procentowych**: pFinal=min(1,pBase+0.10). Bez mnożenia pBase przez 1.10 i bez kumulacji kilku egzemplarzy uprawnienia. Przykłady interpretacji: 40% →50%, 80% →90%, 95% →100%; nie są tabelą bazowych szans. Bonus dotyczy wyłącznie powodzenia łączenia, nie siły peta, receptury ani innych losowań. Nie jest automatycznym bonusem Roblox Premium. **R — powiązanie produktu:** bonus należy do Pro, bez osobnego premium passa, zgodnie z [25](25_approved_product_structure.md). Cena pozostaje odłożona.

Zatwierdzono **zastąpienie dopłat do każdej próby passem**. Nie ma osobnych dopłat $/GE/Robux za kolejne losowanie lub chwilowe zwiększenie szansy. Wymagane pety są nadal materiałem receptury, a nie dodatkowym zakupem. Podnoszenie szansy passem pozostaje płatnym modyfikatorem wyniku i nie wyłącza wymagań platformy.

### Skutek porażki — zatwierdzone R

1. Przed próbą gracz wskazuje **jednego peta bazowego**, pozostałe wymagane kopie są materiałem. Obowiązuje zgodność gatunku, tieru i wariantu wejściowego zgodnie z zatwierdzoną definicją powyżej; nie mieszać kopii innych kategorii. Liczby kopii nadal są odłożone.
2. **Sukces:** wejścia zostają zastąpione jednym petem wyższego wariantu zgodnie z recepturą. Wynik jest rozliczony raz.
3. **Porażka:** bazowy pet pozostaje w dotychczasowym wariancie i sile; zużywane są wyłącznie pozostałe kopie materiałowe. Brak obniżenia wariantu, utraty petów spoza wybranego zestawu i dodatkowej opłaty walutą.
4. Każda porażka zwiększa trwały licznik gwarancji dla gracza i kombinacji **gatunek × tier × docelowy wariant**. Nie tworzy odłamków ani nowej waluty. Po osiągnięciu jawnego progu następna prawidłowo opłacona materiałami próba ma 100% powodzenia; dopiero sukces zeruje ten licznik. Progu liczbowego nie określamy teraz.
5. Licznik nie zależy od UID peta bazowego, nie znika przy wyjściu, prestiżu ani zmianie jaja. Inne gatunki/tiery go nie przenoszą. Premium zmienia tylko szansę +10 p.p., nie szybkość naliczania gwarancji i nie materiały. Gdy gwarancja jest aktywna, szansa pozostaje 100%.
6. Przed zatwierdzeniem próby podgląd pokazuje chronionego peta, zużywane kopie, końcową szansę, stan gwarancji i oba wyniki. Wynik oraz zużycie/postęp muszą być jedną trwałą operacją według D07; utrata połączenia nie daje nowego losowania.

**Uzasadnienie przyjętej zasady:** porażka zachowuje podstawowego peta i daje trwały postęp, a zużycie materiałów utrzymuje znaczenie zdobywania kopii. Zachowanie wszystkich kopii przy darmowym natychmiastowym ponawianiu sprowadzałoby szansę do klikania aż do sukcesu. Nie wprowadzamy zamiast tego nowej opłaty lub timera prób.

Zachowanie peta bazowego, zużycie pozostałych kopii i trwały licznik gwarancji zostały **zatwierdzone przez użytkownika**. To zasady łączenia HatchTheEgg. Mechanizm zużycia materiałów oraz gwarancji zmienia ekonomię względem dawnych modeli; po wznowieniu bilansu wymaga oceny. Obecnie nie ustalamy procentów, progu gwarancji, cen ani receptur, nie modyfikujemy 17–21 i nie uruchamiamy symulacji. Przyjęcie gwarancji nie jest samo w sobie potwierdzeniem zgodności całej przyszłej płatnej oferty z zasadami platformy.

**Zasady platformy:** Roblox zalicza płatne łączenie i modyfikatory szans do paid random items, również przez walutę kupowaną za Robux. Wymaga ujawnienia rzeczywistych końcowych szans i obsługi kwalifikacji gracza. Płatna porażka nie może polegać wyłącznie na utracie zapłaty bez korzyści. Zob. [Creator Hub](https://create.roblox.com/docs/production/monetization/paid-random-items) i [Community Standards](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards), sprawdzone 23.10.2026. GE kupowane za Robux nie omijają tych zasad. Bezpłatnej ścieżki nie utożsamiać automatycznie z całym generatorem dostępnym dla wszystkich graczy.

Receptury, mnożniki, ceny i tempo z 17–21 pozostają odłożone i nie są zgodne z nowym ryzykiem z definicji; przyszła kalibracja będzie musiała je ponownie ocenić. Obecnie nie zmieniamy ich plików ani nie uruchamiamy symulacji.

## 2. Hawk i Enlightenment — D02–D03 zatwierdzone (R)

**D02 — dopuścić dojście do 100% elity.** Zachować zatwierdzone P=1+sum(b) i min(1,pBase×P), bez ukrytego spadku skuteczności i bez nowego limitu 95/99%. Nadmiar szansy ponad 100% nie zwiększa częstości ani wartości nagrody; podgląd pokazuje nasycenie, aby gracz mógł przełożyć wolne sloty na inne statystyki. Przy pBase=0 Hawk nadal nie tworzy elity.

To rekomendacja zgodności i czytelności naszej formuły, **bez zatwierdzania łatwego dostępu do stałej elity**. D02 nie przesądza, ile petów ani jak szybko pozwoli osiągnąć limit; siły i dostępność pozostają w odłożonym bilansie.

**D03 — Enlightenment jako osobna próba bez efektów petów w pierwszej wersji.** Wszystkie pety pozostają w ekwipunku i mogą być widoczne, ale ich efekty są neutralne na tym jaju. Common, Epic, mistyczny bonus, transport i właściwa reguła silosów nadal działają. Boosty zużywalne są nieaktywne, a ich pozostały czas nie maleje; zachowane wpisy wracają do działania po powrocie na zwykłą farmę. Absolutny termin podwajacza nadal upływa według zegara — nie staje się pauzowanym boostem.

**Granica wierności:** wyłączenie i pauza boostów wynika z audytu. Całkowite wyłączenie petów jest uproszczeniem adaptacji: model referencyjny ma wyjątki wyposażenia i Clarity, więc nie jest to pełne odwzorowanie jego endgame. Nie tworzyć teraz drugiego systemu kamieni ani specjalnych petów Clarity. Nie wyłączać samowolnie wszystkich eventów lub podwajacza razem z boostami; każdy z tych wymiarów ma własną bramkę.

**Zatwierdzone przez użytkownika:** D02 dopuszczalność nasycenia; D03 uproszczony zestaw ograniczeń Enlightenment. Same wzory FV i SE nie zmieniają się.

## 3. Odpowiednik reklam — D04 zatwierdzone (R)

Wcześniejsze darmowe kliknięcie było propozycją zastąpienia reklamy interakcją, nie zatwierdzoną mechaniką. Użytkownik proponuje płatność Robux albo pierwsze użycie bezpłatne i następne za GE/Robux. Następnie zatwierdził poniższy wariant: pierwsze użycie każdego dnia UTC darmowe, kolejne płatne, z ujawnioną zawartością prezentu. Nie jest to bezwarunkowo darmowa funkcja.

**Zatwierdzone D04 — podwajacz:** pierwsza aktywacja w każdym dniu UTC bezpłatna, kolejne za GE; Robux mogą być odrębnym wariantem tej samej gwarantowanej usługi. Każda aktywacja daje znany efekt ×2 i znaną długość wynikającą z badania. Zachować 2+0.5×poziom godzin (do 8 h), możliwość odnowienia przy pozostałym czasie <2 h i nadpisywanie terminu na teraz+długość, bez sumowania ze starym terminem. Odliczanie nadal trwa offline. Darmowe uprawnienie nie kumuluje się za opuszczone dni i nie jest zużywane, jeśli aktywacja nie doszła do skutku. Pro Permit sam nie daje drugiego mnożnika ani automatycznego odnawiania. To zatwierdzona adaptacja; reset UTC nie jest opisaną regułą bezpłatnej oferty modelu referencyjnego.

**Zatwierdzone D04 — bonusowy prezent:** zwykłe paczki pozostają bezpłatne. Dla odrębnego kanału bonusowego pierwsza realizacja dnia UTC bezpłatna; przy kolejnych ofertach płatność GE/Robux tylko za **pokazaną wcześniej konkretną zawartość i ilość**. Zatwierdzone D05 ustala wynik przy powstaniu oferty, więc można ujawnić go przed zakupem. Odrzucenie nie kosztuje; ponowne wejście nie zmienia wyniku ani dziennego licznika. Terminy, warunki progresji, kanał 1 i rozkłady pozostają z istniejącej specyfikacji. Nie sprzedawać tu dodatkowego losowania jako pozornie gwarantowanego prezentu.

Jeżeli zamiast ujawnionego wyniku użytkownik wybierze kupowanie zamkniętego losowego prezentu, będzie to płatny losowy wynik z wymaganiami Roblox jak w D01. Pierwszy darmowy odbiór nie zmienia kwalifikacji następnych płatnych losowań. [Zasady Roblox](https://create.roblox.com/docs/production/monetization/paid-random-items).

**Zatwierdzone D04:** reset darmowego użycia co dzień UTC, kolejne użycia za GE z opcjonalnym wariantem Robux, ujawnienie zawartości płatnego prezentu i powyższe warunki podwajacza. Pierwsza aktywacja ×2 i pierwszy odbiór bonusowego prezentu mają osobne liczniki dzienne. Ceny i wybór konkretnych produktów/podaży pozostają w odłożonym bilansie. Bez Ultra; nie zatwierdzono innych ofert przy okazji D04.

### Zatwierdzone doprecyzowania D04/D05/D07

- **R — północ UTC:** opłacone zamówienie sprzed północy zachowuje płatny charakter przy późniejszej realizacji i nie zużywa darmowego prawa kolejnego dnia. Timeout nie dowodzi anulowania.
- **R — rezerwacja:** oferta przy nierozstrzygniętej płatności jest zarezerwowana: bez drugiego zakupu, darmowego odbioru i odrzucenia. Rozłączenie zachowuje zamówienie. Dopiero potwierdzone niewykonanie zakupu przywraca zwykły odbiór; nie zgadywać anulowania na podstawie braku odpowiedzi.
- **R — Enlightenment:** istniejącą ofertę można odebrać ze stałą zawartością. GE trafia do salda, boost do ekwipunku bez automatycznej aktywacji. Zasada nie znosi warunków utworzenia nowych ofert.

Akceptacje po przeglądzie [24](24_doubler_and_bonus_gift_acceptance_review.md). Ceny i produkty pozostają odłożone, a dodatkowy limit dzienny płatnego VD nierozstrzygnięty.

## 4. Paczki i jednorazowe nagrody — D05 zatwierdzone (R)

- Przyjąć roboczy limit **2 zwykłych paczek +1 bonusowej oferty**. Miejsce zajęte od powstania oferty, również w dostawie, do odbioru lub świadomego odrzucenia. Dwa kanały mają niezależne terminy.
- Zachować losowanie I×(0.6+0.5×U), kwalifikację progresji i reguły ponowień z 16. Pełny kanał nie tworzy dodatkowej kolejki ani nie przyznaje pieniędzy. Nie zmieniać referencyjnych baz interwałów przy okazji zatwierdzania limitu.
- Oferta ma jedno ID i jeden ustalony wynik. Proponujemy ustalać rodzaj, kwotę i zastosowane modyfikatory przy jej utworzeniu; odbiór tylko realizuje ten wynik. Zmiana zestawu petów lub ponowne wejście nie losuje lepszej paczki. Jest to jawna reguła adaptacji, nie wynik audytu wszystkich referencyjnych callbacków.
- Oczekujące oferty są zachowane w zapisie wraz z ID, wynikiem i zajętym miejscem. Przerwanie połączenia nie usuwa już otrzymanej oferty, nie odnawia jej i nie przyznaje drugiej. Po powrocie można odtworzyć prezentację dostawy, bez ponownego naliczenia.
- W pierwszej wersji bez automatycznego wygaśnięcia zapisanej oferty; gracz może ją odebrać lub odrzucić. Aktualny status tej reguły rozstrzyga D05 i CURRENT_SPEC.

**Zatwierdzone D05:** limit, trwałość i moment ustalania wyniku. Zastępuje to wcześniejszy status P limitu 2+1. Sposób płatności bonusowego prezentu zatwierdzono następnie osobno w D04.

## 5. Zakres pierwszej wersji — D06 zatwierdzone (R)

**Uwzględnić:** główną ścieżkę 19 jaj z powyższym uproszczeniem Enlightenment; Common/Epic właściwe dla zachowanych systemów; transport i Hyperloop; prestiż; pety bez ekspedycji; kalendarz, drony, zwykłe i bonusowe paczki, podwajacz; trofea populacji z opisanych progów i nagród per jajo.

**Trofea:** zachowywać postęp między zmianami jaj i prestiżami. Po odblokowaniu systemu sprawdzać najwyższą osiągniętą populację danego jaja, a każdą parę jajo×próg nagradzać raz. Proponujemy dostęp po zakończeniu samouczka, z retroaktywnym uznaniem zapisanych rekordów. Ta bramka jest naszą propozycją: audyt tabel nie potwierdził pełnego referencyjnego warunku odblokowania. Nie zastępować źródłowych progów/nagród uniwersalną tabelą.

**Zadania:** na premierę krótki samouczek czynnościowy (wylęg, badanie, kurnik, transport, dron, zmiana jaja, prestiż), bez nowej powtarzalnej ekonomii i bez dopisywania niezweryfikowanych nagród GE. Jeśli ma przyznawać peta startowego lub walutę, kwota/wynik pozostają do odłożonego bilansu. Nie twierdzimy, że to opisany oryginalny zestaw misji.

**Prophecy Eggs:** na premierę wyłącznie kalendarz i trofea. Utrzymać kalendarzowy limit 24 PE; od cyklu 25 właściwa nagroda GE. PE rozliczać według jednorazowych źródeł, nie dowolnym parametrem od klienta. Brak PE z zakupów, losowych paczek i nowo wymyślonych zadań. Bez kontraktów dopływ PE różni się od referencyjnej pełnej gry; nie kompensujemy go teraz nowymi źródłami ani zmianą limitu kalendarza.

**Wydarzenia:** własny, jawny harmonogram serwera, wspólny dla wszystkich graczy bez personalizacji według wydatków. Na start zachować typy z audytowanej mapy w 11: `earnings-boost`, `prestige-boost`, `gift-boost`, `drone-boost`, `boost-duration`, `epic-research-sale`, `research-sale`, `hab-sale`, `vehicle-sale`, `boost-sale`. `piggy-boost` i `piggy-cap-boost` tylko jeśli Piggy wejdzie do wydania. Nie dodawać nowego typu zwiększającego siłę wszystkich boostów ani eventów nieobecnych systemów rakiet/craftingu. Dokładne mnożniki, odstępy, rotacja i podaż należą do odłożonego bilansu. Historyczne rozliczanie offline pozostaje zatwierdzoną zasadą.

**Poza premierą:** ekspedycje, odłamki, kamienie Clarity, handel petami, dodatkowe poziomy doświadczenia, sezonowe źródła PE i Ultra. To ograniczenie zakresu, nie twierdzenie, że nie istnieją w oryginale. Bez kontraktów i bez implementacji.

**Zatwierdzone D06:** zakres, bramka trofeów, źródła PE i samouczek bez nowej tabeli wypłat. Nie zatwierdza oferty monetyzacji ani brakujących liczb bilansu.

## 6. Zapis i spójność ekonomii — D07 zatwierdzone (R)

- Jeden aktywny właściciel sesji zapisu na gracza. Ponowne wejście po utracie połączenia przejmuje sesję dopiero po bezpiecznym zakończeniu/wygaśnięciu poprzedniej; nie nadpisuje jej starszym stanem.
- Serwer jest źródłem czasu i wyników. Zapis przechowuje postęp symulacji oraz stan pozwalający kontynuować, nie tylko czas ostatniego logowania. Restart nie może powtórnie wypłacić tego samego offline.
- Nagroda i znacznik jej realizacji stanowią jedną trwałą zmianę stanu. Powtórne żądanie z tym samym ID zwraca wcześniejszy rezultat, bez drugiej wypłaty. Kalendarz osobno pilnuje dnia serwera i kolejnej pozycji; trofea osobno pary jajo×próg; paczki własnego ID.
- Zakup powtarzalnego produktu ma trwały identyfikator transakcji, weryfikowany przez serwer. Utrata połączenia nie gubi opłaconej korzyści i nie pozwala jej dublować. Gamepass to odrębne trwałe uprawnienie. Nie wybieramy teraz cennika, oferty ani bibliotek.
- Zapisywać terminy i historię eventów/uprawnień potrzebną do naliczenia ich rzeczywistego okresu. Nowo kupiona korzyść nie działa wstecz na wcześniejsze offline.
- Dla kwot farmy i FV stosować reprezentację dużych liczb z określoną precyzją, a liczniki, GE, ID i znaczniki odbioru zachowywać dokładnie w ich dozwolonym zakresie. SE w oryginale jest double; nie zmieniać samowolnie jego funkcji i zaokrągleń. Przyszły moduł matematyczny trzeba porównać z zapisanymi przypadkami FV/SE i granicami konwersji. Sam zapis mantysa/wykładnik nie gwarantuje dokładności wszystkich typów wartości.

Przegląd przekazanych scenariuszy: [23](23_pet_fusion_acceptance_review.md). Zachowuje historyczne korekty oraz aktualizację: użytkownik następnie zatwierdził definicję stopnia i ochronę kopii. Przegląd nie jest wykonaniem testów.

**R — struktura monetyzacji:** Pro zawiera referencyjne korzyści silosów/offline/boostów oraz rozszerzenie petów i bonus +10 p.p.; Buy MAX i Auto-Hatch kurczaków są osobnymi passami, GE i Piggy zakupami powtarzalnymi. Szczegóły i wyłączenia: [25](25_approved_product_structure.md). Bez zatwierdzenia cen, slotów inkubacji lub terminu premiery tych dodatków.

**R — premiera i wariant A:** [26](26_approved_launch_scope_and_pro_availability.md) zatwierdza Rainbow jako koniec v1, Pro/Buy MAX/GE na premierę, Piggy warunkowo po bilansie, Auto-Hatch/VIP później oraz Pro bez niedostępnego +10 p.p. z jawnym opisem przed zakupem. Bez automatycznego zamiennika.

## Rejestr odpowiedzi użytkownika

| ID | Aktualny status |
|---|---|
| D01 | R: premium +10 p.p. zamiast dopłat do każdej próby. R: stopień = tier pochodzenia × cel; wcześniejsze zdjęcie/odblokowanie i brak automatycznej podmiany materiałów. R: chroniony pet bazowy, zużycie pozostałych kopii przy porażce i trwały licznik gwarancji. Procenty bazowe/receptury/próg/ceny odłożone. |
| D02 | R — zatwierdzone: dopuszczalne 100% elity i jawne nasycenie; bez strojenia Hawka. |
| D03 | R — zatwierdzone: Enlightenment bez efektów petów i bez Clarity w v1; pauza boostów. |
| D04 | R — zatwierdzone: pierwsze użycie dnia UTC darmowe, następne GE / opcjonalnie Robux; podwajacz gwarantowany, płatny prezent z zawartością ujawnioną przed zakupem. Ceny odłożone. |
| D05 | R — zatwierdzone: 2+1, trwała oferta i wynik od utworzenia, brak wygaśnięcia. |
| D06 | R — zatwierdzone: zakres premiery, trofea po samouczku, PE z kalendarza/trofeów. |
| D07 | R — zatwierdzone: serwerowy czas, jedna sesja i trwałe jednokrotne rozliczenia. |

Akceptacja zasad nie zatwierdza liczb odłożonego bilansu i nie uruchamia implementacji. Backup sprzed propozycji: ZIP. Backup sprzed zapisania odpowiedzi: ZIP.
