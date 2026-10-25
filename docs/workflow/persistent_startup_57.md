# Bezpieczny start i awaria DataStore — #57

25.10.2026. Zakres: wybór storage, dopuszczenie sesji i potwierdzanie zakupów przy awarii. Bez zmian bilansu 17–21, danych referencyjnych, oferty i kwot produktów. Bez przepisywania historii Git. Nie wykonywano Studio, realnego DataStore ani płatności.

## Przyczyna i poprawka

Wcześniej Main zwracał nil przy błędzie GetDataStore/GetAsync, a Bootstrap zastępował brak portu pamięcią procesu. Gracz mógł dostać pozornie gotowe konto i potwierdzenie zakupu bez trwałego zapisu.

Main teraz domyślnie wybiera PERSISTENT. `RobloxDataStorePort.open` otwiera ten sam DataStore profili i wykonuje wyłącznie odczyt kontrolny przez istniejący adapter z ograniczonymi ponowieniami i UseCache=false. Pusta wartość klucza kontrolnego oznacza poprawny odczyt, nie awarię i nie nowe konto gracza. Nie tworzy się żadnego wpisu kontrolnego.

Nieudane otwarcie lub wyczerpanie prób sondy zatrzymuje inicjalizację: bez świata, remotes, Bootstrapu i sesji ekonomicznych. Obecni i kolejni gracze są odłączani z komunikatem o niedostępności zapisu. Tak zatrzymany proces nie staje się automatycznie serwerem lokalnym; ponowne uruchomienie zdrowej instancji może ponowić zwykły start.

Udana sonda nie dowodzi zdolności zapisu konkretnego profilu. Każdy gracz musi jeszcze skutecznie pozyskać sesję przez UpdateAsync. Błąd na tym etapie odrzuca wejście, zamiast tworzyć stan gotowy do gry. Odmówione połączenie nie ponawia pozyskiwania profilu na każdy pakiet. W trakcie trwającego ładowania nie otwiera się drugiej sesji; przechowywany jest co najwyżej jeden poprawny Bootstrap/RefreshState do obsługi po zakończeniu pierwszego wejścia.

Sam Bootstrap w runtime Roblox domyślnie wymaga PERSISTENT i poprawnego portu read/update. Brak lub niekompletny port jest błędem inicjalizacji. Późniejsza awaria nie podmienia self.store; istniejąca procedura niepewnego zapisu blokuje aktora i dalsze mutacje. Nadal obowiązuje odzyskiwanie sesji/własności, bez obchodzenia lease.

## Jawny lokalny tryb Studio

W Studio można ustawić na serwerowym skrypcie Main atrybut `UseLocalMemoryStore=true`. Wymagane jest rzeczywiste `RunService:IsStudio()`; na opublikowanym serwerze atrybut jest ignorowany. Tekst `"true"` nie włącza trybu. W Studio bez tego atrybutu nadal wymagany jest trwały port — nie ma automatycznego fallbacku przy wyłączonym dostępie do API.

STUDIO_MEMORY nie dotyka chmury i nie przyjmuje zewnętrznego store. Płatne podglądy, realizacja receipt i przyznawanie prawdziwych passów są wyłączone także w portach Bootstrapu/domeny. Zwykły lokalny kalendarz i rozwój testowy pozostają dostępne; dane tej sesji są świadomie nietrwałe. To tryb developerski, nie propozycja ekonomii.

INTERNAL_TEST_ONLY pozostaje domyślnym trybem czystych modułów w Lune z kontrolowanym storage/symulowanymi receipt. Jest zabroniony w runtime Roblox. Pozwala to zachować jednostkowe testy bez nadania produkcji prawa do automatycznej pamięci.

## Potwierdzenia zakupów

