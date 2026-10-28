# Naprawy po review24de421 i porządki kodu — 28.10.2026

## Zakres

Na zlecenie użytkownika naprawiono serwerowe zakupy nieobsługiwanych Epic, klikalne oferty WKRÓTCE oraz podgląd prestiżu podczas wydarzenia. Usunięto potwierdzone martwe helpery i duplikaty. Baza:24de421. Użytkownik zlecił commit i push tej dostawy wraz z testami oraz dokumentacją; zdalne SHA i wynik aktualizacji zgłoszeń są potwierdzane po publikacji. Bez nowego Studio, chmury lub publikacji Roblox. Wcześniejsze zmiany dokumentacji RCB zachowano.

## Zachowanie

- Nowy `src/shared/FeatureAvailability.luau` jest wspólną jawną polityką dla HUD, Bootstrap i adaptera produktów. Nieobsługiwane Epic i ich aliasy odrzucane są przez serwer przed pobraniem GE. Katalog nadal potrafi odczytać historyczne poziomy/efekty; nie kasujemy postępu ani nie przyznajemy automatycznych zwrotów.
- Auto-Hatch, BuyMAX i Epic Robux nie są sprzedawane, dopóki ich korzyści/rozliczenie nie są gotowe. HUD ustawia Active=false i sprawdza politykę w callbacku oraz wspólnej ścieżce marketplace. Serwer odrzuca przygotowanie i niezatwierdzone potwierdzenie takiego produktu. Historyczna własność i idempotentne odtworzenie wcześniejszych sukcesów pozostają zachowane. PRO, 2× Cash i obsługiwane produkty pozostają dostępne według dotychczasowych reguł.
- ViewProjector używa eventPrestigeMult wyliczonego dla serverObservedAt i tej samej funkcji calculatePendingSoulEggs co operacja prestiżu. Podgląd obejmuje początek/koniec wydarzenia i odświeżenie po jego wygaśnięciu.
- Usunięto uproszczone wzory FV/SE z klienta. Gdy projekcji nie ma, panel pokazuje brak wyceny i blokuje akcję zamiast wyliczać wynik z portfela. Formatowanie zachowuje ułamkowy podgląd SE.

## Porządki

- Usunięto cf z FarmPlotBuilder, _nextStreamSerial z NetworkGateway i _buildCloseButton z HUD. Testy sprawdzają rzeczywisty przycisk zamknięcia okna.
- Usunięto dwie kopie getEpicRobuxTier i niedostępne callbacki zakupu Epic Robux; ukryte przyciski pozostają nieaktywne. Ręczne progi cen Robux nie są już wyliczane przez HUD.
- Common przyjmuje wyłącznie całkowity tier1..13. Usunięto gałęzie dawnego tier14; Epic ma osobny modal.
- Dźwięk nagrody pop/coin ma jednego właściciela: potwierdzony popup w Main klienta. Żądanie hitDrone/claimOffer nie odtwarza nagrody przed wynikiem ani ponownie po sukcesie.
- Katalogi nazw, opisów i układu UI pozostają metadanymi prezentacji; nie eksportowano prywatnego katalogu serwera do klienta. Nie zmieniono cen ani formuł ekonomii. Polityka dostępności ma jedno źródło, a matematyka FV/SE pozostaje na serwerze.

## Testy

- `remaining_fixes`: **198 asercji PASS**. Pięć niedostępnych Epic, aliasy, poziomy0/2, ponowienia, brak obciążenia/utraty postępu, pozytywny zakup obsługiwanego badania; sześć niedostępnych produktów, stare rezerwacje i własność; event×4 na początku i granicy końca, porównanie projekcji z grantem oraz delta po wygaśnięciu; brak optymistycznego audio dla odrzucenia i sukcesu.
- `ui`: **444 asercje PASS**. Zablokowane akcje także po programatycznym Activated:Fire, obsługiwany Epic, nieaktywny Robux, brak wymyślonego FV/SE, autorytatywna wycena, odrzucenie tier14 i rzeczywisty close.
- `epic_research`:269 PASS; `purchase_recovery`:109 PASS; `resets`:1148 PASS. Oczekiwania wcześniejszych testów dostosowano do niedostępnych ofert; nie usunięto kontroli wspieranych zakupów i odtwarzania uprawnień.
- Nowy zestaw jest zarejestrowany w tools/test.ps1. Kontrole mapowania uwzględniają42 moduły (nowa publiczna polityka) i2 entrypointy, z zachowaniem granicy prywatnych modułów.
- Końcowy pełny `tools/test.ps1`: **52 zestawy Luau +11 testów Python PASS, exit0**; generatory/oracle i statyczne mapowanie Rojo **42 moduły +2 entrypointy PASS**. Log:build/remaining_fixes_full.log. Gate:LOCAL CHECKS PASSED; RELEASE NOT APPROVED; S/D/H NOT VERIFIED.

Pierwsze przebiegi ujawniły brak zależności w nowym mocku HUD, dawny fixture awansu bez homeFV i starą liczbę41 modułów w kontroli wydania. Poprawiono testowe zależności/oczekiwania i ponowiono sprawdzenia. Dowody są lokalne; testy nie zastępują odbioru telefonu/Studio ani prawdziwego DataStore i zakupów.

## Pozostałe granice

Aktywacja zwykłych boostów (#92) oraz zakup silosów/odblokowanie Hyperloop (#93) nadal wymagają własnej implementacji i nie są deklarowane jako naprawione. Czasowy podwajacz i aktywne RCB pozostają wycofane. Nie zmieniano docs17–21 ani danych referencyjnych. Do testu Studio potrzebna jest pełna synchronizacja z nowym modułem Shared/FeatureAvailability; nie wystarczy podmienić samego HUD.

## Powiązane zgłoszenia

Publikacja obejmuje zabezpieczenia #83/#85/#90/#91, zgodność podglądów #86/#87 i porządki kodu. #84 poprawiono wcześniej i utrzymano jego regresje. #92 nadal dotyczy niezaimplementowanej aktywacji boostów; #93 nadal wymaga pełnego zakupu silosów/Hyperloop. Stan zgłoszeń aktualizowany po potwierdzonym pushu, z linkiem do tej dostawy i ograniczeniami dowodów.
