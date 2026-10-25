# Kontrakt liczb, czasu i stanu gracza

23.10.2026. **P — proponowany kontrakt techniczny przed implementacją.** Dokument konkretyzuje etap 0, ale nie wybiera biblioteki, nie tworzy kodu, konfiguracji produkcyjnej ani migracji. Reguły N/S/R odsyłają do [CURRENT_SPEC](CURRENT_SPEC.md); nowe nazwy pól, formaty i procedury poniżej mają status P. Nie zmieniają D01–D07, zakresu 25–26 ani odłożonego bilansu 17–21.

## 1. Źródła i granice

- Matematyka: [02 — FV](02_eggs_and_farm_value.md), [05 — SE](05_prestige_soul_eggs_and_boosts.md), [13 — księgowanie i konwersje](13_rewards_contracts_resets_and_gift_distributions.md).
- Czas: [06 — drony i silosy](06_drones_silos_and_events.md), [10 — symulacja](10_verified_simulation_and_server_config.md), [12 — podwajacz](12_calendar_scaling_and_video_doubler.md), [16 — efekty i harmonogram](16_pet_stacking_offline_and_package_schedule.md).
- Stan i uprawnienia: [22](22_gameplay_rules_for_approval.md), [24](24_doubler_and_bonus_gift_acceptance_review.md), [25](25_approved_product_structure.md), [26](26_approved_launch_scope_and_pro_availability.md).
- Wartości: [katalog JSON](reference_data/README.md). Dane REFERENCE_ONLY nie stają się aktywnym bilansem przez użycie w opisie typów.

To kontrakt semantyczny, nie kod ani lista potwierdzonych testów. Nie wprowadza kontraktów kooperacyjnych, nowych źródeł PE, cen, liczby miejsc Pro, rotacji eventów lub częstości zapisu. Implementacja nie może zgadywać brakujących współczynników na podstawie tego dokumentu.

## 2. Typy wartości i jednostki

| Typ logiczny P | Zastosowanie | Obliczanie i zapis |
|---|---|---|
| BigAmount | Gotówka, ceny, FV, przychody sesji i dodatkowy przychód prestiżowy | W referencyjnym zakresie skończone binary64; wersjonowany adapter oddzielony od prezentacji. Zapis jako tekst dziesiętny z odtworzeniem tych samych bitów. |
| Real64 | SE, mnożniki, ułamki kur, zapas wylęgarni i tempa | Binary64. SE nie jest ExactUInt i nie otrzymuje dodatkowego floor. Zapis z odtworzeniem bitów. |
| ExactUInt | GE, PE, całkowite populacje, liczby przedmiotów, statystyki i gwarancje | Dokładne nieujemne całkowite, proponowana pojemność do 2^64−1. W zapisie ciąg cyfr; pełny zakres wymaga dokładnych operacji całkowitych. |
| SmallIndex | Indeks jaja, slot, poziom badania i wariant | Dokładna mała liczba całkowita, sprawdzana względem konkretnego katalogu i zatwierdzonego zakresu. |
| Identifier | UID peta, oferta, operacja, zakup, event, wersja konfiguracji, token sesji | Niepusty tekst; bez konwersji do liczby i bez porównywania nazw leksykograficznie jako poziomów. |
| Instant | Absolutny czas serwera | Proponowany zapis: całkowite milisekundy Unix mieszczące się w dokładnym zakresie binary64. |
| Duration | Pozostały czas boostu, dt, ułamki czasu | Skończone binary64 w sekundach. Nie zaokrąglać każdego kroku do milisekund. |

Jednostki funkcji muszą być jawne: vehicleCapacity to jaja/min, produkcja używa jaj/s; IHR z tabeli jest per kurnik/min, a krok przyjmuje sekundy; procent, ułamek prawdopodobieństwa i pełny mnożnik to odrębne wielkości. Indeks jaja w obliczeniach jest od zera; numer dnia kalendarza 1–28 nie jest indeksem cyklu. Koszt poziomu k+1 znajduje się w prices[k]; effectsByLevel[k] opisuje poziom k.

### 2.1. Zakres i precyzja kwot — rekomendacja P

