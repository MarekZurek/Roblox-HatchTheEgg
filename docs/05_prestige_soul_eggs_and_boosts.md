# Prestiż, Jaja Duszy i Boosty (Prestige, Soul Eggs & Boosts)

> **Status N/S:** wzory i granice testów według wskazanych raportów. Phoenix jest adaptacją na warstwie Feather; nie jest referencyjnym petem. [Statusy](CURRENT_SPEC.md).

Prestiż (Prestige) to fundament progresji w HatchTheEgg. Pozwala zamienić zsumowane dochody z obecnej farmy na mistyczne **Jaja Duszy (Soul Eggs)**, które trwale zwiększają dochód przyszłych farm.

---

## 1. Pętla Prestiżu (The Prestige Loop)

Gdy gracz dochodzi do ściany, a ceny kolejnych badań lub kurników stają się zbyt wysokie, decyduje się na prestiż:
* Cała farma zostaje zresetowana do pierwszego jaja (**Edible Egg**).
* Gracz otrzymuje nowo wyliczoną pulę **Jaj Duszy (Soul Eggs)**.
* Poprzednio zdobyte Soul Eggs sumują się z nowymi, podnosząc stały **Earning Bonus (EB)**.
* Dzięki wyższemu mnożnikowi ponowne przejście początkowych poziomów zajmuje sekundy zamiast godzin.

---

## 2. Zweryfikowany wzór Soul Eggs

Referencyjny `calculateSoulEggsInternal` używa funkcji przedziałowej; jeden wykładnik 0.15 nie obowiązuje w całym zakresie.

| Dolny próg E | Wykładnik p |
|---:|---:|
| 1 | 0.15 |
| 1e12 | 0.16 |
| 1e21 | 0.17 |
| 1e30 | 0.18 |
| 1e39 | 0.19 |
| 1e48 | 0.20 |
| 1e60 | 0.21 |

``materiał techniczny``

Epic Prestige Bonus należy do końcowego mnożnika collection. **Soul Beacon i Feather zwiększają przychód wejściowy**, a nie liczbę SE bezpośrednio. Silnik zapisuje dodatkowo `max(0, baseEarnings-lastBaseEarnings)*(prestigeEarningsMult-1)` i sumuje przychody wcześniejszych jaj, bieżącej farmy oraz tę premię. Zmiana jaja nie zeruje całej sesji prestiżu; prestiż zeruje odpowiednie akumulatory.

Źródła i wyniki: specyfikacja obliczeń, walidacja księgowania. Próby funkcji nie są dowodem całej gry end-to-end; szczegóły źródeł i zakresu rozdziela [CURRENT_SPEC](CURRENT_SPEC.md).

## 3. Jaja Przepowiedni (Eggs of Prophecy - PE)

Najrzadszy i najpotężniejszy zasób w grze:
* Źródła obejmują trofea za populację, kontrakty i kalendarz (do 24 PE z tego kalendarza); przeliczenie opisuje [rozdział 13](13_rewards_contracts_resets_and_gift_distributions.md).
* Nie dodają stałej kwoty, lecz **mnożą cały bonus wykładniczo**:
$$\text{MnożnikPE} = \left(1 + \text{BonusNaJajo}\right)^{N_{\text{PE}}}$$

* **BonusNaJajo:**
  * Domyślnie wynosi **$5\%$ ($0.05$)**.
  * Badanie epickie *Prophecy Bonus* (5 poziomów po +1%) zwiększa tę wartość do **$10\%$ ($0.10$)**.
* **Potęga kumulacji wykładniczej:**
  * 10 PE przy bonusie 10%: $1.10^{10} \approx 2.59\times$ mnożnik do wszystkich Soul Eggs.
  * 50 PE przy bonusie 10%: $1.10^{50} \approx 117.4\times$.
  * 100 PE przy bonusie 10%: $1.10^{100} \approx 13\,780\times$!
  * 200 PE: $1.10^{200} \approx 189\,900\,000\times$!

