# Ceny inkubatorów i tempo rozwoju petów

> **Nowszy wynik:** [19. Zintegrowana symulacja progresji](19_integrated_farm_progression_simulation.md), 40 przebiegów i kontrola 28 dni z krokiem 0.3 s. Aktualna propozycja obniża V z 1.5e57 do **1.5e55**. Poniższe kotwice i scenariusze pozostają wcześniejszym etapem; nie są pełną prognozą progresji.

23.10.2026. **Kalibracja wariantu projektu, bez implementacji.** Uzupełnia i w zakresie cen oraz rozkładu V zastępuje propozycję 0.1 z [17](17_pet_balance_draft.md). Nowe zasady inkubacji i prawdopodobieństwa są rekomendacją, nie wcześniej zatwierdzoną decyzją użytkownika. Zweryfikowane wzory farmy pozostają bez zmian.

## 1. Wynik

Samą stałą ceną za gotówkę nie da się utrzymać tempa petów w całej progresji. Po awansie wartość jaja, badania i SE zwiększają dochód; stary inkubator staje się pomijalnym wydatkiem. Podniesienie jego ceny na tyle, żeby spowolnić Universe, zablokowałoby nowego gracza na Edible. Ten problem występuje również bez boostów i bez płatnych przewag.

Rekomendowany wariant:

- Zachować stałe ceny w gotówce; wyprodukowane i sprzedane jaja nie są dodatkową walutą.
- Obniżyć koszt referencyjny III–V do odpowiednio 60, 45 i 30 sekund dochodu. Starsze 120/180/300 sekund były zbyt wysokie dla rzadkich ewolucji przy małym budżecie.
- W V podnieść Phoenix z 2.7% do 4%, Alien z 0.3% do 1%; odjąć po 1 pp Roosterowi i Chickowi. Pozostałe tiery bez zmian.
- Dodać **wspólny dla wszystkich inkubatorów zasób inkubacji**: 1 ładunek za 60 sekund kwalifikowanej produkcji, 1 ładunek na otwarcie. Zasobu nie mnożą pety, boosty, wydarzenia ani liczba slotów. Nie jest to wydłużenie animacji ani timer osobny dla każdego inkubatora.

Ostatnia zasada jest nową mechaniką Roblox. Bez niej wariant ma policzone ceny startowe, ale **nie ma stabilnego tempa w późnej grze**. Rekomendacja nie jest zatwierdzoną regułą HatchTheEgg.

## 2. Skąd ceny

Dla Edible punkt odniesienia to 100 kur, wartość 0.25, tempo 1/30 jaja/kura/s, wystarczający transport, bez badań, petów i pozostałych bonusów: dochód 0.833333…/s. Nie jest to założenie, że każda farma startuje ze 100 kurami.

Dla pozostałych inkubatorów wykorzystujemy potwierdzone progi awansu z [02](02_eggs_and_farm_value.md) jako **kotwice ekonomiczne**, a nie fikcyjny eksport konta. W szczególnym modelu pełnej farmy, bez członu wolnych miejsc i przyszłego IHR, z R=1 oraz valuation=1, wzór FV daje `FV=50*K*income`. Po zmianie gatunku jaja skalujemy ten ekwiwalent dochodu stosunkiem wartości nowego i poprzedniego jaja:

```text
R_ref = prógAwansuDoNowegoJaja / (50*K_poprzedniegoJaja)
        * wartośćNowegoJaja / wartośćPoprzedniegoJaja
C = zaokrąglenie_do_2_cyfr_znaczących(T*R_ref)
```

To **analityczny ekwiwalent dochodu przy progu**, nie dowód osiągalnego stanu farmy. W prawdziwym FV dochodzą człony IHR/wolnych miejsc i maksymalnego RCB; zmiana jaja resetuje populację i badania. Dlatego poniższe ceny są konkretnym wariantem do dalszego strojenia, a nie obietnicą czasu od wejścia na nowe jajo. Nie wolno z tych kotwic wyprowadzać liczby dni do Universe.

