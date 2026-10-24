# IMP-02 — katalog serwera

24.10.2026. Wykonanie lokalne L, **INTERNAL_TEST_ONLY**. To nie zatwierdzenie bilansu produkcyjnego. Katalog nie uruchamia usług, zakupów, inicjalizacji ani agregacji efektów.

Źródła: [manifest 30](../30_first_farm_manifest_and_technical_choices.md), [reguły 31](../31_research_hatching_rcb_and_new_account.md), [typy 27](../27_numbers_time_and_player_state_contract.md), niezmienione [research.json](../reference_data/research.json) i [infrastructure.json](../reference_data/infrastructure.json). Dane źródłowe zachowują `REFERENCE_ONLY` i brak zatwierdzenia konfiguracji produkcyjnej.

## Dostawa i API

[CatalogRegistry](../../src/server/CatalogRegistry/init.luau) przyjmuje zależności `new(NumericCodec, Data, {mode="INTERNAL_TEST_ONLY"})`. [Data](../../src/server/CatalogRegistry/Data.luau) jest modułem wygenerowanym przez [generator](../../tools/generate_catalog.py); nie ma zależności od ścieżek require specyficznych dla Studio lub Lune. W Studio konsument wstrzyknie ModuleScript kodeka i danych; w Lune test wstrzykuje te same moduły przez system plików. Katalog należy wyłącznie do mapowania serwera.

- `getCommon(id)` zwraca opis jednego z siedmiu badań; niewymienione ID są odrzucane.
- `researchPrice(id,currentLevel)` zwraca koszt następnego poziomu; na maksymalnym poziomie zgłasza `MAX_LEVEL`.
- `researchEffects(id,level)` zwraca izolowane efekty, w tym pusty rekord dla poziomu 0. Nie nadaje neutralnemu mnożnikowi wartości 0.
- `tierThreshold(tierRaw)` zwraca jeden z 13 referencyjnych progów. Nie oblicza punktów ani dostępności zakupu.
- `getEgg(0)` zwraca wyłącznie indeks, nazwę i wartość jaja 0; trofea/awans pozostają poza zakresem.
- `getHabitat(typeIndex)` / `habitatPrice(typeIndex,slotIndex)` obsługują COOP/SHACK i cztery indeksy slotów **0–3**.
- `getVehicle(typeIndex)` / `vehiclePrice(typeIndex,sameTypeOwned)` obsługują TRIKE/TRANSIT VAN; cena zależy od liczby posiadanych pojazdów tego typu **przed zakupem**, bez wyznaczania limitu floty.

Rekordy, zagnieżdżone listy i API są zamrożone; konstruktor odcina dane wejściowe kopią. Wszystkie importowane liczby przechodzą walidację skończonej nieujemnej wartości NumericCodec v1. Indeksy są całkowite i sprawdzane względem konkretnego zakresu. Ceny zachowują binary64 bez zaokrągleń do wyświetlania. Jednostki pojemności pojazdów to jaja/min, kurników — kury; konwersja do jaj/s należy do przyszłej matematyki.

## Dowód L i odtwarzanie

1. `python tools/generate_catalog.py --check` — zgodność wygenerowanego modułu i SHA256 źródeł.
2. `python tests/catalog/build_oracle.py --check` — niezależny od generatora produkcyjnego odczyt źródłowych JSON i bitów binary64 przez Python/struct.
3. `.tools/lune-0.11.1/lune.exe run tests/catalog/run.luau` — **2732 asercje PASS**: 163 ceny badań, 170 rekordów efektów (z poziomami 0), 13 progów, jajo 0, 8 cen kurników i 34 ceny pojazdów. Ponadto indeksy poza zakresem/NaN/Inf, maxLevel, odrzucone ID i tryb produkcyjny, izolacja wejścia oraz głęboka niezmienność.

Oczekiwania nie są eksportem testowanego generatora: test L czyta bezpośrednio oryginalne JSON dla struktury i rekordów oraz osobny [oracle bitów](../../tests/catalog/numeric_bits.json), odtwarzany z JSON przez [niezależny skrypt](../../tests/catalog/build_oracle.py). Kontrola SHA256 chroni przed użyciem nieaktualnego oracle.

Wykryto ograniczenie parsera `@lune/serde`: dla części liczb dekodowanie JSON różni się o 1 ULP od poprawnej wartości binary64. Przykład `11.377309475858523`: Python i literał Luau mają little-endian `079126b52ec12640`, parser serde zwraca `089126b52ec12640`. Dlatego serde nie jest wzorcem bitowym; testy nie maskują tej różnicy tolerancją. Generator zapisuje 17 cyfr znaczących, a wykonany kod jest porównywany bitowo z niezależnym oracle.

Nie uruchamiano Studio ani DataStore. Nie sprawdzono runtime replikacji w Studio; mapowanie serwera podlega odrębnej integracji. Nie zmieniono danych referencyjnych ani dokumentów odłożonego bilansu 17–21.
