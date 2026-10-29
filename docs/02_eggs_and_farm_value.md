# Gatunki Jaj i Wycena Farmy (Eggs & Farm Value)

> **Status S/N:** tabela jaj i wzór FV z konfiguracji referencyjnej; licznik konfiguracji i indeks silnika mają różne początki. Pety/ekspedycje są adaptacją, nie danymi referencyjnymi. [Statusy](CURRENT_SPEC.md).

W HatchTheEgg ewolucja farmy opiera się na odkrywaniu coraz bardziej zaawansowanych technologicznie gatunków jaj. Warunkiem przejścia na wyższe jajo jest osiągnięcie odpowiedniej **Wyceny Farmy (Farm Value)**.

---

## 1. Wykaz 19 Gatunków Jaj

Wartość bazowa jaja determinuje przychód generowany przez każde pojedyncze zniesione i wyeksportowane jajo przed zastosowaniem jakichkolwiek badań i bonusów:

| ID konfiguracji | Gatunek | Wartość jaja | FV odkrycia | FV awansu |
|---:|---|---:|---:|---:|
| 1 | Kurze (Edible) | 1.00 | 0 | 0 |
| 2 | SUPERFOOD (Kacze) | 1.25 | 1000000 | 5000000 |
| 3 | MEDICAL | 6.25 | 840000000 | 5300000000 |
| 4 | ROCKET FUEL | 30 | 38000000000 | 240000000000 |
| 5 | SUPER MATERIAL | 150 | 2.7e+13 | 1.7e+14 |
| 6 | FUSION | 700 | 8e+15 | 5e+16 |
| 7 | QUANTUM | 3000 | 3.6e+18 | 2.3e+19 |
| 8 | CRISPR | 12500 | 1.5e+22 | 9.4e+22 |
| 9 | TACHYON | 50000 | 2.7e+25 | 1.7e+26 |
| 10 | GRAVITON | 175000 | 1.5e+29 | 9.8e+29 |
| 11 | DILITHIUM | 525000 | 7.6e+32 | 4.8e+33 |
| 12 | PRODIGY | 1500000 | 2.5e+36 | 1.6e+37 |
| 13 | TERRAFORM | 10000000 | 3.2e+39 | 2e+40 |
| 14 | ANTIMATTER | 1000000000 | 2e+43 | 1.3e+44 |
| 15 | DARK MATTER | 100000000000 | 1.9e+47 | 1.2e+48 |
| 16 | A.I. | 1e+12 | 5.1e+51 | 3.2e+52 |
| 17 | NEBULA | 1.5e+13 | 3.2e+55 | 2e+56 |
| 18 | UNIVERSE | 1e+14 | 6.4e+59 | 4e+60 |
| 19 | ENLIGHTENMENT | 1e-07 | 5.7e+64 | 3.6e+65 |

Progi są wartościami referencyjnymi. Odkrycie i awans to osobne progi; nie są ceną potrącaną z portfela.

> [!NOTE]
> **Jajo Oświecenia (Enlightenment Egg):** Posiada ułamkową wartość bazową ($0.0000001) oraz blokuje działanie boostów i standardowych artefaktów (wymaga specjalnych kamieni *Clarity Stones*). Stanowi ostateczny sprawdzian dla graczy z potężnym bonusem Soul Eggs.

---

## 2. Wzór Farm Value potwierdzony w modelu referencyjnym

```text
L = researchEggLayingRateMult / 30             # jaja/kura/s
C = floor((shippingPerMinute / 60) / L)
P = population, gdy C >= population
P = floor(C + 0.2*(population-C)), w przeciwnym razie
F = max(0, habCapacity-population)^0.6
I = 4 * researchIHRBase * researchIHRMult / 60
T = silosOwned * GDR.siloSeconds()              # W adaptacji HatchTheEgg po wycofaniu silosów (R 29.10.2026): stałe T = 21600s (6h) bez Pro / 64800s (18h) z Pro
R = max(1, (5+researchMaxRCBBase)*researchMaxRCBMult-4)^0.25
K = 1200+600*eggIndex                         # indeks silnika 0..17
K = 3600                                      # Enlightenment, indeks 18

FV = 50*K*GDR.valuationMult()*GDR.localMysticalEarningsMultiplier()
     *L*GDR.eggValueBase()*researchEggValueMult
     *(P+F+0.25*I*T)*R
```