Rekomendowany pierwszy adapter BigAmount zachowuje operacje binary64 w zakresie referencyjnym, zamiast od razu zastępować je nową arytmetyką mantysa/wykładnik. Dostępne tabele zawierają m.in. ceny badań do około 1.66e67 i wartość krańcową krzywej do około 1.90e81. Te liczby mieszczą się w binary64, ale nie wyznaczają maksimum całej progresji ani wyniku całkowania krzywej.

Binary64 ma około 15–17 cyfr znaczących i maksymalną skończoną wartość około 1.7976931348623157e308. Nie zapewnia dokładnego dodawania dowolnie małej kwoty do ogromnego salda. Mantysa/wykładnik może rozszerzyć zakres, ale sama nie zwiększa dokładności zliczania ani nie zachowuje automatycznie referencyjnej kolejności zaokrągleń.

Przed realizacją adaptera należy określić zakres obsługiwanych wejść i wyników każdej funkcji na podstawie katalogów i przypadków granicznych. Nie przeprowadza się w tym celu strojenia progresji. Poza certyfikowanym zakresem obliczenie zgłasza błąd techniczny bez zmiany salda i bez nadania korzyści; nie zapisuje Infinity, nie zeruje kwoty ani nie zastępuje jej arbitralnym limitem. To zabezpieczenie przed uszkodzeniem stanu, nie nowy limit ekonomii. Wydanie nie może dopuszczać osiągalnej ścieżki prowadzącej do takiego błędu.

Rozszerzenie BigAmount ponad zakres binary64 jest osobnym zadaniem technicznym: musi określić operacje, normalizację, precyzję i migrację. Nie jest aktywną częścią tego kontraktu. Adapter ma izolować tę przyszłą zmianę; nie wolno przełączać typów i zaokrągleń zależnie od przypadku bez wersjonowanej specyfikacji.

### 2.2. Dokładne liczniki i konwersje

- Wszystkie całkowite do 2^53−1 są bezpiecznym zakresem bezpośrednich operacji binary64. Powyżej niego ciąg cyfr w zapisie nie wystarcza: także dodawanie, odejmowanie i porównanie ExactUInt muszą być dokładne. Biblioteka nie jest wybrana.
- ExactUInt zapisuje się kanonicznie: "0" albo cyfry bez zer wiodących, bez znaku i notacji wykładniczej. Pojemność techniczna 2^64−1 nie jest ceną, limitem zdobywania zasobów ani zatwierdzonym capem Piggy.
- Nie konwertować dużego GE, PE lub licznika do binary64 przez zwykłe parsowanie tekstu. Przejście do realnego wejścia wzoru jest jawne i opisuje utratę precyzji; nie zastępuje stanu dokładnego. Dotyczy to także populacji użytej w FV/produkcji i PE w wykładniku.
- Stan ExactUInt nie zawija się przy odejmowaniu kosztu ani przepełnieniu. Brak środków oznacza odrzucenie bez korzyści. Specyficzne konwersje int32/uint64 we wzorach nagród z 13 pozostają lokalnymi operacjami modelu i nie są ogólną regułą zawijania salda.
- Odrzucać NaN, nieskończoności i niedozwolone wartości ujemne. Zerowy wynik jest kanonicznie +0. Dopuszczenie ujemnego remaining boostu dotyczy tylko opisanej fazy aktualizacji; nie ujemnego czasu nieobecności.
- Porównanie salda z kosztem i progów nie używa tolerancji testowej ani skrótu UI. Nie dodawać epsilon, aby pozwolić na zakup. Przypadek kosztu mniejszego niż ULP dużego salda musi mieć jawny test referencyjnej arytmetyki; nie obiecywać dokładnego potrącenia w domenie BigAmount.

### 2.3. Zaokrąglenia i format zapisu

Nie dodawać globalnego floor dla gotówki lub SE. Zachować miejsca floor, trunc, float32, uint64 i porządek działań z właściwego wzoru. Przykłady: float32 współczynnika interpolacji krzywej, double(float32(0.1)) dla małej populacji oraz osobne obcięcia bonusów Piggy. Nie łączyć dwóch obcięć w jedno i nie przestawiać mnożeń dla wygody.

