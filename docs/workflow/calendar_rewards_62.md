# Pełny kalendarz — poprawka #62

25.10.2026. Zakres: brakujące wypłaty dni 4/10/15/18/22, ich stan i projekcja oraz regresje całych cykli. Bez zmian bilansu 17–21, danych referencyjnych, cen, szans i monetizacji; bez przepisywania historii Git. Nie uruchamiano Studio, prawdziwych zakupów lub DataStore.

## Źródło i przyczyna

[11 §3](../11_periodicals_calendar_events_and_boost_rules.md) już określał gotówkę jako `amount/100 × Home Farm Value`; [13 §2](../13_rewards_contracts_resets_and_gift_distributions.md) opisywał typ 14 jako dopisanie do licznika uint64. Poprzednie rozpoznanie #62 przeoczyło istniejący wzór gotówki. Był to brak podłączenia istniejących zasad, nie brak wymagający ustalenia nowego bilansu.

Parametry wszystkich pozycji pochodzą z niezmienionego [rewards.json](../reference_data/rewards.json), a ceny konwersji Epic z istniejącego katalogu. Usunięto z kalkulatora kalendarza zastępcze pośrednie nagrody typu 5000 cash; domyślny odczyt używa tej samej wygenerowanej tabeli referencyjnej co serwer.

## Rozliczenie

| Dni | Wypłata |
|---|---|
| 4 | `min(200, 50×(m+1))%` aktualnego FV farmy domowej |
| 15 | 75% aktualnego FV farmy domowej |
| 22 | 150% aktualnego FV farmy domowej |
| 10 | Shell Scripts: 5/7/9/12/15/18 według cyklu, potem 18 |
| 18 | 10 Shell Scripts |

FV jest liczone w serwerowej operacji po rozliczeniu poprzedniego odcinka czasu, przed wypłatą nagrody. Podgląd nie zamraża FV: zmiana jaja między podglądem a odbiorem daje wartość z aktualnej farmy. Dane gotówki nie pochodzą od klienta. Kalendarz farmy domowej nie może przyjąć FV farmy kontraktowej; ten przypadek jest odrzucany, bez podmiany źródła.

Pety/boosty nie dodają drugiego mnożnika do gotowej kwoty. Używany jest istniejący kalkulator FV, z jego wejściami i warstwą badań; nie podmienia się go na metrykę pełnego dochodu. VD, mnożnik zarobków, premia paczek i współczynnik offline nie mnożą tej wypłaty.

Gotówka trafia do portfela, lastCashEarned i earned currentFarmCash. Ten ostatni jest już w implementacji podstawą prestiżu niezależną od wydawania portfela. Aktywny Soul Beacon/Phoenix dodaje odpowiadający przyrost prestigeExtraEarnings raz, przy odbiorze; kolejny krok Timeline nie dolicza go ponownie. Nie zmieniono całego modelu innych nagród non-EPS, wydarzeń ani wzoru SE.

`permanent.shellScripts` to kanoniczny tekst ExactUInt. W nowym profilu wynosi `"0"`; brak pola w starszym profilu jest odczytywany jako zero. Schema sprawdza zapis, a prywatny widok progress udostępnia ten licznik. Nie konwertuje się go do binary64, GE lub gotówki. Nie dodano sklepu kosmetycznego, wymiany, produktów ani cen. Przyrost może być przyznany i trwale zachowany bez wdrażania sposobu jego wydawania.

Nagroda, licznik odebranych prezentów, dzień UTC i wynik operacji zapisują się razem przez istniejącego koordynatora/repozytorium. Ponowienie tego samego ID odtwarza wynik, a inne ID tego samego dnia nie daje nowej nagrody. Brak zapisu/przepełnienie nie zużywa dnia ani częściowo nie wypłaca zasobu. Zachowano blokowanie sesji dla UNKNOWN.

## Testy oczekiwanego zachowania

[calendar_cycle](../../tests/calendar_cycle/run.luau) korzysta z [niezależnej tabeli](../../tests/calendar_cycle/oracle.json), generowanej przez osobny program Pythona z surowego JSON-a i zasad dokumentacji. Nie importuje produkcyjnego resolvera do wyznaczania oczekiwań. Dodatkowo pilnuje udokumentowanych sum pierwszego cyklu: 4372 GE, 140000 SE, 15000 surowego Piggy i 15 Shell Scripts.

- Dziesięć kompletnych cykli (m=0/1/2/3/5/7/9/23/24/66): wszystkie 28 wypłat, stan po każdym odbiorze, replay i odmowa kolejnego odbioru tego samego dnia; także przejście do dnia 1 następnego cyklu. To dziesięć odrębnych scenariuszy startujących na zadanym etapie, nie deklaracja symulacji całych 67 miesięcy.
- Rzeczywiste serwer/transport/protokół/zapis i zwalnianie/ponowne pozyskiwanie sesji pomiędzy dniami. Testowa farma ma zerowe okno offline, by izolować wypłaty od produkcji. Nie zmienia to jednego silosu nowego konta ani zatwierdzonego tempa gry.
- Niezależna arytmetyka FV pustej farmy oraz konkretny scenariusz zmiany jaja po podglądzie.
- Gotówka przy aktywnych bonusach, brak powtórnego dodatku do prestiżu, zakup badania po odbiorze i prestiż po wydaniu części portfela.
- Shell Scripts powyżej 2^53, stary profil bez pola, odrzucenie niekanonicznego licznika i przepełnienia uint64.
- Awaria zapisu osobno dla wszystkich pięciu poprzednio blokowanych dni, bez połowicznej mutacji lub zużycia prawa odbioru.

Nowa tabela sprawdza rotacje, capy i granicę kalendarzowych PE. Ochrona przed błędami jest dodatkowo sprawdzana trzema nowymi mutacjami: brak dzielenia procentu przez 100, utrata dokładności Shell Scripts i pominięcie earned currentFarmCash. Wraz z siedmioma wcześniejszymi to dziesięć wybranych wad semantycznych, nie pełne pokrycie mutacyjne gry.

Pełne uruchomienie: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Wynik: **32 zestawy, 79 765 asercji PASS L**, w tym 9812 nowego zestawu cykli. Wykryto wszystkie dziesięć wybranych mutacji. Rojo: statyczne mapowanie 39 modułów/2 entrypointów. [Wynik i sumy kontrolne](calendar_rewards_62_verification.json). Dokumenty 17–21 i pliki reference_data porównano bajtowo z wersją bazową: bez zmian.

Historyczne szerokie deklaracje gotowości REL-01 w logu nadal dotyczą otwartego #60; nie są dowodem testów Studio lub chmury. Pozostałe #57–61 i niedostępne funkcje odłożonego bilansu nie są przez #62 domykane.
