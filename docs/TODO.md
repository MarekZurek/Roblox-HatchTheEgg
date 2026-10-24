# TODO — stan 23.10.2026

## Odłożone na polecenie użytkownika

- [ ] **Dalsza kalibracja płatnej progresji i ekonomii petów.** Wznowić wyłącznie na kolejne polecenie użytkownika. Zakres: porównania F2P / Pro / 5 slotów / zakupy GE, ostateczne ceny inkubatorów (szczególnie Universe V), limit i tempo odnawiania inkubacji oraz tempo zdobywania i ulepszania petów.
- [ ] W ramach tego odłożonego zadania poprawić strategie symulacji (boosty, prestiż, rezerwa GE na Hyperloop), uwzględnić wybrany zakres trofeów i wydarzeń oraz sprawdzić dokładność modelu przed zamrożeniem bilansu.

Ostatni wynik: [21. Progresja płacącego gracza](21_payer_progression_and_incubation.md), 61 przebiegów analitycznych. Ceny I–IV i saldo F2P 120 / Pro 720 przy odnowieniu 60 s pozostają **niezatwierdzonymi propozycjami**; cena V jest nierozstrzygnięta. Odłożenie zadania nie zatwierdza tych liczb. Bez automatycznego wznowienia.

## Pozostałe decyzje przed implementacją

Propozycje rozstrzygnięć: [22, D01–D07](22_gameplay_rules_for_approval.md). D02–D07 zatwierdzone; D01: premium +10 p.p. zamiast dopłat zatwierdzone, skutek porażki zatwierdzony; definicja stopnia i ochrona kopii zatwierdzone. D04 zatwierdzone. Parametry bilansu nadal odłożone.

- [x] **D01 — zatwierdzony bonus premium:** premium pass +10 punktów procentowych (max 100%) zamiast dopłat do każdej próby zatwierdzone.
- [x] **D01 — skutek porażki:** zatwierdzono zachowanie peta bazowego, zużycie pozostałych kopii i trwały licznik gwarancji.
- [x] **D01 — definicja stopnia:** zatwierdzono tier pochodzenia × docelowy wariant ewolucji; gatunek/rarity bez dodatkowej zmiany szansy. Procenty bazowe/próg/ceny/receptury nadal odłożone.
- [x] **D01 — ochrona wyboru kopii:** zatwierdzono wcześniejsze zdjęcie/odblokowanie i brak automatycznej podmiany materiałów przy zmianie bazowego. Historia korekt scenariuszy: [23](23_pet_fusion_acceptance_review.md).
- [x] D02: dopuszczalne 100% elity i jawne nasycenie Hawka zatwierdzone, bez zmiany sił.
- [x] D03: Enlightenment bez efektów petów i Clarity w v1; zachowanie/pauza boostów zatwierdzone.
- [x] D04: zatwierdzono pierwsze użycie dnia UTC darmowe, kolejne GE/opcjonalnie Robux, z ujawnioną zawartością płatnego prezentu. Ceny odłożone.
- [x] D06: zakres premiery zatwierdzony według 22; PE z kalendarza i trofeów, bez ekspedycji/Ultra.
- [x] D05: limit paczek 2+1, stały wynik i trwałość oferty zatwierdzone.
- [x] D07: wymagania serwerowego czasu, sesji i jednokrotnego rozliczania zatwierdzone; realizacja pozostaje przyszłą implementacją.
- [x] Ujednolicić dokumentację (23.10.2026): [CURRENT_SPEC](CURRENT_SPEC.md) oddziela dowody, zatwierdzone zmiany i propozycje; poprawiono sprzeczności 01–09 i oznaczono historyczne etapy audytów. [Zakres porządkowania](DOCUMENTATION_CLEANUP.md).

## Doprecyzowania po przeglądzie scenariuszy

