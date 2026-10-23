# Kalendarz — ochrona odbioru nagród

Bieżące reguły: [CURRENT_SPEC](CURRENT_SPEC.md), [22 — D07](22_gameplay_rules_for_approval.md). Skalowanie: [15](15_calendar_gameplay_formula_and_roblox_scope.md).

## Odbiór i ponowienia

- Serwer sprawdza uprawnienie do konkretnego dnia i brak wcześniejszego odbioru.
- Blokada przycisku i pojedynczy alert nie zastępują trwałej ochrony serwerowej.
- Koszt, nagroda, oznaczenie odbioru, identyfikator operacji i wynik tworzą jedną trwałą operację zgodnie z D07.
- Powtórzenie żądania zwraca zapisany wynik bez nowej wypłaty lub losowania.
- Nieznany wynik zapisu wymaga rozstrzygnięcia; timeout nie oznacza anulowania.
- Zegar serwera określa dostępność. Zmiana dnia nie usuwa historii odbiorów i wyników operacji.

To wymagania przyszłej realizacji, nie raport testów działającej gry. Nie ustalają nowego bilansu.