P: podstawowe operacje referencyjne stosują binary64 round-to-nearest, ties-to-even; wymagane przejścia float32 są jawne. Nie zastępować osobnego mnożenia i dodawania operacją zespoloną z inną liczbą zaokrągleń. Dla ExactUInt parsowanie i porównanie są numeryczne, bez zależności od locale; cyfry oznaczają ASCII 0–9. Przechowywany SE i jego porównania korzystają z pełnej wartości Real64; skrót UI nigdy nie wraca do stanu.

Proponowany codec BigAmount/Real64 zapisuje skończoną wartość jako tekst round-trip binary64; 17 cyfr znaczących wystarcza jako górna granica formatu, a nie obowiązek dopisywania zer. Test dekodowania musi porównać bity, nie tylko zaokrąglony wynik. Subnormalne wartości nie mogą po cichu zamienić się w zero. Formatować kwoty do K/M/B lub procentów dopiero w UI, nigdy do ponownego naliczania.

W profilu obecne są wersje schematu, codec i semantyki obliczeń. Zmiana kolejności zaokrągleń jest zmianą wersji obliczeń, nie kosmetyką. Tolerancje testów przypisuje się funkcjom i operacjom: ID/ExactUInt/znaczniki dokładnie, round-trip Real64 bitowo, wyniki funkcji matematycznych zgodnie z uzasadnionym kryterium. Nie zakłada się identycznych ostatnich bitów wszystkich funkcji potęgowych w każdej przyszłej bibliotece.

## 3. Kontrakt czasu

| Zegar / pole P | Znaczenie | Czego nie zastępuje |
|---|---|---|
| ServerInstant | UTC z autorytatywnego serwera: dni, wydarzenia, oferty, VD | Czasu podanego przez klienta |
| RuntimeElapsed | Monotoniczny czas w bieżącym procesie, do pomiaru odcinków online | Trwałego timestampu lub porównania między serwerami |
| settledWallThrough | Do tej chwili okres farmy został rozliczony lub świadomie zamknięty bez dalszej produkcji | Ilości sekund faktycznie produkowanych |
| simulationElapsed / checkpoint | Postęp obliczenia, dt, faza i reszta kroku potrzebne do wznowienia | Ostatniego logowania lub czasu renderowania |
| boost.remainingSeconds | Budżet zużywany przez właściwe kroki symulacji | Unix deadline |
| videoDoubler.endsAt | Absolutny koniec VD | Pozostałego czasu boostu |

P: Instant przechowuje milisekundy; porównania z końcem kroku zachowują ułamki Duration w pamięci obliczenia, bez floor każdego kroku do ms. Krok wyznacza się od zapisanego punktu początkowego, a nie przez wielokrotne dodawanie 300 ms do czasu ściennego. Warunek VD pozostaje ścisły. Wybór dokładnego dostawcy zegara i pomiar jego rozdzielczości należą do realizacji adaptera, nie są tu deklaracją API.

Przed porównaniem zamieniać Instant na sekundy w jednym adapterze: stepEndSeconds = startInstantMs/1000 + simulatedOffsetSeconds; endsAtSeconds = endsAtMs/1000. Nie porównywać milisekund z sekundami i nie stosować epsilon przy równości. Siatka rozliczenia używa dt=min(remainingDuration,0.3), z jednym końcowym krótszym krokiem. W trybie online remainingDuration obejmuje cały pozostały czas rozliczanego odcinka i nie jest ograniczany silosami. W trybie away oznacza pozostały czas produkcji po uwzględnieniu limitu posiadanych silosów. Techniczny podział pracy nie zmienia tej siatki. Zgodność dotyczy tego samego wejścia, konfiguracji i siatki, nie dowolnej zamiany 0.3 s na inne kroki. RuntimeElapsed może mierzyć odcinek online lub budżet wykonania, ale do profilu trafia autorytatywnie ustalony odcinek UTC; nie dodaje się obu czasów dla tego samego okresu i nie odtwarza zegara monotonicznego po restarcie.

### 3.1. Rozliczenie okresu i punkty zmiany

