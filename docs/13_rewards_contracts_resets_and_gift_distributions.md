# Nagrody, konwersje, resety i rozkłady prezentów

> **Specyfikacja referencyjna po redakcji.** Zawarte przykłady nie stanowią wykonania testów implementacji HatchTheEgg. Aktualne decyzje R rozstrzyga [CURRENT_SPEC](CURRENT_SPEC.md).

## 2. Odbiór nagród i konwersje

### Maksymalne badania epickie

`collectReward`, dla referencyjnego typu 6:

1. Rozpoznaje ID badania. Sentinel 24 oznacza nierozpoznane ID i brak wypłaty w tej gałęzi.
2. Zamienia kwotę na signed int32 przez obcięcie; kwoty <1 po tej konwersji nie przyznają poziomów.
3. Przetwarza sztuki kolejno: jeżeli poziom jest niższy od maksimum, dodaje poziom; w przeciwnym razie dodaje GE równe `finalEpicLevelPrice[id]`, po konwersji do całkowitych GE.

Wartość `finalEpicLevelPrice[id]` odpowiada cenie ostatniego poziomu badania, **nie sumie wszystkich cen ani aktualnej cenie po wyprzedaży**. Potwierdzono 144 scenariusze dla wszystkich 24 rozpoznawanych badań, początkowego poziomu max−1/max i kwot 1/3/2.75. Przykład: Hold to Hatch na maksimum daje 500 GE za każdą nadmiarową sztukę. Testy obejmują także przejście przez maksimum w jednej nagrodzie.

Mapowanie tekstowych ID sprawdzono dodatkowo na referencyjnych parserach: 24 ID badań i 33 ID boostów. Arytmetyka konwersji była testowana osobno od mapowania.

### Inne typy i Piggy

Identyfikatory kategorii nagród wymagają jawnego mapowania w przyszłym formacie konfiguracji; nie należy utożsamiać numerów z różnych tabel.

| Referencyjny RewardType | Mutacja w sprawdzonej gałęzi collectReward |
|---|---|
| 0 GE | Dodanie kwoty do salda, konwersja wyniku do uint64. |
| 1 / 2 cash | Dodanie do gotówki farmy i `SimEngine.lastCashEarned`; brak bezpośredniego dodania do historycznych akumulatorów. |
| 4 SE | Dodanie do puli SE przechowywanej jako double. |
| 5 PE | Wywołanie `ContractsManager::updateEOP`, czyli ponowne przeliczenie źródeł PE. |
| 6 epic research | Poziomy lub GE za nadmiarowe sztuki, jak wyżej. |
| 7 Piggy fill | Dodanie surowej kwoty do banku Piggy. Ta gałąź nie stosuje limitu ani `piggyGrowthMult`. |
| 8 Piggy multiplier | Nowy surowy bank = `uint64(oldBank*amount)`. |
| 9 Piggy level | Dodanie do przechowywanego licznika poziomu, z konwersją do uint64. |
| 10 boost | Dodanie `int32(amount)` sztuk do rozpoznanego indeksu ekwipunku; sentinel 33 pomijany. |
| 14 Shell Scripts | Dodanie do licznika, z konwersją do uint64. |

Testy arytmetyki: 32 przypadki walut/Piggy i 15 ekwipunku boostów. Nie są to testy wszystkich typów nagród kontraktowych/artefaktowych ani całej prezentacji odbioru.

### Bonus poziomu Piggy i Ultra

Przechowywany licznik poziomu to `k`, a funkcje bez parametru używają `L=k+1`. Ustalona tabela bonusów dla L=0/1/2/3 to 0%/2%/25%/40%; od L=4 obowiązuje `float32(0.5+0.1*(L−4))`. Pierwsze wpisy używane przez sprawdzone funkcje odpowiadają również wartościom po precyzji float32. Nie zastępować ich jednym wzorem od pierwszego poziomu.

