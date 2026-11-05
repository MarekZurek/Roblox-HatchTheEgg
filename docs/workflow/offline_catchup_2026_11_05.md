# Rozliczanie offline i CONNECTING · 05.11.2026

Punktem wyjścia był commit `6cd10a5` i prywatna Beta v8. Raport v8
odnotował kilka minut oczekiwania na pierwsze READY po około 83 minutach
offline. Serwer rozliczał 100 faz, czyli 50 kroków po 0,3 s, w każdym
przebiegu pętli co 0,5 s. Samo tempo harmonogramu dawało około 166 s
oczekiwania w tym przypadku, jeszcze przed uwzględnieniem kosztu obliczeń.

Kolejne porcje offline mają docelowy budżet wykonania 6 ms. Dla ustalonej
populacji bez aktywnych boostów i zdarzeń symulator ponownie wykorzystuje
wynik pełnego kroku produkcji. Saldo i liczniki nadal dodaje w pierwotnej
kolejności w każdym kroku 0,3 s. Końcowy ułamek kroku ma własne wyliczenie.
Przy wzroście populacji lub efektach czasowych nadal działa pełne rozliczenie
faz. Złożone przypadki zachowują pierwotny budżet 100 faz na tick, a czas
ogranicza dodatkową pracę. Porównanie pokazuje
zgodność zapisu salda binary64. Nie zmieniono limitów 6 h i 18 h, mnożników,
cen, zapisu checkpointu ani kroków gry online.

Pierwszy snapshot po wczytaniu profilu z dłuższą przerwą lub zapisanym
checkpointem czeka na rozliczenie przez zwykły tick serwera. Próba
rozpoczęcia rozliczenia wcześniej zmieniała granicę offline i online.
Regresja dochodu RCB wykryła różnicę salda. Blokada w Main zachowuje
dotychczasową granicę i termin rozliczenia. Wznowienie korzysta z kursora
zapisanej sesji i tego samego mechanizmu trwałego zapisu.

## Wynik w prywatnej Becie

Roblox Studio, jeden serwer i jeden rzeczywisty klient. Place
`110937489000525`, universe `10774701473`, tryb `PERSISTENT`.
Źródła robocze zsynchronizowano do Edit prywatnej Bety. Wgrana w Roblox
wersja miejsca to nadal v8. Kontrolowany zegar serwera i trzy odrębne
zakresy tego samego DataStore pozwoliły ustawić dokładne przerwy i powtórzyć
wejście w tej samej chwili symulacji. Główny profil konta pozostał poza
testem. Uprawnienie PRO pochodziło z zapisanego profilu danego przypadku.

Każdy profil zaczynał ze 100 Cash, 250 kurczakami w pierwszym kurniku
i domyślnymi badaniami. Niezależne oczekiwanie korzystało z produkcji
`250 × (1/30)`, transportu `500/60`, wartości jajka 1 i mnożnika offline
0,5 lub 1. Porównanie wartości dokładnych odtwarzało kolejność działań
binary64 bez wywoływania kodu symulatora.

| Próba | Przerwa | Należny okres | Saldo zapisane w DataStore | Czas do pierwszego rozliczonego snapshotu | Saldo po drugim wejściu |
|---|---:|---:|---:|---:|---:|
| F2P 83 min | 4 980 s | 4 980 s | 20 849,999999993506 | 5,71 s | identyczne |
| Limit F2P | 21 601 s | 21 600 s | 90 100,000000120883 | 5,91 s | identyczne |
| Limit PRO | 64 801 s | 64 800 s | 540 099,99999787787 | 7,07 s | identyczne |

Czasy zmierzono od uruchomienia testowego adaptera serwera do wysłania
pierwszego snapshotu. W każdym z sześciu wejść klient pokazał `READY`.
Po każdym Stop niebuforowany odczyt z DataStore potwierdził właściwe saldo,
zgodny licznik dochodu, brak oczekującego checkpointu i zwolnioną sesję.
Ponowne wejście odczytało zapisany kursor w chwili
`1793862906982`, z generacją sesji 2 zamiast 1, i nie przyznało ponownie
dochodu za zamknięty okres. Wszystkie trzy tymczasowe profile usunięto,
przywrócono oryginalny Main i pozostawiono Studio w trybie Edit.

## Regresje

- Przed poprawką test 83 minut przekraczał 32 porcje i kończył się błędem
  `bounded fast catch-up must finish in 32 slices: 4980`. Po poprawce
  sprawdza dokładne saldo i kursor dla 83 minut oraz limitów 6 h i 18 h.