| Inkubator | Jajo | R_ref / s | Cena / otwarcie | Rzeczywiste C/R_ref po zaokrągleniu |
|---|---|---:|---:|---:|
| I | Edible | 0.833333 | 25 | 30 s |
| II | Superfood | 5666.666667 | 340 000 | 60 s |
| III | Fusion | 1.296296296e12 | 7.8e13 | 60.1714 s |
| IV | Tachyon | 2.518518519e21 | 1.1e23 | 43.6765 s |
| V | Universe | 4.938271605e55 | 1.5e57 | 30.375 s |

Kwoty w notacji naukowej są wartościami liczbowymi. Formatowanie skrótów UI nie zmienia ceny. Cena nie zależy od aktualnego dochodu, wyposażenia, salda ani wyniku poprzedniego losowania. Po prestiżu można korzystać z odblokowanego inkubatora, jeśli wystarcza gotówki i ładunków; droższe inkubatory nie stają się automatycznie tanie na Edible.

### Konkurencja z wydatkami farmy

Porównanie z cenami wydobytymi z referencyjnego ResearchEngine, bez zniżek:

| Inkubator | Przykład wydatku o podobnym koszcie |
|---|---|
| I: 25 | Comfortable Nests, poziom 6: 25.01999; drugi poziom Nutritional Supplements: 19.00733 |
| II: 340 000 | Pierwszy Short House: 340 831.26 |
| III: 7.8e13 | Lightweight Boxes, poziom 15: 7.81016e13 |
| IV: 1.1e23 | Super Alloy, poziom 26: 1.08054e23 |
| V: 1.5e57 | Matter Reconfiguration, poziom 177: 1.54154e57 |

To porównanie wartości pojedynczych zakupów, **nie** deklaracja, że wszystkie wymienione poziomy są już odblokowane przy pierwszym wejściu na dany gatunek. Nie symulowano sekwencji zakupów, bramek tierów ani kosztu dojścia do tych poziomów. I nie powinien być obowiązkowym wydatkiem przed podstawowym kurnikiem; rekomendujemy jeden darmowy, **deterministyczny Normal Pup I** w samouczku, przyznawany raz na konto. Nie przyznawać go ponownie po prestiżu. Dalsze otwarcia są losowe.

## 3. Ładunki — doprecyzowanie rekomendacji

- Początkowe saldo 0; samouczkowy Pup jest osobną nagrodą. Pierwsze zwykłe losowanie wymaga zgromadzenia zasobu.
- Jeden wspólny licznik z zachowaniem ułamka 60 sekund. Saldo maksymalnie 120; po zapełnieniu dalszy czas nie tworzy długu ani zaległej kolejki.
- Ładunki powstają online podczas zwykłej symulacji farmy i offline tylko w jej kwalifikowanym oknie produkcji przed wyczerpaniem silosów. Nie zależą od liczby wyprodukowanych jaj, liczby kur ani siły mnożnika. Czas bez produkcyjnej symulacji po wyczerpaniu silosów nie nabija zasobu.
- Nie naliczać jednocześnie czasu online i jego ponownego rozliczenia jako offline. Zachować saldo po prestiżu/zmianie jaja, bez darmowego napełniania po tych czynnościach.
- Zasobu nie można kupić ani przyspieszyć w tym wariancie. Trzy i pięć slotów mają takie samo tempo jego powstawania. Różna pojemność silosów nadal może dawać różne okno produkcji offline — nie obiecujemy identycznego postępu kalendarzowego dla Pro i F2P.
- Ładunek oraz gotówka są zużywane razem przy skutecznym otwarciu. Bez środków nie ma losowania ani ujemnego salda. To reguła ekonomii, nie opis gotowego kodu.

Limit 120 pozwala zachować dwie godziny zasobu. Jest jawnym kompromisem: dłuższa nieobecność może utracić część przyrostu ładunków, nawet jeśli silosy nadal produkują gotówkę. Należy go ocenić wraz z docelową długością sesji. Brak dobowego resetu, handlu, wymiany duplikatów i pity w tej kalibracji.

Zgromadzone ładunki i gotówka pozwalają otworzyć wiele jaj naraz. „1/min” jest tempem odnawiania, **nie zakazem szybkiego zużycia zapasu**. Dla n otwarć, początkowych q ładunków i gotówki B, przy stałym R i budżecie b:

```text
czas >= max(0, (n-q)*60, (n*C-B)/(b*R))
```

