# Analiza workflow źródłowego i decyzje adaptacji

23.10.2026. **P — wnioski i dopasowanie procesu do HatchTheEgg**, nie zmiana zasad produktu ani aktywacja procedur w środowisku. Źródła: `projekt źródłowy workflow` oraz istniejące `docs/ecc`. Dokładne pliki/hash i zakres odczytu: [source_snapshot.json](source_snapshot.json).

## Co zastano

GrowASnack ma rozbudowany workflow w `.agent/WORKFLOW.md`, aktywne nadpisania w `.agent/MODEL_ROUTING.md` i `CURRENT_PROJECT_AUTHORITY.md`, poziomy dowodu w `.agent/VALIDATION.md`, protokół niezależnej QA w `.agent/NATIVE_QA.md` oraz osiem skill entrypointów w `.agents/skills/`. Nie jest to jeden neutralny szablon: zawiera wcześniejsze reguły i ich historyczne zastąpienia, istniejące środowiska, preferencje właściciela, narzędzia i mechaniki innej gry.

HatchTheEgg ma już zatwierdzone reguły adaptacji, gotowy podział produktów i zakres premiery. Nie ma natomiast wdrożonego kanonicznego drzewa konfiguracji, środowiska DEV tej gry, przypiętej biblioteki zapisu ani wskazanego runtime'u wieloagentowego. Bilans pozostaje odłożony. Dlatego kopiowanie całych instrukcji operacyjnych nadawałoby nieistniejące uprawnienia i tworzyło fikcyjne zależności.

## Mapa zachować / dostosować / odrzucić

| Element źródłowy | Decyzja | Uzasadnienie i miejsce docelowe |
|---|---|---|
| AGENTS i Current Project Authority: krótki start + hierarchia aktualnej prawdy | Zachować zasadę, dostosować ścieżki | Używać WORKING_CONTEXT/CURRENT_SPEC i źródeł systemu. Bez tworzenia kolejnego równoległego „kanonu” lub zmiany R/P. [WORKFLOW](WORKFLOW.md). |
| Planner: małe zadania, rzeczywiste zależności, podział implementacji i akceptacji | Zachować | Konkretne wejście, zakres, rezultat i dowód. Wspólny milestone/reviewer nie jest automatycznie zależnością. [Etapy](IMPLEMENTATION_STAGES.md), skill hte-plan-task. |
| Bug Investigator i Canonical Auditor | Rozdzielić diagnozę od rutynowej nawigacji | Minimalny repro i źródło mają wartość; zakaz czytania archiwów lub obowiązkowy STOP na każdy detal nie jest potrzebny. Nawigacja we wspólnym workflow, diagnoza jako wyspecjalizowany skill. |
| Code Reviewer + QA Sentinel | Połączyć wspólne reguły, ograniczyć trigger | Review konkretnej zmiany i prawdziwych dowodów. Bez nowego audytu całego repo przy każdej funkcji, arbitralnych test counts lub SHIP z pojedynczego pakietu. |
| Autorzy nie wykonują testów; tylko świeży Gemini testuje wszystko | Odrzucić dla HTE | Autor powinien uruchamiać właściwe testy. Niezależne review jest dodatkowym sprawdzeniem ważnych zmian, nie substytutem testów autora. Nie wymaga konkretnego dostawcy. |
| Cline/DeepSeek autor, GPT/Astra planner, Gemini QA, limit 10 autorów, reguły kwot | Nie przenosić | To ustawienia i zgody innego projektu. Nie znamy realnych limitów kont i nie zgadujemy kosztów. Współpraca tylko po autoryzacji i rzeczywistej potrzebie. |
| Automatyczny push do develop, zamykanie issues, stałe zgody Studio | Nie przenosić | Odczyt source workflow nie daje takich zezwoleń w HatchTheEgg. Nie wykonano zdalnych mutacji ani testów Studio. |
| Runtime V2: task JSON, worktree, frozen diff, SHA/receipts | Zachować identyfikację wersji; automat odłożyć | Nie kopiujemy ani nie uruchamiamy task_runtime/native_qa. Dla małej pracy wystarczy brief i fingerprint. Zapis SHA to kontrola zmiany, nie kryptograficzny dowód niezależności modelu. |
| Jeden wykonawca Studio, własna instancja, cleanup, brak domyślnej produkcji | Zachować zasadę | Zidentyfikować instancję i tryb danych. Nie przenosić identyfikatorów universe/place i fixture. Skill hte-validate-studio. |
| Fazy review gates z bezwzględnym blokowaniem całej następnej fazy | Zastąpić zależnościami konkretnych rezultatów | Istotne ryzyko blokuje zależny zakres i wydanie, nie wszystkie niezależne zadania. Odróżniać bieżący routing od historycznej listy obowiązkowego Opusa. |
| Stałe 3/12 przyjętych pakietów między regresjami | Zastąpić oceną zmiany | Pełna integracja przy etapie/nowym ryzyku; nie powtarzać kontroli bez zmiany badanych plików i nie odkładać krytycznych testów zapisu na później. |
| v1_canonical JSON → generator → Luau | Inspiracja na późniejszy projekt konfiguracji | Nie tworzymy istniejącego tylko z nazwy generatora, folderu lub approval BCR. Dane konfiguracji referencyjnej są materiałem źródłowym; konfiguracja wydania z niezatwierdzonymi liczbami nie może powstać przypadkiem. |
| ProfileStore z przypiętym commitem, istniejący save schema | Nie przenosić decyzji | HTE ma D07, a nie zatwierdzoną bibliotekę. Wybór realizacji przy właściwym zadaniu technicznym, bez ponownego projektowania zasad gry. |
| QA Sentinel: FIFO <=100 przetworzonych zakupów, „118/118”, schema V2 | Odrzucić wartości i założenia | To dane innego projektu. Usunięcie trwałych identyfikatorów bez modelu powtórek może naruszyć D07; historia tamtych testów nie jest dowodem dla HTE. |
| Integrity Guard: reset wizualizacji, softlock tutoriala, sortowanie list | Zachować problem, nie cudzy kod | Klient ma posprzątać właściwe obiekty po resecie i odtworzyć widok. Nie narzucać nazw ResetAll/PrestigeLevel, układu przenośników ani Crop DAG. |
| Visual Designer: spec/review/asset reuse/flow migration | Zachować procedury selektywnie | HTE ma kury, kurniki, flotę i pety, nie dwie linie przekąsek. Czytelność, prawa do assetów i zakres zmian ważniejsze niż kopiowany styl. |
| 35 stopni, 60 części, 18–20 studs, wymóg czarnego UIStroke, 5 minut FTUE | Nie przenosić jako norm HTE | Lokalna reguła ergonomii i historyczny incydent nie są uniwersalnym standardem Roblox. Parametry ocenić przy realnej scenie/UI, bez nowego bilansu teraz. |
| ECC: ports/adapters, Result, ADR, referencje i handoff | Zachować jako wsparcie P | Przydatne odseparowanie czystej logiki od API; nie zamieniać szablonów w zatwierdzoną architekturę lub pretekst do wielkiej abstrakcji. |
| ECC: pełny vertical slice i małe story | Dostosować kolejność | Zapis/transakcje wcześniej, historyczny czas eventów razem z offline, pety i sklep wydania dopiero z zatwierdzonymi parametrami. |
| ECC: minimum 20 terminów, 3 ADR, pliki 200–400 linii | Nie narzucać bramek ilościowych | Potrzebne kontrakty i kryteria wystarczą. Długość lub liczba plików nie dowodzi poprawności. |

