# PRE-01–03 — zakres przygotowania i review

24.10.2026. **Dokumentacja P przygotowana; implementacja i L/S/D niewykonane.**

## Dostarczone materiały

- [33 — PRE-01](../33_pre01_toolchain_and_clocks.md): przypięte wersje warsztatu, mapowanie źródeł, Clock i rozdzielenie dowodów.
- [34 — PRE-02](../34_pre02_sessions_and_retention.md): natywny adapter jednego agregatu, lease/fence, UNKNOWN, limity retencji i recovery.
- [35 — PRE-03](../35_pre03_routes_and_arrivals.md): serwerowe trasy, zachowanie grup podczas upgrade/reconnect oraz faza dotarć zgodna z kolejnością kroku.

## Wkład pomocniczy

Cline / DeepSeek v4.1 Flash przygotował równolegle szkice PRE-02 i PRE-03 na podstawie przekazanych fragmentów kontraktów. Nie korzystał z narzędzi ani nie edytował projektu. W redakcji nie przyjęto błędnego sumowania budżetów 2+3 MiB, przenoszenia monotonicznego zegara między serwerami, traktowania braku wpisu jako pewnego niewykonania, sztywnego formatu uint64 dla wszystkich identyfikatorów ani odrzucania spóźnionych prawidłowych dotarć. Nie przeniesiono także błędnej interpretacji L/S jako pul zdarzeń.

AGY / Gemini 3.8 Flash otrzymał pełne teksty 33–35 i skrót wiążących reguł 27/28/31. Wynik tekstowego QA: **PASS**, bez wskazanych usterek. Sprawdził podział zegarów, pojedynczy agregat, fencing/UNKNOWN, wliczanie ledger do rozmiaru profilu oraz fazę dotarcia i reconnect. Nie był to pełny ponowny audyt starszych dokumentów, niezależne sprawdzenie API ani testy wykonania. Brak usterek w tym review nie dowodzi działania adaptera.

## Kontrola lokalna i ograniczenia

Sprawdzono istnienie lokalnych celów Markdown i parsowanie JSON, a listę zmienionych plików porównano z sumami SHA-256 sprzed zadania. Zmiany ograniczono do dokumentów przygotowania, ich indeksów i rejestru zadań. Dane referencyjne, docs 17–21, skills i kontrakty 27–28 pozostały bajtowo niezmienione. Nie instalowano narzędzi, nie tworzono konfiguracji wykonywalnych, kodu gry lub sceny, nie używano Studio/DataStore.

PRE-* zamykają przygotowanie dokumentacji. Weryfikacja wersji w działającym warsztacie pozostaje IMP-01, rzeczywistego zapisu IMP-07, sceny IMP-13 i integracji IMP-15. Długotrwała retencja bez utraty replay pozostaje bramką wydania, a ograniczony wewnętrzny profil z 34 nie jest jej zaliczeniem. Wybory P nie otrzymały statusu R. Zwykła publikacja nowych dokumentów nie przepisuje historii Git.