- [x] D04/D05/D07: zatwierdzono płatny charakter opłaconego zamówienia sprzed północy bez zużycia nowego darmowego prawa oraz rezerwację oferty przy nierozstrzygniętej płatności — [24](24_doubler_and_bonus_gift_acceptance_review.md).
- [x] D03/D04: zatwierdzono odbiór istniejącej oferty na Enlightenment; boost trafia do ekwipunku bez automatycznej aktywacji — R w 24.
- [ ] **W ramach odłożonego bilansu, nie aktywne zadanie:** podaż płatnych aktywacji VD i propozycja braku dodatkowego limitu dziennego; bez rozstrzygania teraz.

## Pozostałe decyzje adaptacji poza bilansem

Zakres: [ADAPTATION_OPEN_DECISIONS](ADAPTATION_OPEN_DECISIONS.md).

- [x] Podział produktów zatwierdzony: mocne Pro z dodatkowymi miejscami petów i +10 p.p.; osobne Buy MAX i Auto-Hatch kurczaków; powtarzalne GE i Piggy. [25](25_approved_product_structure.md). Ceny/liczby/tempo odłożone.
- [x] Zakres premiery zatwierdzony: Rainbow kończy v1, Pro/Buy MAX/GE od premiery, Piggy warunkowo po bilansie, Auto-Hatch i VIP później — [26](26_approved_launch_scope_and_pro_availability.md).
- [x] Zatwierdzono wariant A Pro: brak niedostępnego +10 p.p., reszta korzyści działa; jasny opis przed zakupem, bez zamiennika w v1 — [26](26_approved_launch_scope_and_pro_availability.md).
- **Pominięte:** task Opusa dotyczący ponownego przeglądu kalendarza/trofeów/PE. Nie wznawiać.

## Organizacja pracy

- [x] Przeanalizować workflow GrowASnack i dostosować do HatchTheEgg/ECC: [workflow](workflow/README.md), [etapy](workflow/IMPLEMENTATION_STAGES.md), [mapa skills](workflow/SKILLS_PLAN.md). Rezultat P; bez aktywacji.
- [x] Utworzyć siedem skills projektu w `.agents/skills` i połączyć z [workflow](workflow/SKILLS_PLAN.md). Zweryfikowano definicje i linki; bez instalacji hooków/runtime, uruchomienia Studio i implementacji gry. Załadowanie przez klienta niepotwierdzone.

## Po osobnym rozpoczęciu implementacji

- [ ] Zaprojektować autorytatywne rozliczanie ekonomii i zapis gracza po stronie serwera Roblox, w tym jednokrotny odbiór nagród.
- [ ] Sprawdzić całość w działającej grze: granice wydarzeń i offline, zmianę wyposażenia, składanie efektów, zmianę jaja i prestiż oraz odbiór nagród. Testy analityczne nie zastępują tej weryfikacji.


## Przygotowanie techniczne bez implementacji

- [x] Przygotować propozycję kontraktu liczb, czasu i modelu stanu: [27](27_numbers_time_and_player_state_contract.md). Oznaczenie dotyczy sporządzenia dokumentu P, nie akceptacji techniki, implementacji lub zaliczenia testów.
- [ ] W odpowiednim późniejszym zadaniu dobrać i zweryfikować adaptery liczb/czasu/zapisu, zakresy i konwersje, pola startowe resetu, retencję ID oraz harness. Nie jest to zlecenie realizacji ani wznowienia bilansu.

- [x] Przygotować propozycję podziału modułów i kontraktu komunikacji na podstawie 27: [28](28_modules_and_client_server_contract.md). Zamknięto sporządzenie dokumentu P, nie realizację, zatwierdzenie platformowego adaptera lub testy.
- [x] Doprecyzować 28 po lokalnym przeglądzie: obowiązkowy podgląd zakupów, rozdzielenie NOT_ACCEPTED/PENDING i odzyskiwanie po utracie kolejki oraz jedna ścieżka PreparePurchase dla prezentu Robux. Uzupełniono scenariusze; nie uruchomiono testów implementacji i nie nadano propozycjom statusu R.
- [ ] Przy osobnym zleceniu realizacji dobrać transport, schematy wiadomości i projekcji, budżety kolejek/rozmiarów oraz testy integracji protokołu 28. To przyszła zależność techniczna, nie aktywacja bilansu lub funkcji spoza v1.