```text
withLevel = rawPiggy + uint64(rawPiggy * levelBonus)
withAll   = withLevel + uint64(withLevel * ccBonus)
```

Obcięcie następuje **osobno na obu etapach**. `ccBonus` wynosi 0.25 dla poziomu Ultra Standard lub 0.4 dla Pro, gdy lokalny status subskrypcji to 1/4 i `now < cachedTimestamp+1500`. Przy równości terminowi wynosi 0. Sprawdzono 336 kombinacji poziomu, kwoty, statusu i granicy czasu; nie jest to potwierdzenie subskrypcji rzeczywistego konta. Przypisanie pól statusu/poziomu opiera się na schemacie `UserSubscriptionInfo`; testowano lokalny predykat, nie płatność.

### PE z kalendarza

`ContractsManager::updateEOP`, przelicza PE ze źródeł konta. Składnik kalendarza wynosi `min(24, trunc(num_daily_gifts_collected/28))` dla prawidłowego nieujemnego licznika. Kontrolowane konto bez kontraktów, sezonów i trofeów zwracało właśnie tę liczbę; ponowne przeliczenie jej nie zwiększało. Sam parametr amount w nagrodzie typu 5 nie jest poleceniem dodania dowolnej liczby PE.

Callback odbioru zwiększa licznik prezentów **przed** wypłatą. Dzięki temu odbiór dnia 28 uwzględnia nowy pełny cykl przy przeliczeniu PE. `collectCalendarGift` dla odpowiedniej późnej pozycji PE zamienia ją na 100000 GE; potwierdzono granice w testach złożonych i wrappera. Pełne sumowanie PE z rzeczywistych kontraktów/sezonów/trofeów nie jest objęte kontrolowanym kontem.

### Ponowny odbiór i atomowość

Rozdzielono trzy warstwy:

- `collectReward`: brak sprawdzenia dnia czy identyfikatora wypłaty; dwa wywołania po 192 GE dały 384 GE.
- `collectCalendarGift`,: wybiera nagrodę/konwersję, ale nie zwiększa licznika odebranych prezentów i nie blokuje powtórnego wywołania.
- Właściwy callback: przy parametrze bool=true pomija gałąź wypłaty; przy bool=false zwiększa licznik, wypłaca nagrodę i zapisuje dzień serwera oraz czas. W kontrolowanym dwukrotnym wywołaniu tego samego callbacku licznik wzrósł 1→3 i wypłata została wywołana dwukrotnie.

## 4. Soul Mirror, tokeny i dochód jednorazowy

### Soul Mirror

`currentCoopTopPlayerEarningsBonus`, pobiera aktualny coop status i wybiera maksimum materiał techniczny, przechowywanego jako log10. Aktywność, ban_votes i podobne flagi nie są filtrami w tej konkretnej funkcji.

```text
top = 1                              // brak coop status
// gdy status istnieje:
top = 10 ^ max(0, soul_power graczy)  // również 1 dla pustej listy
```

`GDR.totalEarningsMultiplier`, przy aktywnym Mirror **zastępuje własny składnik SE/PE/Eggs of Truth przez top**. Potem mnoży przez `GDR.earningsMult()` i `_autoPlayEarningsMult()`. Nie mnoży top ponownie przez własny EB. Wykonano 6 scenariuszy top i 12 pełnej funkcji GDR, m.in. top=1000, earnings=2500 → 2500000 przed podwajaczem wideo. Przeliczenie top jest bieżącym odczytem kooperacji; nie jest kwotą zamrożoną przy aktywacji Mirror.

Warunki aktywacji, pojedynczy Mirror i wyłączenie Soul Beacon w kontrakcie pozostają opisane w rozdziale 11. Testy nie uruchamiały serwera kooperacji ani pełnego przeliczania materiał techniczny u wszystkich graczy.

### Tokeny

