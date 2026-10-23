# Podwajacz dochodu — czas i składanie efektów

Aktualne decyzje produktu: [22](22_gameplay_rules_for_approval.md), D04. Jest to opis reguł, nie wynik testów implementacji HatchTheEgg.

## Aktywacja i odnowienie

- Pierwsza aktywacja dnia UTC jest darmowa; kolejne są płatne zgodnie z D04. Ceny pozostają odłożone.
- Odnowienie wymaga ściśle mniej niż 7200 s pozostałego czasu. Dokładnie 2 h nie spełnia warunku.
- Długość wynosi `2 + 0.5 * level` godzin, level 0..12, czyli 2..8 h. Poziom badania i czas odczytuje się przy skutecznym rozliczeniu aktywacji.
- Termin zostaje nadpisany na `now + duration`, bez dodawania starego pozostałego czasu. Przykład: 1 h pozostała i nowa długość 8 h dają 8 h, nie 9 h.
- Brak środków lub odrzucenie operacji nie zmienia terminu. D07 wymaga trwałego jednokrotnego rozliczenia; ponowienie żądania zwraca poprzedni wynik.
- Zmiana jaja i prestiż zachowują termin. Zmiana badania nie wydłuża aktywnego terminu; wpływa na następną aktywację.

## Dochód i offline

```text
V = 2 if stepEnd < videoEnd else 1
```

Przy `stepEnd == videoEnd` bonus jest nieaktywny. W referencyjnym modelu kroku do 0.3 s krok przecinający termin nie jest dzielony na część ×2 i ×1 — rozstrzyga koniec kroku.

V jest osobnym czynnikiem dochodu ze sprzedaży jaj. Mnoży się z mnożnikami aktywnych kategorii boostów, ale Beacon nie wzmacnia samego V ani jego długości. Przykład: boost 50 i Beacon 50 dają 2500×; aktywny podwajacz daje 5000× tego składnika dochodu.

Kilka uprawnień do tego samego podwojenia nie tworzy automatycznie ×4. Pro nie daje osobnego ×2 ani automatycznego odnawiania. Zasady produktów rozstrzygają dokumenty 25–26.

Termin podwajacza jest absolutny i upływa offline. Produkcja nadal podlega limitowi silosów. Nie należy scalać tego zegara z pozostałym czasem aktywnych boostów zużywanym przez symulację. Podwajacz nie przyznaje sam w sobie mnożnika dronów, prezentów, dochodu jednorazowego ani końcowej liczby SE.

## Powiązane reguły

Darmowe prawa VD i prezentu są osobne, globalne dla gracza w dniu UTC i nie resetują się przez zmianę jaja lub prestiż. Szczegóły granicy UTC, płatności i rezerwacji: [24](24_doubler_and_bonus_gift_acceptance_review.md). Skalowanie kalendarza: [15](15_calendar_gameplay_formula_and_roblox_scope.md).
