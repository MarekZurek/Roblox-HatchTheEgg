# Trwałość identyfikatorów grup kur — #59

Stan: 25.10.2026. Naprawa zgodności z docs/38, bez zmian zasad resetu lub odłożonego bilansu.

Zmiana jaja i prestiż zerowały hatchGroupSequence. Po usunięciu dawnych grup następna kura mogła otrzymać identyfikator użyty na poprzedniej farmie. Opóźnione dotarcie dawnej grupy mogło wówczas zamknąć nową grupę o tym samym ID.

Obie operacje zachowują teraz dokładny tekstowy licznik ExactUInt. Nadal usuwają grupy w drodze, rezerwacje i runningCount zgodnie z resetem farmy. Nowa grupa zwiększa zachowany licznik; zamknięcie grupy nie obniża go. Nie dodano migracji ani odgadywania historii starszych profili bez licznika.

Regresje w tests/resets/run.luau obejmują obie operacje dla liczników 0, 123 i 9007199254740992. Sprawdzają rzeczywiste wypuszczenie przed resetem, zachowanie najwyższego ID, format trwałego profilu i JSON round trip, kolejne dokładne ID, spóźnione dotarcie dawnej grupy oraz poprawne i powtórzone dotarcie nowej. Oczekiwane ID są podane niezależnie od algorytmu inkrementacji. Dotychczasowy test oczekujący zera poprawiono na zachowanie licznika. Nowa regresja przed poprawką odtworzyła błąd: UpgradeEgg retains high watermark: 0 != 1.

Zestaw resets: 1148 asercji PASS (114 nowych). Dwie mutacje przywracające reset licznika osobno dla zmiany jaja i prestiżu włączono do wspólnego sprawdzania mutacji.

Weryfikacja jest lokalna L i statyczna, bez Studio, chmury lub zmian danych kont. Dokumenty 17–21 i dane referencyjne bez zmian. Pozostałe ustalenia audytu: #60–61. [Raport weryfikacji](reset_group_ids_59_verification.json).

Pełny runner: **34 zestawy / 80 240 asercji PASS**, **22/22 wybrane mutacje wykryte**, w tym obie mutacje #59. Statyczny build: 39 modułów / 2 skrypty wejściowe.
