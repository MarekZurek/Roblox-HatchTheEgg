# Dane referencyjne HatchTheEgg

Zestaw przywraca dostęp do istniejących tabel; nie jest konfiguracją wydania, nową kalibracją ani raportem testów implementacji. Każdy JSON ma `status: REFERENCE_ONLY` oraz `productionConfigurationApproved: false`. Decyzje R i zakres v1 rozstrzyga [CURRENT_SPEC](../CURRENT_SPEC.md). Dane nie nadają uprawnień, nie włączają produktów ani nie zatwierdzają parametrów odłożonego bilansu.

| Plik | Zawartość |
|---|---|
| [research.json](research.json) | 56 Common i 24 Epic; 2998 cen zakupów i efekty wszystkich 2998 poziomów, dodatkowo poziom 0; 13 progów tierów i wektory parametrów ceny. |
| [infrastructure.json](infrastructure.json) | 19 jaj farmy domowej i ich trofea, 19 kurników z cenami, 12 pojazdów ×17 cen, populacje referencyjne i parametry Hyperloop, trzy przykłady cen silosów. |
| [price_curves.json](price_curves.json) | Dwie tablice po 500 punktów: krzywa 0 farmy domowej i krzywa 1 wariantu alternatywnego poza v1. Punkty opisują wartość krańcową; FV krzywej wymaga całkowania. |
| [boosts.json](boosts.json) | 33 rekordy efektów/czasu oraz referencyjne nadpisania ceny i progu SE po ID. Katalog i oferta to dwie warstwy. |
| [rewards.json](rewards.json) | 17 kategorii nagród z parametrami wag, ilości i harmonogramu; 28 wpisów kalendarza. |
| [reward_probability_examples.json](reward_probability_examples.json) | Dziewięć przykładów rozkładów farmy domowej: trzy tryby ×trzy wartości mu, przy jawnych wejściach szans. To przykłady, nie pełna funkcja kwalifikacji dla dowolnego gracza. |
| [drone_and_silo_rules.json](drone_and_silo_rules.json) | Dziewięć przedziałów struggleModifier, wyjątek małej populacji, parametry czasu silosu, próg away i jakość dochodu offline. |

## Indeksy, jednostki i precyzja

- W badaniach `prices[k]` to koszt zakupu poziomu k+1, a `effectsByLevel[k]` opisuje poziom k, włącznie z zerem. Nie utożsamiać izolowanego efektu z agregatem wszystkich badań. Common kosztują gotówkę, Epic GE. `tier_raw` jest numerowany od zera.
- Ceny kurników i pojazdów indeksuje liczba posiadanych egzemplarzy danego typu przed zakupem, a nie bezwarunkowo numer parceli. Startowy darmowy obiekt przy resecie jest osobną regułą.
- Przepustowość pojazdów podano w jajach na minutę; czas w sekundach. Normalna krzywa cen ma indeks 0. Współczynnik interpolacji jest float32, całkowanie zachowuje udokumentowaną kolejność.
- Zachowano wartości liczbowe bez zaokrąglania do prezentacji UI. JSON nie koduje automatycznie typu float32 ani bezpiecznej reprezentacji dużych liczb w Luau; jest punktem odniesienia, nie biblioteką liczb.
- `categoryEntries` zachowuje kolejność kategorii i pary parametrów normal/video; `giftConfig` zawiera referencyjne ilości i parametry konfiguracyjne po ID. Nie dodawać tych dwóch zestawów jako osobnych wag.
- Typy kalendarza i kategorie prezentów mają odrębne numeracje. Przy nagrodach kolejność wpisów, filtry, gwarancje i konwersje z [13](../13_rewards_contracts_resets_and_gift_distributions.md) nadal obowiązują.

## Granice zakresu

Same nazwy kategorii i rekordy katalogu nie włączają funkcji spoza v1. Zachowane identyfikatory służą jednoznacznemu mapowaniu; nie zastępują listy funkcji zatwierdzonych w dokumentach 22, 25 i 26. Zestaw nie zawiera konfiguracji kontraktów, prywatnych ścieżek, narzędzi ani raportów pochodzenia. Krzywa alternatywna jest referencją, a nie rozszerzeniem v1.

Ceny i szanse inkubatorów, siły petów, receptury, próg gwarancji, oferta Robux oraz tempo progresji pozostają odłożone. Zestaw nie jest gotowym bilansem, generatorem konfiguracji ani uruchomionym testem. Dla danych poza opisanym zakresem nie zgadywać brakujących wartości.

Kontrola zgodności wartości i zakresu: [verification.json](verification.json). Odtworzono dane, nie wykonano ponownie dawnych symulacji.

## Semantyka pierwszej farmy

[31](../31_research_hatching_rcb_and_new_account.md) uzupełnia znaczenie punktów Common i progów, aktywne RCB, press/hold/refill oraz referencyjny start konta. Nie zmienia wartości ani flag tych JSON-ów i nie zatwierdza konfiguracji wydania.
