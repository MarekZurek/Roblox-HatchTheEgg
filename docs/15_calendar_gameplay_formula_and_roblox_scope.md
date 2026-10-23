# Kalendarz — skalowanie i cykle nagród

Specyfikacja referencyjna, nie raport testów implementacji HatchTheEgg. Aktualne decyzje: [CURRENT_SPEC](CURRENT_SPEC.md).

## 2. Wzór pięciu nagród

Niech `C` oznacza liczbę wcześniej odebranych prezentów:

```text
m = floor(C / 28)        // cykl od zera
day = C % 28 + 1        // następny dzień od 1 do 28
reward(m) = min(cap, base × 2^m)
```

`m` oznacza cykl 28 odbiorów, nie miesiąc roku. Dzień 1 pierwszego cyklu ma m=0. Limity obowiązują osobno dla każdej pozycji.

| Dzień | Typ | Base | Cap | Pierwszy cykl z capem, od 1 |
|---|---|---:|---:|---:|
| 1 | Golden Eggs | 192 | 6144 | 6 |
| 8 | Golden Eggs | 396 | 9472 | 6 |
| 17 | Golden Eggs | 96 | 12288 | 8 |
| 26 | Golden Eggs | 396 | 6336 | 5 |
| 27 | Wypełnienie Piggy | 10000 | 40000 | 3 |

| Cykl od 1 | Dzień 1 | Dzień 8 | Dzień 17 | Dzień 26 | Dzień 27, Piggy |
|---|---:|---:|---:|---:|---:|
| 1 | 192 | 396 | 96 | 396 | 10000 |
| 2 | 384 | 792 | 192 | 792 | 20000 |
| 3 | 768 | 1584 | 384 | 1584 | 40000 |
| 4 | 1536 | 3168 | 768 | 3168 | 40000 |
| 5 | 3072 | 6336 | 1536 | 6336 | 40000 |
| 6 | 6144 | 9472 | 3072 | 6336 | 40000 |
| 7 | 6144 | 9472 | 6144 | 6336 | 40000 |
| 8 i dalsze | 6144 | 9472 | 12288 | 6336 | 40000 |

Cap dnia 8 jest dokładnie **9472**. Nie zaokrąglać go do 9500/9600 ani kolejnej potęgi dwójki. Dzień 27 dodaje surowe środki do Piggy, a nie GE do portfela. Bonus poziomu/Ultra i zasady wypłacania Piggy opisuje rozdział 13.

Do przyszłej implementacji nie trzeba obliczać olbrzymiego `2^m`: po odpowiednio m=5/5/7/4/2 wynik danej pozycji jest capem. Jest to matematycznie równoważne dla prawidłowego nieujemnego postępu i unika przepełnienia. To wskazówka specyfikacyjna, bez kodu gry.

## 3. Pełny kalendarz i jego końcowy cykl

Wniosek dla długiej progresji:

- Wszystkie rosnące kwoty tabeli osiągają swoje limity najpóźniej w cyklu 10.
- Dzień 28 daje PE przez 24 cykle; od cyklu 25 zmienia się na 100000 GE.
- Od cyklu 25 **bazowa tabela** powtarza się co 42 cykle, czyli 1176 odbiorów. Wynika to z rotacji podtypów dnia 16 co 2 cykle, dnia 20 co 3 i dnia 23 co 7: `lcm(2,3,7)=42`.
- Sprawdzono 55 porównań pełnego wektora 28 nagród dla odstępu 42. Krótsze dzielniki 1/2/3/6/7/14/21 nie dały takiej okresowości.

To okresowość **tabeli**, nie identycznych końcowych wypłat każdego profilu. Gotówka zależy od Farm Value, nadmiarowe badania mogą zamieniać się w GE, a poziom Piggy nadal rośnie. Nie zamrażać całej ekonomii po cyklu 25.

### Suma nagród potrzebna do bilansu Roblox

Sumy poniżej obejmują bezpośrednie GE oraz surowe wypełnienie Piggy z tabeli. Nie obejmują GE za maksymalne badania ani wartości boostów.

| Cykl | Bezpośrednie GE | Surowe wypełnienie Piggy |
|---|---:|---:|
| 1 | 4372 | 15000 |
| 2 | 8744 | 30000 |
| 3 | 14196 | 55000 |
| 4 | 21808 | 60000 |
| 5 | 33740 | 65000 |
| 6 | 44776 | 70000 |
| 7 | 50640 | 75000 |
| 8 | 58576 | 80000 |
| 10–24 | 62160 | 90000 |
| 25 i dalsze | 162160 | 90000 |

Od czwartego cyklu bezpośrednie SE z czterech dni kalendarza wynoszą łącznie **4.5 miliarda na cykl** w badanej tabeli. To stałe kwoty, nie procent aktualnych SE i nie wynik prestiżu. Szczegółowe dane, także cykl 9, zawiera dokumentacja referencyjna.


## Dane referencyjne w projekcie

Maszynowa tabela 28 wpisów kalendarza: [rewards.json](reference_data/rewards.json), sekcja calendar. Tryby i skalowanie stosować według tego dokumentu; numeracji typów nie łączyć z kategoriami paczek.