- `secondsPerBoostToken`,: dodatni interwał z opisu kontraktu w minutach ×60. Brak kontraktu lub wartość niedodatnia daje fallback **10000 s**. 12 scenariuszy z kontrolowanym wyszukaniem kontraktu.
- `availableBoostTokens`,: `received − spent − given`. Niespójny stan z wynikiem ujemnym zawija uint32; nie ma w tej funkcji clamp do 0. 4 scenariusze.
- `boostTokenProgress`,: na kontrakcie `(interval−remaining)/interval`, poza kontraktem 0. Nie zaciska wyniku do [0,1]. 10 scenariuszy.
- Początek `BoostManager::update`: na własnej farmie kontraktu odejmuje dt od remaining. Przy wyniku <=0 zwiększa received o **jeden** i ustawia remaining na pełny interval. Nie zachowuje nadmiaru czasu i nie wykonuje tu pętli nadrabiającej wiele tokenów w jednym wywołaniu. 10 scenariuszy, w tym krok 180 s przy interwale 60 s. Zwykły SimEngine dzieli czas na małe kroki; wynik jednego dużego dt nie jest całym algorytmem offline.

Potwierdzona aktywacja najpierw zapisuje aktywny boost i jego czas, odejmuje sztukę z ekwipunku oraz zwiększa licznik użyć; dopiero potem ponownie sprawdza dostępne tokeny i zwiększa spent o token price. **Jeżeli po wcześniejszym dialogu tokenów już nie wystarcza, w zbadanym callbacku boost i zużycie przedmiotu są już zapisane, a tokeny nie są odjęte.** Sprawdzono 30 scenariuszy callbacku, nie cały dialog/publiczny gate. Nie uznawać tego za atomową transakcję ani samowolnie zmieniać reguły projektu Roblox w audycie. Sieciowe przekazywanie/odbieranie tokenów wymaga osobnej walidacji.

### Non-EPS, boosty gotówkowe i prestiż

`addCashNonEPS`, dodaje kwotę do gotówki farmy i `SimEngine.lastCashEarned`. Nie dodaje jej od razu do historycznych akumulatorów dochodu. **Na domowej farmie kwota jest jednak częścią przychodu prestiżowego**, ponieważ bieżąca gotówka tej farmy wchodzi do jego podstawy. Nie oznacza to doliczania gotówki farm kontraktowych do domowego prestiżu. Non-EPS nie oznacza „bez wpływu na prestiż”.

Na domowej farmie wykonano 12 scenariuszy integracji referencyjnego managera boostów, `addCashNonEPS` i getterów prestiżu, dla Subsidy/Blank Check/Money Printer i kontrolowanego prestigeEarningsMult 1/5/500/25000. Jednorazowa kwota wynosi odpowiednio 0.1/1/5 × kontrolowany FV. W kolejnym przebiegu manager dopisuje `max(0,newBase−lastBase)*(M−1)` do dodatkowego przychodu prestiżowego. Mnożnik nie jest bezpośrednio wypłacaną dodatkową gotówką.

Przykład: baza przychodu 1100, Money Printer przy FV=1000 dodaje 5000 gotówki. Dla M=500 po kolejnym update przychód prestiżowy wynosi 1100+5000×500 = 2501100. Między wypłatą a kolejnym update dodatkowy akumulator pozostaje jeszcze stary. Nie naliczać dodatku powtórnie przy każdym kroku.

## 5. Zmiana jaja i prestiż

`resetCurrentFarm`, przed przebudową zachowuje blok farmy + o długości, zawierający 10 rekordów aktywnych boostów. Gdy jego argument bool jest true, przywraca ten blok po przebudowie i odświeżeniu managerów. False go nie przywraca. 10 scenariuszy dla docelowych jaj 0/1/17/18/20 potwierdziło różnicę oraz zachowanie ekwipunku i terminu podwajacza.

`resetHomeFarm`, wywołuje `resetCurrentFarm(target,true)`. W sześciu scenariuszach referencyjnego kontrolera i zagnieżdżonej przebudowy:

