# IMP-05 — faza IHR

Stan: 24.10.2026. Dostawa kodu i testów poziomu L; bez Studio, zapisu produkcyjnego i zmian bilansu.

## Zakres i źródła

[`ihr.luau`](../../src/server/FarmMath/ihr.luau) wykonuje pojedynczą fazę wewnętrznego wylęgu dla dokładnie czterech slotów. Źródła reguł: [03](../03_habitats_and_population.md), [10](../10_verified_simulation_and_server_config.md), [27](../27_numbers_time_and_player_state_contract.md) i [31](../31_research_hatching_rcb_and_new_account.md). Efekty badań, Calm, petów i pozostałych bonusów muszą być już złożone w przekazanym tempie na sekundę. Moduł nie uruchamia zegara, nie pobiera RNG z silnika i nie zarządza produkcją jaj; koordynator wywoła go po produkcji.

## Kontrakt API

`IHR.new(codec, populationMath).step(habitats, ratePerHabSecond, dt, sharing, drawSource)` zwraca cztery nowe tablice slotów, zachowując pozostałe pola i nie zmieniając wejścia. Pojemność, populacja i rezerwacje `assignedInTransit` są kanonicznym tekstem uint64, akumulator `fractionalIHR` jest nieujemnym skończonym binary64. `dt` mieści się w `[0, 0.3]`, a sharing w `[0, 1]`. Zerowe `dt` po walidacji zwraca niezmieniony logicznie stan.

Puste sloty nie produkują ani nie przekazują IHR. Zbudowany slot z wolnym miejscem dodaje `rate*dt` do swojego akumulatora. Część całkowita jest ograniczana wolnym miejscem z uwzględnieniem rezerwacji biegnących kur. Odejmowana jest **faktycznie dodana** liczba, więc akumulator po klipowaniu może być większy lub równy 1; ograniczenie zapisu `<1` byłoby błędem.

Pełny slot przy dodatnim tempie i sharing wybiera jeden cel ważony aktualnymi wolnymi miejscami. Wstrzyknięte `drawSource(sourceSlotIndex)` dostarcza kanoniczny uint64; `PopulationMath` realizuje selekcję modulo sumy miejsc. Cel otrzymuje `rate*sharing*dt`, a nie równy udział dla wszystkich kurników. Sloty są obsługiwane kolejno 1–4; cel może otrzymać przekazanie przed lub po własnej fazie. Bez sharing albo dostępnego celu pełny slot czyści swój akumulator. Stan pełnego źródła nie jest przenoszony jako dodatkowa nadwyżka.

Wartość całkowita akumulatora `>=2^64` jest odrzucana przed konwersją; nie wykonujemy zawijania ani cichego zaokrąglania populacji przez number. To granica reprezentacji NumericCodec, nie parametr progresji. Iloczyny `rate*dt` oraz `(rate*sharing)*dt` korzystają z `Real64.multiply`; niezerowe argumenty, których wynik zanika do zera, powodują jawny błąd niedomiaru. Sharing najpierw zmienia tempo, a następnie mnoży je przez czas; test z niezależnym oczekiwaniem binary64 chroni tę kolejność przed zmianą o 1 ULP. Zmiana populacji odbywa się przez arytmetykę uint64; odjęcie od binary64 akumulatora jawnie używa `toReal64Rounded`.

## Weryfikacja

[`tests/ihr/run.luau`](../../tests/ihr/run.luau) sprawdza niezależne oczekiwania: resztę binary64, rezerwacje, klipowanie i akumulator `1.5`, puste/pełne sloty, wybór celu, kolejność slotów, brak mutacji, populację powyżej `2^53`, odrzucanie niepoprawnych danych oraz końcowy krótszy krok. Osobne przypadki integrują rzeczywisty `PopulationMath`, w tym wybór celu dla losowania `18446744073709551615` oraz stan zajęcia większego od pojemności.

Przykład 1 s IHR away z [10](../10_verified_simulation_and_server_config.md) daje 102 kury i `0.9999999999999997`, gdy ostatni krok wynika z odejmowania `remaining`. Zastąpienie go sztywnym `0.1` zmienia ślad binary64; test celowo tego nie maskuje tolerancją.

Wynik L zapisuje się w `build/ihr-results.json` (artefakt lokalny, poza publikacją). Nie stanowi dowodu wykonania produkcji przed IHR w przyszłym koordynatorze, zachowania zegara, integracji petów/boostów ani zapisu DataStore. Nie zmieniono parametrów ani statusu odłożonego bilansu.
