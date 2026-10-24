# Skills projektu HatchTheEgg

23.10.2026. **Utworzono siedem lokalnych skills na polecenie użytkownika.** Definicje znajdują się w `.agents/skills/`; zastępują opisane wcześniej kontrakty migracji. Szczegóły procedur są w SKILL.md, a reguły gry, plan etapów i dowody pozostają w docs.

## Katalog i routing

| Skill | Kiedy wybrać | Definicja |
|---|---|---|
| `hte-plan-task` | Planowanie etapu/funkcji i rzeczywistych zależności | [SKILL.md](../../.agents/skills/hte-plan-task/SKILL.md) |
| `hte-review-change` | Review konkretnej zmiany lub integracji | [SKILL.md](../../.agents/skills/hte-review-change/SKILL.md) |
| `hte-investigate-bug` | Diagnoza zgłoszonego błędu lub nieudanego testu | [SKILL.md](../../.agents/skills/hte-investigate-bug/SKILL.md) |
| `hte-check-economy-state` | Integralność sald, nagród, zapisu i transakcji | [SKILL.md](../../.agents/skills/hte-check-economy-state/SKILL.md) |
| `hte-validate-studio` | Zlecona kontrola w rzeczywistym Studio | [SKILL.md](../../.agents/skills/hte-validate-studio/SKILL.md) |
| `hte-design-visuals` | Brief, review sceny/UI i dobór assetów | [SKILL.md](../../.agents/skills/hte-design-visuals/SKILL.md) |
| `hte-verify-domain-math` | Kontrola konkretnej funkcji matematycznej | [SKILL.md](../../.agents/skills/hte-verify-domain-math/SKILL.md) |

Dobierz jedną procedurę główną do zleconego zadania. Przy nakładającym się ryzyku można doczytać potrzebny fragment drugiego skilla: review płatności może korzystać z kontroli transakcji, a diagnoza granicy offline z weryfikacji matematyki. Nie uruchamiaj wszystkich siedmiu i nie twórz z tego stałej sekwencji audytów. Stosowanie skilla nie tworzy automatycznie osobnego agenta.

Katalog nie przypisuje modeli, nie nadaje uprawnień do delegacji, implementacji, Studio lub zewnętrznych mutacji. Zlecenie utworzenia skills nie uruchamia ich procedur na kodzie gry. Gdy obecne zadanie dotyczy tylko planu/docs, zwracamy plan/docs, a nie implementację.

## Co pozostało w docs

- [WORKFLOW](WORKFLOW.md): wspólny start, zakres, poziomy dowodu i zakończenie zadania.
- [IMPLEMENTATION_STAGES](IMPLEMENTATION_STAGES.md): uporządkowane etapy i zależności; nie są zleceniem realizacji.
- [TASK_TEMPLATES](TASK_TEMPLATES.md): krótki brief i raport/handoff, bez duplikacji proceduralnej w każdym zadaniu.
- [CURRENT_SPEC](../CURRENT_SPEC.md), 22, 25, 26: reguły i decyzje domenowe, odczytywane tematycznie.
- [ECC](../ecc/README.md): rozszerzone materiały warunkowo czytane, bez instalowania ECC.
- [SOURCE_ADAPTATION](SOURCE_ADAPTATION.md): pochodzenie i uzasadnienia selekcji z GrowASnack/ECC; opis braku skills dotyczył historycznego etapu planowania.

Nie utworzono globalnych skills, aktywnego AGENTS.md, metadanych wymuszających modele, hooków, skryptów gry lub nowych zależności. Frontmatter ma precyzyjne opisy zastosowania; nie wyłączono domyślnego automatycznego doboru dodatkową polityką explicit-only.

## Zakres weryfikacji

Sprawdzono nazwy, wymagane pola frontmatter, lokalne odnośniki i zakres procedur. Frontmatter zawiera dwa proste jednowierszowe pola YAML, skontrolowane lokalnie bez instalacji zależności. Standardowy quick_validate.py z skill-creator nie uruchomił się z powodu braku PyYAML; nie deklarujemy zaliczenia tego walidatora. Testy gry, Studio i rzeczywiste scenariusze wykonywania procedur nie były uruchamiane. Dostępność w dynamicznym katalogu konkretnego klienta nie wynika z samego zapisania plików i nie została potwierdzona w tej sesji; nie raportować ich jako załadowanych przez aplikację bez takiego dowodu.

