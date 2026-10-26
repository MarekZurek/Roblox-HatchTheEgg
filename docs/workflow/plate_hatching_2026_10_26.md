# Płyta 30/s i strumień wizualnych kur — 26.10.2026

## Zatwierdzony zakres

Użytkownik wybrał **30 kurczaków/s podczas stania na płycie**, dopóki wystarcza zapasu i miejsca. Zapas, refill, ceny, badania i reszta bilansu bez zmian. To nowa, jawnie zatwierdzona adaptacja płyty; nie zmienia zwykłego pojedynczego naciśnięcia ani Epic Hold-to-Hatch poza płytą. Fizyczną obecność musi potwierdzać serwer.

Kurczaki fizyczne/animacje są kosmetyką klienta. Serwer zachowuje dane rezerwacji, runningCount, zużycie zapasu, wybór celu i czas dotarcia. Nie dodajemy zasiedlonej populacji natychmiast przy starcie: omijałoby to dotarcia i zmieniało RCB/produkcję. Klient ma prezentować ograniczony strumień ruchu, bez wymagania jednego modelu na prawdziwego kurczaka.

## Stan bazowy i potwierdzone błędy

Git początkowo czysty, HEAD `eb7b2e08dbdc4d3269cd7ab3009d5f531b5123e8`. Płyta klienta wysyłała pojedynczy HatchPress co co najmniej 0,28 s (około 3,6/s przed ograniczeniami stock/capacity). Modele już były tworzone lokalnie; serwer nie musiał replikować modeli kur.