1. Odczytaj od właściciela sesji aktualny profil i autorytatywny czas. Różnicę <=0 traktuj jako brak nowego okresu; nie wypłacaj za ujemny czas i nie cofaj settledWallThrough. Oznacz rozbieżność zegara do wyjaśnienia. Nie nakładaj nieuzgodnionego dodatniego capu offline.
2. Wybierz online dla przerwy <=60 s, away dla >60 s. W away oblicz limit produkcji z posiadanych silosów i parametrów obowiązujących w tym okresie; pełna nieobecność jest oddzielną wielkością.
3. Rozliczaj kroki do 0.3 s w kolejności: efekty właściwego kroku, produkcja z populacji początkowej, transport, dochód i jego księgowanie, wylęg/refill oraz IHR per kurnik. Nie aktualizuj populacji przed produkcją.
4. Boost wnosi efekt w kroku przed usunięciem przy remaining<0; zero nie spełnia tego warunku. Na Enlightenment obowiązuje pauza boostów i neutralne efekty petów z D03. Nie zużywaj dodatkowo całej nieobecności po wyczerpaniu produkcji silosów.
5. VD działa, gdy stepEnd < endsAt; przy równości nie działa. Nie zmieniać tego warunku na historyczne ważenie VD przez część kroku. Czas po wyczerpaniu silosów może wygasić VD bez dodatkowej produkcji.
6. Po zakończeniu utrwal ekonomię i settledWallThrough obejmujące cały rozliczony okres, także odcinek bez produkcji po limicie. Restart nie może drugi raz wypłacić tej samej nieobecności.

Przed zmianą wyposażenia, badania, infrastruktury, aktywacją efektu, awansem jaja, prestiżem lub nadaniem korzyści należy rozliczyć poprzedni odcinek starym stanem. Nowa korzyść zaczyna działać od skutecznej operacji serwera, nie od chwili późniejszego ponownego logowania ani wstecz od początku nieobecności.

P: przerwanie długiego obliczenia nie może tworzyć nowego modelowego kroku ani ponownie wybierać gałęzi online/away. Checkpoint zawiera pierwotny start/cel okresu, tryb, limit i zużyty czas produkcji, numer kroku, pozostały dt oraz fazę. Wznowienie po technicznym yield nie nalicza ponownie boostu. Dodatkowy czas rzeczywisty po zamrożonym celu tworzy następny odcinek, po zakończeniu poprzedniego.

### 3.2. Wydarzenia i zmiany uprawnień

R: historia wydarzenia wpływa tylko na faktyczne nakładanie z oknem produkcji. P: okna mają konwencję [start,end). Dla eventu dochodu waży się jego modyfikator czasem w granicznym kroku według 16. Nie wykonuje się drugiej aktualizacji boostów/IHR z powodu rozcięcia tego samego kroku na granicy eventu. VD i boosty zachowują własną semantykę końca kroku.

Event prestiżu jest oceniany w chwili kolekcji. Wyprzedaż i bonus długości boostu — w chwili odpowiedniej operacji. Długość boostu ustalona przy aktywacji nie zmienia się po końcu eventu.

Historia zawiera ID i wersję harmonogramu, okno UTC, typ oraz modyfikator; nadpisanie bieżącego harmonogramu nie usuwa danych potrzebnych do nierozliczonego okresu. Nakładające się eventy tej samej kategorii wymagają reguły z konfiguracji: bez niej nie zgadujemy sumowania ani mnożenia. Kontrakt nie ustala rotacji lub sił.

Uprawnienia Pro, wariant dostępności +10 p.p. i inne zmienne warunki mają obserwację serwerową oraz effectiveAt. Jeśli platforma nie dostarcza wiarygodnej wcześniejszej daty nabycia, P: stosować chwilę pierwszego potwierdzenia przez serwer, bez wymyślania działania wstecz. Szczegóły integracji pozostają osobnym zadaniem. Brak historii wymaganej do offline nie uprawnia do naliczenia całej nieobecności według obecnych bonusów.

### 3.3. Dni UTC i harmonogram ofert

D04: prawa do darmowego VD i bonusowego prezentu są osobne, przypisane graczowi i dniowi UTC; nie kumulują się za opuszczone dni ani nie resetują przez prestiż. P: zapisywać datę ostatniego wykorzystania każdego prawa zamiast wymagać fizycznego resetu profilu o północy. Klucz dnia UTC to floor(ServerInstantMs/86400000); strefa klienta i zmiana czasu letniego nie wpływają na ten klucz.