## Konkretne korekty planu ECC bez przerabiania jego całej zawartości

Poprzedni [implementation_workflow_draft](../ecc/implementation_workflow_draft.md) zachowuje historię etapów; jego bieżącym zastępstwem dla planowania jest [IMPLEMENTATION_STAGES](IMPLEMENTATION_STAGES.md). Nie kopiujemy z niego sprawdzania dochodu wynikiem FV, wydaniowych placeholderów petów ani późnego dołączania historycznych eventów. Schematy techniczne ECC nadal są P, a ich realizacja wymaga prawdziwych testów nowego kodu.

Nie ponawiano audytu ECC na GitHub ani mechanik HatchTheEgg Nie weryfikowano na nowo aktualnych limitów Roblox, modeli lub assetów: to nie wybór technologii ani instalacja. Opisaliśmy proces, który przy konkretnej późniejszej pracy kieruje do właściwego oficjalnego źródła zamiast utrwalać niezweryfikowane liczby.

## Zakres i granice wykonanej analizy

- Przeczytano wskazane workflow, bieżącą authority/routing, definicje ośmiu skills i istotne sekcje środowiska/testów źródła. Nie deklarujemy przeglądu całego GrowASnack ani działania jego runtime'u.
- Polecenie Git odczytujące commit źródła nie uzyskało dostępu; **nie przypisujemy nieznanego SHA**. Manifest zawiera hashe konkretnych odczytanych plików. Nie podejmowano eskalacji ani mutacji źródła.
- Zachowano lokalny backup docs sprzed adaptacji. Oryginalne docs 17–21 i materiały robocze oraz kod biblioteki nie były zmieniane. Katalog `projekt źródłowy workflow` nie otrzymał żadnych zapisów.
- Nie uruchomiono skryptów źródłowych, testów gry, Studio, delegacji, konfiguracji ani instalacji skills. Kontrole wykonanej pracy dotyczą tylko kompletności dokumentów, ich linków, zgodności statusów i hashy chronionych źródeł.

## Uzupełnienie siedmiu skills — 23.10.2026

Po porównaniu źródłowych skills uzupełniono istniejące procedury o cztery punkty:

| Punkt | Miejsce | Granica zastosowania |
|---|---|---|
| Flagi dekoracji CanCollide/CanTouch/CanQuery | hte-design-visuals | Wyłączane dla czysto wizualnych części bez interakcji, zaznaczania i wykrywania; nie zbiorczo dla kur i jaj. Nie stanowią same w sobie dowodu wydajności. |
| Martwe/nadpisane zapisy i pochodzenie wartości | hte-review-change | Tylko dotknięty przepływ danych; źródło, jednostki, baza i mnożniki, bez wymuszania komentarzy. |
| Odzyskiwanie postępu samouczka | hte-plan-task | Uzupełnienie zasobu i cofnięcie kroku to możliwe wzorce, nie zatwierdzone mechaniki ani zgoda na darmowe zasoby lub ustalanie bilansu. |
| Izolacja developerskich operacji przyznających przywileje | hte-review-change, hte-validate-studio | Przy wydaniu lub zmianie narzędzi developerskich: brak testowych remotes/handlerów w produkcyjnej konfiguracji; ukryte UI nie wystarcza. Bez zakazu zwykłej diagnostyki i bez publikacji w celu sprawdzenia. |

Nie powstały nowe skills, narzędzia ani kod gry. Reguły produktu i odłożony bilans nie uległy zmianie. Raporty utworzenia i audytu Opusa pozostają dowodami ocenionych wówczas wersji; po zmianie treści nie potwierdzają automatycznie nowych SHA. Aktualna kontrola: [skills_supplement_verification.json](skills_supplement_verification.json).
