# Prywatne QA — DataStore i reconnect, 04.11.2026

**Późniejsza naprawa QA-DATA-01/02 i ponowny odbiór:** [raport naprawy](session_lifecycle_fixes_2026_11_04.md). Poniżej zachowano historyczne wyniki FAIL z wcześniejszej wersji.

Kod: `db557b18fdaa869c20322aec34bb8ba3896ef788`. Osobne doświadczenie **HatchTheEgg - Private QA**, universe `10774701473`, place `110937489000525`, konto `theZuraz`. Ceny, katalogi i balans bez zmian.

## Konfiguracja i metoda

- [Creator Hub — limit serwera](https://create.roblox.com/dashboard/creations/experiences/10774701473/places/110937489000525/access): **4**, zapisane i potwierdzone po przeładowaniu strony. Domyślna wartość w Hub wynosiła 50; otwarte Studio pokazywało lokalne 12. Lokalna właściwość `Players.MaxPlayers` jest tylko do odczytu i nie służy do konfiguracji chmury.
- Doświadczenie utworzono jako niepubliczne; nie zmieniano jego odbiorców. Studio Access to API Services włączony, `Main.UseLocalMemoryStore=false`. Runtime potwierdza `PERSISTENT`.
- Prawdziwy DataStore `HatchTheEgg_PlayerProfile_v1`, klucz `player:11647593962`; izolacja przez osobny universe. Nie usuwano ani nie zastępowano rekordu fixture'em. Nie testowano zakupów.
- Jeden rzeczywisty klient i serwer Studio, kilka kolejnych sesji. To Studio korzystające z chmury, a nie klient uruchomiony przez aplikację Roblox na hostowanym serwerze.
- 50/50 źródeł porównano z repo przed testem. Tymczasowe lokalne Script/LocalScript i BindableFunction odczytywały rzeczywisty koordynator. Osobna sonda wywołała istniejące `checkpointPlayer`; nie przyznawała zasobów. Sond i zmodyfikowanego Main nie publikowano.
- Postęp uzyskano przez wejście na płytę (narzędzie nawigacji), wyklucie 250 kur i natywny zakup jednego `nutritional_sup`. Populacja, GE, infrastruktura i badanie są kontrolami ciągłości profilu. [Surowe wyniki](private_qa_datastore_2026_11_04.evidence.json).

## Wykryte blokery

### QA-DATA-01 — zamknięcie Studio nie zawsze zapisuje i zwalnia sesję

Pierwszy Stop: przed wyjściem working cash `1366.703593233731`, READY, busy=false, queue=0. Odczyt chmury po zamknięciu: cash `915.84942656706346`, revision 6, settledWallThrough `1793819483285`, aktywny owner i endsAtMs `1793819625017`. Powtórny odczyt bez cache potwierdził ten sam rekord. Log deklarował „All player sessions saved and released”, ale reconnect przed końcem lease odrzucono `SESSION_BUSY`.

Wynik **FAIL** dla tego zamknięcia. Nie skasowano blokady ręcznie; czekano na jej wygaśnięcie. Kod `playerLeaving` ignoruje wyniki checkpoint/drain/release i usuwa sesję, a `BindToClose` ogłasza sukces bez sprawdzenia trwałego rezultatu. Równoległe PlayerRemoving/BindToClose i zajęty writer wymagają osobnego odtworzenia przy naprawie; dokładny przeplot pierwszego Stop nie został zarejestrowany.

Kontrola rozdzielająca: jawny `checkpointPlayer` zwrócił APPLIED, revision 10, cash `2543.6775515670611`; niezależny GetAsync z UseCache=false potwierdził tę samą kwotę i wersję. Późniejsze rozłączenia przez Player:Kick wykonały finalny checkpoint i wyzerowały ownerToken/endsAtMs. Adapter potrafi zapisywać, ale nie zamyka to nieudanego scenariusza Stop.

### QA-DATA-02 — klient pozostaje CONNECTING po rozliczaniu zaległego czasu

Po wygaśnięciu lease nowa sesja generacji 2 przywróciła populację 250, sequence 250, nutritional_sup=1 i GE=10. Pierwszy pomiar: coordinator.ready=false, checkpoint AWAY w toku; później server READY, ale HUD nadal CONNECTING i $0. Diagnostyczne ponowienie istniejącego `client:connect` przywróciło READY i aktualny widok. Nie jest to PASS automatycznego reconnectu.

Powtórzenie po poprawnym zwolnieniu sesji: generacja 3, serwer READY, klient nadal CONNECTING. Dotyczy więc także powrotu bez starej blokady. Main przechowuje bootstrap przed rejestracją gracza, ale nie ponawia go po przejściu koordynatora z rozliczania do READY; gateway odrzuca bootstrap przy SESSION_NOT_READY, a klient startuje go jednokrotnie. Wymagany test handshake przed/po zakończeniu rozliczenia.

## Wynik offline i powtórnego wejścia

Po prawidłowym zwolnieniu generacji 3 trwały profil miał cash `3421.0733849003914`, settledWallThrough `1793819801323`, ownerToken pusty. Następne wejście rozliczyło AWAY do `1793819884811`: **83.488 s**. W tym stanie nie ma IHR, petów, boostów, Pro, SE ani eventów; 250 kur / 30 × wartość jajka 1 × nutritional_sup 1.25 daje dochód online `10.416666666666668/s`, offline F2P połowę. Źródła oczekiwania: produkcja w `FarmMath/production_research.luau`, wartość Regular w `FarmMath/fv_se.luau`, efekt badania z katalogu i zatwierdzona reguła offline z CURRENT_SPEC/06. Nie użyto TimelineSimulation do wyliczenia oczekiwanej kwoty.

- Oczekiwany dochód offline: **434.83333333333337**. Po dalszej produkcji online oczekiwany cash `4085.687968233725`; working cash dokładnie taki sam. **PASS dla sprawdzonego naliczenia F2P**, mimo osobnego FAIL UI: klient CONNECTING.
- Kolejne poprawne rozłączenie zapisało cash `4273.8546349003936`, settledWallThrough `1793819924934` i pustego właściciela. Krótki reconnect rozliczył 21.833 s według gałęzi ONLINE: oczekiwane `4501.281718233727`, rzeczywiste `4501.2817182337285` (różnica 1.82e-12, poniżej tolerancji 1e-8). **Brak ponownej wypłaty wcześniejszych 83.488 s** w tym scenariuszu; klient osiągnął READY bez diagnostycznego ponowienia.
- Zachowano populację 250, sequence 250, poziom badania 1 i GE 10. Generacja sesji zwiększała się po kolejnych poprawnych wejściach.

| Kontrola | Wynik |
|---|---|
| Limit czterech graczy w Creator Hub | PASS, potwierdzony po reload |
| Rzeczywisty odczyt/zapis i wersje DataStore | PASS w wykonanych scenariuszach |
| Jawny checkpoint i poprawne rozłączenia | PASS |
| Pierwszy Stop / zwolnienie lease | FAIL — QA-DATA-01 |
| Reconnect krótki po poprawnym wyjściu | PASS, HUD READY |
| Reconnect podczas/po dłuższym rozliczaniu | FAIL dla klienta — QA-DATA-02; stan serwera odtworzony |
| Offline F2P po czystym wyjściu / brak podwójnego naliczenia | PASS w opisanym oknie |

Nie sprawdzono limitu 6h/18h w czasie rzeczywistym, Pro, konfliktu dwóch hostowanych serwerów, nieoczekiwanego zerwania procesu ani pełnej macierzy A01–A16. Nie wykonano niezależnego review ani nie zatwierdzono release. Diagnostyka zawierała błędną ścieżkę StatusLabel i wywołanie nieistniejącego getView; poprawiono sondę na getState, a błędy nie stanowią defektów gry. Pierwsza próba odczytu po Kick zastała już Edit zamiast Server; odczyt powtórzono w poprawnym DataModel.

Własne sesje zakończono. Końcowy stan źródeł, usunięcie sond i zwolnienie ostatniej blokady zapisano w dowodach JSON. Nie publikowano diagnostyki ani zmian kodu gry. **Wynik całości: wymaga naprawy QA-DATA-01/02 przed release.**