- Zmiana zwykłego jaja archiwizuje bieżącą gotówkę do historycznego przychodu sesji i historii całkowitej, zachowuje dodatkowy przychód prestiżowy oraz bazę managera.
- Prestiż wymaga odpowiedniej flagi i celu Edible (0) na domowej farmie. Dodaje obliczone SE, zwiększa licznik prestiżów, zeruje akumulatory przychodu sesji i `BoostManager.lastBaseEarnings`.
- Obie ścieżki zachowują **ID i pozostały czas aktywnych boostów** oraz deadline reklamy. Przebudowa nie zużywa czasu boostu sama przez się.
- Dla starego jaja Virtue (testowane 20) nie archiwizowano tej gotówki do zwykłych akumulatorów. Pozostałych systemów Virtue nie uznano przez to za w pełni odtworzone.

Testy izolowały misje, artefakty, odświeżenia ich managerów, UI i telemetryczne tworzenie napisów. Wartość SE w teście resetu była kontrolowanym wejściem 42; sam wzór SE był sprawdzony w poprzednim etapie. Nie są to testy animacji przejścia, restartu aplikacji ani całej integracji artefaktów. Zachowane boosty mogą być nieaktywne na Enlightenment/Virtue zgodnie z `boostsEnabled` — zachowanie wpisu nie znaczy, że działa na każdym jaju.

## 6. Końcowe rozkłady paczek i reklam

Wykorzystano snapshot konfiguracji serwera z **20.10.2026**, jego wagi, kwoty, ceny i progi SE boostów. Nie jest to odpowiedź konkretnego konta ani potwierdzenie aktualnej oferty 22.10.2026.

### Progresja, filtry i normalizacja

```text
mu = float32(overallMult * clamp((totalGESpent−minSpent)/(maxSpent−minSpent),0,1))
p  = clamp(mu,0,1)
weight = float32(minWeight + p*(maxWeight−minWeight))
```

Przy snapshotcie minSpent=5000, maxSpent=300000 i overallMult=1. Liczą się **wydane GE**, a nie saldo. Potwierdzono 24 scenariusze `giftMu` i 2040 indywidualnych wag dla 17 pozycji, 5 mu, 2 rodzajów farmy, 4 populacji i 3 wariantów losowania.

Filtry referencyjnych callbacków:

- W zwykłej paczce argument bool=false wyklucza GE (GiftData type=0); true je dopuszcza. Oba warianty mają osobne rozkłady. Nie ustalono tu całego harmonogramu i wszystkich miejsc wyboru tej flagi.
- Tokeny (type=11) mają wagę 0 poza kontraktem.
- Reklamowe skrzynki kurczaków (type=3) mają wagę 0 poza kontraktem lub przy populacji >=90% pojemności. Testowano dodatnią pojemność i granicę 899/900 przy capacity=1000.

1. `goldGuaranteed`: tylko type=0, z pierwszeństwem nad cashGuaranteed.
2. W przeciwnym razie `cashGuaranteed`: tylko type=1 lub 2.
3. Bez gwarancji: type=0 ×goldChanceMult, type=1 ×cashChanceMult, pozostałe bez tej zmiany.

Ważny szczegół: gotówkowe wpisy tej tabeli mają **type=2**, więc w tej funkcji nie są mnożone przez cashChanceMult. Nie uogólniać działania nazwy wymiaru na wszystkie warianty gotówki.

Sampler `random_gift`, sumuje końcowe wagi w float32, losuje float32(U×sum), a następnie odejmuje wagi w kolejności 17 wpisów, wybierając przy `draw<=weight`. Matematyczne prawdopodobieństwo dla dodatniej sumy to `weight/sum(weights)`; do zgodności bitowej istotna jest kolejność zaokrągleń. Kontrolowane U=0 może wybrać pierwszy wpis o zerowej wadze. Wynik na górnej granicy zależy również od float32. Nie deklarowano równoważności dowolnej innej biblioteki weighted-random.

