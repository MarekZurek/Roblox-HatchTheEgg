# Wybór materiałów ECC dla HatchTheEgg

Data analizy: 2026-10-23. Źródło: [affaan-m/ECC@90606c8](https://github.com/affaan-m/ECC/tree/90606c8315ee09cafc303515c5f33024db6b9882). Licencja MIT.

## Legenda statusu

| Status | Znaczenie |
|---|---|
| **Użyć** | Zasady lub wzorce stosowalne bez zmian lub z minimalną zmianą nazewnictwa |
| **Zaadaptować** | Wymaga przerobienia na Roblox/Luau, ale rdzeń jest wartościowy |
| **Inspiracja** | Wzorzec cenny koncepcyjnie, ale implementacja wymaga własnego projektu |

## Legenda priorytetu

| Priorytet | Faza |
|---|---|
| **A — przed** | Przeczytać/zastosować przed rozpoczęciem implementacji |
| **B — podczas** | Stosować w trakcie implementacji |
| **C — później** | Przydatne po uruchomieniu MVP |

---

## Tabela wyboru

### Planowanie i architektura

| # | Materiał ECC | Link | Co zawiera | Zastosowanie w HTE | Status | Dostosowanie do Roblox/Luau | Zależności / ograniczenia | Priorytet |
|---|---|---|---|---|---|---|---|---|
| 1 | `agents/planner.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/agents/planner.md) | Proces planowania: analiza wymagań → przegląd architektury → podział na kroki → kolejność implementacji. Szablony planu z fazami, ryzykami, kryteriami sukcesu | Szablon planowania etapów HTE. Fazy: minimum viable → core → edge cases → optimization. Każda faza osobno wdrażalna | **Zaadaptować** | Zamienić ścieżki plików na strukturę Roblox (ServerScriptService/ReplicatedStorage). Dodać specyfikę klient/serwer. Usunąć odniesienia do npm/npm test | Wymaga własnego szablonu planu HTE | **A** |
| 2 | `skills/blueprint/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/blueprint/SKILL.md) | 5-fazowy pipeline: Research → Design → Draft → Review → Register. Plan jako cold-start dokument z kontekstem per krok, grafem zależności, wykrywaniem równoległości | Tworzenie planu implementacji HTE jako serii one-PR-sized kroków. Każdy krok ma self-contained brief (ważne przy zmianie asystenta). Adversarial review gate | **Zaadaptować** | Zamienić PR/branching na format zmian w Roblox Studio. Pominąć git/gh detection. Zachować: cold-start execution, dependency graph, plan mutation protocol | Czysto Markdown — brak runtime. Nie wymaga narzędzi | **A** |
| 3 | `skills/architecture-decision-records/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/architecture-decision-records/SKILL.md) | Szablony ADR w formacie Nygard: Context → Decision → Alternatives → Consequences. Workflow: detect decision → document → index | Rejestr decyzji projektowych HTE. Projekt ma już 26 dokumentów decyzji — ADR-y uzupełnią o decyzje techniczne (format zapisu, zakres liczb i precyzja, architektura modułów) | **Użyć** | Bez zmian — format .md jest uniwersalny. Dodać do `docs/adr/` | Nie zależy od narzędzi | **A** |
| 4 | `skills/hexagonal-architecture/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/hexagonal-architecture/SKILL.md) | Ports & Adapters: domain model bez frameworka, use cases jako orchestracja, inbound/outbound ports, composition root. Migration playbook: strangler approach, slice-by-slice | Architektura HTE: domena (ekonomia, pety, prestiż) oddzielona od Roblox API (DataStore, RemoteEvents, MarketplaceService). Czysta logika testowalna offline | **Zaadaptować** | Luau nie ma interfejsów/DI w sensie OOP. Zastosować wzorzec: ModuleScript z czystą logiką + adapter wrappujący Roblox API. Composition root w init skrypcie serwera | Luau ogranicza: brak generics, brak abstract class. Użyć tabel z metatables lub wzorca factory | **A** |
| 5 | `skills/context-and-decisions/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/context-and-decisions/SKILL.md) | Separacja: "co te pojęcia biznesowe znaczą" vs "dlaczego wybrano tę opcję". Glossary/CONTEXT.md dla terminologii domeny, handoff do ADR dla tradeoffów | Projekt HTE ma złożoną terminologię (Farm Value, Soul Eggs, prestiż, tiers petów). CONTEXT.md da stałe źródło definicji dla asystentów | **Użyć** | Bez zmian — czysty Markdown. Projekt już ma CURRENT_SPEC.md, CONTEXT.md uzupełni o mapping terminów gry → kod | Nie zależy od narzędzi | **A** |

### Implementacja i weryfikacja

| # | Materiał ECC | Link | Co zawiera | Zastosowanie w HTE | Status | Dostosowanie do Roblox/Luau | Zależności / ograniczenia | Priorytet |
|---|---|---|---|---|---|---|---|---|
| 6 | `skills/story-lifecycle/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/story-lifecycle/SKILL.md) | Plik-based delivery loop: Epic → Stories → Sprint → Implement → Done. Story format z acceptance criteria, vertical slices, state machine (todo→in-progress→review→done) | Podział implementacji HTE na epiki (rdzeń farmy, prestiż, pety, monetyzacja, offline) i stories per vertical slice. Bez zewnętrznego PM tool | **Zaadaptować** | Pominąć skrypt ledger.js (Node.js). Zachować: formaty plików .md, vertical slices, acceptance criteria, state machine. Stories w `.stories/` lub w docs | ledger.js wymaga Node.js — alternatywa: ręczne zarządzanie lub prosta adaptacja. Formaty .md są uniwersalne | **A** |
| 7 | `rules/common/development-workflow.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/rules/common/development-workflow.md) | 5-krokowy pipeline: Research & Reuse → Plan First → TDD → Code Review → Commit & Push. Mandatory research before implementation | Workflow implementacji HTE: research (przeczytaj specyfikację) → plan (etap ze stories) → implement (z referencyjnymi wynikami) → review → commit | **Zaadaptować** | Zamienić npm/git na Roblox Studio workflow. Pominąć "search npm/PyPI". Zachować: research-first, plan-then-code, review-before-commit | Nie zależy od narzędzi | **A** |
| 8 | `skills/tdd-workflow/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/tdd-workflow/SKILL.md) | Pełny TDD: user journeys → test cases → RED → implement → GREEN → refactor → coverage → evidence report. Plan handoff, safety checklist, checkpoint commits | Adaptacja: zamiast 80% coverage, testy oparte na wynikach referencyjnych z docs (FV, SE, kalendarz). RED/GREEN cycle dla matematyki ekonomii. Evidence report per etap | **Zaadaptować** | Roblox nie ma npm test. Zastosować TestEZ/testrunner Luau. Zamienić Jest/Vitest na assert-based testy. Zachować: RED/GREEN cycle, evidence report, test isolation | Wymaga frameworka testowego Luau (TestEZ lub custom). Nie wymaga 80% coverage — zastosować testy referencyjne z istniejących wyników | **B** |
| 9 | `skills/verification-loop/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/verification-loop/SKILL.md) | 6-fazowa weryfikacja: Build → Type Check → Lint → Tests → Security Scan → Diff Review. Verification report PASS/FAIL | Checklist weryfikacji per etap HTE: Studio build → testy referencyjne → przegląd diff → security (RemoteEvent validation). Raport przed przejściem do kolejnego etapu | **Zaadaptować** | Zamienić npm/tsc/eslint na: Roblox Studio output → Selene linter → TestEZ → przegląd RemoteEvents. Pominąć fazy webowe | Selene (Luau linter) jest opcjonalny, ale zalecany. Roblox Studio jako "build" | **B** |
| 10 | `skills/error-handling/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/error-handling/SKILL.md) | Wzorce: typed errors, Result pattern, kategoryzacja błędów (walidacja vs przejściowe vs nieznany wynik zapisu), user-facing messages ≠ developer messages, checklist obsługi błędów | Obsługa błędów w HTE: Result pattern dla operacji serwera (zakupy, prestiż, łączenie petów). Idempotencja operacji i zakaz ponownego losowania przy timeout. Error codes dla klienta | **Zaadaptować** | Result pattern w Luau: `{ok=true, value=...}` / `{ok=false, error=...}`. Kategoryzacja błędów zamiast ślepego retry. Czysty callback UpdateAsync bez skutków ubocznych. Pominąć React ErrorBoundary, FastAPI handler | Luau nie ma try/catch w takim samym sensie — używa pcall/xpcall. Wzorzec Result jest naturalny | **B** |

