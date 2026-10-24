---
name: hte-verify-domain-math
description: Verify a specific HatchTheEgg FV, SE, production, boost, offline or pet-stacking function against documented references. Not for progression simulation or price calibration.
---

# Weryfikacja matematyki domenowej HatchTheEgg

Wejście: konkretna funkcja, jej jednostki, wejścia i zmieniane zachowanie. Wybierz źródła z [mapy workflow](../../../docs/workflow/WORKFLOW.md) i sprawdź ich status w [CURRENT_SPEC](../../../docs/CURRENT_SPEC.md). Nie wczytuj całego zbioru analiz bez potrzeby.

## Procedura

1. Rozdziel znaczenia: FV, sprzedaż/dochód, saldo, przychód prestiżowy i końcowe SE. Nie sprawdzaj funkcji dochodu samym wynikiem FV.
2. Ustal jednostki czasu, indeksy, bazy i warstwy research vs pełne GDR/pety/boosty. W FV nie podmieniaj wejść ResearchEngine pełnymi bonusami wyposażenia; Phoenix wzmacnia przyszły przychód prestiżowy, nie końcowe SE ani historię wstecz.
3. Dobierz istniejące wejścia/wyniki referencyjne z właściwego pliku. [Referencje ECC](../../../docs/ecc/adaptations/reference_testing_and_verification.md) są indeksem, nie dowodem wykonania. Nie generuj oczekiwań przez wywołanie testowanej funkcji.
4. Sprawdź dotknięte granice: zero, próg, cap, obcięcie, ograniczenie transportu/pojemności, wygaśnięcie. Kontroluj zegar/RNG jako zależności. Historyczny event dochodu i koniec kroku VD mają różne reguły; pozostały czas boostu nie jest absolutnym terminem.
5. Jeżeli zlecono i umożliwiono wykonanie Luau, uruchom odpowiedni istniejący runner (`./tools/test.ps1 -PythonExecutable python`), w tym kontrole spójności generatorów danych i wektorów (`tools/generate_catalog.py --check`, `tests/catalog/build_oracle.py --check`, `tools/generate_population_vectors.py --check`). Dobierz tolerancję do pola i konwersji (bitowy round-trip IEEE-754 dla `NumericCodec`/katalogu, dokładny `ExactUInt` bez `tonumber` dla `PopulationMath` i liczników), nie jeden epsilon dla wszystkiego. Jeśli zlecono tylko projekt kontroli, oddaj scenariusze z NIE URUCHOMIONO, bez tworzenia implementacji.

## Wynik i granice

Raport zawiera konkretne źródło i status N/S/R oczekiwań, rzeczywisty wynik albo brak uruchomienia oraz dotknięty zakres. N/S oznaczają rodzaj specyfikacji referencyjnej, nie wykonanie testów implementacji HatchTheEgg. Opisane wzory i przykłady nie dowodzą działania nowego Luau, a mock nie potwierdza chmury.

Nie kalibruj nowych cen, procentów, receptur, progu gwarancji, sił lub inkubacji. Nie wykonuj ponownie analiz progresji/prestiżu z odłożonego bilansu i nie zmieniaj docs/17–21. Nie otwieraj ponownie zamkniętych ustaleń ani nie uruchamiaj Studio lub zakupów bez zlecenia wymagającego takiej czynności. Materiały prywatne poza projektem nie są zależnością procedury; korzystaj z referencji dostępnych w docs, a brak wymaganych danych zgłoś wprost.