Pełne wagi/proporcje i sprawdzone wyniki są w dokumentacji referencyjnej; skrócone tabele w dokumentacji referencyjnej. To rozkłady **rodzaju nagrody przy ofercie**, nie częstości czasowej pojawiania się paczek.

### Kwota i konkretny boost z prezentu

`reward_snapshot`, potwierdzono w 132 scenariuszach liczbowych:

- GE/Shell Scripts/tokeny: bazowa kwota ×`GDR.giftRewardMult()`, przed dalszym odbiorem nagrody.
- Gotówka type=2: baza ×FV/100 ×struggleModifier ×giftRewardMult. Oryginał zapisuje ten rachunek jako `(0.5*baza*FV)/50`, co zachowano przy interpretacji kolejności.
- Kurczaki: `rounded=100*uint64(max(1000,baza/100*population*giftRewardMult)/100)`, następnie min z `uint64(vacancy−10000)`. Przy vacancy<10000 odejmowanie zawija uint64, a nie daje ujemnego clampa; sprawdzono także ten brzeg. Reguły oferty ograniczają część takich stanów.
- Boost type=10: wynik to **indeks wybranego boostu**, nie liczba jego sztuk. Ta gałąź nie mnoży indeksu przez giftRewardMult.

Dla giftMu=mu i kwoty A kategorii boost_regular/rare/epic (w snapshotcie A=1/4/10), kwalifikują się boosty:

```text
 giftEligibleFlag == 1
 soulEggs >= requiredSE
 float32((10+50*mu)*A) <= priceGE <= float32((200+550*mu)*A)
 weight = float32(100/priceGE)
```

Mu w tej gałęzi pochodzi bezpośrednio z `giftMu`; nie wstawiono dodatkowego clamp [0,1], którego tu nie ma. Używane są ceny i progi SE po konfiguracji. Sprawdzono mu 0/0.5/1, SE 0/1e6/1e30 oraz graniczne U. Suma tych wag jest akumulowana w double, ale draw i odejmowanie wag są float32. Przy braku wyboru model referencyjny zwraca 0; ten wynik nie jest osobnym sentinelem „brak boostu”. Sprawdzono 189 wyborów konkretnego boostu. Pełne listy kwalifikowanych ID i wyniki zawiera dokumentacja referencyjna.

### Generator i zakres zgodności losowania

`GameController::frandom` używa zapisywanego w  stanu `hq_rand`. Referencyjny `hq_rand::frand`, potwierdzono na 18 kontrolowanych stanach i 270 kolejnych losowaniach, łącznie ze skokiem pomijającym 378 kroków po 11 wyjściach:

```text
12 słów 48-bit, indeks i, carry c, licznik wyjść
step:
    t = state[(i+7)%12] - state[i] - c
    c = 1 gdy t<0, inaczej 0
    state[i] = t mod 2^48
    i = (i+1)%12
frand:
    jeśli licznik >10: wykonaj 378 pominiętych step i ustaw licznik=1
    inaczej licznik += 1
    x = step()
    zwróć float32(float32(x) * 2^-48)
```

Float32 może zaokrąglić wynik do **1.0**, więc sprawdzono też U=1 w samplerach. Testy generatora nie obejmują inicjalizacji/seedowania rzeczywistego konta ani statystycznego dowodu jakości losowości. Proporcje w tabelach to model rozkładu przy losowym U; odtworzenie identycznej sekwencji wymaga zgodnego stanu PRNG i kolejności jego użycia przez całą grę.


## Dane referencyjne w projekcie

Pełne parametry 17 kategorii nagród, ilości i harmonogram: [rewards.json](reference_data/rewards.json). Dziewięć przykładów rozkładów farmy domowej: [reward_probability_examples.json](reference_data/reward_probability_examples.json). Pozostałe wejścia wymagają filtrów i reguł opisanych tutaj. Ceny końcowych poziomów Epic do konwersji: [research.json](reference_data/research.json).