Opłacone zamówienie sprzed północy zachowuje ustalone finansowanie i nie zużywa prawa nowego dnia. Żądanie jeszcze nierozliczone wymaga ponownej walidacji bieżącego prawa przed obciążeniem; wynik operacji zapisuje wybraną datę i ścieżkę płatności. Czas kliknięcia klienta nie jest autorytetem.

Terminy dronów/paczek przechowuje się oddzielnie od ich zawartości i odbioru. Brak stosu ofert za offline. D05: kanały zajmują maksymalnie 2 zwykłe i 1 bonusowe miejsce, od utworzenia także podczas dostawy. Oferta ma trwały ID i wynik; nierozstrzygnięta płatność utrzymuje rezerwację, a nie nową próbę losowania.

## 4. Model autorytatywnego profilu — P

Poniższe sekcje są logicznym podziałem jednego spójnego agregatu gracza, nie decyzją o liczbie kluczy w bazie. Nie rozdzielać salda, materiałów i wyniku transakcji na niezależne zapisy bez wykazanej spójności.

| Sekcja | Pola i odpowiedzialność |
|---|---|
| meta | schemaVersion, numericCodecVersion, calculationVersion, configRevision, revision ExactUInt, identyfikator gracza. |
| ownership | sessionToken/generation, właściciel, stan dzierżawy; weryfikacja podczas każdej mutacji, odnowienia i zwolnienia. |
| farm | eggIndex, maxEggReached, cash BigAmount, cztery rekordy kurników: typ, population ExactUInt, fractionalIHR Real64, kury przypisane w drodze; pojazdy i długość każdego pociągu, silosOwned, Common, zapas/refill wylęgarni, autorytatywny stan RCB i wypuszczonych grup. |
| accounting | prestigeSessionArchivedCash, prestigeExtraEarnings, lastBaseEarnings, bieżące akumulatory dochodu i lastCashEarned, lifetime statystyki; każda wielkość ma własną rolę. |
| permanent | GE i totalGESpent ExactUInt, SE Real64, PE ExactUInt lub suma źródeł, Epic, odblokowanie Hyperloop, liczba prestiżów, trwałe flagi postępu. |
| inventory | Sztuki boostów ExactUInt; pety po UID: gatunek, tier pochodzenia, wariant, lock; wyposażenie jako UID. Liczniki gwarancji po kluczu gatunek×tier×cel, nie po UID. Liczba miejsc pozostaje parametrem bilansu. |
| effects | Lista aktywacji boostów: ID aktywacji, ID boostu, remainingSeconds, długość przy aktywacji i wersja konfiguracji; endsAt VD. Skuteczność/pauza wynika z aktualnego jaja i reguł, nie z usunięcia wpisu. |
| timeline | settledWallThrough, ewentualny checkpoint obliczenia, potrzebne wersje eventów i historia uprawnień/zmian stanu. |
| rewards | Kalendarz: nextPosition/numCollected i ostatni odebrany dzień; trofea po jajo×próg, prawa UTC, oferty i rezerwacje, terminy następnych prób, identyfikatory odbiorów. |
| piggy | Osobno saldo, poziom, utracone przyrosty i stan operacji otwarcia; sekcja może pozostać nieaktywna. Nie definiuje cap/rate. |
| entitlements | Potwierdzone gamepassy, effectiveAt i historia potrzebna do rozliczenia; Pro oddzielnie od Buy MAX, warunek dostępności +10 p.p. oddzielnie od posiadania Pro. |
| operations | Trwałe ID, rodzaj, hash argumentów, stan, koszt, wynik i wersja rozliczenia; osobne identyfikatory potwierdzonych zakupów powtarzalnych. |

Powiązania obowiązkowe: każdy wyposażony UID istnieje, nie występuje dwukrotnie i mieści się w uprawnionych miejscach; materiał łączenia nie jest wyposażony/zablokowany ani bazowy; poziomy nie przekraczają maxLevel; długość pociągu należy do istniejącego pojazdu. Zmiana pojemności przez zdjęcie peta nie usuwa nadmiarowych kur: może zatrzymać wzrost, więc population<=capacity nie jest uniwersalnym inwariantem zapisu.

