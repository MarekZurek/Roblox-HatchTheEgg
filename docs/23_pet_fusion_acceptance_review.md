# Przegląd scenariuszy akceptacyjnych łączenia petów

> **Aktualizacja po decyzji użytkownika:** definicja stopnia tier × cel, wcześniejsze zdjęcie/odblokowanie i brak automatycznej podmiany materiałów są zatwierdzone R. Poniższa tabela zachowuje ocenę scenariuszy sprzed tej akceptacji (H); dawne „nadal P” w tych punktach nie jest aktualną listą braków. Kierunek trudności i Rainbow jako ostatni wariant nie zostały osobno zatwierdzone. Aktualne zasady: [22](22_gameplay_rules_for_approval.md).

23.10.2026. Przegląd 20 scenariuszy przekazanych przez użytkownika, przygotowanych przez Opusa. To recenzja dokumentacji, **nie wykonane testy ani zatwierdzenie definicji stopnia**. Źródło statusów: [22](22_gameplay_rules_for_approval.md) i rzeczywiste decyzje użytkownika. Brak implementacji, symulacji i zmian bilansu 17–21.

## Korekty do raportu

| Scenariusz / uwaga | Korekta i powód |
|---|---|
| 1–2, 9–16 i 19 | Zatwierdzone są rdzenie: skutek sukcesu/porażki, +10 p.p., gwarancja i trwałość jej licznika. Konkretna receptura oraz kategoria bazowej szansy nadal zakładają definicję stopnia P. Nie traktować całego przykładu gatunek/tier/wariant jako zatwierdzenia wszystkich warunków wejścia. |
| 6–7: wyposażone i zablokowane kopie | Status P / brak pełnego rozstrzygnięcia, nie R. „Nie wybierać automatycznie” nie oznacza zakazu ręcznego wyboru ani obowiązku wcześniejszego zdjęcia/odblokowania. Te mocniejsze reguły są propozycją ochrony UI, której użytkownik jeszcze nie zatwierdził. |
| 8: zmiana peta bazowego | Brak rozliczenia przed wykonaniem próby jest zgodny z zatwierdzoną transakcją. Automatyczne przeniesienie starego bazowego A do materiałów nie wynika z tej reguły. Rekomendacja P: po zmianie bazowego usunąć A z wyboru, a użycie go jako materiału wymaga jawnego wyboru; ponownie pokazać podgląd. |
| 11 i 13: gwarancja | 100% nie pomija walidacji dostępności receptury i wymaganych materiałów. Poprawny przypadek wymaga ich obecności. Sam licznik >=N nie daje bezpłatnej ewolucji. |
| 14: porażka przy liczniku 3 | Warunek powinien jawnie obejmować 3<N i końcową szansę <100%. Bez tego dla nieznanego N lub premium losowanie porażki może być niemożliwe. Zamiast wprowadzać N, użyć symbolicznego f<N. |
| 17–18: utrata połączenia | Rozróżnić brak trwałego wykonania od nieznanego wyniku zapisu. Przerwane połączenie/timeout nie dowodzi anulowania. Jeśli zapis już utrwalił wynik, wraca ten sam rezultat. Jeśli stan potwierdza niewykonanie i żaden zapis nie jest już w toku, nie ma zużycia. Jeśli status jest nieznany, najpierw trzeba go rozstrzygnąć dla tego samego ID; nie wolno od razu pozwalać na nowe losowanie. To wymagane zachowanie D07, bez wyboru techniki implementacji. |
| „Częstotliwość zapisu po łączeniu to detal” | Mechanizm i organizacja zapisów są detalem, ale **moment uznania wyniku za trwale zakończony nie jest dowolny**. Nie potwierdzać sukcesu jako trwałego przed zapewnieniem trwałości całej operacji. Sam późniejszy checkpoint, który może zgubić potwierdzone zużycie/wynik lub umożliwić powtórkę, nie spełnia D07. |
| „Obie strony muszą walidować” | D07 wymaga niezależnej autorytatywnej walidacji serwera. Walidacja klienta jest pomocą UI, nie podstawą bezpieczeństwa ani osobnym zatwierdzonym wymogiem każdej ścieżki. |
| Brakujące p, N i liczby kopii | Są odłożonymi parametrami. Nie blokują opisania i późniejszego sprawdzania reguł symbolicznie, warunkowo dla poprawnej konfiguracji. Blokują zamrożenie liczbowego bilansu, nie obecny przegląd logiki. |
| Definicja stopnia i zgodność kopii | Nadal P. Zgodność gatunku/tieru/wariantu można zatwierdzić osobno od wyboru klucza tabeli szans; brak definicji stopnia nie oznacza automatycznie, że wszystkie walidacje są niemożliwe do opisania. |

## Historyczna lista decyzji przed ostatnią akceptacją (H)

1. Propozycja stopnia **tier pochodzenia × cel** i zgodności kopii, wraz z Rainbow jako ostatnim wariantem v1 — nadal P.
2. Reguła ręcznego używania wyposażonych/zablokowanych petów oraz zachowanie wyboru po zmianie peta bazowego — nadal P. Rekomendacja: najpierw jawnie zdjąć/odblokować; nigdy nie podmieniać materiałów automatycznie po zmianie bazowego.

Nie ustalono nowych procentów, progów, cen, receptur ani oferty produktu. Premium +10 p.p. oraz zachowanie bazowego / zużycie kopii / licznik gwarancji pozostają R. Przekazanie scenariuszy nie jest akceptacją propozycji P.
