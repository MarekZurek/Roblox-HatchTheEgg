# Usunięcie czasowego podwajacza — 28.10.2026

## Decyzja i zakres

Użytkownik zatwierdził usunięcie czasowego podwajacza oraz badania „Dłuższe Wzmocnienia” (`video_doubler_time`). Osobny pass `double_cash` (2× Cash) pozostaje; jego wcześniejszy błąd naliczania z #84 nie jest naprawiany ani maskowany w tej zmianie. Pozostałe boosty i bonusowe prezenty pozostają w zakresie dotychczasowych kontraktów.

Na zlecenie użytkownika wyodrębniono do osobnego commitu wyłącznie usunięcie podwajacza na bazie `701d087`. Pozostałe lokalne zmiany Gemini (UI, bilans, mnożniki i nowe zakupy Epic) nie wchodzą do tej dostawy. Osobny pass 2× Cash pozostaje w lokalnym drzewie; nie jest dodawany ani usuwany tym commitem. Wynik pushu i SHA są potwierdzane po publikacji w odpowiedzi końcowej. Bez synchronizacji Studio i publikacji Roblox.

## Implementacja

- HUD nie oferuje wycofanego badania. CatalogRegistry nie wystawia go w aktywnych epicIds, a getEpic/epicPrice/epicEffects odrzucają ten identyfikator. Próba zakupu wycofanego ID nie może nadać poziomu ani pobrać GE. W lokalnym drzewie z obsługą BuyEpicResearch jest odrzucana przez katalog; na bazowym main sama nowa obsługa zakupu Epic jeszcze nie istnieje. Bez zwiększenia totalGESpent.
- EffectsManager ignoruje dawne terminy w obu formatach. Kompatybilne pola projekcji pozostają neutralne (false/1); dawne wywołanie activateVideoDoubler zwraca false/FEATURE_REMOVED bez mutowania profilu. Timeline nie mnoży już dochodu przez VD.
- Stare poziomy badania, terminy i nieznane pola profilu pozostają czytelne i zachowane. Bez kasowania postępu, automatycznego zwrotu GE lub zmiany uprawnień passa. Zwrot dawnych wydatków wymagałby osobnej decyzji produktu i wiarygodnej historii zakupów.
- Historyczne JSON-y referencyjne i generowany import nadal mogą zawierać dawne badanie; nie są aktywną ofertą. Nie zmieniono docs/17–21 ani historycznych raportów. Bieżące indeksy i kontrakty wskazują nową decyzję jako nadrzędną wobec dawnych zasad VD.

## Weryfikacja

- Nowy zestaw `tests/retired_doubler/run.luau`: **26 asercji PASS**. Odczyt i JSON round-trip nowego/starego profilu, zachowanie poziomu i passa, odrzucenie zakupu i retry bez kosztu oraz realny cash/accounting z Bootstrap/Timeline. Oferta w HUD usunięta, double_cash nadal obecny. Stały fixture jajka1 ($1.25) oddziela wynik od niezwiązanej zmiany wartości pierwszego jajka. Bezpośrednie regresje getEpic/epicPrice/epicEffects odrzucają wycofane ID. Zestaw włączony do tools/test.ps1.
- `effect_boundaries`: **324 asercje PASS**, w tym odmowa aktywacji dla poziomów 0..12 i obu dawnych formatów oraz porównanie zarobków i księgowości z profilem bez podwajacza: online, away, standard/Pro, checkpoint encode/decode, krótkie i godzinne okresy. Zachowane testy boostów, wydarzeń, silosów i deterministycznego wznowienia.
- Zaktualizowano oczekiwane efekty w testach production_context, event_time, session_prestige_rcb i release_candidate; katalog sprawdza aktywne 23 badania oraz odmowę dostępu do wycofanego ID. Ceny i wzory pozostałych mechanik zachowane z main, dane oracle bez zmiany.
- Pierwszy pełny `tools/test.ps1` **PASS (exit 0)** dotyczył całego lokalnego drzewa z innymi pracami: 51 zestawów Luau, 11 testów Python (`build/remove_doubler_full.log`). Przed commitem wykonano niezależny pełny runner na wyodrębnionym snapshotcie main + tylko ta zmiana: **50 zestawów Luau i 11 Python PASS (exit 0)**, generatory/oracle i statyczny build Rojo **41 modułów + 2 entrypointy PASS**. Log: `build/scoped_doubler_review/scoped_validation.log`. Końcowy gate: LOCAL CHECKS PASSED; RELEASE NOT APPROVED; S/D/H NOT VERIFIED.
- W lokalnej wersji Gemini poprawiono oczekiwanie 24 kart Epic na 23. Te korekty nowego UI/testów Epic pozostają razem z tamtą niezatwierdzoną pracą i nie są przenoszone do commitu usunięcia VD. Nowy helper po korekcie wywołania Schema.validate i odseparowaniu fixture przeszedł 26 asercji w wydzielonym snapshotcie.

Dowody są lokalne (L i statyczny build), bez prawdziwego DataStore, zakupów i nowego testu Studio. Nie stanowią zatwierdzenia wydania.

## GitHub

Zaktualizowano i potwierdzono odpowiedzi API dla [#85](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/85) (badanie wycofane; pozostałe braki Epic nadal otwarte), [#92](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/92) (nowy tytuł i zakres: wyłącznie aktywacja zwykłych boostów) i [#84](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/84) (pass pozostaje, brak potrzeby składania z usuniętym VD). Żadne z tych zbiorczych zgłoszeń nie jest w całości rozwiązane przez tę zmianę; wszystkie pozostały otwarte. Opisy odróżniają lokalny kod od opublikowanego main.