- [x] Sporządzić [29 — plan pierwszej farmy](29_first_farm_implementation_plan.md): zakres, zadania F01–F09, zależności oraz A01–A16. Zamknięto przygotowanie planu P, nie realizację zadań ani testy.
- [x] Przygotować dokumentacyjną część F01: [30 — manifest i wybory techniczne](30_first_farm_manifest_and_technical_choices.md). Opisano ID, źródła startu/fixture, wejście i RCB, projekcję oraz kierunki adapterów, bez kodu lub konfiguracji wydania.
- [ ] Wykonać i sprawdzić pozostałe techniczne zależności F01: scenę/dotarcie oraz adaptery U05–U06. Projekty dokumentacyjne PRE-01–03 przygotowano w 33–35. Referencyjne U01/U02 i rdzeń U03/U04 rozstrzygnięto w 31. Nie oznaczać adapterów jako wykonanych, nie zmieniać bilansu; realizacja wymaga osobnego zlecenia.

## Aktualizacja 24.10.2026 — pierwsza farma i backlog

- [x] Rozstrzygnąć referencyjne progi Common, bazowy press/hold, aktywne RCB i podstawowy start konta — [31](31_research_hatching_rcb_and_new_account.md). Bez zmian bilansu i implementacji.
- [x] Przygotować kontrakt RouteProvider i autorytatywnego dotarcia — [35](35_pre03_routes_and_arrivals.md). Geometria i test sceny w IMP-13/15 nadal niewykonane.
- [x] Przygotować warsztat U06 i projekt zapisu/retencji U05: [33](33_pre01_toolchain_and_clocks.md), [34](34_pre02_sessions_and_retention.md). Wykonanie i testy pozostają w IMP-01/07; nie nadano gotowości wydania.

- [x] PRE-01/02/03: dokumentacja przygotowana równolegle i powiązana z backlogiem; odbiór statyczny opisuje [raport](workflow/preparation_01_03_review.md). L/S/D pozostają niewykonane.

## Wykonanie IMP-01

- [x] Przygotować przypięty warsztat Lune/Rojo oraz NumericCodec v1 i wykonać testy L — [36](36_imp01_numeric_codec_delivery.md).
- [ ] Pozostałe adaptery czasu, sesji i ich S/D pozostają przy istniejących IMP-*; lokalny codec ich nie zalicza. Nie wznawiać odłożonego bilansu.

## Wykonanie równoległe

- [x] IMP-02: wybrany katalog referencyjny i niezależne kontrole bitowe.
- [x] IMP-03: ścisłe schematy pierwszej farmy i adwersarialne testy L.
- [x] IMP-07: repozytorium/port natywny i kontrolowany fake L; rzeczywisty test D niewykonany.
- [ ] Studio/RPC, rzeczywiste konflikty DataStore oraz długotrwała retencja przed wydaniem pozostają przy odpowiednich integracjach, nie są zaliczone tymi checkboxami. [Wyniki](37_imp02_imp03_imp07_delivery.md).

## IMP-04/05/06 — wykonano L (24.10.2026)

[38 — produkcja, IHR i wylęg/RCB](38_imp04_imp05_imp06_delivery.md): ukończono trzy zlecone moduły i testy lokalne. Wspólny runner: **20 536 asercji PASS**, 490 niezależnych przypadków uint64, statyczny build 12 modułów bez skryptów startowych. AGY: PASS przeglądu dostarczonych źródeł każdego zakresu; nie jest to test silnika. ProfileSchema dopuszcza prawidłowy carry IHR >=1 i opcjonalny licznik grup. Nie wykonano Studio, rzeczywistych tras, RPC, DataStore ani typecheckera. Timeline, Gateway i integracja zapisu pozostają kolejnymi zadaniami. Bilans 17–21 i JSON-y referencyjne bez zmian. Wcześniejsze wyniki i ograniczenia uprawnień są historycznymi zapisami poprzednich dostaw; bieżące zlecenie obejmuje IMP-04/05/06 i publikację kodu/testów/docs, bez automatycznego rozpoczynania pozostałych zadań.