Nie zapisywać jako drugiej niezależnej prawdy: FV, EB, dochodu/s, tempa IHR, pełnych mnożników ani renderowanej liczby modeli. Cache jest wyprowadzany z revision, configRevision i stanu czasu. Stały wynik istniejącej oferty jest wyjątkiem — przechowujemy go, zamiast przeliczać po zmianie farmy. PE można cache'ować wyłącznie ze zgodnością do jednorazowych źródeł kalendarza i trofeów.

### 4.1. Księgowanie przychodu i SE

Portfel nie jest całym przychodem sesji. accounting musi zachować składniki określone w 05 i 13, w tym bazę ostatniego rozliczenia. Phoenix i Soul Beacon działają na przyszły przyrost: `max(0,newBase-lastBase)*(M-1)`, a nie wstecz na historię lub bezpośrednio na wynik SE. Po rozliczeniu przyrostu aktualizuje się lastBase w tej samej operacji; replay nie nalicza dodatku ponownie.

Jednorazowa gotówka non-EPS na farmie domowej zwiększa portfel i właściwy bieżący akumulator oraz wpływa na bazę prestiżu. Nie dopisywać jej jednocześnie do każdej historii. Przed zmianą mnożnika lub resetem zamknąć zaległy przyrost według starego stanu. Opis w 13 określa kolejność; kontrakt nie zastępuje jej prostym sumowaniem salda i wszystkich statystyk.

Zwykła zmiana jaja archiwizuje właściwy składnik bieżącej farmy bez zerowania całej sesji. Prestiż najpierw oblicza i przyznaje SE z właściwą końcową konwersją, a następnie resetuje akumulatory sesji i bazę lastBase. Nie narzuca dodatkowego zaokrąglenia SE.

### 4.2. Macierz resetu

| Stan | Zmiana jaja | Prestiż |
|---|---|---|
| Jajo i infrastruktura | Docelowe jajo; odbudowa zgodnie z 02/13, bazowy kurnik i pojazd, populacja/RCB/Common/zapas według reguły resetu | Pierwsze jajo i odbudowa; zakres jak w 02/13 |
| Portfel i księgowanie sesji | Portfel startowy, należne archiwizowanie przychodu, zachowana historia sesji i bonusy przychodowe | Najpierw naliczenie SE, potem portfel startowy i reset właściwych akumulatorów sesji |
| GE, SE/PE, Epic, trwałe odblokowania | Zachowane | Zachowane, z nowymi SE i zwiększonym licznikiem prestiżu |
| Pety, lock, wyposażenie, gwarancje | Zachowane; efekty zależą od docelowego jaja | Zachowane |
| Aktywne boosty i VD | Wpisy, remaining i endsAt zachowane | Wpisy, remaining i endsAt zachowane |
| Kalendarz, trofea, prawa UTC, ID operacji | Bez wyzerowania | Bez wyzerowania |
| Istniejące oferty i płatne rezerwacje | Trwały ID/wynik nie jest losowany ponownie; zużycie slotu zachowane | Tak samo |

Macierz nie zgaduje liczby odbudowanych silosów lub zapasu wylęgarni na podstawie nazwy Pro: wartości początkowe wymagają konkretnego kontraktu resetu z 02/13 oraz aktywnej konfiguracji. Brak ustalonego pola startowego to jawna zależność zadania resetu, nie powód do usunięcia trwałego zasobu lub użycia przypadkowego zera.

## 5. Operacje, trwałość i odtwarzanie

R/D07: serwer waliduje świeży stan; koszt, materiały, korzyść, znaczniki i rezultat są rozliczone jednokrotnie. P: każda komenda ma operationId, typ, expectedRevision i identyfikatory wejść. Klient nie wysyła autorytatywnej kwoty, FV, wyniku losowania lub czasu offline.

Najpierw sprawdzić, czy operationId ma utrwalony wynik. Dla tego samego ID i tych samych argumentów zwrócić wynik nawet przy nowszej revision; dla zmienionych argumentów odrzucić konflikt ID. Dopiero nową operację walidować względem aktualnej wersji. Konflikt wersji nie może zmienić powtórzenia udanej operacji w nowy zakup.

