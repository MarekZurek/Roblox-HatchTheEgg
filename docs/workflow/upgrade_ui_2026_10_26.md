# Efekty badań, ceny ulepszeń i okna HUD — 26.10.2026

## Zakres

Na dodatkowe polecenia użytkownika, po commicie optymalizacji/naprawy zakupów `9b7c489`, dodano:

- Badania Common: opis efektu obecnego i następnego poziomu z aktualnego katalogu serwera, np. `Tempo znoszenia: +0% → +10%`, po zakupie `+10% → +20%`. Wartości oznaczają izolowany efekt tego badania, nie wzrost całego dochodu farmy. Dla liczników i tempa IHR stosowane są odpowiednie jednostki, dla maksimum `(MAX)`. Wieloefektowe badania mają osobne wiersze, zamiast pomniejszania całego opisu do jednej linii.
- Kurniki: cena następnego typu na przycisku zamiast ULEPSZ; niezbudowana parcela pokazuje cenę COOP, a najwyższy typ MAX. Cena pochodzi z tej samej funkcji co wycena zakupu, uwzględnia liczbę obiektów danego typu i Epic discount. Zlecenie filtrowania niższych kurników użytkownik wycofał — nie dodawano takiego filtra.
- Flota: podstawowe cztery miejsca są dostępne niezależnie od liczby kupionych pojazdów. Puste miejsce jest opisane jako puste, nie jako istniejący Trike. Przycisk pokazuje cenę kolejnego pojazdu; puste miejsca kupują pierwszy typ. Dalsze miejsca wynikają z istniejącego serwerowego fleetLimit, bez nowych cen lub reguł ich odblokowania. Przy braku gotówki przycisk pozostaje nieaktywny; nie oznacza to wymagania badań floty.
- Stały licznik złotych jaj w HUD, aktualizowany z progress.GE. Skróty liczb służą wyłącznie prezentacji.
- Okna badań, kurników i floty zajmują około 70% szerokości/wysokości dostępnego obszaru. Na wąskich lub niskich widokach używają większej części ekranu. Mają przewijanie, centrowanie i przeskalowanie minimalnego układu na wąskich ekranach. Pozostałe dialogi zachowują dotychczasowe ograniczenia rozmiarów; nie deklarujemy ich pełnego przeprojektowania.

## Dane i poprawka floty

ViewProjector dodaje opcjonalne, ograniczone pola prezentacyjne: efekty aktualnego/następnego poziomu Common, nextHabitatId/upgradePrice oraz fleet.slotLimit/fleet.upgrades. Ceny to podglądy bez rejestracji quoteId; kliknięcie nadal pobiera właściwą wycenę i potwierdza ją przez autorytatywną komendę. Nie przeniesiono katalogu prywatnego do klienta. ProtocolSchemas waliduje nowe pola, liczby oraz unikalne efekty; listy pojazdów i indeksy pojazdów obsługują istniejący zakres do 17 miejsc. Zakres parceli pozostaje 1–4.

Main używa wskazanego przez serwer następnego typu, zamiast dawnych stałych SHACK/TRANSIT VAN dla dowolnego posiadanego poziomu. Nie dodano automatycznej podmiany niższych budynków lub pojazdów.

Test kupowania od razu w miejscu 4 ujawnił dodatkowy błąd: przypisanie vehicles[4], gdy brakowało 2–3, tworzyło tablicę z lukami i kończyło się UNKNOWN podczas kopiowania/zapisu. FarmActions wypełnia teraz wcześniejsze wolne miejsca jawnym `{typeIndex=-1}`. Jest to zwykła gęsta tablica profilu; zajęte miejsca zachowują tożsamość. ProgressActions pomija puste miejsca przy liczeniu transportu/FV, podobnie do istniejącego mostu symulacji i projektora. Ponowny zakup pustego miejsca, produkcja oraz zapis/reconnect są objęte regresjami. Nie dodano zasobów, grantów, cen ani migracji kont.

## Weryfikacja

