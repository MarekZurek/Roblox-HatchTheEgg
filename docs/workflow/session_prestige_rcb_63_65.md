# ID sesji, wydarzenie prestiżu i aktywne RCB — #63–65

Stan: 25.10.2026. Naprawy istniejących reguł z 28, 31 i 16, bez nowego bilansu i bez włączania funkcji odłożonych.

## #63 — nowe intencje i stare powtórki

Nowy klient resetował licznik zakupów i tworzył ponownie op-BuyResearch-1. Ledger zwracał dawny sukces zamiast nowego zakupu. Regresja przed poprawką: drugi zakup po reconnect otrzymał REPLAYED zamiast APPLIED i pozostał na poziomie 1.

Serwerowy strumień zawiera teraz trwałą generację właściciela profilu oraz licznik strumienia. Zmienia się także po ponownym handshake. W rzeczywistej sesji generacja pochodzi z SessionRepository; nowy proces nie odtwarza poprzedniej przestrzeni nazw. Izolowane mocki bez sekcji ownership mogą używać generacji 0, co nie jest ścieżką tworzenia kont runtime.

ShopController używa strumienia i własnego licznika dla ID nowej operacji. Upgrade Egg używa tej samej przestrzeni sesji z innym prefiksem; pozostałe komendy już korzystały ze strumienia. Nowa generacja strumienia chroni je również po restarcie procesu. Format jest szczegółem transportu, nie tokenem uprawnień.

Nie zmieniono formatu ledgera ani reguł replay: retry zachowuje oryginalny operationId i argumenty, nawet jeśli pochodzi ze starego strumienia. Nie usuwa się zapisanych wyników i nie przelicza dawnego zakupu jako nowej intencji. Kontrakty DTO i wersja profilu pozostają bez zmian.

## #64 — kolekcja SE przy prestiżu

Bootstrap wyznacza eventPrestigeMult z zaufanej konfiguracji liveEvents i zegara serwera przy przygotowaniu Prestige. Nie używa effectivePrestigeBoost: Soul Beacon/Phoenix należą do przyrostów przychodu wejściowego. Mnożnik kolekcji jest nakładany po funkcji SE i istniejącym bonusie Epic. Usunięto pobieranie mnożnika z argumentów operacji; kontrolowany kontekst deps pozostaje wejściem API domeny.

Przed zapisem serwer ponownie sprawdza aktualny mnożnik. Zmiana daje PRESTIGE_EVENT_CHANGED bez przyznania SE i bez resetu przychodu; nowa świadoma próba potrzebuje nowego ID. Przy zapisanym wyniku replay odtwarza pierwotne SE niezależnie od późniejszej zmiany eventu. Zachowano przedział aktywności [start,end), atomowy reset oraz ochronę UNKNOWN/recovery.

## #65 — biegnące kury i dochód

Agregator odczytuje istniejące onscreenChickenMult Common/Epic jako współczynnik c; mnożniki badań składa zgodnie z agregacją ich wymiaru. Limit K to baza 5 plus istniejące addytywne onscreenChickenMultMax Common/Epic. W obecnym katalogu nie ma odrębnego końcowego źródła M, więc pozostaje neutralne 1. Nie dodano nowego peta ani bonusu.

Wspólny wzór hatching_rcb.rcb jest dostępny także poza fabryką przejść; dotychczasowe API fabryki deleguje do tej samej funkcji. Produkcja dostaje runningCount z początku kroku i liczy q=min(c^n,K), stosując M tylko gdy q>1. Przy braku biegających kur lub neutralnym c wynik pozostaje 1. Dotarcia następują po produkcji, więc bonus znika od kolejnego kroku. Away zamyka grupy przed produkcją i nie zachowuje aktywnego RCB.

HUD oblicza ten sam bieżący bonus. RCB składa się raz z wartością jaj, mystical, petami, boostem dochodu, VD i historycznym wydarzeniem dochodu. Faktyczny dochód zasila istniejące akumulatory, w tym premię Soul Beacon. Nie podmieniono maksymalnego RCB we wzorze FV — problem adaptera FV pozostaje poza tym zakresem (#67).

## Weryfikacja i granice

tests/session_prestige_rcb/run.luau: **142 asercje**. Rzeczywiste ClientBootstrap/Bootstrap/Repository badają kolejne zakupy po reconnect i restarcie, stare retry, ogólne komendy klienta, granice eventu, zmianę podczas zapisu, utratę potwierdzenia i recovery, odrzucenie podrobionego mnożnika, c/K z Common/Epic, HUD, dotarcie i away. Oddzielny test checkpointu każdej fazy porównuje bitowy wynik ze ścieżką bez przerwania. Oczekiwania pochodzą z jawnych równań i wartości katalogowych; fixture nie zatwierdza bilansu.

Cztery nowe mutacje przywracają lokalne ID sklepu, pomijają generację strumienia, wyłączają event kolekcji lub wymuszają neutralne RCB. Mock starszego testu resetu uzupełniono o istniejącą metodę getStreamId; jego oczekiwania gameplay nie zostały osłabione.

Wyłącznie L i statyczny build, bez Studio, rzeczywistych API chmury/zakupów i odbioru człowieka. releaseCandidateReady pozostaje false. Dokumenty 17–21 i reference_data bez zmian; historyczne raporty nie zostały przepisane. Otwarte #66–70 i brakujące konfiguracje funkcji pozostają poza dostawą. [Dowody i sumy kontrolne](session_prestige_rcb_63_65_verification.json).

Pełny runner: **36 zestawów Luau / 80 502 asercje PASS**, dodatkowo **11 testów raportowania Python PASS**, **29/29 wybranych mutacji wykrytych**. Build statyczny: 39 modułów / 2 entrypointy. Pierwszy pełny przebieg wykrył niepełny mock getStreamId; po jego uzupełnieniu cały runner przeszedł ponownie. Bez deklaracji procentowego pokrycia lub gotowości wydania.