P: kluczem deduplikacji jest (playerId,operationId); typ operacji należy do podpisanych semantycznie argumentów. Właściciel serializuje mutacje profilu, a kontrola ID następuje ponownie wewnątrz trwałego zatwierdzenia. Dwa równoległe żądania o tym samym kluczu otrzymują ten sam wynik, nie dwa koszty. Terminalne odrzucenie może być utrwalonym wynikiem tej operacji; błąd transportu i nieznany zapis nie są takim odrzuceniem. Nowa próba po rozstrzygniętym odrzuceniu ma nowy ID. Reguła retencji nie może zgubić utrwalonego prawa do rozpoznania powtórki.

Losowy wynik przygotowuje się raz dla konkretnej operacji z przypiętą wersją wejść. Retry mechanizmu zapisu nie może ponownie losować. Wynik, koszt i przypisane parametry są utrwalane razem; niezmienność kandydata do czasu rozstrzygnięcia nie zastępuje walidacji materiałów na świeżym profilu. Zmiana warunków nowej operacji wymaga odrzucenia, a nie cichej podmiany materiałów lub nowego losu.

P: rozróżniać wykonano, już wykonano, odrzucono, anulowano transformację oraz nieznany wynik zapisu zgodnie ze [szkicem zapisu ECC](ecc/adaptations/datastore_migration_and_session_lock.md). Sukces wywołania technicznego nie jest automatycznie dowodem rozliczenia. Przy nieznanym wyniku utrzymać stan oczekiwania i odczytać wynik tego samego ID; nie zwalniać rezerwacji ani przyjmować sprzecznego zakupu.

Po utracie sesji nie wolno zapisać starego bufora, potwierdzić wypłaty bez trwałego wyniku lub zwolnić dzierżawy nowego właściciela. Migracja profilu wymaga aktualnego właściciela, wersjonowanego dekodowania i zachowania wartości; nie tworzy domyślnego pustego profilu po błędzie danych. Oddzielić profil nieistniejący od nieczytelnego lub nowszego schematu.

Checkpoint offline zawiera także skutki ekonomiczne, a nie sam cursor. Jeśli nie da się zapisać spójnego checkpointu pośrodku kroku, utrwalać dopiero ukończony krok. Załadowany stan musi dać się kontynuować bez ponownej wypłaty lub utraty czasu. Dobór częstotliwości i kosztu zapisu pozostaje poza tym kontraktem.

Nie usuwać historii operacji prostym FIFO bez modelu bezpiecznych powtórek. Projekt trwałych potwierdzeń zakupów i retencji ma uwzględnić ograniczenia wybranego zapisu; obecna tabela operations nie oznacza nieograniczonego rozmiaru jednego profilu. Potwierdzanie platformowych zakupów i rozpoznawanie własności passów wymagają osobnego adaptera. Nie wybiera się tu API ani biblioteki.

## 6. Scenariusze odbioru kontraktu — do przyszłego wykonania

| Scenariusz | Oczekiwana własność |
|---|---|
| GE tuż poniżej i powyżej 2^53; dekodowanie i potrącenie jednej sztuki | Dokładny stan ExactUInt, bez zaokrąglenia przez number |
| FV i ceny z pełnych tabel; double(float32(0.1)); konwersje Piggy | Jednostki, kolejność i lokalne zaokrąglenia zgodne z referencją |
| NaN, Infinity, ujemne saldo, niekanoniczny licznik i nieznany codec | Błąd bez częściowego przyznania korzyści, bez wyzerowania profilu |
| SE z ułamkiem oraz round-trip profilu | Brak dodatkowego floor; odtworzenie zapisanej Real64 |
| Nieobecność 60 s i minimalnie dłuższa; pełny limit silosów | Właściwa gałąź; zamknięcie całego okresu bez ponownej wypłaty |
| Boost remaining=0 i <0; pauza na Enlightenment; VD stepEnd=end | Zachowana różnica zegarów i ścisłych warunków |
| Koniec eventu wewnątrz kroku, zmiana peta lub Pro po powrocie | Ważenie eventu bez dodatkowego kroku; korzyść nie działa wstecz |
| Przerwanie obliczenia po produkcji/przed IHR i wznowienie | Ten sam wynik co nieprzerwany okres przy tej samej siatce kroków |
| Dwa potwierdzenia, timeout i ponowienie po przejęciu sesji | Jeden trwały koszt i wynik, brak nowego losu |
| Zmiana jaja i prestiż z aktywnymi boostami, ofertą i gwarancją | Właściwa macierz pól; brak resetu trwałych uprawnień i ID |
| Zdjęcie peta pojemności z pełnego kurnika | Kury zachowane, dalszy wzrost ograniczony |
| Zamówienie przez północ UTC i spóźnione potwierdzenie płatności | Zachowana ścieżka finansowania, rezerwacja i właściwy dzień prawa |