### Bezpieczeństwo i jakość

| # | Materiał ECC | Link | Co zawiera | Zastosowanie w HTE | Status | Dostosowanie do Roblox/Luau | Zależności / ograniczenia | Priorytet |
|---|---|---|---|---|---|---|---|---|
| 11 | `rules/common/security.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/rules/common/security.md) | Mandatory checklist: no hardcoded secrets, input validation, injection prevention. Secret management, security response protocol | Checklist HTE: walidacja RemoteEvents, brak zaufania klientowi, serwerowa walidacja żądań (D07). Nie przechowywać cen/kluczy w klientzie | **Zaadaptować** | SQL injection → nie dotyczy. Zamienić na: walidacja argumentów RemoteEvent, rate limiting RemoteEvents, brak secrets w ReplicatedStorage. CSRF/XSS nie dotyczy | Specyfika Roblox: klient nie jest zaufany, serwer autorytatywny. To pokrywa się z D07 | **A** |
| 12 | `rules/common/code-review.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/rules/common/code-review.md) | Review checklist, severity levels (CRITICAL/HIGH/MEDIUM/LOW), security triggers, approval criteria. Common issues to catch | Checklist review kodu HTE: czytelność, error handling, brak hardcoded values, testy, performance. Security triggers: auth, płatności, dane gracza | **Zaadaptować** | Pominąć console.log checks, N+1 queries. Dodać: walidacja serwerowa, rozróżnienie zakresu double vs precyzji całkowitej do 2^53-1 dla dokładnych liczników, idempotencja operacji | Nie zależy od narzędzi | **B** |
| 13 | `AGENTS.md` (Coding Style) | [link](https://github.com/affaan-m/ECC/blob/90606c8/AGENTS.md) | Immutability, file organization (200-400 lines, 800 max), error handling at every level, input validation at boundaries, code quality checklist | Styl kodu HTE: małe moduły, brak mutacji stanu gry bez serwera, walidacja wejść, czytelne nazewnictwo | **Zaadaptować** | Immutability w Luau: zwracać nowe tabele zamiast mutować. File organization: ModuleScripts 200-400 linii. Luau ma inne konwencje nazewnicze (PascalCase dla modułów) | Luau idiomy różnią się — nie wymuszać TypeScript patterns | **B** |

### Kontekst i ciągłość między sesjami

| # | Materiał ECC | Link | Co zawiera | Zastosowanie w HTE | Status | Dostosowanie do Roblox/Luau | Zależności / ograniczenia | Priorytet |
|---|---|---|---|---|---|---|---|---|
| 14 | `skills/strategic-compact/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/strategic-compact/SKILL.md) | Strategiczna kompakcja kontekstu: kiedy kompaktować (after research, after planning, after debugging), co przetrwa kompakcję (pliki na dysku, instrukcje), co się traci. "Write before compacting" | Zarządzanie kontekstem HTE: zapisywać stan/plan do pliku przed kompakcją. Tabela faz przejścia. Ważne przy długich sesjach z wieloma plikami docs | **Użyć** | Bez zmian — dotyczy procesu pracy z asystentem, nie kodu. Dodać rekomendację: `/compact` po fazie planowania, po debugowaniu | Nie zależy od narzędzi | **A** |
| 15 | `skills/unified-memory/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/unified-memory/SKILL.md) | Memory Vault: durable context between sessions. Scopes (project/team/user). Workflow: recall → save → handoff → validate. Trust boundaries, handoff body format | Wzorzec handoff między sesjami/asystentami HTE: co zrobiono, jakie decyzje podjęto, co dalej. Recalled memory ≠ truth — weryfikować przeciw repo | **Inspiracja** | Nie instalować ECC Memory Vault. Zaadaptować wzorzec: plik handoff w docs z obiektywem, stanem, dowodami, następną akcją. Weryfikacja przeciw CURRENT_SPEC | Nie wymaga instalacji ECC. Sam wzorzec handoff jest uniwersalny | **A** |
| 16 | `skills/delivery-gate/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/delivery-gate/SKILL.md) | Mechaniczna brama: rationalization detection, stale learning logs, disk space. "Complex task → must touch learning libraries" | Inspiracja: checklist "zanim skończysz etap" — czy zaktualizowano TODO, WORKING_CONTEXT, czy zapisano evidence? Nie automatyczny hook, ale checklist | **Inspiracja** | Nie instalować jako hook. Zrobić checklist w docs/ecc/adaptations. Pominąć disk space i rationalization regex | Nie wymaga instalacji | **C** |

### Procesy wspierające

| # | Materiał ECC | Link | Co zawiera | Zastosowanie w HTE | Status | Dostosowanie do Roblox/Luau | Zależności / ograniczenia | Priorytet |
|---|---|---|---|---|---|---|---|---|
| 17 | `skills/database-migrations/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/database-migrations/SKILL.md) | Wzorce migracji: expand-contract, forward-only, immutable migrations, batched backfills. Safety checklist, zero-downtime strategy | Inspiracja dla migracji zapisu gracza (DataStore versioning) oraz blokady sesji (Session Lock D07). Expand-contract do dodawania pól. Backward compatibility | **Inspiracja** | SQL→DataStore: nie ma ALTER TABLE. Wzorzec: wersja schematu w zapisie, rurociąg migracji w przód, unikalny sessionToken z CAS w UpdateAsync (ochrona przed nadpisaniem po wygaśnięciu TTL) | DataStore to key-value, nie relacyjna baza. Migrate = deserializuj + transformuj + serializuj | **B** |
| 18 | `rules/common/patterns.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/rules/common/patterns.md) | Repository Pattern, API Response Format (envelope z success/data/error), Skeleton Projects (search for battle-tested templates) | Repository Pattern w HTE: DataStoreRepository behind interface. Envelope dla odpowiedzi serwera na RemoteFunction | **Zaadaptować** | Repository: ModuleScript wrapping DataStore z findById/save/update. Envelope: `{success=bool, data=..., error=string?}` na RemoteFunction return | Luau nie ma abstract interface — użyć duck typing lub metatables | **B** |
| 19 | `skills/plan-orchestrate/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/plan-orchestrate/SKILL.md) | Router: plan document → steps → tagged commands. Tag classification (impl/fix/test/refactor/design), scope-carrying, self-check phase | Inspiracja: klasyfikacja kroków planu HTE (impl/fix/test/refactor). Nie używać komend ECC, ale zachować tag → action mapping dla organizacji pracy | **Inspiracja** | Pominąć komendy ECC. Zachować: tag classification table, step decomposition, self-check | Nie wymaga narzędzi ECC | **C** |
| 20 | `skills/search-first/SKILL.md` | [link](https://github.com/affaan-m/ECC/blob/90606c8/skills/search-first/SKILL.md) | Research before coding: need analysis → parallel search → evaluate → decide (adopt/extend/build). Decision matrix | Zasada HTE: przed implementacją sprawdź istniejące zasoby Roblox (marketplace, community modules). Adopt/Extend/Build decision matrix | **Zaadaptować** | Zamienić npm/PyPI na: Roblox Marketplace, Wally (Luau package manager), community GitHub. Decision matrix zachować | Nie wymaga narzędzi | **B** |

---

## Podsumowanie selekcji

**Wybrano 20 materiałów** z 311+ skills, 71 agentów, 10 common rules i głównego AGENTS.md.

**Odrzucono ~400+ plików** z powodów:
- **Specyficzne dla języka/frameworka**: React, Vue, Django, SpringBoot, Rust, Go, Swift — HTE używa Luau
- **Specyficzne dla webowej infrastruktury**: Docker, deployment, CI/CD, Playwright E2E
- **Specyficzne dla narzędzi AI**: GAN harness, autonomous loops, Codex/Cursor adaptery
- **Redundantne z wybranym**: wiele skills powtarza zasady z common rules
- **Poza zakresem**: marketing, social media, healthcare, bengali NLP, itp.
