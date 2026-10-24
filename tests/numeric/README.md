# NumericCodec — testy L

Z katalogu projektu w PowerShell:

```powershell
./tools/bootstrap.ps1
./tools/test.ps1
```

Bootstrap pobiera przypięte narzędzia do ignorowanego .tools, sprawdza SHA-256 archiwów i plików wykonywalnych. Test nie pobiera zależności. Wynik L i plik sceny powstają w ignorowanym build/. Nie wykonuje się synchronizacji, publikacji lub testu Studio/DataStore.

Test importuje ten sam [NumericCodec](../../src/shared/NumericCodec.luau), który Rojo mapuje do ReplicatedStorage/HatchTheEgg/Shared. Korzysta z wbudowanych asercji i buforów IEEE-754; runner Lune dodaje tylko zapis raportu i JSON. Po IMP-02/03/07 tools/test.ps1 uruchamia również nowe suite i dwa niezależne sprawdzenia katalogu wymagające Python 3.10+; ścieżkę można podać przez -PythonExecutable. Sam bezpośredni runner NumericCodec nadal nie wymaga Pythona.

[Wektory](reference_vectors.luau) pochodzą z niezależnego [generatora Python](../../tools/generate_numeric_vectors.py): dokładne int, float i struct, stały seed 0x48544501. Żadne oczekiwanie nie jest wyznaczane przez testowany codec. Są danymi testowymi, nie bilansem. Odtworzenie wektorów: python tools/generate_numeric_vectors.py (Python 3.10+; stdlib, bez pakietów). Sam runner NumericCodec nie wymaga Pythona; pełny runner warsztatu od IMP-02 używa go do kontroli katalogu i mapowania.

Sprawdzane są: bitowy round-trip bin64, kanoniczne +0, skrajne normalne i subnormalne, strict decimal/NaN/Inf/underflow, uint64 i przeniesienia/pożyczki, overflow, granice 2^53, konwersja zaokrąglana z flagą exact, brak mutacji wejść, float32 oraz potrącenie kwoty mniejszej niż ULP. Brak porównywania salda epsilonem i brak potęgowania/symulacji progresji.