W modelu zakładamy możliwość równoległego gromadzenia obu zasobów i ich natychmiastowego wydawania. Interfejs, niepełne saldo i przerwy mogą zwiększyć czas. Wyniki poniżej używają q=B=0, stałego dochodu i braków strat na limicie salda.

## 4. Losowanie i ewolucja

V po korekcie: **Pup 22%, Rooster 22%, Chick 27%, Cow 15%, Hawk 9%, Phoenix 4%, Alien 1%**. Suma 100%. I–IV: tabela z 17. Siły petów oraz proponowane receptury 5 Normal → Golden i 3 Golden → Rainbow nie zmieniają się w tej kalibracji. Tier musi się zgadzać; nie łączymy tanich kopii I w peta V.

`E[N]=k/p`, gdzie k=1/5/15 dla Normal/Golden/Rainbow. Granica 95% to najmniejsze n spełniające `P(Binomial(n,p)>=k)>=0.95`; nie zastępować jej średnią ani 15-krotnością kwantyla pierwszej kopii. Każde otwarcie ma niezależne p. Wynik 95% **nie jest gwarancją**.

### Dolne tempo długoterminowe przy dostatecznej gotówce

Średnie godziny odnawiania ładunków od pustego salda, przy jednym otwarciu/minutę:

| Pet V | Normal | Golden | Rainbow | Rainbow: próg 95% |
|---|---:|---:|---:|---:|
| Pup | 0.076 h | 0.379 h | 1.136 h | 1.600 h |
| Hawk | 0.185 h | 0.926 h | 2.778 h | 4.000 h |
| Phoenix | 0.417 h | 2.083 h | 6.250 h | 9.067 h |
| Alien | 1.667 h | 8.333 h | 25.000 h | 36.417 h |

W I Pup ma p=55%: Golden średnio po 9.09 otwarciach, Rainbow po 27.27, czyli około 9 i 27 minut produkcji przy dostatecznej gotówce. **To może być szybkie**, lecz jest to podstawowy pet I; pełny zestaw trzech Rainbow Pupów kosztuje średnio 81.82 otwarcia, a nie 27.27. Pierwszy tutorialowy Pup zmniejsza potrzebne dalsze kopie odpowiednio o jedną; powyższy ogólny wzór go nie odejmuje. Wczesna ewolucja jest celowo widoczna podczas pierwszych sesji, zamiast uzależniać cały system od zdobycia Mythica.

### V przy budżecie 20% dochodu referencyjnego

Jedno otwarcie wymaga 151.875 s na gotówkę, więc tutaj gotówka jest ograniczeniem silniejszym niż ładunki:

| Pet V | Normal: średnio | Golden: średnio | Rainbow: średnio | Rainbow: próg 95% |
|---|---:|---:|---:|---:|
| Pup | 0.192 h | 0.959 h | 2.876 h | 4.050 h |
| Hawk | 0.469 h | 2.344 h | 7.031 h | 10.125 h |
| Phoenix | 1.055 h | 5.273 h | 15.820 h | 22.950 h |
| Alien | 4.219 h | 21.094 h | 63.281 h | 92.180 h |

To godziny kwalifikowanej produkcji przy stałej farmie, nie koniecznie godziny patrzenia na ekran. Przy efektywnych dwóch godzinach takiej produkcji dziennie średni Alien Rainbow V oznacza około 32 dni, a poziom 95% około 47 dni. Przy szybszej farmie i dostatecznej gotówce średnia spada do 12.5 takich dni dzięki granicy 25 godzin na ładunki. Nie są to prognozy retencji ani całej drogi do inkubatora V.

## 5. Wrażliwość i obejścia

V, budżet 20%, cel Alien Rainbow, brak początkowych zasobów:

| Dochód względem R_ref | Tylko gotówka: średnio | Gotówka + rekomendowane ładunki: średnio |
|---|---:|---:|
| 0.1× | 632.813 h | 632.813 h |
| 1× | 63.281 h | 63.281 h |
| 10× | 6.328 h | 25 h |
| 1000× | 0.0633 h | 25 h |
| 22500× | 0.00281 h | 25 h |

Ostatni wiersz jest **stałym scenariuszem wrażliwości**, nie założeniem legalnego nieprzerwanego zestawu boostów przez cały wymagany czas. Model nie zużywa boostów ani GE. Pokazuje, dlaczego mnożnik dochodu nie powinien sam określać tempa całego systemu petów.

