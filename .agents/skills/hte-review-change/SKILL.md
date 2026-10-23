---
name: hte-review-change
description: Review a specific HatchTheEgg diff, delivery or integration for correctness, scope and evidence. Use for requested change review, not a whole-project audit or cosmetic style enforcement.
---

# Review konkretnej zmiany HatchTheEgg

Wejście: zlecenie/DoD, diff lub lista ocenianych plików z wersją oraz raport autora. Sprawdź [specyfikację](../../../docs/CURRENT_SPEC.md) i właściwe źródła z [workflow](../../../docs/workflow/WORKFLOW.md). Deklaracja PASS autora jest twierdzeniem do sprawdzenia.

## Procedura

1. Ustal dokładną wersję: commit, jeśli dostępny, albo SHA256 ocenianych plików. Odróżnij ocenę pakietu od jego integracji. Zmiana źródeł może unieważnić wcześniejsze wyniki.
2. Sprawdź zachowanie względem zakresu i źródeł R/N/S/P/H, wywołujących funkcji oraz dotkniętych interfejsów. Nie dodawaj brakującej reguły produktu na podstawie własnej preferencji.
3. Dla dotkniętej ekonomii/zapisu sprawdź autorytet serwera, zużycie i wynik, powtórki, nieznany zapis, timery i konwersje. Dla UI oceń rzeczywiste stany/prezentację, bez pełnej regresji progresji z samej zmiany wyglądu.
4. Zweryfikuj dowody: jakie kontrole rzeczywiście wykonano, w jakim środowisku i na jakich plikach. Test na mocku nie dowodzi chmury; dokumentacja referencyjna nie jest wykonaniem nowego Luau. Dobierz brakujące sprawdzenie do rzeczywistego ryzyka.
5. Zwróć konkretne ustalenia z miejscem, skutkiem i potrzebną korektą/kontrolą. Nie zmieniaj działającego kodu dla stylu i nie dopisuj sąsiednich audytów.

## Wynik i granice

W dotkniętym przepływie danych sprawdź zapisy nigdy nieodczytywane lub nadpisywane przed wykorzystaniem. Dla wartości obliczanych ustal źródło, jednostkę, bazę i warstwy mnożników; zgłaszaj konkretny skutek niejasności, nie sam brak komentarza.

Przy review wydania lub zmian narzędzi developerskich sprawdź, że konfiguracja produkcyjna nie tworzy ani nie rejestruje testowych RemoteEvents/RemoteFunctions lub handlerów przyznających zasoby i omijających reguły gry. Ukrycie przycisku debugowego na kliencie nie wystarcza. Nie rozszerzaj tej kontroli na niezwiązane zmiany ani na zakaz zwykłej diagnostyki.

Status: poprawne w ocenionym zakresie / wymaga poprawy / niezweryfikowane. Użyj [raportu](../../../docs/workflow/TASK_TEMPLATES.md); nie deklaruj SHIP całej gry z pojedynczego diffu. Autor może wykonać self-review, ale nie nazywać go niezależną akceptacją.

Review domyślnie nie modyfikuje ocenianego kodu. Testy i raport mieszczą się w przyznanym zakresie; skill nie uprawnia do uruchomienia produkcji lub delegacji. Nie zmieniaj odłożonego bilansu i docs/17–21 ani nie otwieraj ponownie zamkniętych ustaleń niezwiązanych ze zmianą.
