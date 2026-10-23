# Architektura Roblox — szkic do przyszłej implementacji

> **Bieżący plan procesu:** [workflow](workflow/README.md) i [etapy realizacji](workflow/IMPLEMENTATION_STAGES.md). Poniższy szkic techniczny nadal jest P; nie oznacza wyboru bibliotek ani zlecenia implementacji. Mapa przyszłych procedur: [SKILLS_PLAN](workflow/SKILLS_PLAN.md).

**Status P:** projekt techniczny, bez wyboru ostatecznych bibliotek, bez istniejącej implementacji i bez zlecenia jej rozpoczęcia. Reguły ekonomii pochodzą z [CURRENT_SPEC](CURRENT_SPEC.md), a nie z tego szkicu. Dawny przykładowy profil nie był kompletnym odwzorowaniem stanu silnika.

## 1. Podział odpowiedzialności

- Serwer powinien obliczać farmę, zakupy, prestiż, losowania i wypłaty. Klient zgłasza zamiar działania, nie gotową kwotę FV, nagrody lub dowolny czas nieobecności.
- Wizualne modele kur i petów mogą działać po stronie klienta; ich liczba nie jest stanem ekonomii. Serwer nadal potrzebuje stanu biegających kur/RCB lub uzgodnionego modelu tego stanu. Sam brak fizyki serwera nie uzasadnia pominięcia RCB.
- Czyste funkcje matematyczne, tabele konfiguracji, symulację czasu, zapis i prezentację warto rozdzielić, by dało się porównywać obliczenia z zachowanymi testami referencyjnymi.

To rekomendacje architektoniczne, nie potwierdzone moduły gry. Nazwy usług i struktura katalogów pozostają do ustalenia przy implementacji.

## 2. Liczby i konfiguracja

Zwykły format liczbowy nie gwarantuje dokładności dowolnie wielkich liczników. Reprezentacja mantysa/wykładnik ułatwia duże kwoty, lecz sama nie zapewnia dokładnej arytmetyki całkowitoliczbowej. Trzeba osobno dobrać reprezentację kwot, liczników i serializacji oraz ustalić zaokrąglenia na podstawie testów źródłowych. Nie traktować wcześniejszego szkicu BigNum jako gotowej biblioteki.

Konfiguracja konfiguracji referencyjnej obejmuje 19 jaj głównej ścieżki, 19 kurników, **12 typów pojazdów** i do **17 miejsc floty**, 56 Common oraz 24 rozpoznawane Epic. Rozpoznanie wpisu konfiguracji referencyjnej nie oznacza jego dostępności w pierwszej wersji Roblox. Indeksy silnika od 0 rozróżniać od ID konfiguracji i numerów w UI.

Nie wpisywać na stałe błędnego limitu regeneracji wylęgarni 22.5/s. Potwierdzona wartość przy maksymalnych odpowiednich badaniach to **50.625/s**, według [03](03_habitats_and_population.md). Faktyczny stan wylęgarni, tempo ręcznego wylęgu i wolne miejsca to odrębne ograniczenia.

## 3. Stan potrzebny do wiernego rozliczania

Przyszły schemat zapisu powinien uwzględniać co najmniej:

- bieżące jajo i najwyższe osiągnięte jajo, populację i ułamkowy akumulator każdego z czterech kurników, ręczną wylęgarnię oraz stan potrzebny do RCB;
- każdy typ kurnika i pojazdu, długość każdego pociągu, posiadane silosy oddzielnie od limitu dostępnych miejsc;
- Common, Epic, trwałe uprawnienia, odblokowanie Hyperloop i waluty;
- oddzielne akumulatory gotówki i przychodu prestiżowego, stan ostatniego rozliczenia przyrostów, sumę wydanych GE oraz liczniki postępu;
- **pozostały czas** każdego zużywalnego boostu, osobny **absolutny termin** podwajacza, harmonogram wydarzeń i historię uprawnień potrzebną do uzgodnionego offline;
- licznik i dzień odbioru kalendarza, stan Piggy z rozróżnieniem salda, poziomu i utraconych przyrostów, identyfikację rozliczonych nagród;
- ekwipunek i zestaw petów oraz czas ich zmiany, wersję danych i konfigurację używaną do rozliczanego okresu.

## 4. Wymagania symulacji i transakcji

Offline nie może być pojedynczym mnożeniem aktualnego dochodu przez czas. Należy zachować kolejność produkcji i wzrostu, limity transportu/pojemności, warunek away, silosy, timery boostów i historyczny czas eventu. Szczegóły: [10](10_verified_simulation_and_server_config.md) i [16](16_pet_stacking_offline_and_package_schedule.md).

Jednorazowe przyznanie nagrody musi być spójne z zapisem postępu odbioru. Ochrona kolejki alertów modelu referencyjnego nie jest dowodem odporności nowego zapisu na restart lub powtórzony komunikat. Konkretna realizacja, migracje, blokowanie sesji i obsługa zakupów Roblox wymagają osobnego projektu po rozpoczęciu implementacji.

## 5. Kolejność przyszłych prac

Po osobnym zleceniu implementacji: wybrać model danych i liczby, przenieść potwierdzone funkcje z kontrolami wyników, połączyć farmę i resety, dodać warstwę zapisu/transakcji oraz UI. Zapis i idempotencja są wymaganiem całej pętli, nie dodatkiem dopiero po ukończeniu ekonomii.

Nie wybieramy teraz ProfileService ani innej biblioteki, nie tworzymy modułów Luau i nie wznawiamy odłożonego bilansu. Biblioteki i modele wspomniane w dawnych szkicach wymagałyby sprawdzenia przed wyborem; ich nazwy nie są potwierdzeniem licencji, utrzymania ani jakości.

## Kontrakt przygotowany przed implementacją

[27 — liczby, czas i stan gracza](27_numbers_time_and_player_state_contract.md) konkretyzuje tę część szkicu: typy i jednostki, serializację, zegary, checkpoint offline, sekcje profilu, macierz resetu i trwałe operacje. Ma status P, bez wyboru biblioteki lub rozpoczęcia realizacji. Nie zastępuje decyzji R ani konfiguracji bilansu.

## Podział modułów i protokół — P

[28 — moduły i komunikacja serwer–klient](28_modules_and_client_server_contract.md) uzupełnia kontrakt 27: jeden koordynator zmian profilu, czysta domena/matematyka, adapter zapisu i platformy, projekcje oraz klient. Definiuje intencje, podglądy, statusy, snapshot/delta i reconnect. Nazwy nie są istniejącymi modułami; transport i biblioteki nie zostały wybrane.
