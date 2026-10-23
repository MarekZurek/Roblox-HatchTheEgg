# Następny task dla Opusa — przegląd D04/D05/D07

Prompt do wklejenia; zadanie nie zostało uruchomione ani wysłane do innego modelu.

```text
Przeprowadź przegląd przypadków brzegowych podwajacza i bonusowych prezentów HatchTheEgg. Tylko analiza dokumentacji: nie edytuj plików, nie pisz kodu, nie uruchamiaj symulacji i nie zmieniaj bilansu.

Przeczytaj docs/CURRENT_SPEC.md, docs/22_gameplay_rules_for_approval.md i docs/TODO.md. Przy weryfikacji reguł źródłowych korzystaj według potrzeby z docs/12_calendar_scaling_and_video_doubler.md oraz docs/16_pet_stacking_offline_and_package_schedule.md. Oddziel model referencyjny od zatwierdzonej adaptacji Roblox.

Zatwierdzone:
- pierwsza aktywacja podwajacza i pierwszy odbiór bonusowego prezentu każdego dnia UTC są darmowe, mają osobne liczniki i nie kumulują się za opuszczone dni;
- kolejne użycia za GE, opcjonalnie Robux; cen i konkretnych produktów nie ustalamy;
- podwajacz: długość 2+0.5×poziom godzin, maksymalnie 8 h; odnowienie przy pozostałym czasie <2 h, termin nadpisywany, nie sumowany; czas biegnie offline;
- płatny prezent ma dokładną zawartość ujawnioną przed zakupem; wynik ustalony przy utworzeniu oferty i zachowany przy ponownym wejściu;
- limit 2 zwykłych paczek +1 bonusowej, z miejscem zajętym również podczas dostawy; brak automatycznego wygaśnięcia i backlogu za offline;
- D07: trwałe jednokrotne rozliczenie. Timeout nie dowodzi anulowania; nieznany wynik trzeba rozstrzygnąć przed ponowieniem wypłaty/obciążenia.

Przygotuj maksymalnie 20 scenariuszy w tabeli: stan | działanie | oczekiwany wynik | R/P/brak decyzji | źródło. To specyfikacja, nie wykonane testy.

Uwzględnij: granicę 2 h i wygaśnięcie, osobne darmowe liczniki, północ UTC, ofertę powstałą poprzedniego dnia, zmianę badań/eventu/jaja między ofertą a odbiorem, brak GE, odrzucenie płatności, ponowne żądanie, nieznany wynik zapisu, opóźnione potwierdzenie Robux, dwa żądania równocześnie i pełny kanał paczek.

Nie wymyślaj brakujących zasad, cen, limitów dziennych ani uprawnień Pro/premium. Nie rozwiązuj automatycznie zderzenia zakupu rozpoczętego przed północą z darmowym użyciem nowego dnia. Wyraźnie oznacz każdą lukę. Rozdziel decyzje produktu od szczegółów technicznych przyszłej realizacji. Nie zakładaj, że walidacja klienta zapewnia bezpieczeństwo albo że nieudana odpowiedź oznacza brak zapisu.

Na końcu wypisz maksymalnie 5 rzeczywistych brakujących decyzji, z minimalną rekomendacją oznaczoną P. Jeśli źródła wystarczają, nie dopisuj sztucznych luk. Dokumenty 17–21, analysis, kontrakty i implementacja pozostają poza zakresem.
```
