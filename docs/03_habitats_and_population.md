# Kurniki i Populacja (Habitats & Population)

> **Status S/N:** pojemności, ceny i odczyty funkcji z konfiguracji referencyjnej. Sterowanie przyciskiem 3D oraz bonusy petów to adaptacja. Statusy i źródła: [CURRENT_SPEC](CURRENT_SPEC.md).

Populacja kurczaków jest sercem farmy: każdy kurczak znosi jaja w bazowym tempie 1 jajo na 30 sekund. Liczba kurczaków jest ściśle ograniczona przez łączną pojemność **4 kurników (Habitats)**.

---

## 1. Wykaz 19 Kurników i Cennik Slotów

Farma posiada 4 dedykowane parcele budowlane (sloty). Koszt zakupu danego kurnika rośnie w zależności od tego, czy jest to 1., 2., 3. czy 4. egzemplarz danego typu na farmie:

| ID | Kurnik | Pojemność | 1. egzemplarz | 2. | 3. | 4. |
|---:|---|---:|---:|---:|---:|---:|
| 0 | COOP | 250 | 11.26678686 | 29.12425184 | 56.3652941 | 96.57052851 |
| 1 | SHACK | 500 | 466.6688788 | 803.8970068 | 1257.274495 | 1862.801763 |
| 2 | SUPER SHACK | 1000 | 12267.05506 | 23532.66564 | 40899.1978 | 66811.5497 |
| 3 | SHORT HOUSE | 2000 | 340831.2645 | 733774.7384 | 1418850.754 | 2551205.668 |
| 4 | THE STANDARD | 5000 | 21440013.54 | 68130183.94 | 178166488.3 | 408981186.3 |
| 5 | LONG HOUSE | 10000 | 2320890124 | 5958070940 | 1.334777538e+10 | 2.719498881e+10 |
| 6 | DOUBLE DECKER | 20000 | 1.482676374e+11 | 3.923318833e+11 | 9.004729326e+11 | 1.866673268e+12 |
| 7 | WAREHOUSE | 50000 | 1.779352592e+13 | 6.608965748e+13 | 1.941478433e+14 | 4.858689699e+14 |
| 8 | CENTER | 100000 | 3.240362007e+15 | 8.752958511e+15 | 2.039668903e+16 | 4.289463791e+16 |
| 9 | BUNKER | 200000 | 2.502129405e+17 | 6.766411329e+17 | 1.577814495e+18 | 3.319270341e+18 |
| 10 | EGGKEA | 500000 | 3.256729406e+19 | 1.22012537e+20 | 3.602751158e+20 | 9.041752971e+20 |
| 11 | HAB 1000 | 1000000 | 6.045755364e+21 | 1.632219161e+22 | 3.799722945e+22 | 7.980220401e+22 |
| 12 | HANGAR | 2000000 | 4.633006489e+23 | 1.249351003e+24 | 2.905261013e+24 | 6.095210505e+24 |
| 13 | TOWER | 5000000 | 5.926397131e+25 | 2.202211251e+26 | 6.392870039e+26 | 1.576651464e+27 |
| 14 | HAB 10,000 | 10000000 | 1.246771271e+28 | 3.786933587e+28 | 9.59659005e+28 | 2.146041243e+29 |
| 15 | EGGTOPIA | 25000000 | 2.929953573e+30 | 1.285330896e+31 | 4.193363878e+31 | 1.12893263e+32 |
| 16 | MONOLITH | 50000000 | 2.801131668e+33 | 1.561992309e+34 | 5.924154733e+34 | 1.753520535e+35 |
| 17 | PLANET PORTAL | 100000000 | 8.572180301e+36 | 5.868223369e+37 | 2.387561895e+38 | 7.183229834e+38 |
| 18 | CHICKEN UNIVERSE | 600000000 | 3.216374959e+41 | 3.589507603e+42 | 1.942278489e+43 | 7.123624932e+43 |

Ceny zakupu z funkcji referencyjnej, bez zniżek; pełna precyzja w danych konfiguracji referencyjnej. Numer kolumny oznacza kolejny egzemplarz danego typu, nie bezwarunkowo numer parceli. Darmowy startowy Coop przy resecie nie oznacza zerowej ceny funkcji zakupu pierwszego egzemplarza.

---

## 2. Formuła Pojemności Kurników

Każdy kurnik oblicza swoją pojemność indywidualnie, zaokrąglając wynik w górę:
$$\text{HabSpace}_h = \left\lceil \text{BaseHabSpace}_h \times M_{\text{universal}} \times M_{\text{portal}} \times M_{\text{artifacts}} \right\rceil$$

### Mnożniki:
1. **$M_{\text{universal}}$ (Dotyczy wszystkich kurników):**
   $$M_{\text{universal}} = (1 + 0.05 \times \text{Remodel}) \times (1 + 0.05 \times \text{Microlux}) \times (1 + 0.02 \times \text{GravPlating})$$
2. **$M_{\text{portal}}$ (Wormhole Dampening):**
   * Dotyczy **tylko** kurników typu *Planet Portal* (ID 17) oraz *Chicken Universe* (ID 18):
   $$M_{\text{portal}} = (1 + 0.02 \times \text{WormholeDampeningLvl})$$
   Na maksymalnym 25 poziomie daje $+50\%$ pojemności portali!
