# Kierunek bilansu: gracz płacący i progresja HatchTheEgg

> Wyniki kolejnego etapu: [21. Progresja płacącego gracza i inkubacja](21_payer_progression_and_incubation.md). Wykonano 61 przebiegów i zapisano propozycję v3. Poniższy dokument ustala wcześniejszy kierunek oraz plan, nie zastępuje nowszych wyników.

23.10.2026. **Potwierdzony kierunek użytkownika:** przy kolejnej optymalizacji priorytetem jest doświadczenie gracza wydającego pieniądze. Zachowujemy bliskie model referencyjnyowi spowolnienie późnej progresji i znaczenie płatnych przyspieszeń. Nadal wyłącznie dokumentacja i analiza, bez implementacji gry.

## 1. Co zmienia się względem poprzedniego etapu

Wolniejsze F2P nie oznacza samo w sobie błędu cen. Nie próbujemy automatycznie doprowadzić darmowego konta do Universe w miesiąc ani usuwać wszystkich barier zakupu. Ważne jest, czy po spowolnieniu nadal istnieje postęp i sensowne decyzje: prestiż, rozbudowa, badania, oszczędzanie GE i przygotowanie boostów.

Główny profil bilansu to **Pro + rozwijane Epic Research + finansowany, poprawnie dobrany zestaw boostów**, z osobnym porównaniem dodatkowych slotów petów. F2P pozostaje punktem odniesienia oraz ścieżką poznania gry i przejścia do pierwszego zakupu. Nie utożsamiać głównego profilu z kontem mającym od razu wszystkie badania i ogromne SE.

**Cena Universe 1.5e55 z rozdziału 19 pozostaje przebadanym wariantem, a nie zamrożoną ceną.** Obniżenie jej ze 1.5e57 o 100× pomagało słabszemu profilowi zaawansowanemu. Nie wykazano jednak, że jest potrzebne dla docelowego gracza płacącego. Przed rozstrzygnięciem ceny trzeba porównać pełne finansowane profile. Nie zmieniono historycznych wyników ani pliku propozycji v2; nie przywrócono też automatycznie starej ceny.

## 2. Odtwarzamy źródła przewagi, nie samą długość czekania

| Element | Rola w docelowym bilansie |
|---|---|
| Pro Permit | Dłuższy offline, jakość przychodu offline 1 zamiast 0.5, pięć aktywnych boostów zamiast dwóch; osobny produkt od slotów petów |
| GE i Piggy | Finansowanie trwałych Epic Research, Hyperloop oraz zużywalnych boostów; liczyć źródło każdej wpłaty i późniejsze wydatki |
| Zestawy boostów | Krótka faza dużego wzrostu lub korzystnego prestiżu; skończony czas, koszty, wymagane SE i dostępne sloty |
| Pety | Zestawy pod konkretną czynność; płatne 5 slotów może dawać realną przewagę, której nie trzeba automatycznie wyrównywać z 3 |
| Wygoda | Mniej ręcznych czynności i lepsze wykorzystanie sesji; zakup ma jasno określony efekt |

Zakup nie musi omijać całej gry. Dobrze dobrany zestaw powinien pozwolić osiągnąć zauważalny cel, po którym pojawia się następny etap badań, populacji i prestiżu. Powtarzalna wartość może wynikać z kolejnych zużywalnych boostów i rozwoju Piggy; nie wymaga kasowania kupionych korzyści ani zmieniania szans po rozpoznaniu płacącego konta.

## 3. Profile następnego porównania

| Profil | Zasoby i produkty do jawnego zadania |
|---|---|
| F2P kontrolny | Bez zakupów, rzeczywiste darmowe GE, 3 pety, 2 boosty |
| Pierwszy zakup | Pro, bez dodatkowej dotacji GE; badania i SE nadal zdobywane w modelu |
| Stałe ulepszenia | Pro + 5 petów; nie dodawać z tego tytułu darmowych GE ani maksymalnych badań |
| Umiarkowany zakup GE | Poprzedni profil + zadany pakiet GE; pełny bilans zakupu i wydania, porównanie inwestycji w Epic oraz boosty |
| Regularne zakupy | Ten sam profil z jawnym harmonogramem kolejnych pakietów/rozbić Piggy; skończony budżet i stan Piggy |

Rozmiary pakietów, ceny Robux i częstotliwości zakupów są parametrami do przetestowania, nie oszacowaną gotowością klientów do płacenia. Starsze ceny Robux w 08 pozostają koncepcją. Nie zakładać, że każdy klient kupuje wszystkie produkty ani że wyższy wydatek automatycznie daje lepszą retencję.

Wykonać osobne strategie: wzrost populacji, prestiż, oszczędzanie na większy zestaw oraz rozwój trwałych badań. Gracz płacący nie powinien być reprezentowany przez tę samą prostą politykę, która stale kupuje małe boosty i nigdy nie zbiera na potrzebny duży zestaw.

