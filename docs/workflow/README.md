# Workflow HatchTheEgg — adaptacja GrowASnack + ECC

23.10.2026. **Workflow pozostaje planem procesu (P); siedem lokalnych skills utworzono na wyraźne polecenie użytkownika.** Nie stanowi to uruchomienia implementacji ani zgody na delegację/operacje zewnętrzne. Zatwierdzone reguły produktu pozostają R w [CURRENT_SPEC](../CURRENT_SPEC.md), [22](../22_gameplay_rules_for_approval.md), [25](../25_approved_product_structure.md) i [26](../26_approved_launch_scope_and_pro_availability.md).

Połączono lokalny workflow `projekt źródłowy workflow` z istniejącymi materiałami [ECC](../ecc/README.md). Przenosimy użyteczne procedury, nie uprawnienia, infrastrukturę i mechaniki tamtej gry.

| Dokument | Przeznaczenie |
|---|---|
| [WORKFLOW](WORKFLOW.md) | Jedna ścieżka zadania, zasady zakresu, walidacji i odbioru |
| [IMPLEMENTATION_STAGES](IMPLEMENTATION_STAGES.md) | Etapy, rzeczywiste zależności i granica odłożonego bilansu |
| [SKILLS_PLAN](SKILLS_PLAN.md) | Katalog siedmiu utworzonych skills, linki do SKILL.md i dobór procedury |
| [TASK_TEMPLATES](TASK_TEMPLATES.md) | Krótki brief zadania oraz raport/handoff |
| [SOURCE_ADAPTATION](SOURCE_ADAPTATION.md) | Co zachowano, uproszczono i odrzucono ze źródeł |
| [source_snapshot.json](source_snapshot.json) | Lista źródeł i ich SHA256, zakres odczytu, granice weryfikacji |

**Utworzono dokumentację i definicje siedmiu skills w `.agents/skills`.** Nie utworzono `AGENTS.md`, hooków, konfiguracji modeli, modułów Luau, skryptów automatyzacji ani środowiska Studio. Nie potwierdzono załadowania skills przez klienta; sprawdzono ich pliki i powiązania. Projekt GrowASnack jest tylko źródłem odczytu i pozostaje niezmieniony. Nie instalowano modeli, bibliotek ani narzędzi.

Workflow porządkuje przyszłą pracę. Nie jest nową listą audytów HatchTheEgg, nie wznawia bilansu i nie wymaga przed każdą drobną zmianą zatwierdzenia przez kilka modeli. Główna lista aktualnych zadań pozostaje w [TODO](../TODO.md); plan etapów nie jest samodzielnym zleceniem ich realizacji.

## Przygotowane kontrakty

[27 — liczby, czas i stan gracza](../27_numbers_time_and_player_state_contract.md) dostarcza część etapu 0 jako P. Wybór narzędzi, adapterów i ich rzeczywista weryfikacja pozostają przyszłymi zadaniami. Sam dokument nie zleca implementacji.

W kontrakcie 27 po review tekstu przez Gemini doprecyzowano różnicę czasu rozliczenia online i away; limit silosów dotyczy produkcji away. Status P i zakres etapu 0 pozostają bez zmian. Aktualną kontrolę redakcji zawiera [contract_verification.json](contract_verification.json).

[28 — moduły i komunikacja](../28_modules_and_client_server_contract.md) opisuje dalszą część etapu 0: kierunki zależności, odpowiedzialność za stan i logiczny protokół. Bez wyboru bibliotek/transportu i bez realizacji. [Kontrola dokumentu](module_protocol_verification.json) jest statyczna, nie potwierdza działania sieci.

[29 — plan pierwszej farmy](../29_first_farm_implementation_plan.md) dostarcza konkretny podział fragmentu etapów 0–2: F01–F09, zależności oraz A01–A16. Implementacja i scenariusze pozostają niewykonane. Plan oddziela wewnętrzny fragment do weryfikacji od wydania i odłożonego bilansu; dokumentacyjny F01 przygotowano w 30.

Aktualny wynik dokumentacyjnego F01: [30 — manifest i wybory techniczne](../30_first_farm_manifest_and_technical_choices.md), status P z U01–U06, bez pełnej gotowości wykonawczej. Nie utworzono kodu, fixture wykonywalnych, konfiguracji wydania ani środowiska Studio.

[31](../31_research_hatching_rcb_and_new_account.md) uzupełnia reguły podstawowej farmy, a [32](../32_parallel_delivery_backlog.md) i [rejestr GitHub](github_task_registry.json) mapują ukończone materiały i przyszłe zadania do równoległych ścieżek. [Zakres QA](research_hatching_backlog_review.md). Bez implementacji lub wznawiania bilansu.

## PRE-01–03

Przygotowane projekty P: [33 — warsztat i zegary](../33_pre01_toolchain_and_clocks.md), [34 — sesja i retencja](../34_pre02_sessions_and_retention.md), [35 — trasy i dotarcia](../35_pre03_routes_and_arrivals.md). Wykonanie i dowody L/S/D należą do istniejących IMP-*; dokumentacyjne zamknięcie PRE-* nie jest ich zaliczeniem. [Przegląd przygotowania](preparation_01_03_review.md).

## Pierwszy wykonany zakres — IMP-01

[36 — warsztat i NumericCodec](../36_imp01_numeric_codec_delivery.md) zawiera API i odtwarzalne komendy; [raport L](numeric_codec_verification.json) podaje wersje, hashe oraz ograniczenia. Uruchomienie Lune i build Rojo nie są testem Studio/DataStore. Implementacja użytkownika ograniczona do IMP-01; kolejne taski pozostają planem.

## IMP-02/03/07

[37](../37_imp02_imp03_imp07_delivery.md) opisuje wykonane moduły i granice; [raport](parallel_implementation_verification.json) utrwala wyniki L i scope QA. Nowy runner wymaga Python 3.10+ (stdlib) dla zgodności katalogu i statycznego pliku Rojo. Dawne manifesty weryfikacji są snapshotami wcześniejszych wersji; nie przepisano ich sum.