To specyfikacja przyszłych testów, **NIE URUCHOMIONO**. Brak kodu nie jest błędem tego zadania dokumentacyjnego. Kontrola spójności dokumentów nie jest zaliczeniem powyższych scenariuszy.

## 7. Decyzje techniczne i dalsze zależności

Rekomendacja P w tym dokumencie: oddzielne BigAmount/Real64/ExactUInt, tekstowy zapis liczb z round-trip, rozdzielone zegary i spójny agregat stanu. Nie ma nowych decyzji produktu do wymuszonego zatwierdzenia, ale nie należy oznaczać tych rekomendacji jako R bez decyzji użytkownika.

Przed realizacją odpowiedniego fragmentu pozostają: wybór i sprawdzenie adaptera liczb, potwierdzenie zakresów i konwersji, mapowanie potrzebnych pól początkowych resetu, dostawca czasu, bezpieczne przechowywanie historii i ID, biblioteka zapisu oraz harness testowy. Szczególnie rozszerzenie ponad binary64, retencja potwierdzeń i brak historii wymagają jawnego rozwiązania technicznego. Nie blokują pisania niezależnego briefu UI, ale nie można ich zastąpić domyślnymi wartościami w ekonomii.

Nie ustalono nowych limitów petów, cen, szans, progów gwarancji, cap/rate Piggy, rotacji wydarzeń ani cennika Robux. Dane referencyjne i dokumenty 17–21 pozostają niezmienione. Implementację uruchamia osobne polecenie, nie powstanie tego kontraktu.

### Pomocnicze review koncepcji

Za zgodą użytkownika Cline z modelem DeepSeek v4.1 Flash ocenił krótki opis koncepcji bez narzędzi i zmian plików. Wykorzystano uwagi o granicach liczb, jawnych konwersjach, rolach zegarów, kluczu deduplikacji i macierzy resetu. Było to review opisu, nie całego dokumentu ani danych i nie jest niezależnym PASS realizacji.

Nie przyjęto sugestii dodania nieuzgodnionego capu offline ani wymogu identyczności wyników dla dowolnych siatek kroków. Budżet pracy technicznej wymaga checkpointu/wznowienia, a nie obcięcia należnej produkcji. Nie przyjęto globalnego zakazu wszystkich floor poza UI, bo wzory mają jawne lokalne konwersje.

### Redakcja po review Gemini

Gemini 3.8 Flash Medium przez AGY oceniło pełny tekst kontraktu i przekazany zestaw reguł bazowych, bez pełnego porównania pozostałych docs i bez testów kodu. Po review doprecyzowano, że online rozlicza cały pozostały odcinek bez limitu silosów, a away używa czasu produkcji ograniczonego silosami; poprawiono także formę „ani bazowy”. Są to wyjaśnienie istniejącej reguły i korekta językowa, nie nowy limit lub zmiana bilansu. Status technicznych propozycji pozostaje P.


### Doprecyzowanie zapisu kalendarza — implementacja #62

Referencyjny typ 14 jest przechowywany jako permanent.shellScripts (ExactUInt, kanoniczny tekst; nowy profil "0", starszy brak pola odczytywany jako zero). Counter jest trwały i trafia do prywatnego progress; nie oznacza wdrożenia sklepu kosmetycznego lub kursu wymiany. Wypłata typu 2 jest BigAmount wyliczanym jako procent aktualnego FV farmy domowej. W obecnym modelu earned currentFarmCash dopisuje się ją do podstawy prestiżu niezależnej od portfela, z jednokrotnym dodatkiem aktywnego boostu/peta prestiżu. Nie zmieniono capów, cen, parametrów ani typów pozostałych sekcji. [Weryfikacja #62](workflow/calendar_rewards_62.md).
