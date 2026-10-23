# Przewodnik po materiałach adaptacyjnych ECC dla HatchTheEgg

> **Bieżące uporządkowanie workflow:** [workflow HatchTheEgg](../workflow/README.md) łączy użyteczne procedury lokalnego GrowASnack i tego pakietu ECC. [Katalog skills projektu](../workflow/SKILLS_PLAN.md) prowadzi do siedmiu utworzonych SKILL.md. ECC pozostaje materiałem referencyjnym; nie instalowano jego hooków/runtime. Procedur nie uruchomiono na kodzie gry; bez implementacji.

Niniejszy katalog zawiera selektywny, przefiltrowany i zaadaptowany zestaw wzorców inżynieryjnych z repozytorium **Everything Claude Code (ECC)** ([affaan-m/ECC](https://github.com/affaan-m/ECC)), przygotowany z myślą o przyszłej implementacji gry **HatchTheEgg** na platformie Roblox w języku Luau.

> [!IMPORTANT]
> **Status materiałów**: Żadne materiały w tym katalogu nie stanowią rozpoczęcia implementacji gry. Nie aktywują w projekcie pluginów, hooków, serwerów MCP ani konfiguracji narzędziowych. Nie modyfikują zatwierdzonych reguł rozgrywki (D01–D07), struktury produktów (D25) ani zakresu premiery (D26). Odłożony bilans pozostaje nienaruszony.

---

## Źródło i licencja

- **Repozytorium źródłowe**: https://github.com/affaan-m/ECC
- **Commit SHA**: `90606c8315ee09cafc303515c5f33024db6b9882` (20.10.2026)
- **Licencja**: **MIT License**, Copyright (c) 2026 Affaan Mustafa
- Szczegółowe metadane i spis przeczytanych plików źródłowych: zobacz [`source_manifest.md`](source_manifest.md).

---

## Struktura katalogu `docs/ecc/`

```text
docs/ecc/
├── README.md                           -- Niniejszy przewodnik po zestawie materiałów
├── source_manifest.md                  -- Commit SHA, licencja, spis przeczytanych plików i kryteria odrzucenia
├── selection.md                        -- Tabela 20 wyselekcjonowanych materiałów z oceną i uzasadnieniem
├── implementation_workflow_draft.md    -- Proponowany proces realizacji HTE w małych, weryfikowalnych etapach
└── adaptations/                        -- Szczegółowe adaptacje wzorców do Roblox / Luau
    ├── adr_template_and_guide.md                  -- Szablon Architecture Decision Records
    ├── server_validation_and_security_checklist.md-- Walidacja serwerowa, RemoteEvents i model zagrożeń
    ├── hexagonal_luau_architecture.md             -- Ports & Adapters w Luau (izolacja czystej matematyki)
    ├── reference_testing_and_verification.md      -- Testy oparte na wektorach referencyjnych z docs (placeholdery, bez wymyślonych PASS)
    ├── error_handling_and_result_pattern.md       -- Wzorzec Result<T, E>, API envelope, kategoryzacja błędów i nieznany wynik zapisu
    ├── datastore_migration_and_session_lock.md    -- Wersjonowanie zapisu, migracje, Session Lock z tokenem generacji i CAS (D07)
    └── context_continuity_and_handoff.md          -- Ciągłość kontekstu i protokół handoff między asystentami
```

---

## Jak korzystać z tego zestawu?

### 1. Przed rozpoczęciem implementacji (Faza 0)
- **Zapoznanie z procesem**: Przeczytaj [`implementation_workflow_draft.md`](implementation_workflow_draft.md), aby poznać proponowane fazy realizacji gry w pionowych wycinkach (vertical slices).
- **Utrwalenie decyzji technicznych**: Skorzystaj z [`adaptations/adr_template_and_guide.md`](adaptations/adr_template_and_guide.md) do spisania decyzji o formacie DataStore, zakresie i precyzji liczb (granica $2^{53}-1$ dla dokładnych liczników vs zakres double dla gotówki) i architekturze modułów.
- **Hierarchia prawdy**: Zapoznaj się z [`adaptations/context_continuity_and_handoff.md`](adaptations/context_continuity_and_handoff.md), aby zapewnić, że kolejni asystenci AI nie zgubią zatwierdzonych reguł ze specyfikacji.

### 2. Podczas implementacji kodu w Roblox Studio (Fazy 1–6)
- **Struktura kodu**: Zastosuj [`adaptations/hexagonal_luau_architecture.md`](adaptations/hexagonal_luau_architecture.md) — trzymaj czystą matematykę ekonomii w niezależnych modułach bez `game:GetService()`.
- **Weryfikacja matematyki**: Zamiast arbitralnego 80% coverage uruchamiaj testy asercyjne oparte na wektorach referencyjnych z dokumentacji według [`adaptations/reference_testing_and_verification.md`](adaptations/reference_testing_and_verification.md).
- **Bezpieczeństwo sieci**: Przy każdym zdarzeniu `RemoteEvent`/`RemoteFunction` stosuj checklistę z [`adaptations/server_validation_and_security_checklist.md`](adaptations/server_validation_and_security_checklist.md).
- **Spójność danych i transakcji (D07)**: Wykorzystaj mechanizmy Session Lock i idempotencji opisane w [`adaptations/datastore_migration_and_session_lock.md`](adaptations/datastore_migration_and_session_lock.md).
- **Obsługa błędów**: Komunikuj wyniki operacji przez unię `Result` oraz ustandaryzowaną kopertę sieciową z [`adaptations/error_handling_and_result_pattern.md`](adaptations/error_handling_and_result_pattern.md).

---

## Ograniczenia i zakres adaptacji

Materiały ECC powstały z myślą o środowiskach webowych (Node.js, TypeScript, Python, React, PostgreSQL) i agentach terminalowych. W związku z tym:
- **Odrzucono ponad 400 plików** powiązanych ze stosami technologicznymi niemającymi zastosowania w Roblox.
- **Nie zainstalowano żadnych narzędzi wykonawczych**.
- Wszystkie uniwersalne zasady inżynieryjne przetłumaczono na idiomy Luau i specyfikę silnika Roblox (DataStore, RemoteEvents, autorytatywny serwer, limity platformowe).
