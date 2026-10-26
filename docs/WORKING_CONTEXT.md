# Bieżący kontekst — 26.10.2026

Cel: farma HatchTheEgg z petami w Roblox, zgodna z opisaną specyfikacją. Poniższy skrót przekazania jest aktualnym punktem startowym; starsze opisy etapów i listy otwartych zgłoszeń dalej w pliku są historyczne.

## Przekazanie do nowego chatu — 26.10.2026

- Projekt: `HatchTheEgg`; repozytorium [MarekZurek/Roblox-HatchTheEgg](https://github.com/MarekZurek/Roblox-HatchTheEgg), gałąź `main`. Baza bieżącego zadania: `eb7b2e08dbdc4d3269cd7ab3009d5f531b5123e8`, wcześniej wypchnięta na `main`. Zmiany płyty 30/s i UI #77–80 opisane poniżej są lokalne, bez nowego commitu/pusha. Nowy chat powinien najpierw sprawdzić aktualne `git status` i log, zamiast zakładać, że ten SHA nadal jest najnowszy.
- #71–74 naprawiono, opublikowano i zamknięto w `b7d8ca88d37b8a3402d1cc26a35973f0af5a9773`: nadanie potwierdzonych passów po offline/UNKNOWN, maksimum RCB badań w FV, zniżki Epic i zakończenie hold dopiero po zatwierdzonym resecie. [Opis i dowody](workflow/entitlement_farm_fixes_71_74.md).
- Dowody dla dostawy #71–74: 38 zestawów / 80 838 asercji Luau (192 nowe), 11 testów raportowania Python, 41/41 wybranych mutacji wykrytych. Są przypisane do tamtej dostawy; nie stanowią ponownej weryfikacji późniejszych zmian HUD/sceny ani pełnego odbioru Studio/chmury.
- Później opublikowano `5035b4c`: poprawki klikalności, odświeżania wycen i stanów zakupu badań w HUD. Ten sam commit zawiera konfigurację oświetlenia. `0b75542` usuwa stare pola zakupowe 3D przed laboratorium i aktualizuje powiązane wywołanie klienta. Nie cofać tych zmian przy synchronizacji starszego buildu.
- **Oświetlenie jest gotowe i opublikowane.** W [default.project.json](../default.project.json), bezpośrednio pod usługą `Lighting`: `LightingStyle = Soft`, `PrioritizeLightingQuality = false`, `GlobalShadows = true`. To współczesne ustawienia odpowiadające Voxel; nie dodawać runtime zapisu do przestarzałego `Lighting.Technology`. [Mapowanie Roblox](https://devforum.roblox.com/t/3401512).
- Otwarty lokalny plik Studio: `HatchTheEgg.rbxlx`. Przy tym przekazaniu Studio było w **Edit**, `PlaceId=0`; odczytano powyższe trzy ustawienia Lighting oraz `ServerScriptService.HatchTheEgg.Main.UseLocalMemoryStore=true`. Stan procesu może się zmienić — sprawdzić połączenie i tryb przed działaniem. Sam ten odczyt nie dowodzi zgodności wszystkich źródeł otwartej sceny z najnowszym HEAD.
- **Test lokalny:** `UseLocalMemoryStore=true` to jawny tryb Studio bez trwałego postępu i bez zakupów. Po Stop dane testu znikają. Domyślny build nie ustawia tego atrybutu: po ponownym otwarciu wygenerowanego pliku sprawdzić go przed Play i włączyć na zlecenie testów lokalnych. Nie włączać produkcyjnego fallbacku do pamięci. Lokalny nieopublikowany place bez tego trybu wcześniej zwrócił `DATASTORE_OPEN_FAILED` i prawidłowo odmówił wejścia.
- W tym zadaniu ponownie wykonano Rojo build i `tools/verify_build.py`: **PASS_STATIC_BUILD**, 39 modułów i 2 entrypointy. Plik lokalny: `build/HatchTheEgg.rbxlx`; build jest ignorowany przez Git. Nie uruchamiano ponownie całego runnera ani Play; wynik nie zatwierdza wydania.
- **Granice pozostają:** odłożony bilans `docs/17–21` bez zmian i bez wznowienia; dane referencyjne nie są automatycznie zatwierdzoną konfiguracją premiery. Odbiór S/D/H i pozostała integracja premiery nadal wymagają osobnych dowodów. Nie ponawiać dawnych audytów mechanik bez związku z nowym zadaniem.
- Przy rozpoczęciu tego zadania drzewo Git było czyste. Dawne dziewięć nieśledzonych plików audytu jest już śledzone w `5035b4c`; poprzednie ostrzeżenie, że nadal są nieśledzone, jest nieaktualne. Nie usuwać ich ani nie przepisywać historii w ramach optymalizacji kontekstu.

## Dostawa Git i UI — 26.10.2026

Użytkownik zlecił commit i push optymalizacji/naprawy zakupów oraz dopisał zmiany UI. Optymalizacje, naprawa i ich testy/docs zapisano w `9b7c489`; [raport nowego UI](workflow/upgrade_ui_2026_10_26.md) opisuje drugi zakres: efekty badań teraz→następny poziom, serwerowe ceny kurników i floty, cztery podstawowe miejsca floty, licznik GE, responsywne przewijane okna tych trzech paneli. Wycofano prośbę o dodatkowy filtr niższych kurników. Poprawiono też zapis kupna pojazdu poza kolejnością (gęste puste miejsca typeIndex=-1, bez ich wpływu na transport/FV). Pełne testy: 41 zestawów / 81 624 asercje Luau, 11 Python i Rojo 39+2 PASS. Ograniczony render Studio w landscape, mały/duży widok PASS, nie pełne H/S/D. Użytkownik zgodził się zakończyć swój Play do synchronizacji; własny test zakończono w Edit, symulator default, UseLocalMemoryStore=true. Roblox niepublikowany. Wynik zleconego pusha i najnowsze SHA sprawdzić w git; wcześniejsze wpisy o braku commitów opisują stan przed tą dostawą.

## Optymalizacja klienta — zmiany lokalne 26.10.2026

Na bazie `3284b5b` wdrożono na zlecenie użytkownika HUD na zdarzenia, niemutowalny cache widoku farmy i indeks płytek. [Raport wdrożenia i pomiary](workflow/client_performance_2026_10_26.md): 39 zestawów / 80 861 asercji Luau oraz 11 testów Python PASS; Rojo 39 modułów + 2 entrypointy. Trzy krótkie próbki Studio: przed około 58,1/55,0/52,4 FPS, po około 60 FPS; bez gwarancji stałego zysku. Cztery źródła klienta zsynchronizowano z otwartą instancją; własny Play zakończono w Edit, UseLocalMemoryStore=true. Zmiany są lokalne, bez commitu/push/publikacji i bez zapisu pliku place. Pełny odbiór S/D/H nadal niewykonany. Początkowy [raport diagnozy](workflow/performance_investigation_2026_10_26.md) zachowuje wcześniejsze pomiary.

**Błąd ujawniony podczas optymalizacji naprawiono następnie lokalnie na osobne zlecenie:** [zakup za świeży dochód](workflow/fresh_cash_purchase_fix_2026_10_26.md). PlayerCoordinator przekazuje validatorowi stan po symulacji, przed zakupem, z kontrolą bazowych pól na aktualnym rekordzie. Dochód, wydatek, korzyść i kursor czasu nadal mają jeden atomowy commit; replay/fencing pozostają aktywne. 308 nowych asercji, wybrane mutacje 6/6 wykryte; pełny runner 40 zestawów / 81 171 asercji Luau i 11 testów Python PASS, Rojo 39 modułów + 2 entrypointy. Studio: zakup z rewizji 0 przed autosave APPLIED, dwa duplikaty REPLAYED, poziom i rewizja pozostają 1. Tylko PlayerCoordinator dosynchronizowano do Studio; końcowo Edit, UseLocalMemoryStore=true. Zmiany nadal lokalne; niezależnego review i rzeczywistego DataStore nie wykonano, wydanie niezatwierdzone. Historyczny raport optymalizacji zachowuje wcześniejszy błąd jako wynik tamtego testu. Bilans i dane referencyjne bez zmian.

## Płyta 30/s i kosmetyczny strumień — 26.10.2026

Użytkownik zatwierdził **30 kurczaków/s podczas stania na płycie**, przy niezmienionym zapasie/refill i pojemności. [Raport, decyzja i dowody](workflow/plate_hatching_2026_10_26.md). Serwer co 0,25 s sprawdza rzeczywistą postać przy płycie; nie ma klientowskiego żądania płyty ani 30 pakietów HatchPress/s. Zachowano serwerowe grupy danych, rezerwacje, RCB i dotarcia. Klient pokazuje ciągłą reprezentację ruchu: do 8 modeli/s, maksymalnie 32 naraz, historia do 256 ID. Zwykły press i Epic Hold poza płytą bez zmiany znaczenia.

Cline dostarczył implementację i regresje; root zintegrował poprawki streamu, limitu długu animacji oraz czasu wejścia/RCB. AGY wykonał celowane niezależne QA, z ograniczeniami opisanymi w raporcie. Root wykonał pełny runner: **44 zestawy / 81 928 asercji Luau, 11 Python, Rojo 39 modułów + 2 entrypointy PASS**. Nowe regresje: 160 serwer, 55 wizualizacje i 89 niezależnych integracyjnych; obejmują m.in. śród-krokowe wejście i brak RCB za wcześniejszy czas. Zakupy za świeżą gotówkę: 308 istniejących asercji nadal PASS; lokalny native smoke zakupu APPLIED i identycznej operacji REPLAYED bez drugiego poziomu.

Studio po własnych próbach ponownie **Edit**, `HatchTheEgg.rbxlx`, PlaceId=0, `Main.UseLocalMemoryStore=true`. Zsynchronizowano i porównano sześć zmienionych skryptów, nie całą scenę. Nowe pomiary i ograniczenia w raporcie; brak chmury/publikacji/odbioru całego wydania. Błędy bazowe zgłoszono jako otwarte [#75](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/75) i [#76](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/76); poprawki są lokalne. Nie wznawiać bilansu 17–21 ani przenosić lokalnego trybu pamięci do konfiguracji produkcyjnej.

## UI #77–80 — realizacja lokalna 26.10.2026

Aktualne zlecenie: [feedback wylęgu, nazwy Tier i usunięcie płytek pojazdów](workflow/ui_tasks_77_80_2026_10_26.md). Użytkownik jawnie zlecił implementację Cline i QA AGY. Wcześniejsze lokalne zmiany płyty zachowane; repo nadal na eb7b2e0 bez nowego commitu/pusha. Użytkownik zgodził się zakończyć zastany Play, wykonano Stop; root jest jedynym wykonawcą Studio. Cline wykonał kod i korekty po review, AGY dał końcowy PASS w celowanym zakresie (review przekazanych fragmentów/SHA i dowodów, bez własnego uruchamiania testów). Root wykonał pełny runner: **46 zestawów / 82 190 asercji Luau, 11 Python i Rojo 39+2 PASS**. Nowe zestawy: 230 autora i 32 niezależne. Studio: rzeczywisty komunikat przy 147 zasiedlonych + 103 w drodze, klik akcji otwiera panel; 0 płytek pojazdów i 0 żądań ich zakupów po przejściu starych miejsc. Kontrolowane ramki GUI 320×640, 640×360 i 1200×700 bez clip/overlap nowego paska, Tier 19/12 i puste sloty sprawdzone. Szczegóły, pierwotne błędy i ograniczenia w raporcie.

Końcowo Studio **Edit**, PlaceId=0, UseLocalMemoryStore=true; trzy zmienione skrypty zgodne z plikami repo, usunięto także stare dwa modele płytek z Edit i poprawiono istniejące etykiety. Własny fixture i probe usunięte, HUD przywrócony, Play zakończony. #77–80 nadal otwarte do publikacji kodu. Brak nowego commitu/pusha/publikacji i pełnego odbioru wydania/chmury.

## Wcześniejsze decyzje i historia dostaw

## Czytać na początku

1. [CURRENT_SPEC](CURRENT_SPEC.md): rejestr potwierdzonych wzorów, specyfikacji referencyjnej, decyzji użytkownika i propozycji; główny punkt rozstrzygania sprzeczności.
2. [TODO](TODO.md): otwarte decyzje oraz odłożone zadania.
3. [16](16_pet_stacking_offline_and_package_schedule.md): mapa petów/boostów/offline i harmonogram paczek. FV: [02](02_eggs_and_farm_value.md), prestiż: [05](05_prestige_soul_eggs_and_boosts.md), kalendarz: [15](15_calendar_gameplay_formula_and_roblox_scope.md), odbiór/rozkłady: [13](13_rewards_contracts_resets_and_gift_distributions.md).

Raporty 10–16 zachowują dowody i ograniczenia kolejnych etapów. Historyczne listy braków nie oznaczają aktualnego zlecenia. Rozdziały 01–09 uporządkowano według istniejących danych; architektura, UI i produkty nadal są szkicami P.

Nowe rekomendacje: [22, D01–D07](22_gameplay_rules_for_approval.md). D02–D07 zatwierdzone. D01 — R: premium +10 p.p. zamiast dopłat do każdej próby; zatwierdzono stopień = tier pochodzenia × docelowy wariant, wcześniejsze zdjęcie/odblokowanie oraz brak automatycznej podmiany materiałów. R: przy porażce zachować peta bazowego, zużyć pozostałe wybrane kopie i zwiększyć trwały licznik gwarancji. R: stopień łączenia = tier pochodzenia × docelowy wariant; gatunek/rarity nie zmieniają dodatkowo szansy. D04 zatwierdzone: pierwsza aktywacja ×2 i pierwszy bonusowy prezent dnia UTC darmowe, kolejne płatne, zawartość prezentu jawna przed zakupem. Bez wdrożenia i zmian bilansu.

## Decyzje użytkownika

- Pety tej samej statystyki: P=1+sum(b). Drone Hawk zwiększa szansę elity, nie częstość, z końcowym ograniczeniem szansy do 100%.
- Offline rozlicza faktyczny historyczny czas wydarzenia, w oknie produkcji silosów. To świadoma adaptacja, nie dowód referencyjnego predykatu.
- Kierunek ekonomii: znaczenie płatnych korzyści, GE i boostów oraz późnego spowolnienia. Nie zatwierdza konkretnych liczb i produktów.

## Odłożony bilans — nie wznawiać

Dalsze strojenie progresji F2P/Pro/5 petów/GE, ceny inkubatorów i limit inkubacji **odłożone na polecenie użytkownika**. Wznowić wyłącznie na nowe polecenie. Dokumenty 17–21, dane i skrypty analiz pozostały bez zmian podczas porządkowania.

[21](21_payer_progression_and_incubation.md) zachowuje ostatnie 61 przebiegów analitycznych; rekomendacje v3 nie są zatwierdzoną konfiguracją. V nierozstrzygnięte. Nikt w naturalnych próbach nie odwiedził V; nie prognozować na tej podstawie czasu prawdziwego gracza. Kontrola kroku 5 vs 0.3 s w nowszym modelu różni SE około 19–24%; starszy wynik 0.54% z 19 dotyczy innego, uproszczonego modelu. Bez nowych symulacji i zmian parametrów.

## Nie zmieniać przypadkiem

D01: premium +10 p.p. (nie ×1.10) zamiast dopłat za próbę zatwierdzone. Skutek porażki zatwierdzony: zachowany pet bazowy, zużyte pozostałe kopie, trwały licznik do gwarantowanej próby. Definicja stopnia (tier × cel) i ochrona wyboru kopii zatwierdzone; próg/liczby i oferta produktu odłożone. Kierunek trudności pozostaje w odłożonym bilansie; Rainbow jako końcowy wariant v1 zatwierdzono w 26. Nie zmieniać plików bilansu.

**R — po przeglądzie 24:** opłacone zamówienie sprzed północy nie zużywa darmowego prawa nowego dnia; oferta przy nierozstrzygniętej płatności jest zarezerwowana bez kupna/odbioru/odrzucenia; istniejącą ofertę można odebrać na Enlightenment, otrzymany boost tylko do ekwipunku. Szczegóły w [22](22_gameplay_rules_for_approval.md) i [24](24_doubler_and_bonus_gift_acceptance_review.md).
Task [Opus — kalendarz/trofea/PE](OPUS_NEXT_TASK.md) pominięty na polecenie użytkownika. Nie proponować kolejnych przeglądów zamkniętych ustaleń. Rzeczywiste otwarte decyzje: [ADAPTATION_OPEN_DECISIONS](ADAPTATION_OPEN_DECISIONS.md); brak nowego aktywnego taska dla Opusa.

**Najnowsza decyzja R — [25](25_approved_product_structure.md):** mocne Pro (silosy/pełna jakość offline/sloty boostów + rozszerzenie miejsc petów i +10 p.p.); osobne Buy MAX i Auto-Hatch kurczaków; powtarzalne GE i Piggy. Nie dodawać Buy MAX do Pro ani nie mylić Auto-Hatch z otwieraniem petów. Ceny, liczby miejsc i inkubacja pozostają odłożone. Zakres premiery i wariant A dostępności +10 p.p. zatwierdzono w 26. Bez implementacji i zmian bilansu.

**Najnowsza decyzja R — [26](26_approved_launch_scope_and_pro_availability.md):** Rainbow kończy v1; Pro/Buy MAX/GE na premierę, Piggy warunkowo po przygotowaniu bilansu; Auto-Hatch/VIP później. Wariant A Pro: dla nieuprawnionego konta +10 p.p. niedostępne, reszta działa, jasny opis przed zakupem i bez automatycznego zamiennika. Trzy grupy decyzji adaptacji zamknięte. Nie wznawiać odłożonego bilansu ani nie tworzyć kolejnego przeglądu zamkniętych ustaleń

**Plan procesu 23.10.2026 (P):** [workflow/README](workflow/README.md) to dostosowanie workflow z GrowASnack i materiałów ECC. [Etapy](workflow/IMPLEMENTATION_STAGES.md) zastępują wcześniejszy szkic etapów ECC. [SKILLS_PLAN](workflow/SKILLS_PLAN.md) prowadzi do siedmiu lokalnych skills utworzonych następnie na polecenie użytkownika; ich definicje zweryfikowano, załadowanie przez klienta niepotwierdzone. Nie dziedziczyć modeli, uprawnień Git/Studio, identyfikatorów DEV, bibliotek i runtime agentów źródłowego projektu. Autor wykonuje właściwe testy, niezależne review dobierane do ryzyka; brak automatycznej delegacji. Zmiany teraz wyłącznie dokumentacyjne, bez wznowienia bilansu.

**Skills projektu utworzone:** `.agents/skills/hte-*` (siedem SKILL.md); dobór i linki w [katalogu](workflow/SKILLS_PLAN.md). Procedury wspierają workflow, nie zastępują domeny i nie uprawniają do rozpoczęcia implementacji lub wznowienia bilansu. Bez globalnej instalacji, hooków, delegacji i narzędzi gry.

**Porządkowanie projektu:** prywatne analizy, backupy i narzędzia przeniesiono poza projekt z manifestem integralności. Workflow i skills korzystają z docs; brak danych referencyjnych należy wskazać jawnie. Nie przywracać archiwum do projektu przez rutynowe kopiowanie. Historia Git nie była przepisywana. Bilans pozostaje odłożony.

## Dane referencyjne w projekcie

**Przywrócenie danych:** tabela struggleModifier i wzór czasu silosów są ponownie w 06; [reference_data](reference_data/README.md) zawiera pełne dostępne tabele do przyszłej implementacji. Wartości porównano z zachowanymi danymi, bez nowych symulacji i zmian 17–21. Historyczne raporty sprzed naprawy nie opisują aktualnej zawartości.

**Przygotowanie techniczne P:** [kontrakt 27](27_numbers_time_and_player_state_contract.md) opisuje liczby, jednostki, codec, czas offline i eventów, model stanu oraz resety/transakcje. To część etapu 0, nie ukończenie całego przygotowania technicznego. Adapter liczb, zakresy funkcji, biblioteka zapisu, retencja ID i harness wymagają przyszłej realizacji. Cline/DeepSeek v4.1 Flash wykonał pomocnicze review krótkiej koncepcji bez narzędzi i zmian plików; nie jest to test implementacji lub pełny audyt kontraktu.

**Redakcja kontraktu 27 po Gemini:** jawnie rozdzielono remainingDuration online (pełny odcinek, bez limitu silosów) i away (czas produkcji ograniczony silosami) oraz poprawiono formę językową w powiązaniach materiału łączenia. Review dotyczyło pełnego tekstu i przekazanych reguł, nie całego repo ani kodu. Bez nowej decyzji R, zmian bilansu i implementacji.

**Moduły i sieć P:** [kontrakt 28](28_modules_and_client_server_contract.md) uzupełnia 27. Koordynator jest jedynym autorem zmian gracza; domena i symulacja nie zapisują samodzielnie. Protokół rozdziela operationId/requestId, commitRevision/viewSeq, wynik operacji i strumień widoku. Obejmuje podglądy, płatności, wylęg, replay i resync, bez implementacji lub wyboru frameworka. Scenariusze są opisane, nie wykonane.

**Korekty 28 po lokalnym przeglądzie (P):** quoteId obowiązuje również przy badaniach i infrastrukturze, Buy MAX potwierdza konkretny zakres/koszt. Nieprzyjęta komenda otrzymuje admission=NOT_ACCEPTED; PENDING oznacza śledzone wykonanie, a utrata kolejki wymaga odtworzenia lub rozstrzygnięcia braku efektu. Prezent Robux: PreparePurchase → trwałe zamówienie/rezerwacja → płatność → zaufane potwierdzenie i jedna wypłata. ClaimOffer obsługuje tylko free/GE. Bez implementacji, nowych cen lub zmian 27; wcześniejszy manifest utworzenia 28 pozostaje snapshotem historycznym.

**Pierwszy fragment P — [29](29_first_farm_implementation_plan.md):** plan F01–F09 obejmuje jedno jajo, ręczny wylęg/RCB/IHR, sprzedaż/transport, pojedyncze zakupy Common/kurników/zwykłych pojazdów, sesję/zapis, projekcję i minimalne UI. Powrót w neutralnym stanie nie pomija reguł away/silosów. Aktywne efekty poza obsługiwanym zakresem nie mogą zostać po cichu usunięte. Dokumentacyjny F01 przygotowano w 30; zadania implementacyjne i A01–A16 niewykonane. Bez implementacji, instalacji, aktywacji danych referencyjnych lub bilansu.

**Aktualizacja F01 — [30](30_first_farm_manifest_and_technical_choices.md):** dokumentacyjny manifest gotowy jako P, z siedmioma Common i jawnym TEST_ONLY startem; nie stanowi pełnej gotowości wykonawczej. U01–U04 to brakujące doprecyzowania bramek, bazowego wylęgu/RCB oraz nowego konta; U05–U06 dotyczą adapterów, retencji i warsztatu. Bez zgadywania lub ponownego audytu całej domeny. Cline/DeepSeek analizował przekazany skrót bez narzędzi, autor lokalnie sprawdził dane. Implementacja F02–F09 oraz A01–A16 nie ruszyły. Nowe propozycje techniczne i TEST_ONLY nie są R ani bilansem wydania.

QA tekstu 30 przez AGY/Gemini: warunkowe PASS; autor uwzględnił cztery doprecyzowania, bez ponownego modelowego QA końcowej redakcji. [Zakres i ograniczenia](workflow/first_farm_f01_review.md). Nie traktować jako pełnego audytu plików lub zaliczenia testów gry.

**Aktualizacja 24.10.2026 — [31](31_research_hatching_rcb_and_new_account.md):** rozstrzygnięto referencyjne U01/U02, matematyczny i stanowy rdzeń U03 oraz podstawowy start U04. Nie wracać do starszych stwierdzeń o braku tych danych. 3/s to refill, nie darmowy automat; 28 zawiera HatchPress obok hold. Trasa/czas dotarcia to osobne zadanie sceny, a U05/U06 pozostają techniczne. Nowa tabela startu nie zastępuje fixture w 30 i nie jest konfiguracją wydania. [32](32_parallel_delivery_backlog.md) porządkuje zadania i równoległe ścieżki; nie autoryzuje kodowania.

## PRE-01–03 — przygotowane 24.10.2026

[33 — warsztat i zegary](33_pre01_toolchain_and_clocks.md), [34 — sesja i retencja](34_pre02_sessions_and_retention.md), [35 — trasy i dotarcia](35_pre03_routes_and_arrivals.md). Dokumentacja P przygotowana; narzędzia, adaptery i scenariusze L/S/D nadal niewykonane. Wybrano Rojo/Lune i port Clock, skończoną retencję jednego agregatu oraz serwerowe trasy z fazą dotarć po produkcji, przed IHR. To wybory techniczne do realizacji, nie nowe R ani konfiguracja wydania. Następny etap po osobnym zleceniu: IMP-01, potem równolegle IMP-02/03/07 według 32. Bilans 17–21 pozostaje odłożony.

## IMP-01 — wykonano zakres lokalny

[36 — NumericCodec i warsztat](36_imp01_numeric_codec_delivery.md): kod NumericCodec v1, warsztat Lune/Rojo, niezależne wektory i wykonane testy L. To pierwsza implementacja infrastruktury numerycznej, bez logiki farmy. Uprawnienie użytkownika obejmuje wyłącznie IMP-01; nie rozpoczynać pozostałych IMP-* samym zamknięciem zależności. Nie wykonano Studio/DataStore ani typecheckera. Historyczne stwierdzenia o braku kodu dotyczą wcześniejszych etapów. Kolejne możliwe zadania po osobnym zleceniu: równolegle IMP-02/03/07. Bilans i dane referencyjne bez zmian.

## IMP-02, IMP-03 i IMP-07 — wykonano L

[37 — katalog, DTO i SessionRepository](37_imp02_imp03_imp07_delivery.md): prywatny CatalogRegistry wewnętrznej farmy, ProtocolSchemas v1 oraz SessionRepository z wersjonowaniem, fencing i odzyskiwaniem UNKNOWN. Wspólny runner: NumericCodec 15702, katalog 2732, protokół 745, zapis 151 asercji PASS L (łącznie 19330); statyczny build rozdziela moduły prywatne i wspólne. Nie wykonano Studio/RPC/prawdziwego DataStore/typecheckera. Nowe zlecenie użytkownika obejmuje te trzy zadania oraz publikację kodu/testów/docs, nie pozostałe IMP-*. Bilans i JSON-y referencyjne bez zmian. Gotowość L nie jest gotowością produkcji lub zatwierdzeniem konfiguracji.

## IMP-04/05/06 — wykonano L (24.10.2026)

[38 — produkcja, IHR i wylęg/RCB](38_imp04_imp05_imp06_delivery.md): ukończono trzy zlecone moduły i testy lokalne. Wspólny runner: **20 536 asercji PASS**, 490 niezależnych przypadków uint64, statyczny build 12 modułów bez skryptów startowych. AGY: PASS przeglądu dostarczonych źródeł każdego zakresu; nie jest to test silnika. ProfileSchema dopuszcza prawidłowy carry IHR >=1 i opcjonalny licznik grup. Nie wykonano Studio, rzeczywistych tras, RPC, DataStore ani typecheckera. Timeline, Gateway i integracja zapisu pozostają kolejnymi zadaniami. Bilans 17–21 i JSON-y referencyjne bez zmian. Wcześniejsze wyniki i ograniczenia uprawnień są historycznymi zapisami poprzednich dostaw; bieżące zlecenie obejmuje IMP-04/05/06 i publikację kodu/testów/docs, bez automatycznego rozpoczynania pozostałych zadań.

## IMP-08/09 — wykonano L (24.10.2026)

[39 — koordynator i neutralna symulacja](39_imp08_imp09_delivery.md): jeden autor komend/ticków/checkpointów, rozstrzyganie PENDING/UNKNOWN i odzyskiwanie sesji; neutralny Timeline z siatką do 0.3 s, fazowym checkpointem i pełnym zamknięciem away. Wspólny runner **20 885 asercji PASS L**, w tym 221 koordynatora, 58 Timeline i 70 integracji; statyczny build 14 modułów. Integracja używa rzeczywistych modułów z kontrolowanym storage i testowym adapterem pamięć–wire. Studio, prawdziwy DataStore, Gateway, produkcyjny bootstrap i typechecker niewykonane. Bieżące zlecenie obejmuje IMP-08/09 i publikację kodu/testów/docs; wcześniejsze ograniczenia zakresu są historyczne. Nie rozpoczęto kolejnych zadań. Bilans 17–21 i referencyjne JSON-y bez zmian.

## IMP-10–15 oraz QA-01 — wykonano i odebrano (24.10.2026)

[40 — ukończenie i odbiór pierwszej farmy](40_first_farm_completion_delivery.md): zaimplementowano moduły i sprawdzono ich lokalne warianty L; bez zaliczenia S/D/H dla pierwszej farmy (FarmActions, ViewProjector, NetworkGateway, ClientTransport, ClientStateStore, RoutePresentation, IntentControllers, HUD, Bootstrap serwera i klienta oraz formalny odbiór A01–A16 w tests/acceptance/run.luau). Zgłoszenia #19–#25 zamknięte na GitHubie.

## NEXT-01–10 oraz REL-01 — wykonano, zweryfikowano i odebrano (24.10.2026)

[41 — dostawa kandydata wydania (Release Candidate)](41_release_candidate_delivery.md): w pełni zaimplementowano, przetestowano na poziomie L i zweryfikowano przez QA cały zakres rozszerzeń domenowych oraz integracji kandydata wydania:
- `NEXT-01` (#26): Farm Value & Soul Eggs (`FarmMath/fv_se.luau`, 358 asercji).
- `NEXT-02` (#27): Zmiana jaja, prestiż i księgowanie sesji (`ProgressActions.luau`, 199 asercji).
- `NEXT-03` (#28): Pełne offline, boosty, Video Doubler i historia (`EffectsManager.luau`, 204 asercje).
- `NEXT-04` (#29): Pety: ekwipunek, wyposażenie i składanie efektów (`pets/equipment.luau`, 152 asercje).
- `NEXT-05` (#30): Łączenie petów, ochrona slotów/locków i trwała gwarancja (`pets/fusion.luau`, 103 asercje).
- `NEXT-06` (#31): Autorytatywne drony, walka, nagrody GE/Cash i pojedynczy claim (`rewards/drones.luau`, 72 asercje).
- `NEXT-07` (#32): Kanały dostaw 2+1, darmowe odrzucenie, dzienny bonus i rezerwacje (`rewards/offers.luau`, 64 asercje).
- `NEXT-08` (#33): Kalendarz 28 dni, trofea 19 jaj i konwersje nagród (`rewards/calendar.luau`, `rewards/trophies.luau`, 76 asercji).
- `NEXT-09` (#34): Adapter produktów Pro, Buy MAX, GE i warunkowego Piggy (`platform/products.luau`, 55 asercji).
- `NEXT-10` (#35): Onboarding, odzyskiwanie kroku samouczka i baseline konta (`onboarding/manager.luau`, `client/onboarding/TutorialController.luau`, 62 asercje).
- `REL-01` (#36): Nadrzędny runner kandydata wydania (`tests/release_candidate/run.luau`, 113 asercji) oraz audytor bramek wydania (`tools/verify_release.py`).

Wspólny runner: **23 875 asercji (100% PASS L)** w 28 zestawach testów.  
Rojo: Dokładnie **37 modułów Luau** oraz **2 skrypty wejściowe** (`Main.server.luau`, `Main.client.luau`).  
Zadania #2–#42 (`DOC`, `PRE`, `IMP`, `QA`, `NEXT`, `REL`, `VIS`) zamknięte w rejestrze GitHub; warstwa wizualna i HUD w `StarterGui` zsynchronizowane z Roblox Studio.
Utworzono na GitHubie 8 zadań pełnego wdrożenia produkcyjnego `PROD-01–08` (#43–#50) na podstawie dogłębnej analizy dokumentacji referencyjnej. Repozytorium ma status **lokalne testy L; wydanie niezatwierdzone**. Bilans 17–21 i referencyjne JSON-y bez zmian.


## Pełne nagrody kalendarza — #62 (25.10.2026)

[Dostawa #62](workflow/calendar_rewards_62.md) zastępuje wcześniejsze ograniczenie pięciu dni z #56. Wzór gotówki był już w 11 §3: procent aktualnego Home Farm Value; typ 14 z 13 zapisuje się jako trwały ExactUInt permanent.shellScripts, bez nowej wymiany lub sklepu. Wszystkie 28 pozycji są rozliczane przez serwer, z ochroną dnia UTC/replay i księgowaniem earned/prestiżu. Testy obejmują dziesięć kompletnych cykli z niezależnym oracle oraz awarie. Wyłącznie L i statyczny build, bez Studio/chmury. Bilans 17–21 i referencyjne JSON-y bez zmian; pozostałe #57–61 i niedostępność funkcji bez konfiguracji pozostają aktualne. Dawna informacja o zatrzymaniu na dniu 4 opisuje stan poprzedniego commitu.


## DataStore bez fallbacku produkcyjnego — #57 (25.10.2026)

[Dostawa #57](workflow/persistent_startup_57.md): runtime domyślnie wymaga PERSISTENT i portu read/update. Awaria otwarcia/sondy zatrzymuje start; brak skutecznego pozyskania sesji odrzuca wejście gracza. Pamięć jest jawnym trybem STUDIO_MEMORY z rzeczywistym IsStudio i atrybutem UseLocalMemoryStore=true, bez płatności/passów. INTERNAL_TEST_ONLY pozostaje poza runtime Roblox. Main ma od początku bezpieczny handler receipt; nowy zakup nie jest potwierdzany bez trwałego sukcesu. Potwierdzony retry synchronizuje również snapshot, a sukces po restarcie jest odtwarzany bez drugiego grantu. Weryfikacja lokalna rzeczywistego entrypointu z kontrolowanymi usługami, bez Studio/chmury. Pozostałe #58–61 nie są domknięte; bilans i reference_data bez zmian. Wcześniejsze listy #57–61 opisują stan poprzednich dostaw.


## Polityka konta i bonus Pro — #58 (25.10.2026)

[Dostawa #58](workflow/pro_policy_58.md): własność Pro pozostaje trwała, a +10 p.p. wymaga aktualnej zaufanej polityki. Brak/błąd odczytu wyłącza bonus, zachowując pozostałe korzyści. Zapisane pro_plus10_enabled jest wyłącznie historyczną kwalifikacją nadania; nie autoryzuje użycia. Podgląd i potwierdzenie zakupu uwzględniają dostępność. Testy L: 34 zestawy, 80 126 asercji, 20 wykrytych mutacji; bez Studio/chmury. Pozostałe #59–61; bilans i dane referencyjne bez zmian. Starsze listy otwartych ustaleń opisują poprzednie dostawy.


## Identyfikatory grup po resecie — #59 (25.10.2026)

[Dostawa #59](workflow/reset_group_ids_59.md): zmiana jaja i prestiż zachowują hatchGroupSequence, usuwając poprzednie grupy i rezerwacje. Regresje sprawdzają następne dokładne ID oraz brak wpływu starych dotarć na nową grupę, także powyżej 2^53 i po serializacji profilu. Bez zmian bilansu i danych referencyjnych. Starsze listy otwartych ustaleń opisują stan poprzednich dostaw; pozostałe #60–61.


## Zakres dowodów — #60 (25.10.2026)

[Raport #60](workflow/release_evidence_60.md) koryguje wcześniejsze deklaracje L/S/D i zatwierdzenia wydania. Lokalne harnessy dają wyłącznie L, także przy kontrolowanym DataStore i rzeczywistym Main. Dla A01–A16 brak zarejestrowanego dowodu per scenariusz S/D/H; pozostają NOT_VERIFIED. Zamknięcie Issues, synchronizacja sceny i liczby asercji nie dowodzą odbioru. Bieżące raporty mają releaseCandidateReady=false. Bez zmian bilansu i historycznych JSON-ów.


## Historyczny czas wydarzeń dochodu — #61 (25.10.2026)

[Dostawa #61](workflow/earnings_event_time_61.md): graniczny krok otrzymuje mnożnik dochodu ważony rzeczywistym czasem wydarzenia. Bez dodatkowego IHR, dotarć lub odliczania boostów; VD zachowuje predykat końca kroku. Regresje obejmują silosy, wznowienie fazy i rzeczywisty most Bootstrap. Lokalne L i statyczny build nie zaliczają S/D/H ani nie zatwierdzają wydania. Bilans i reference_data bez zmian. Wcześniejsze listy otwartych ustaleń opisują stan historycznych dostaw; #61 jest domknięte w tej dostawie.


## Poprawki #63–65 — 25.10.2026

[Dostawa #63–65](workflow/session_prestige_rcb_63_65.md): nowe intencje zakupów mają ID w przestrzeni generacji/strumienia sesji, stare retry zachowują wynik. Prestige stosuje zaufany event kolekcji na końcowe SE, ze sprawdzeniem granicy zapisu. Produkcja i HUD używają aktywnego RCB z runningCount oraz istniejących badań Common/Epic. Nie zmieniono FV (#67) ani bilansu. Testy lokalne nie zaliczają S/D/H; pozostałe #66–70 pozostają otwarte.


## Poprawki #66–70 — 25.10.2026

[Dostawa #66–70](workflow/farm_gaps_66_70.md): widoczne nagrody mają ID wystawione przez serwer; pusty/nieskonfigurowany kanał nie udaje dostępnej nagrody. Accounting Tricks wpływa na FV, hold działa według Epic z dzierżawą intencji, Sharing przekazuje rzeczywisty efekt i zachowuje kursor wyboru celu, a pociąg wymaga trwałej stacji. Nie dodano harmonogramu nagród, kupna stacji/wagonów ani konfiguracji odłożonego bilansu. To naprawa błędów integracji, nie zakończenie wszystkich funkcji premiery. Tylko L/statyczny build, bez zaliczenia S/D/H.

[Dostawa #71–74](workflow/entitlement_farm_fixes_71_74.md): posiadany pass jest nadawany po rozliczeniu starego okresu; UNKNOWN wymaga rozstrzygnięcia i odzyskania sesji. FV uwzględnia Common/Epic maksimum RCB, zakupy zniżki Epic, a runtime hold tylko potwierdzony reset. Tylko L i statyczny build; bilans bez zmian.
