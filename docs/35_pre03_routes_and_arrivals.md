# PRE-03 — RouteProvider i autorytatywne dotarcie

24.10.2026. **P — kontrakt techniczny, dokumentacja przygotowana.** [#9](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/9). Podstawa: [27](27_numbers_time_and_player_state_contract.md), [28](28_modules_and_client_server_contract.md), [31](31_research_hatching_rcb_and_new_account.md). Bez sceny, kodu, wartości prędkości i zmian bilansu.

## 1. Granica odpowiedzialności

Serwer wybiera kurnik regułą wolnych miejsc z 31. RouteProvider nie wybiera najbliższego lub najpustszego kurnika. Sprawdzenie zapasu i pojemności poprzedza wypuszczenie; przy starcie wspólnie zmieniają się zapas −1, rezerwacja +1 oraz running +1. Dopiero dotarcie zmienia rezerwację −1, running −1 i settled +1. Tylko settled produkuje. RCB korzysta z serwerowego running, nie liczby modeli.

Animacja, klientowskie Touched i komunikat „dotarłem” nie zwiększają populacji. Scheduler może obudzić koordynator po terminie; spóźnione prawidłowe dotarcie nie przepada. Duplikat jest no-op.

## 2. Dane RouteProvider i grupy

| Dane | Kontrakt P |
|---|---|
| Definicja trasy | routeVersion, stabilny targetSlot, wersja sceny, punkty polilinii w lokalnych współrzędnych farmy, długości odcinków w studs |
| Ruch | Wersjonowany speedProfile: dodatnia skończona prędkość studs/s na każdym odcinku |
| Grupa w profilu | groupId, liczność ExactUInt, targetSlot, routeVersion, startInstantMs, travelDurationSeconds, status IN_TRANSIT |
| Zachowany przebieg | Niezmienny snapshot używanej trasy/profilu ruchu albo jego wersja z trwałą definicją w tym samym agregacie |
| Termin | startInstantMs/1000 + travelDurationSeconds; porównania zachowują ułamki Duration z 27 |

Długość i duration oblicza serwer; czas = suma długość/prędkość dla odcinków. Nie ma globalnej stałej 6 s. Prędkość i rzeczywiste punkty ustali IMP-13 w scenie; nie jest to brak wzoru gospodarki ani pozwolenie na zmianę tempa w tym zadaniu. Zerowa długość całej trasy, brak celu, niefinitywne wartości lub brak profilu ruchu uniemożliwiają start przed zużyciem zapasu.

Nowa grupa nie ma luźnego „pending” poza profilem po obciążeniu. Rezerwacja, start i dane umożliwiające odtworzenie stanowią spójny kandydat koordynatora. Budżet przechowywania sprawdza [34](34_pre02_sessions_and_retention.md); odmowa admission nie zabiera zapasu. Grupowanie jest dozwolone tylko przy identycznym celu, trasie i czasie dotarcia, bez zmiany liczności lub terminów. Limit renderowanych modeli klienta nie jest limitem kur.

## 3. Zmiana kurnika i odtworzenie

Upgrade zachowuje targetSlot i logiczną rezerwację. Nowe wypuszczenia otrzymują nową wersję trasy. Grupy w locie zachowują wcześniejszą geometrię oraz duration; nie teleportują, nie zmieniają celu ani czasu wskutek podmiany modelu. Scena utrzymuje stabilny punkt wejścia slotu albo wizualizuje stary snapshot; wygląd nie steruje ekonomią.

Brak aktualnego modelu po reconnect nie blokuje dotarcia, jeśli zachowany serwerowy termin i rezerwacja są prawidłowe. Uszkodzony termin, ujemna liczność lub niespójność running/rezerwacji/grup wymaga odzyskiwania profilu; nie zgadujemy zera i nie przyznajemy dodatkowej populacji. Usunięcie grupy po jej rozliczeniu i zmiany liczników są jednym checkpointem, aby restart nie odtworzył wypłaconego dotarcia.

## 4. Dotarcie a siatka symulacji

**Jawny wybór P:** geometryczny termin określa gotowość grupy; zmiana populacji jest stosowana w fazie dotarć na końcu pierwszego modelowego kroku obejmującego ten termin, po produkcji/transportowaniu/księgowaniu i przed wylęgiem/refill/IHR. Oznacza dyskretyzację do kroku maksymalnie 0.3 s, nie dodatkowy krok. To projekt integracji, nie twierdzenie o potwierdzonej ciągłej symulacji ruchu.

Dla kroku (start,end] produkcja korzysta ze stanu początkowego według 27. Potem wszystkie nierozliczone grupy z terminem <=end przechodzą IN_TRANSIT→settled w kolejności termin, groupId. Termin równy end wchodzi w tę fazę; grupa już gotowa na start okresu jest rozliczana przed pierwszą produkcją. Kolejny krok używa nowej populacji i running. Nowe grupy wypuszczone w fazie wylęgu nie otrzymują produkcji w już zakończonym kroku.

Nie dzielić dt dla IHR, refill lub boostów z powodu dotarcia, nie pobierać efektów ponownie. Wewnętrzne yield i checkpoint nie są granicami nowych kroków. Zachować start/cel, indeks i fazę z 27; jeśli nie zapisano pełnej fazy, utrwalać tylko kompletny krok. Zakończenie krótszego końcowego kroku jest regułą 27, nie dodatkowym tickiem RouteProvider. Zmiany drzewa modeli nie przesuwają siatki.

W przyszłych testach należy osobno sprawdzić produkcję przed dotarciem i po nim oraz RCB: przy neutralnym c=1 zmiana running nie daje sztucznego bonusu. W pierwszej farmie nie dodajemy boostów/eventów; przy NEXT-03 zachować ich semantykę z 27 bez dodatkowych aktualizacji.

## 5. Reconnect i away

Przerwa <=60 s pozostaje online: odtworzyć grupy i ich terminy oraz rozliczyć kolejne kroki; nie zamykać wszystkich grup automatycznie. Przy >60 s ścieżka away z 31 zamyka istniejące grupy dokładnie raz przed produkcją away. Następnie silosy ograniczają okno produkcji, a settledWallThrough zamyka całą nieobecność, także odcinek bez dochodu. Nie dokładać drugiego mechanizmu dotarcia tych samych kur i nie utrzymywać running RCB dla zamkniętych grup.

Checkpoint po powrocie zapisuje grupy, rezerwacje, running, settled i ekonomię wspólnie. Przerwanie zapisu korzysta z UNKNOWN/fence z 34. Ponowne połączenie nie resetuje duration ani trasy. Klient dostaje jawny podzbiór danych wizualnych przez projekcję 28; prywatny ledger i ownerToken nie są ujawniane.

## 6. Odbiór projektu i przyszłe testy

| Przypadek | Kryterium | Właściciel dowodu |
|---|---|---|
| Cel o zerowej pojemności / brak route | Brak startu, kosztu i rezerwacji | IMP-06/13, L |
| Geometryczny termin wewnątrz kroku i równy end | Stara populacja produkuje w tym kroku; dotarcie przed IHR, bez dodatkowego dt | IMP-09, L |
| Duplikat, spóźniony scheduler, checkpoint po produkcji | Jedno dotarcie; spóźnienie nie gubi kury | IMP-08/09, L |
| Podmiana kurnika w locie | Cel i czas grupy zachowane; nowe grupy używają nowej trasy | IMP-13/15, S |
| Klient fałszuje Touched i liczbę modeli | Brak wpływu na populację i RCB | IMP-11/15, S |
| Reconnect 60 s / away >60 s / zero silosów fixture | Prawidłowa gałąź, zamknięcie grup raz, bez dodatkowego dochodu | IMP-09/15, L/S; zapis D w IMP-07 |

Przygotowano kontrakt dla niezależnej pracy IMP-13 nad sceną i IMP-06/09 nad czystymi przejściami. **Testy L/S/D niewykonane.** Rzeczywista geometria i pomiar czasu animacji należą do implementacji, nie wymagają kolejnego audytu mechanik lub wznowienia bilansu.