Zanim start wykona pierwsze potencjalnie oczekujące wywołanie storage, Main rejestruje jeden callback ProcessReceipt z delegatem zwracającym NotProcessedYet. Dopiero dopuszczona trwała inicjalizacja przełącza delegata na rzeczywistą obsługę. Tryb Studio memory oraz nieudany start zachowują odpowiedź odraczającą. Brak callbacku nie byłby bezpiecznym zastępstwem — [oficjalna dokumentacja MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) opisuje automatyczne potwierdzanie przy jego braku.

Nowa realizacja wymaga trwałego sukcesu. UNKNOWN, nieudany zapis i zapisane odrzucenie nie są potwierdzane. REPLAYED musi wskazywać terminalne APPLIED. Jeżeli sam retry lub nowa instancja potwierdzi wcześniej zapisany sukces, można zwrócić PurchaseGranted bez drugiej wypłaty. Bootstrap uwzględnia trwały wynik zwrócony przez submit, także gdy po restarcie nie ma jeszcze wpisu w pamięci koordynatora.

Gdy po utracie ACK powtórny UpdateAsync odczytuje istniejący wynik i anuluje transformację, repozytorium przyjmuje również ten zweryfikowany snapshot (po kontroli właściciela, generacji i argumentów). Koordynator synchronizuje working z trwałym sukcesem. Sam wynik bez odświeżenia stanu pozostawiał starszy profil i blokował następną operację; regresja sprawdza zakup, potwierdzone ponowienie i późniejszy odbiór kalendarza bez utraty zakupionych GE. Niepewny wynik nadal blokuje aktora — nowy snapshot nie jest zgadywany na podstawie samego pcall.

Nie zmieniono konfiguracji produktów ani zasad dostępności Pro (#58 pozostaje otwarte). Nie dodano obietnicy automatycznego ponowienia receipt co określoną liczbę sekund ani zwrotu środków.

## Dowody zachowania

[persistence_startup](../../tests/persistence_startup/run.luau) uruchamia **niezmodyfikowany tekst rzeczywistego Main.server** i osobno gałąź runtime Bootstrapu przez środowisko Lune. Kontroluje wyłącznie usługi Roblox, scheduler i wizualny WorldBuilder; Bootstrap, port native, protokół, koordynator, repozytorium i mutacje są rzeczywiste. Nie zwraca gotowego sukcesu zamiast domeny.

Scenariusze: błąd GetDataStore, nil portu, trwały/przejściowy błąd sondy, wyłączony dostęp do API Studio bez flagi, ignorowana flaga na produkcji, odrzucenie niekompletnego portu, nieudany zapis przy wejściu, odcięcie kolejnych prób tej samej odrzuconej sesji, handshake w trakcie UpdateAsync, awaria podczas płatności, utrata ACK i restart, potwierdzony retry oraz zakaz potwierdzania odrzuconego replay. Lokalny tryb sprawdza brak chmury i blokadę receipt/passów/płatnych podglądów przy zachowaniu darmowej rozgrywki.

Pięć nowych mutacji kontroluje brak wczesnego handlera receipt, przypadkowe włączenie płatności lokalnych, uznanie REPLAYED/REJECTED za grant, pominięcie trwałego replay po restarcie oraz pozostawienie starego working po potwierdzonym retry. To wybrane wady semantyczne, nie pełne pokrycie mutacyjne repo.

Pełny runner: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Wynik: **33 zestawy, 79 919 asercji PASS L**, w tym 154 nowej regresji startu. Wszystkie 15 wybranych mutacji wykryte; statyczny build 39 modułów/2 entrypointów. [Zapis weryfikacji i sumy kontrolne](persistent_startup_57_verification.json). Dokumenty 17–21 i reference_data porównano bajtowo z wersją bazową: bez zmian.

Weryfikacja L i statyczny build nie oznaczają rzeczywistej awarii chmury, uruchomienia Studio ani gotowości całej gry. Historyczne twierdzenia REL-01 w logu nadal podlegają #60. Pozostałe ustalenia audytu #58–61 nie są tą dostawą zamykane.