`tests/upgrade_previews/run.luau`: **453 asercje**. Rzeczywisty transport/projektor/HUD: efekty i ich aktualizacja po zakupie; porównanie z niezależnymi wierszami referencyjnymi wszystkich 56 Common na poziomie 0 i max; zgodność cen z wycenami, rabaty, pusta parcela, MAX, cztery miejsca floty, dodatkowe miejsce według istniejącego limitu, zakup miejsca 4 przed 2–3 i późniejszy zakup miejsca 2, produkcja, poprawny profil i reconnect, licznik GE po nagrodzie, odrzucenie nieprawidłowych danych oraz wymiary układu dla małych/dużych ekranów. Testy UI odwołujące się do kart kurników dostosowano do nowego przewijanego kontenera; fixture floty ma jawny podgląd ceny.

Końcowy pełny `tools/test.ps1` z pakietowym Pythonem: **41 zestawów / 81 624 asercje Luau PASS**, 11 testów Python PASS, generatory/oracle PASS, Rojo build i mapping PASS (39 modułów + 2 entrypointy), lokalna kontrola dowodów wydania PASS. `git diff --check` PASS. Bilans docs/17–21 i dane referencyjne bez zmian. Mutation checks poprzedniej naprawy nie były powtarzane w tym zadaniu.

## Studio i wygląd

Przed synchronizacją Studio było w Play uruchomionym poza tym zadaniem. Użytkownik wyraźnie zgodził się zakończyć test. Po Stop sprawdzono sześć źródeł względem bazy `9b7c489` (długości i niekryptograficzne sumy po normalizacji CRLF→LF), a następnie zsynchronizowano zmienione skrypty. Nie kopiowano całej sceny.

Pierwszy Play ujawnił istniejące błędne rozpoznawanie Enum: typeof(Enum) w Roblox nie spełniało warunku table, więc HUD wybierał imitację enumów. Dodane wyrównanie pionowe tekstu zatrzymywało tworzenie kart. Warunek poprawiono na rzeczywiste isRoblox; ponowne próby potwierdziły tworzenie wszystkich kart i brak błędów konsoli. To przykład błędu silnika/UI, którego testy Lune nie wykryły; nie przedstawiamy pierwszej próby jako PASS.

Jedna lokalna instancja `HatchTheEgg.rbxlx`, jeden klient i serwer, PlaceId=0, UseLocalMemoryStore=true. ScreenInsets w odczycie runtime: CoreUISafeInsets; gra LandscapeSensor. Sprawdzono render przez screen_capture i wymiary runtime:

| Próba | Viewport | Obszar ScreenGui | Okno |
|---|---|---|---|
| Desktop, badania | 1214×793 | 1214×735 | 849×514 |
| Samsung Galaxy A06, landscape | 705×338 | 705×280 | ok. 493,5×251,3 |
| Duży widok, override rozdzielczości 1920×1080 | 1825×1057 | 1825×999 | 1277×699 |
| Końcowy desktop, kurniki | widok domyślny | 1214×695 | 849×486 |

Obserwacje: efekty i nazwy badań widoczne; po nadejściu QuoteView cena comfy_nests 0,5$ i stan braku środków. Kurniki pokazują 466,67$ za SHACK w parceli 1 oraz 29,12$ za COOP w pustych parcelach. Flota pokazuje 544,54$ za kolejny pojazd w miejscu 1 i 22,41$ w pustych miejscach 2–4. Licznik złotych jaj pokazuje 10. Na małym widoku karta miejsca 4 jest w pełni osiągalna po przewinięciu; odczyt granic potwierdził, że mieści się w przewijanym obszarze. Końcowy odczyt błędów LogService: pusta lista.

To ograniczona kontrola trzech paneli w landscape, nie pełny odbiór H na fizycznym telefonie, wszystkie zakładki ani pełny S/D/H. Zakupy z zapisem testowano w L; nie wydawano Robux ani nie zmieniano produkcyjnych danych. Niezależnego review nie wykonywano.

Końcowo zatrzymano własny Play i przywrócono symulator do default (oryginalnie default, orientacja LandscapeRight). Studio pozostaje w Edit z UseLocalMemoryStore=true i nowymi źródłami w otwartej instancji. Nie zapisywano pliku place ani nie publikowano Roblox. GitHub push jest osobnym, zleconym etapem dostawy; jego wynik podaje końcowa wiadomość i stan git.
