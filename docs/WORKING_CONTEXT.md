# Bieżący kontekst — 23.10.2026

Cel: farma HatchTheEgg z petami w Roblox, zgodna z opisaną specyfikacją. **Wyłącznie dokumentacja i analiza, bez implementacji.**

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
