# Reguły pierwszej farmy i backlog — zakres kontroli

24.10.2026. Materiał: [31](../31_research_hatching_rcb_and_new_account.md) i [32](../32_parallel_delivery_backlog.md). Wyłącznie dokumentacja, bez implementacji, zmian bilansu i przepisywania historii Git.

Autor sprawdził znaczenie licznika poziomów, inicjalizację podstawowej farmy i przejścia ręcznych kur w dostępnych materiałach. Ponownie porównał 50 zapisanych przypadków progu z points>=threshold oraz 144 zapisane przypadki RCB z q=min(c^n,K), mnożnikiem M tylko gdy q>1: zero rozbieżności. Nie uruchamiano ponownie symulacji progresji lub gry. Prywatne materiały pochodzenia pozostają poza projektem.

**Cline / DeepSeek v4.1 Flash:** pomocnicza analiza oczyszczonego skrótu reguł i propozycja DAG, bez narzędzi. Wykorzystano kontrolę press/hold/refill i rozdzielenia rezerwacji od populacji. Odrzucono zbędne zależności wszystkich czystych funkcji od koordynatora oraz IHR od gotowego serwisu produkcji. Wynik nie jest niezależnym audytem źródeł.

**AGY / Gemini 3.8 Flash Medium:** QA pełnego tekstu 31/32 oraz przekazanego skrótu potwierdzonych reguł, bez dostępu do innych plików. Werdykt pozytywny z dwiema uwagami: uniezależnić UI od ukończenia ClientStore i jawnie opisać zakres losowania celu. Obie rozpatrzono:

- IMP-14 zależy od DTO IMP-03 i testowego portu; rzeczywista integracja wymaga IMP-12 w IMP-15.
- Dopisano r w [0,V−1], r<v[h] i odejmowanie długości przedziału. Nie przyjęto błędnej sugestii, że 0 samo w sobie wymaga wskazania ostatniego slotu. Nie wybrano nowego generatora RNG.

Końcową korektę sprawdza autor; nie wysyłano jej ponownie do modelu. QA tekstu nie potwierdza wykonania gry lub zgodności całego repo. Dane N/S, wybory P i fixture nie otrzymały statusu R; konfiguracja wydania nadal wymaga właściwego zatwierdzenia. U05/U06 i dostarczenie czasu dotarcia przez scenę pozostają przyszłymi zadaniami.