- Testy porównują też wynik ze zwykłym przebiegiem faz po wznowieniu
  połowy zapisanego kroku, z 2x Cash, wzrostem populacji i zdarzeniem.
- `tests/timeline/run.luau` przeszło 74 asercje.
  `tests/session_lifecycle/run.luau` przeszło 35, w tym kontrolę pierwszego
  snapshotu po długiej przerwie.
- Pełny `tools/test.ps1` zakończył się kodem 0 po uruchomieniu 59 zestawów
  Lune i kontroli Rojo/Python. Po ostatniej korekcie budżetu ponownie
  przeszły testy symulatora, cyklu sesji i dochodu RCB.

SHA256 testowanych źródeł:

- `src/server/Bootstrap.luau` · `5a06e9189ece5e2700d71284b8fd18bf457da4a3f2d3c890e8db581415938dd8`
- `src/server/Main.server.luau` · `371fbcb762bb4bf3124310f41c2cf50c699ea6b98765c7de8164aa427cab78b5`
- `src/server/TimelineSimulation.luau` · `144c299a1e56401c7f10b693e3d767b4415eec88ec1cabd2472160ff1226dc46`

Po pomiarach w Studio dodano dolną granicę 100 faz dla ścieżki ogólnej.
Nie dotyczy ona szybkiej ścieżki wykorzystanej w tych trzech próbach.
Końcowy plik `TimelineSimulation.luau` ma SHA256
`ef2aefaf3ab9b2108f43d9ca89083a3372289794ffc1fcacc0bdedbf85dee711`.

Pomiar dotyczy kontrolowanej farmy i serwera Studio z prawdziwym
DataStore. Czas rozliczania rozwijających się farm zależy od ich stanu
i aktywnych efektów.

## Prywatna Beta v9 · serwer hostowany

Opublikowano `999fd47` w miejscu `110937489000525` (universe
`10774701473`). Przed publikacją 51 źródeł w Studio porównano z repozytorium.
Creator Hub potwierdził opublikowaną wersję 9 i prywatny dostęp, a strona
Roblox potwierdziła pojemność 4. Konsola serwera zwróciła `PlaceVersion=9`
i `IsStudio()=false`.

Na tym serwerze uruchomiono osobną instancję opublikowanego `Bootstrap`
z tym samym adapterem DataStore, osobnym zakresem i kontrolowanym zegarem.
Pętla wywoływała tick co 0,5 s. Pomiar od rozpoczęcia wczytywania profilu
do pierwszego rozliczonego `StateSnapshot` obejmuje zapis blokady i pracę
serwera. Nie obejmuje połączenia klienta, ładowania świata ani renderowania
HUD. Każdy przypadek użył farmy ze 100 Cash i 250 kurczakami.

| Próba | Przerwa | Należny okres | Pierwszy snapshot | Snapshot po reconnect | Saldo Cash w obu wejściach |
|---|---:|---:|---:|---:|---:|
| F2P 83 min | 4 980 s | 4 980 s | 0,869 s | 0,852 s | 20 849,999999993506 |
| Limit F2P | 21 601 s | 21 600 s | 1,804 s | 0,802 s | 90 100,000000120883 |
| Limit PRO | 64 801 s | 64 800 s | 3,953 s | 0,802 s | 540 099,99999787787 |

Saldo snapshotu zgadzało się z niebuforowanym odczytem DataStore. Przy
stałym zegarze ponowne wejście zachowało dokładnie tę samą reprezentację
salda i kursor rozliczenia; generacja wzrosła z 1 do 2. Po każdym wyjściu
blokada była zwolniona i nie było oczekującego checkpointu. Niezależny
odczyt potwierdził usunięcie trzech tymczasowych profili.

Osobny test przez klienta Roblox w przeglądarce objął naturalny powrót
konta PRO po 9 h 55 min 39 s i ponowne wejście. Trwałe saldo wzrosło
z `82645.690949992655` do `3805464.1284528375`, zgodnie ze stawką farmy
około 104,17 Cash/s. Między zapisami przed i po reconnect minęło 24,244 s,
a przyrost wyniósł `2525.4166666665114` Cash, zgodnie z bieżącą produkcją.
Na klatce po 12,3 s od otwarcia klient jeszcze ładował grę, a po 16,34 s
HUD był już gotowy. To przedział obserwacji całego reconnectu; osobnego
czasu pierwszego długiego wejścia w kliencie nie zmierzono.