3. **Maksymalna pojemność w grze:**
   * 4x *Chicken Universe* z max badaniami daje bazowo **11 340 000 000 (11.34 mld)** kurczaków bez wyposażenia. Pojemność z petami zależy od niezatwierdzonych sił i zestawu; nie ma zatwierdzonego maksimum projektu.

---

## 3. Mechanika Ręcznego Wylęgu (Manual Hatching)

Gracz wchodzi na podłogowy przycisk wylęgu na farmie lub przytrzymuje `[E]`:

### 3.1. Maksymalna Pojemność Wylęgarni (Hatchery Capacity)
Pojemność określa, ile kurczaków gracz może wypuścić w ciągłej serii zanim zbiornik wylęgarni się opróżni:
$$\text{MaxHatcheryCap} = 250 + (10 \times \text{HatcheryExpansionLvl}) + (50 \times \text{HatcheryRebuildLvl}) + (10 \times \text{CompactIncubatorsLvl})$$
* **Bazowa:** 250 kurcząt.
* *Hatchery Expansion* (Tier 2, 10 lvl): $+100$.
* *Hatchery Rebuild* (Tier 4, 1 lvl): $+50$.
* *Compact Incubators* (Tier 5, 10 lvl): $+100$.
* **Maksymalna pojemność po ulepszeniach:** **500 kurcząt**.

### 3.2. Tempo odnawiania ręcznej wylęgarni

Zweryfikowane `GDR::hatcheryRefillRate`: baza 3 kurczęta/s, mnożona przez Better Incubators, **Rooster Booster** i Epic Hatchery. Przy maksymalnych tych badaniach: `3 * 2.5 * 2.25 * 3 = 50.625/s`. Poprzednie 22.5/s pomijało Rooster Booster.

### 3.3. Automatyczny Wylęg (Hold to Hatch)
* Badanie epickie *Hold to Hatch* (15 poziomów po +2 kury/s) pozwala na ciągły automatyczny wylęg przy przytrzymaniu `[E]` lub staniu na przycisku podłogowym (do **+30 kurcząt na sekundę**).

---

## 4. Wewnętrzny Wylęg (Internal Hatchery Rate - IHR)

Kurczaki rodzą się samoczynnie wewnątrz kurników:
$$\text{IHR}_{\text{per\_hab\_active}} = \left( \sum_{\text{common}} \text{level}_i \times \text{per\_level}_i \right) \times (1 + \text{EpicIntLvl} \times 0.05) \times M_{\text{artifacts}}$$

* **Wartości badań powszechnych:**
  * *Internal Hatcheries* (Tier 2): +2 kury/min/hab
  * *Internal Hatchery Upgrades* (Tier 3): +5 kury/min/hab
  * *Internal Hatchery Expansion* (Tier 5): +10 kury/min/hab
  * *Internal Hatchery Expansion II* (Tier 7): +25 kury/min/hab
  * *Machine Learning Incubators* (Tier 8): +5 kury/min/hab (250 poziomów = aż +1,250!)
  * *Neural Linking* (Tier 10): +50 kury/min/hab (30 poziomów = +1,500!)
* **Tempo farmy:** Wynik mnożony jest przez liczbę kurników (np. $4 \times \text{IHR}_{\text{hab}}$).

### Wylęg Offline (Internal Hatchery Calm)
Gdy gracz opuszcza grę, a farma posiada zasilanie w silosach:
$$\text{IHR}_{\text{away}} = \text{IHR}_{\text{active}} \times (1 + \text{CalmLvl} \times 0.10)$$
* Na 20 poziomie badania epickiego tempo wylęgu w trybie offline wynosi **$3.0\times$ (300%)** tempa online!

### Przepełnienie i Współdzielenie (Internal Hatchery Sharing)
* Gdy jeden z kurników osiągnie 100% zapełnienia, bez badania jego wylęg bezpowrotnie przepada.
* Badanie epickie *Internal Hatchery Sharing* przekazuje od 10% do 100% nadwyżkowego wylęgu do pozostałych wolnych kurników.

## Uściślenie symulacji po audycie modelu referencyjnym

IHR działa per slot kurnika z ułamkowym akumulatorem i limitem wolnego miejsca. Wzrost jest naliczany po produkcji jaj danego kroku. Sharing z pełnego slotu wybiera cel przez `selectHabByVacancy`; nie oznacza równego podziału na pozostałe kurniki. Szczegóły, próg away >60 s i testy: [rozdział 10](10_verified_simulation_and_server_config.md). Tabela cen została ujednolicona ze źródłem podczas porządkowania dokumentacji; pełne dane znajdują się w dokumentacji referencyjnej.

## Dane referencyjne w projekcie

Pełna precyzja pojemności i cen 19 kurników: [infrastructure.json](reference_data/infrastructure.json), sekcja habitats.

## Ręczne wejście i aktywne RCB — doprecyzowanie 24.10.2026

[31](31_research_hatching_rcb_and_new_account.md) rozdziela pojedynczy press (jedna próba wypuszczenia), refill 3/s i holdRate (0 bez Epic, +2/s na poziom Hold to Hatch). Przytrzymanie nie nadaje domyślnie 3 kur/s. Opisuje aktywne RCB, ważony wolnymi miejscami wybór celu, rezerwację przy wypuszczeniu i zaliczenie do zasiedlonej populacji przy dotarciu. Referencyjna nowa farma startuje z pełnym zapasem 250 i jednym silosem; nie należy utożsamiać jej z zerowym fixture.