## 4. Kryteria oceny

- Czas do pierwszego widocznego efektu zakupu: awans jaja, odblokowanie badania, wzrost SE albo osiągnięcie celu populacji.
- Porównanie tempa F2P/Pro/Pro+GE przy tych samych sesjach i początkowej progresji; osobno efekt każdego produktu.
- Ile postępu daje pojedynczy sfinansowany zestaw i na ile kolejnych sesji pozostawia użyteczne korzyści.
- Czy po zakupie pojawia się kolejny cel, czy gracz jedynie wpada natychmiast na tę samą barierę.
- Koszt GE i liczba aktywacji na etap, wykorzystanie czasu boostów, ograniczenia transportu i kurników, efektywność prestiżu.
- Długoterminowo: powroty D1/D7/D28, konwersja do pierwszego zakupu, odsetek kupujących ponownie, przychód na płacącego oraz dni z zakupem. Te wskaźniki wymagają danych graczy; obecna symulacja nie przewiduje konwersji, retencji ani przychodu w Robux.

Duża przewaga płatnego zestawu nie jest automatycznie usterką. Trzeba sprawdzić, czy daje wartościowy postęp i pozostawia długoterminową progresję. Nie nadawać z góry jednej docelowej proporcji przyspieszenia bez testów.

## 5. Inkubacja wymaga ponownej oceny

Wspólne ładunki 1/min i saldo 120 są **niezatwierdzoną propozycją**, która ogranicza nadmierną podaż petów. Wyniki 19 potwierdzają potrzebę kontroli podaży, ale nie dowodzą, że właśnie ten mechanizm jest najlepszy dla modelu płatności.

Ten sam sztywny limit może sprawić, że dodatkowy dochód za GE nie daje już korzyści przy zbieraniu petów. Z kolei Pro z długim offline może tracić większość przyrostu na saldzie 120. Dlatego nie przyjmować bez dalszego testu, że płacący i F2P muszą mieć identyczną pojemność lub tempo inkubacji. Porównać większą pojemność, sprawniejsze otwieranie albo jawne przyspieszenie jako osobne warianty projektu. Niczego takiego jeszcze nie zatwierdzono ani nie wdrożono.

Nie zastępować automatycznie niewykorzystanych ładunków płatnym losowaniem. Jeżeli przyszła oferta pozwoli kupić losowe wyniki bezpośrednio lub pośrednio za Robux, trzeba osobno określić zasady takiej oferty. Obecny kierunek monetyzacji nie zatwierdza nowych płatnych jaj ani zmian prawdopodobieństw.

## 6. Jak czytać poprzednią symulację

40 przebiegów z 19 jest użytecznych do oceny podaży petów i wrażliwości cen. **Nie stanowią jeszcze testu docelowego płacącego klienta.** W głównych przebiegach nie było Pro, a jawne profile zaawansowane otrzymywały maksymalne Epic Research, SE/PE i GE na starcie. Nie przedstawiać ich jako historii zakupów od nowego konta.

Przed końcową kalibracją płatnych zestawów trzeba uzupełnić dochód o rzeczywiste RCB, gotówkowe drony/prezenty i wybrane wydarzenia. RCB=1 oraz pominięte źródła gotówki z 19 mogą zmieniać ocenę wydajności mocnych boostów. Wydarzenia offline nadal rozliczamy historycznie, zgodnie z decyzją użytkownika.

Zachowujemy zweryfikowane wzory i ich ograniczenia. Nie zmieniamy FV ani funkcji SE tylko po to, aby uzyskać wcześniej założoną długość czekania. Nie skracamy również automatycznie referencyjnych spowolnień wyłącznie dlatego, że profil F2P rozwija się wolno.

## 7. Co faktycznie wiadomo o rekomendacjach Roblox

Według [Roblox Discovery](https://create.roblox.com/docs/discovery) monetyzacja jest sygnałem rekomendacji: liczą się m.in. dni z wydatkiem i Robux na użytkownika. Dokumentacja nadaje najwyższy priorytet także wejściom do gry, pierwszym szybkim wyjściom, dniom powrotów i czasowi gry. Są to wskaźniki na użytkownika, a nie ranking łącznych zarobków gry.

[Discovery FAQ](https://create.roblox.com/docs/discovery-faq) wyjaśnia, że nie ma jednego sygnału decydującego o pozycji i że dobre wyniki monetyzacji oraz retencji mogą działać wspólnie. **Wniosek projektowy:** optymalizować długoterminową wartość zakupów i powroty płacącego klienta, zamiast zakładać, że sama większa presja zakupowa zapewni dystrybucję. Weryfikacja źródeł: 23.10.2026.

Ten etap ustala kierunek i kryteria następnych badań. Nie wykonano nowej symulacji profili płatnych ani nie oszacowano przychodu.