Raport techniczny: [skills_creation_verification.json](skills_creation_verification.json). Bilans 17–21 i materiały robocze pozostają niezmienione. Historyczne materiały i kopie bezpieczeństwa przechowywane są prywatnie poza projektem; procedury nie wymagają dostępu do tego archiwum.

## Uzupełnienie po porównaniu ze źródłem

Do istniejących skills dodano warunkowe kontrole flag dekoracji, przepływu danych, odzyskiwania postępu samouczka i izolacji developerskich operacji przyznających przywileje. Zakres i zastrzeżenia: [mapa adaptacji](SOURCE_ADAPTATION.md). Nie zmieniono ról siedmiu skills ani zasad produktu.

Raport utworzenia oraz audyt Opusa dotyczą wcześniejszej wersji. Hashe i kontrolę wersji z chwili uzupełnienia zawiera [raport uzupełnienia](skills_supplement_verification.json); nie oznacza on ponownego audytu przez Opusa ani wykonania procedur w Studio. Wszystkie siedem skills jest obecnie widoczne w katalogu skills tej sesji klienta; historyczne ograniczenie w raporcie utworzenia nie zostało nadpisane.

## Redakcja i archiwizacja materiałów prywatnych

Siedem skills korzysta z referencji w docs. Prywatne analizy, kopie i narzędzia nie należą do dystrybuowanego projektu i nie są zależnością workflow. Gdy wymaganych danych nie ma w docs, należy zgłosić brak zamiast zakładać dostęp do prywatnego archiwum. N/S opisują rodzaj referencji, nie wykonanie testów gry. Raporty sprzed redakcji są historyczne. Aktualny zapis kontroli plików z etapu porządkowania: [repository_cleanup_verification.json](repository_cleanup_verification.json).

## Uzupełnienie o spójność danych, kontraktów i indeksów — 24.10.2026

Po realizacji i uporządkowaniu `IMP-01–09` zaktualizowano wszystkie siedem `SKILL.md`, aby agenci pilnowali spójności danych, schematów i dokumentacji:
- **`hte-plan-task` i `hte-review-change`**: kontrola spójności nagłówków dat/statusów w głównych indeksach (`docs/README.md`, `CURRENT_SPEC.md`, `TODO.md`, `WORKING_CONTEXT.md`, `workflow/README.md`), zgodności liczników otwartych/zamkniętych zadań w `docs/32_parallel_delivery_backlog.md` z `github_task_registry.json` oraz czystości katalogu `build/` (brak jednorazowych skryptów pomocniczych).
- **`hte-check-economy-state`**: kontrola spójności kontraktów danych między `NumericCodec`, `ProfileSchema`, `ProtocolSchemas`, `SessionRepository`, `PlayerCoordinator` i `TimelineSimulation` (`BigAmount`/`Real64` vs kanoniczny `ExactUInt` bez `tonumber`, `durable` vs `working`, portfel `farm.cash` vs akumulator `accounting.currentFarmCash`, `commitRevision` vs `viewSeq`, monotoniczny `hatchGroupSequence`, carry `fractionalIHR >= 0`).
- **`hte-verify-domain-math` i `hte-investigate-bug`**: obowiązek weryfikacji spójności generatorów i wyroczni (`tools/generate_catalog.py --check`, `tests/catalog/build_oracle.py --check`, `tools/generate_population_vectors.py --check`) oraz kontraktów schematów przy wykonywaniu `./tools/test.ps1 -PythonExecutable python`.
- **`hte-validate-studio` i `hte-design-visuals`**: kontrola granicy modułów `ReplicatedStorage/HatchTheEgg/Shared` vs `ServerScriptService/HatchTheEgg` (`tools/verify_build.py`) oraz oddzielenia wizualnej liczby modeli/animacji/`Touched`/skrótów `K`/`M`/`B` od autorytatywnego stanu `RouteProvider` i `TimelineSimulation`.