---

## 4. Łączny Bonus Zarobków (Earning Bonus - EB)

Poniższy EB to **dodatkowa premia**, nie pełny mnożnik dochodu. Bez artefaktów/petów i innych wymiarów, pełny mnożnik mistyczny wynosi `1+EB`. Procent wyświetlany w UI to `100×EB`. Dla SE=0 mnożnik bazowy pozostaje 1, a nie 0:

$$\text{EarningBonus} = \text{SoulEggs} \times (0.10 + 0.01 \times \text{SoulFoodLvl}) \times (1.05 + 0.01 \times \text{ProphecyBonusLvl})^{\text{ProphecyEggs}}$$

Rangi farmera nie są potrzebne do powyższego wzoru. Usunięto wcześniejszą niezweryfikowaną listę progów, aby nie przedstawiać jej jako tabeli opisanej z silnika.

---

## 5. Zweryfikowane reguły boostów

Aktualne dane i rozróżnienie wersji legacy znajdują się w tabeli konfiguracji referencyjnej i snapshotcie LiveConfig. Pełne ustalenia oraz ograniczenia: [rozdział 11](11_periodicals_calendar_events_and_boost_rules.md).

- Jimbo, Tachyon i Soul Beacon sumują siły we własnej kategorii; Boost Beacony również sumują się między sobą, następnie mnożą aktywne kategorie. Dwa Jimbo 50 dają 100x, a Jimbo 50 + dwa Beacon 50 dają 5000x.
- Soul Beacon zwiększa przychód wejściowy do prestiżu, a event `prestige-boost` zwiększa końcowy `soulEggCollectionMult`. To różne warstwy.
- Czas jest zapisywany przy aktywacji jako bazowy czas × aktualny boostDurationMult. Zmiana wydarzenia czasu później nie przelicza istniejącego timera.
- Boosty tracą czas symulowany; gdy boostsEnabled=false, manager nie odejmuje ich czasu. Wyczerpanie silosów i wyłączenie boostów to osobne przypadki.
- Efekt wpisu działa w kroku jego wygaśnięcia; usunięcie następuje przy remaining<0, nie ==0. Zachować kolejność operacji.
- Subsidy Application, Blank Check i Money Printer to jednorazowe 0.1 / 1 / 5 FV przez `earningsAdditionPOFV`, a nie zwykłe czasowe mnożniki dochodu. Beacon nie zwiększył tej wartości w wykonanym teście managera.
- Limit aktywnych wpisów wynosi 2 bez pozwolenia i 5 z pozwoleniem. Zakup pakietu daje 5 sztuk za 4 ceny jednostkowe. Dostępność w sklepie, inventory, tokeny, Mirror i żarówki mają dodatkowe bramki.

Wykonane testy izolują UI oraz wejścia GDR; Mirror, tokeny, non-EPS oraz reset kontrolera sprawdzono w [rozdziale 13](13_rewards_contracts_resets_and_gift_distributions.md); pełny serwerowy obieg kontraktów i integracja pozostałych managerów nadal wymagają osobnych scenariuszy. Nagrodę reklamową i regułę odświeżania zweryfikowano dalej w [rozdziale 12](12_calendar_scaling_and_video_doubler.md). Podwajacz wideo ma własny termin i kilka ścieżek aktywacji, więc nie należy utożsamiać go z timerem zużywalnych boostów.

Aktualizacja audytu 22.10.2026: zmiana jaja i prestiż zachowują aktywne boosty wraz z czasem. Gotówka non-EPS wchodzi do przychodu prestiżowego; szczegóły kolejności i testy integracji są w rozdziale 13.

## Dane referencyjne w projekcie

Pełny katalog sił/czasów i referencyjna oferta boostów: [boosts.json](reference_data/boosts.json). Obecność wpisu nie zatwierdza jego użycia w v1.
