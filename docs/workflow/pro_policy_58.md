# Bonus Pro i aktualna polityka konta — #58

Stan: 25.10.2026. Implementacja zatwierdzonego wariantu A z dokumentu 26; bez nowych produktów i zmian bilansu.

Własność Pro jest trwałym uprawnieniem. Bonus +10 punktów procentowych wymaga jednocześnie własności Pro i aktualnego, zaufanego wyniku serwerowego `ArePaidRandomItemsRestricted == false`. Brak odpowiedzi, błąd, nieprawidłowy typ albo trwający odczyt oznaczają niedostępność bonusu. Pozostałe korzyści Pro pozostają dostępne. Zapisane `pro_plus10_enabled` opisuje kwalifikację przy ostatnim nadaniu; nie jest źródłem uprawnienia do użycia bonusu.

Serwer odczytuje politykę przy wejściu i odświeża ją przed podglądem Pro oraz skonfigurowaną próbą fuzji. Zakup passa unieważnia poprzednią obserwację i uruchamia nowy odczyt, niezależnie od nadania pozostałych korzyści. Równoległe odczyty są łączone; odpowiedź starego żądania lub poprzedniej sesji nie zastępuje aktualnej. Odczyty sieciowe odbywają się poza transakcją zapisu. Walidacja na najświeższym stanie odrzuca zmienioną kwalifikację jako POLICY_CHANGED, bez zużycia materiałów.

Podgląd Pro przy nieznanej polityce jest niedostępny. Przy ograniczeniu pokazuje pakiet bez bonusu i jasną informację przed zakupem. Klient ponownie porównuje podgląd z ostatnim otrzymanym stanem przed otwarciem okna zakupu. Prywatny widok zawiera własność, faktyczną dostępność i stan allowed/restricted/unknown; surowa odpowiedź platformy nie trafia do widoku publicznego ani trwałego profilu. Widok opisuje ostatnią obserwację serwera, nie gwarantuje niezmienności polityki podczas zewnętrznego okna zakupu.

Reguła odpowiada [oficjalnej dokumentacji płatnych elementów losowych](https://create.roblox.com/docs/production/monetization/paid-random-items). Własność i potwierdzenie zakupu obsługiwane są zgodnie z [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService). Jest to naprawa konkretnego wariantu A, nie deklaracja całościowej zgodności wszystkich produktów z politykami platformy.

## Weryfikacja

Pełny runner: 34 zestawy, 80 126 asercji PASS; 20 wybranych mutacji wykrytych. Nowy zestaw pro_policy ma 207 asercji, obejmujących rzeczywisty entrypoint Main z kontrolowanymi usługami, oba porządki zakończenia odczytów, błędy, reconnect, spóźnione odpowiedzi, zmianę polityki, pięć slotów Pro oraz podgląd i potwierdzenie klienta. Istniejący zestaw startu storage zachowuje 154 asercje i korzysta ze wspólnego harnessu. Pięć nowych mutacji sprawdza skuteczność regresji polityki.

Testy lokalne L i statyczny build Rojo: 39 modułów, 2 skrypty wejściowe. Bez Studio, rzeczywistego PolicyService, DataStore i zakupów. Produkcyjna fuzja nadal wymaga osobnej konfiguracji i podglądu; fixture testowy jej nie włącza. Dokumenty 17–21 oraz dane referencyjne pozostają identyczne bajtowo z bazą. Pozostałe ustalenia audytu: #59–61.

[Dowody i sumy kontrolne](pro_policy_58_verification.json).