Przy zaledwie 0.1 R_ref zbieranie najrzadszej ewolucji jest zbyt wolne. Zalecany kierunek gry: najpierw rozwijać farmę, kupować Normal/Golden i przechodzić dalej, zamiast wymagać Rainbow do awansu. **Żaden awans jaja nie powinien wymagać petów ani ukończenia kolekcji** w tym wariancie.

Przykład obejścia cen: na kotwicy Universe otwieranie I za gotówkę nie stanowi praktycznie żadnego kosztu ekonomicznego. Nie wyciągamy z absurdalnie małej wyliczonej liczby sekund wniosku o szybkości interfejsu — ograniczeniem stałyby się kliknięcia/animacja. Wspólny zasób uniemożliwia wykorzystanie osobnych timerów I–V do pięciokrotnego zwiększenia podaży. Nie istnieje również premia za otwarcie nowego serwera czy prestiż.

Przy wspólnym zasobie wyższy tier ma większą szansę Phoenix/Aliena i większą premię. Gdy gotówki wystarcza, losowanie niższego tieru nie daje przewagi liczby prób na godzinę. Gdy gotówki brakuje, starszy tier pozostaje rozsądnym źródłem słabszych petów. To zamierzone, nie wymagamy powrotu do starego gatunku jaja.

## 6. Czy tempo jest właściwe

**Warunkowo tak dla rekomendowanego wariantu:** zwykłe pety i pierwsze Golden dają krótkoterminowy postęp, Rainbow rzadkich gatunków jest celem wielosesyjnym. Alien V po korekcie ma znacznie mniejszy koszt oczekiwany niż pierwotne 5000 otwarć, a wspólne ładunki ograniczają przyspieszenie przez bardzo wysoki dochód. Wariant wyłącznie za stałą gotówkę nie spełnia celu stabilnego tempa późnej gry.

Pozostają trzy istotne granice:

1. **Siła Hawka:** dwa Rainbow Hawki V osiągają 100% elity przy bazie 8%. Wymagają 30 kopii, średnio 333.33 otwarcia: 5.56 h przy dostatecznej gotówce lub 14.06 h na kotwicy V z budżetem 20%. Cena nie naprawia trwałego nasycenia efektu. Jeżeli stała elita ma być rzadka, trzeba obniżyć premię Hawka lub jego ewolucji.
2. **Pięć slotów:** sama inkubacja nie jest szybsza, lecz końcowy zestaw Pup/Alien wciąż może dawać około 2.508× przewagi wobec trzech slotów. Koszt petów opóźnia dojście do zestawu, nie usuwa tej przewagi.
3. **Pełna progresja:** nie wykonano polityki zakupu badań, resetów i rozwoju populacji przez wszystkie jaja. Kotwice FV nie zastępują takich trajektorii. Ceny wymagają w przyszłości walidacji na działającej symulacji lub konkretnych profilach gracza; obecnie nie ma podstaw twierdzić, że progresja całej gry jest już zbalansowana.

Wybór ładunków, ich pojemności, nowej szansy V i deterministycznego tutorialowego Pupa pozostaje propozycją. Nie zmieniono wzorów FV/prestiżu ani zatwierdzonego sumowania petów. Enlightenment i zamiennik reklamowych prezentów nadal wymagają osobnych zasad.

## 7. Dowody i zakres obliczeń

dokumentacja referencyjna generuje dokumentacja referencyjna: pięć kotwic cen, 105 kombinacji tier/gatunek/ewolucja, 1620 scenariuszy wrażliwości i 10 porównań starszych inkubatorów z późniejszym dochodem. Kwantyle pierwszej kopii sprawdzono dodatkowo względem wzoru geometrycznego; dla ewolucji sprawdzono minimalność progu 50% i 95%.

Dane źródłowe: dokumentacja referencyjna, progi awansu z 02 i propozycje z 17. Hash parametrów zapisano w wyniku. To analityczne obliczenia rozkładów i scenariuszy, **nie 1620 pełnych rozgrywek**, nie wykonanie biblioteki referencyjnej i nie kod Roblox. Starszy wynik pet_balance_validation.json nadal opisuje wcześniejszy wariant 0.1, a nie nowe prawdopodobieństwa.
