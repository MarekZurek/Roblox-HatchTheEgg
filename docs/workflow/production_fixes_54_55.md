# Produkcja i kontekst efektów — poprawki #54–55

25.10.2026. Zakres: rzeczywista ścieżka Bootstrap → Timeline → produkcja oraz projekcja jej metryk. Nie zmieniono tabel cen, szans, sił gatunków, ewolucji ani danych referencyjnych. Bilans 17–21 pozostaje odłożony; ta poprawka nie zatwierdza konfiguracji premiery. Pozostałe ustalenia audytu nie są przez nią zamykane.

## Wzory i warstwy

Podstawy: [05 §4](../05_prestige_soul_eggs_and_boosts.md), [16](../16_pet_stacking_offline_and_package_schedule.md), [27](../27_numbers_time_and_player_state_contract.md). Reguły istniejące w docs połączono z rzeczywistym naliczaniem:

- Baza wartości pochodzi z bieżącego eggIndex w katalogu, a nie stale z jaja 0. Badania i pet wartości jaja mnożą tę bazę.
- Mnożnik mistyczny: `1 + SE × (0.10 + 0.01 × SoulFoodLevel) × (1.05 + 0.01 × ProphecyBonusLevel)^PE`. SE=0 daje 1 także przy bardzo dużym PE. Dokładny licznik PE pozostaje tekstem uint64; konwersja na wykładnik binary64 jest jawna i nie zastępuje zapisu. Niefinitywny wynik oznacza błąd zakresu, nie nowy cap bilansu.
- Potwierdzone efekty Epic są czytane z istniejącego katalogu: Soul Food/Prophecy Bonus, Epic Comfy Nests, refill Epic Hatchery, Transportation Lobbyists, Calm i pojemność czasowa silosu. Nie zgadywano formuł specjalnych wpisów o pustych próbkach.
- Bonusy petów tej samej statystyki sumuje istniejący Equipment. Znoszenie jest modyfikowane **przed** min z transportem. Pojemność używa końcowego ceil po przemnożeniu badań i peta; zdjęcie Cow nie usuwa kur ponad nową pojemnością. Wzrost pozostaje blokowany do powstania miejsca.
- Jimbo/Tachyon/Soul Beacon używają sum kategorii × sumy Beaconów × Alien, raz. Alien nie aktywuje pustej kategorii. Pet IHR działa oddzielnie; Calm tylko w away. Phoenix i Soul Beacon zwiększają dodatkowy przychód prestiżowy od nowych wpływów, nie portfel ani końcowe SE i nie przeliczają archiwum wstecz.
- Enlightenment neutralizuje pety i pauzuje zużywalne boosty, zachowując wyposażenie i wpisy. VD zachowuje własny ścisły predykat końca kroku.

Nie podmieniono wejść research-only Farm Value przez pełne efekty produkcji. Czysty kalkulator FV zachowuje swoją warstwę. Nie dodano nowych wymiarów artefaktów lub kontraktów.

## Stan, czas i zapis

Bootstrap przekazuje do nowego okresu efekty, SE/PE/Epic i kopię wyposażonych petów. Checkpoint zamraża ten kontekst razem z konfiguracją i fazą. W pamięci Duration boostu jest binary64; w profilu pozostaje round-trip tekst NumericCodec. Starszy numeryczny zapis Duration jest nadal czytelny. Schema waliduje Duration i terminy VD; wygaśnięcie usuwa wpis po wykorzystaniu właściwego kroku, a zero nie oznacza wcześniejszego usunięcia.

Efekty po symulacji wracają do profilu i są zapisywane z ekonomią oraz cursorem. Pełne wznowienie Bootstrap po fazie AFTER_PRODUCTION zachowuje bitowo wynik i pozostałe czasy. Zakończenie zapisuje integrationCheckpoint=false: jawny znacznik zamiast zabronionego przez koordynatora usunięcia pola. Nie powtarza już naliczonej produkcji.

Zmiana wyposażenia, uprawnienia Pro i mutacje przez Gateway najpierw przekazują koordynatorowi rozliczenie starego odcinka do czasu serwera. Niepełne rozliczenie pozostaje settling i wymaga kontynuacji oraz jawnego ponowienia komendy, zgodnie z kontraktem koordynatora; nie aplikuje nowego zestawu wstecz. Portfel i earned currentFarmCash nadal są odrębne.

Starsze checkpointy bez nowych wejść pozostają czytelne: używają wyłącznie danych już w nich zachowanych, a brakujące wymiary są neutralne. Nie dopisujemy aktualnego wyposażenia do środka dawnego okresu i nie przeliczamy już wypłaconych faz. Pełny kontekst obejmuje kolejny nowy okres. Ta zgodność formatu nie oznacza wstecznej korekty historycznych niedopłat starej wersji lub bitowej zgodności pomiędzy starym błędnym wzorem i jego poprawką.

## Testy i granice dowodu

[production_context](../../tests/production_context/run.luau): **147 asercji PASS L**. Oczekiwania liczbowe wynikają z niezależnych działań na potwierdzonych danych, nie z odczytania wyniku badanej funkcji. Testy obejmują aktualne jajo, SE/PE i Epic, rzeczywiste UpgradeEgg i Prestige z kolejnym wylęgiem/dotarciem, stack petów i Alien/Beacon, transport, IHR/Calm, końcowe ceil, zdjęcie Cow, Enlightenment, wygaśnięcie, deadline VD, rozliczenie przed wyposażeniem, HUD, offline Standard/Pro, zero silosów i pełny zapis/wznowienie.

Runner: ./tools/test.ps1 -PythonExecutable python — **67 941 asercji, 30 zestawów PASS**, statyczny build 38 ModuleScript i 2 entrypointy. [Wyniki i hashe](production_fixes_54_55_verification.json). To testy lokalne i kontrolowany storage; bez Studio, natywnej chmury, płatności i typecheckera. Poprzednie raporty pozostają historycznymi snapshotami.

**Poza zakresem:** historyczne ważenie eventu w granicznym kroku pozostaje w #61 (lista wydarzeń jest podłączona, punktowy predykat nie został w tym zadaniu zastąpiony). Podłączenie brakujących przycisków/aktywacji z #56, kwalifikacja Pro z #58, reset ID z #59 oraz deklaracje S/D/H z #60 nadal wymagają osobnej realizacji. Nie zmieniono testowego katalogu sił petów ani nie uznano go przez samo podłączenie za zatwierdzony bilans produkcyjny.
