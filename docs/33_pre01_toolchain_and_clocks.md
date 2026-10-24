# PRE-01 — warsztat, mapowanie źródeł i zegary

24.10.2026. **P — projekt techniczny, dokumentacja przygotowana.** Zadanie [#7](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/7). Podstawa: [27](27_numbers_time_and_player_state_contract.md), [28](28_modules_and_client_server_contract.md), [29](29_first_farm_implementation_plan.md), [30](30_first_farm_manifest_and_technical_choices.md). Bez instalacji, plików wykonawczych, Studio, implementacji i zmian bilansu. Wybory P nie stają się decyzjami produktowymi R.

## 1. Wybrany warsztat

| Element | Wybór P dla pierwszej farmy | Granica dowodu |
|---|---|---|
| Synchronizacja | Rojo **7.7.1**, przypięta wersja zamiast latest | Wydanie istnieje; synchronizacji nie wykonano. |
| Lokalny runner | Lune **0.11.1**; proste testy Luau z asercjami i kontrolowanymi portami | Nie jest pełnym silnikiem Roblox. |
| Silnik i replikacja | Roblox Studio; wersję zanotować przy przyszłym odbiorze | Nie otwierano Studio. |
| Zależności | Na początek bez dodatkowego frameworka testów, managera pakietów i biblioteki sesji | Ewentualną potrzebę wykazać w konkretnym zadaniu. |

W przyszłym IMP-01 wykonawca pobiera wskazane oficjalne wydania, zapisuje wersję i sumę użytego artefaktu oraz sprawdza minimalny import/test. Nie aktualizuje wersji automatycznie. W obecnym PATH nie znaleziono rojo/lune/luau; nie jest to przeszukanie całego komputera.

Oficjalne źródła sprawdzone 24.10.2026: [wydanie Rojo](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1), [wydanie Lune](https://github.com/lune-org/lune/releases/tag/v0.11.1), [zakres i ograniczenia Lune](https://lune-org.github.io/docs/).

## 2. Przyszłe mapowanie, bez tworzenia konfiguracji

| Źródła | Cel w Studio | Właściciel |
|---|---|---|
| src/shared | ReplicatedStorage/HatchTheEgg/Shared | IMP-01 codec, IMP-03 DTO; tylko jawnie publiczne moduły |
| src/server | ServerScriptService/HatchTheEgg | Serwer i prywatny katalog; nigdy obszar replikowany |
| src/client | StarterPlayer/StarterPlayerScripts/HatchTheEggClient | Transport, store i kontrolery klienta |
| assets/farm | Workspace/HatchTheEggFarm | IMP-13; wyłącznie własne poddrzewo sceny |
| tests, docs, fixtures, narzędzia | Poza mapowaniem gry | Testy i dokumentacja, nie zasoby produkcyjne |

Wspólne czyste moduły nie pobierają usług Roblox, zegara, sieci ani losu globalnie. Test L ładuje ten sam moduł obliczeń przez lokalną ścieżkę; Studio przez ModuleScript. Różnią się adaptery wejścia/importu, nie implementacja wzoru. Serwerowe konfiguracje i moduły nie trafiają do klienta przez wygodny wspólny katalog. Jawna projekcja z 28 pozostaje jedynym źródłem stanu UI.

Przyszły plik projektu Rojo ogranicza synchronizację do wskazanej testowej sceny, chroni cudze poddrzewa i wyklucza testy. Sposób opisuje [oficjalny format projektu](https://rojo.space/docs/v7/project-format/). Nie utworzono teraz pliku .project.json, drzewa src ani skryptu uruchamiającego.

## 3. Port Clock

| Odczyt | Adapter serwera P | Użycie |
|---|---|---|
| utcNowMs | DateTime.now().UnixTimestampMillis | Dni UTC, terminy VD, przejęcie sesji, utrwalone granice okresów |
| elapsedNowSeconds | os.clock() w tym samym procesie | Czas trwania pracy i odcinki online; nigdy timestamp między serwerami |
| FakeClock | Niezależnie sterowane UTC i elapsed | Przyszłe testy L: skoki, restart, ułamki i granice |

To wybór adaptera, nie dowód jego zmierzonej rozdzielczości lub idealnej synchronizacji serwerów. [DateTime](https://create.roblox.com/docs/reference/engine/datatypes/DateTime) korzysta z zegara urządzenia i wskazuje os.clock do pomiaru upływu; dlatego tylko serwer wyznacza czas domeny. Zegar klienta i liczba Heartbeat nie wyznaczają produkcji.

Koordynator zamraża start i cel okresu UTC; RuntimeElapsed służy do pomiaru pracy, nie jest dodawany drugi raz do tego okresu. Zachować Duration binary64 oraz konwersję ms/sekundy z 27. Checkpoint zachowuje siatkę 0.3 s, fazę i resztę; nie zaokrąglać każdego kroku do ms.

Cofnięcie UTC poniżej settledWallThrough nie cofa cursora ani nie nalicza ujemnej produkcji. Okres czeka na bezpieczne rozstrzygnięcie zegara. Rozbieżność UTC/elapsed w procesie jest sygnałem diagnostycznym, nie podstawą dopisania zasobów. Przy podejrzeniu skoku zegara adapter blokuje nowe działania wymagające dzierżawy i uruchamia odzyskiwanie według [34](34_pre02_sessions_and_retention.md); nie przelicza sam lease na zegar klienta. Po restarcie elapsed zaczyna nową epokę. Dodatni rzeczywisty okres po odzyskaniu rozlicza 27; nie wprowadzamy capu nieobecności. Dokładność i detekcja skoków wymagają przyszłego testu D, bez deklarowania gwarancji synchronizacji platformy.

## 4. Rozdzielenie dowodów

| Poziom | Przyszły runner i zakres | Czego nie dowodzi |
|---|---|---|
| L | Lune: codec, matematyka, FakeClock, kolejka i fake repozytorium z wymuszonymi awariami | Replikacji, prawdziwego zapisu i ruchu modeli |
| S | Studio: serwer + klienci, projekcja, input, synchronizacja sceny, adapter czasu i trasy | Trwałości chmurowej po utracie procesu |
| D | Oddzielne dopuszczone dane testowe: UpdateAsync, konflikt właścicieli, timeout i recovery | Gotowości wydania lub zatwierdzenia bilansu |
| H | Odbiór człowieka zgodnie z 29 | Automatycznego zaliczenia L/S/D |

Plik wyników przyszłego uruchomienia zawiera commit, wersje narzędzi, przypadki, wynik, konfigurację i ograniczenia. Fake może symulować nieznany zapis, ale nie zastępuje D. Żadnego testowego remotu przyznającego zasoby w produkcji.

## 5. Odbiór dokumentacji i następni wykonawcy

Przygotowano: konkretne wersje, mapowanie prywatne/publiczne, dwa zegary i macierz dowodów. **L/S/D nie uruchomiono.** IMP-01 realizuje warsztat i codec; IMP-03 DTO może później pracować niezależnie od IMP-07 zapisu. IMP-13 realizuje scenę według [35](35_pre03_routes_and_arrivals.md). Nie są wymagane kolejne taski dokumentacyjne do rozpoczęcia tych prac po osobnym zleceniu implementacji.

## Realizacja warsztatu w IMP-01

Stan PRE-01 powyżej jest zapisem przygotowania. Następnie na polecenie użytkownika wykonano [36](36_imp01_numeric_codec_delivery.md): lokalne przypięte narzędzia, konfigurację Rojo obejmującą wyłącznie Shared i testy codec L. Adapter zegara, synchronizacja ze Studio i pomiary czasu w silniku nadal niewykonane. Nie uznawać samego wyboru Clock za jego wdrożenie.