Nie pomijać wartości bazowej jaja ani bazowego tempa 1/30. Człon przyszłego wylęgu używa czterech wywołań ResearchEngine; nie liczby zakupionych kurników i nie bonusu Calm. Po usunięciu aktywnego RCB nazwy researchMaxRCBBase/researchMaxRCBMult pozostają historycznymi parametrami badawczego członu FV. Ten człon nadal działa w kodzie, nie zależy od biegnących kur i nie jest przywróceniem bonusu za wylęg; nie zmieniamy teraz formuły FV. Nie zastępować każdej wartości ResearchEngine pełnym GDR z bonusami wszystkich źródeł.

Uzupełnienie dla petów: [rozdział 16](16_pet_stacking_offline_and_package_schedule.md) potwierdza wybór `totalHabCapacityOf(..., true)` w FV. Jest to pojemność z ResearchEngine, a nie pełna pojemność GDR z wyposażeniem. Bonusów wartości jaj, znoszenia, IHR i pojemności petów nie dopisujemy bezpośrednio do wejść tego wzoru. Wpływ przez faktycznie zmienioną populację pozostaje zachowany.

Kontrakty mają osobną gałąź K=6000, Virtue/Enlightenment K=3600. Warianty te wymagają osobnych scenariuszy integracyjnych. Pusta farma Edible z Coop=250 bez bonusów: FV około **54 928.02716531** (przy wartości bazowej $0.50).

## 3. Mechanika Przejścia na Wyższe Jajo (Egg Transition)

Gdy $\text{Farm Value} \ge \text{Wymagany Próg}$:
* W UI pojawia się ikona nowego jaja oraz przycisk **Upgrade Egg**.
* Gracz otrzymuje wybór natychmiastowego awansu na nowe jajo.

### 3.1. Różnica między Bieżącą Gotówką a Zyskiem z Prestiżu
* **`FarmCash` (Gotówka w portfelu):** Resetuje się do $0$ przy awansie na wyższe jajo.
* **`PrestigeEarnings` (Dochód sesji prestiżu):** **NIE resetuje się przy zmianie jaja!** Sumuje się przez kolejne gatunki jaj podczas całej sesji; to logiczna suma kilku akumulatorów, nie pojedynczy licznik tożsamy z portfelem. Jednorazowy dochód i dodatkowe przyrosty managera mają kolejność księgowania opisaną w [13](13_rewards_contracts_resets_and_gift_distributions.md). Dzięki temu gracz nie traci wypracowanego postępu Jaj Duszy (Soul Eggs) przy zmianie farmy! Reset następuje **wyłącznie w momencie wciśnięcia przycisku Prestiżu**.

### 3.2. Co ulega resetowi podczas awansu:
* Licznik gotówki farmy (`FarmCash`) -> reset do wartości początkowej ($0).
* Wszystkie kurczaki na farmie -> reset do 0.
* Kurniki -> powrót do 1 bazowego kurnika (Coop w slocie 1).
* Pojazdy -> powrót do 1 bazowego pojazdu (Trike w slocie 1).
* Wszystkie Badania Powszechne (Common Research) -> reset do poziomu 0.

### 3.3. Co zostaje zachowane:
* Jaja Duszy (Soul Eggs) oraz Jaja Przepowiedni (Eggs of Prophecy).
* Cały Earning Bonus (EB).
* Akumulowany dochód do prestiżu (`PrestigeEarnings`).
* Wszystkie Badania Epickie (Epic Research).
* Złote Jaja (Golden Eggs) i zawartość Piggy Bank.
* Licencje/uprawnienia trwałe rozróżniać od odbudowy infrastruktury i faktycznie posiadanych silosów. `Buy MAX Research` jest osobnym zatwierdzonym produktem, poza Pro. Szczegóły resetu: [13](13_rewards_contracts_resets_and_gift_distributions.md).
* Aktywne boosty z pozostałym czasem i termin podwajacza są zachowane; na jajach wyłączających boosty zachowany wpis nie działa.
* **P — projekt petów:** zachowanie ekwipunku, wariantów i wyposażenia jest założeniem adaptacji, nie wynikiem referencyjnego testu petów.
* **P — jeśli ekspedycje zostaną przyjęte:** ich trwałość i zegar trzeba ustalić osobno; nie są potwierdzoną częścią referencyjnego resetu.

## Dane referencyjne w projekcie

Maszynowa tabela 19 jaj, ich wartości i trofeów: [infrastructure.json](reference_data/infrastructure.json). Progi FV odkrycia i awansu pozostają w tabeli tego dokumentu.

[Integracja maksimum RCB #72](workflow/entitlement_farm_fixes_71_74.md): adapter przekazuje addytywne onscreenChickenMultMax Common oraz Epic Multiplier jako researchMaxRCBBase. researchMaxRCBMult=1 wobec braku odrębnego efektu w katalogu. Bieżące runningCount i Epic Clucking nie zastępują tego członu.