Reprodukcja Lune na osobnej kopii źródeł z HEAD: wypuszczono 20 kur, następnie po 4 s rozliczono ich dotarcie i wypuszczono kolejnych 20. Klient miał najpierw 2 grupy wizualne; po wymianie 0, mimo autorytatywnego `reservedInTransit=20`. Bootstrap tworzył modele tylko dla dodatniej różnicy liczby kur w drodze. Zgłoszenie [#75](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/75).

Drugi test bazowego RoutePresentation: po 2000 zakończonych animacjach pozostawało 2000 wpisów `_completedGroups` i zero aktywnych grup. Limit 5 modeli na grupę nie był limitem globalnym ani limitem historii. Zgłoszenie [#76](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/76). Jest to dowód nieograniczonej retencji tabeli, nie pomiar wycieku silnika.

## Pomiar bazowy Studio

Lokalny `HatchTheEgg.rbxlx`, Edit → własny Play → Stop, PlaceId=0, `Main.UseLocalMemoryStore=true`. Postać ustawiona na płycie na 5 s: 18 wypuszczonych kur (5 zasiedlonych + 13 w drodze), 18 żądań HatchPress, stock 246,406, 8 modeli klienta. Czas klatki: średnia 16,78 ms, p95 19,56 ms, maksimum 49,29 ms. To pojedyncza lokalna próbka; większa liczba kur po zmianie oznacza inny nakład pracy, a nie bezpośredni test tego samego obciążenia. Próba nie używała chmury ani trwałych zakupów.

## Podział pracy i odbiór

Na podstawie zgody użytkownika uruchomiono lokalny Cline CLI do implementacji i regresji. Agent nie ma zlecenia commitu, pusha, publikacji, Studio ani zmian odłożonego bilansu. Root odpowiada za integrację, niezależną kontrolę i Studio. AGY CLI ma otrzymać gotowy diff do read-only review według workflow. Samo przekazanie zadania nie oznacza wyniku QA.

Wymagany odbiór: serwerowe 30/s od zaobserwowanej obecności, stop po wyjściu i utracie postaci/sesji, brak klientowskich grantów/30 pakietów sieciowych na sekundę, stock/capacity/RCB/dotarcia i replay bez naruszeń. Wizualizacje: ciągły ruch także przy stałym liczniku in-transit, globalny limit modeli i emisji, ograniczona historia, cleanup/reset. Testy L nie zastępują rzeczywistej próby Studio/chmury.

Implementacja i lokalna integracja zakończone. Wyniki poniżej nie stanowią odbioru całego wydania. Zmiany pozostają lokalne na bazie `eb7b2e0`; w tym zadaniu nie wykonano nowego commitu, pusha ani publikacji Roblox.

## QA wersji roboczej

AGY przygotował checklistę granic (sesja, wejście/wyjście, zapas/pojemność, RCB/dotarcia, sieć i pamięć). Próba odczytu plików przez headless CLI nie otrzymała uprawnienia do polecenia, więc root przekazał potrzebny kod i dane bez narzędzi. Dwa szerokie review diffów przekroczyły limit 240 s bez werdyktu — nie są dowodem PASS. Skuteczne celowane review AGY (`f24e0780-5521-4638-9e16-6d70e03b6639`) potwierdziło dwa problemy wersji roboczej: obserwacja płyty mogła przeżyć zmianę streamu (reprodukcja root: 15 → 22 bez nowej obserwacji), a blokada modeli przy niskim FPS zachowywała rosnący dług emisji. Oba poprawiono i odtworzono w regresjach. Follow-up AGY `ff02f946-d4ff-4c6f-92dc-38302f373af9` uznał poprawki za logicznie poprawne; dodatkowe zabezpieczenia braku gateway oraz pustego celu również dodano. StreamId od początku jest niepustym ID nadanym przez serwer; sugestia hipotetycznego nil==nil nie wymagała nowego stanu produktu. Checklistowe sugestie pooling/O(1) i globalnego ograniczenia wszystkich ręcznych naciśnięć nie są nowymi regułami produktu.

## Wykonana implementacja

- `Main.server`: obserwacja rzeczywistej, żywej postaci w obszarze rzeczywistej płyty co 0,25 s. Brak nowego RemoteEvent/protokołu deklarującego obecność. `Main.client` zachowuje kolor/dźwięk wejścia, przestaje wysyłać seryjne HatchPress.
- `Bootstrap` serwera: oddzielna obserwacja płyty, 1-sekundowa ograniczona ważność, brak dziedziczenia przez reconnect/zmianę streamu, reset i disconnect. Nie rozlicza całej przerwy po zatrzymanym samplerze. Zwykłe press/Epic Hold nie stają się płytą.
- `TimelineSimulation`: istniejący data-only wylęg z tempem 30/s, bez natychmiastowego zasiedlania i bez fizycznych kur na serwerze. Stock, refill, ważony cel, rezerwacje, runningCount i dotarcia pozostają autorytatywne. Kroki są dzielone na granicach wejścia/wygaśnięcia obserwacji: bez pomijania końcówki interwału, trasy sprzed wejścia ani RCB za wcześniejszy czas.
- Klient emituje reprezentację proporcjonalną do serwerowych liczb kur w drodze, także przy stałych licznikach. Do 8 reprezentatywnych modeli/s, globalnie do 32 jednocześnie, do 256 ostatnich ID kosmetycznych. To nie limit domenowych kur ani historii transakcji. Nadmiar emisji przy limicie/FPS jest odrzucany; animacje nie przyznają populacji. Zanik liczników/zmiana streamu czyści aktywne wizualizacje.

## Regresje i integracja

Końcowy root runner `./tools/test.ps1 -PythonExecutable <bundled Python 3.12.14>`: **44 zestawy / 81 928 asercji Luau, 11 Python, generatory --check i Rojo 39 modułów + 2 entrypointy PASS**. Nowe zestawy: `plate_hatching` 160, `plate_visuals` 55, `plate_acceptance` 89. Dotychczasowe zakupy za świeżą gotówkę 308 nadal PASS, wraz z powtórkami, opóźnionym/nieznanym zapisem i reconnect na kontrolowanym adapterze. To nie test chmury.

Niezależna integracja root rzeczywiście wykryła: 15 → 22 po zmianie view streamu bez nowej obserwacji; dług emisji przy cap=1 i niskim FPS; utratę wylęgu po wejściu w środku kroku; start trasy sprzed wejścia; naliczenie RCB za część kroku przed wejściem. Wszystkie dostały regresje. Ostatni przypadek porównuje jeden opóźniony interwał z rozliczeniem czasu OFF przed wejściem, na 100 zasiedlonych kurach i badaniach RCB. Obie ścieżki dają zgodną gotówkę, nie referencję wyliczoną z tego samego błędnego przebiegu.

Cline dostarczył sześć skryptów oraz dwa zestawy i ich rejestrację. Jego próba pełnego runnera w PowerShell 5.1 zakończyła się brakiem Get-FileHash; nie uznajemy jej za PASS. Root wykonał pełny runner we właściwym środowisku, zintegrował powyższe korekty i zakończył CLI autora po dostarczeniu kodu/testów. Autor nie wykonał Studio, Git ani publikacji. AGY review ma zakres celowanych ustaleń; szerokie timeouty nie są akceptacją całego diffu.

## Studio: końcowe dowody i porównanie

Jeden klient / jeden lokalny serwer, PlaceId=0 i pamięć testowa. Przed synchronizacją sześć skryptów sprawdzono względem bazy Git, po niej porównano długości i ważone sumy z końcowymi plikami. Nie zakładano zgodności całej sceny z HEAD. Ostatnia próba po zakończeniu runnera używała tego samego 5-sekundowego ustawienia postaci na płycie co baza.

| Pomiar | Baza eb7b2e0 | Końcowy kod lokalny |
|---|---:|---:|
| HatchPress z płyty w 5 s | 18 | 0 |
| Kury ogółem w odczytanym widoku po próbie | 18 | 132 |
| Modele kur klienta w końcowej klatce | 8 | 29 (cap 32) |
| Średni czas klatki | 16,78 ms | 16,70 ms |
| p95 klatki | 19,56 ms | 18,37 ms |
| Maksimum klatki | 49,29 ms | 40,44 ms |

To krótkie próbki, nie dowód wzrostu FPS ani skalowania serwera. Odczyt licznika przy płycie jest kwantowany: sampler 0,25 s i synchronizacja stanu około 0,5 s, więc nie należy oczekiwać dokładnie 150 w widoku po 5 s. Test kontrolowanego ciągłego interwału daje 30/s. Próby poprzedzające ostatni pomiar dawały 121–128 w pierwszym widoku, po zejściu 137–146; ostatni test ustabilizował się na 132. Pierwszy pomiar końcowej poprawki nakładał się na runner: średnia 17,50 ms / p95 23,44 ms; z tego powodu powtórzono próbę po jego zakończeniu. Nie mierzono CPU wieloosobowego serwera.

Smoke na końcowej logice: po zejściu liczba zatrzymała się na 146 w osobnej próbie; jeden zwykły press dał 147 i ACCEPTED. Zakup badania za naturalnie zarobioną gotówkę dał APPLIED; identyczny operationId/packet dał REPLAYED i poziom pozostał 1. Pierwszy assertion smoke błędnie oczekiwał APPLIED również dla replay; odczyt OperationStatus potwierdził REPLAYED, poprawna kontrola przeszła bez zmiany kodu zakupów. Po własnym Play wykonano Stop, usunięto transient probe; Studio zwrócono w Edit, lokalny atrybut pamięci pozostaje true.

Nie wykonano chmury, realnych płatności platformowych, publikacji ani nowego commitu/pusha. #75–76 pozostają otwarte do opublikowania poprawki. Bilans docs/17–21 i dane referencyjne bez zmian.

## Wersja sprawdzonych plików

SHA256 surowych plików po końcowym runnerze (CRLF/LF rozróżniane):

```text
f7a3ca85a784680cf2e26169b3eb467f6af7e5be165871a1cde528b0e0146a3b  src/client/Bootstrap.luau
067522e71352ae73f54389466a5a52d97c07db695b34a3d53c51b581eb9205b5  src/client/Main.client.luau
79b48ded2c614c297a86f9ee5543c49e72ee8c63dccc214c42d2c0bfba72379d  src/client/RoutePresentation.luau
318e32707056d397c719bf1698649fae05cf26388ef8f007852d88b36ab17d1a  src/server/Bootstrap.luau
90df228ca9739304af305eff2007935adb5e9fca7b8f61fccda5691b634272aa  src/server/Main.server.luau
52f013e51a75c7a9b9dfc36bccd4a01434627bf96261c3a0e3905b5d19402e9c  src/server/TimelineSimulation.luau
7d7173b3143fbab707798bed833aaffd6e4c23cb85c4c4bd2ae13173c12316a1  tests/plate_hatching/run.luau
634a07913500e8274fc8c56d7541f610de217f6b8768bc0f53e82ee07d149f9e  tests/plate_visuals/run.luau
0a398e3bcebdc1f507d9534f19ddb6a9734d556e206bdee1e14603535f7c604c  tests/plate_acceptance/run.luau
a73ef6e9d34cf07af66f128df2fdc3b7e251500ba7bda1830d1be3f89e63b317  tools/test.ps1
```

Końcowe review granic czasu w AGY (67fd2be6 i 4f2207d9) przekroczyło odpowiednio 240 s i 180 s bez werdyktu. Tej ostatniej poprawki nie oznaczamy jako niezależnie przyjętej przez AGY: potwierdza ją self-review root, regresja porównawcza, pełny runner i opisane smoke Studio. To jawna granica QA przed przyszłym wydaniem, nie blokada lokalnego testowania.

Kontrola przed commitem: usunięto wyłącznie nadmiarowe puste linie EOF w czterech nowych zestawach; ponowne wykonanie 89 + 160 + 55 + 230 asercji PASS, bez zmian logiki. Powyższe SHA testów uwzględniają tę korektę formatowania.
