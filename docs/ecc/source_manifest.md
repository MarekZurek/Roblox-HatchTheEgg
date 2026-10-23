# Manifest źródła — ECC (Everything Claude Code)

## Metadane repozytorium

| Pole | Wartość |
|---|---|
| Repozytorium | https://github.com/affaan-m/ECC |
| Commit SHA | `90606c8315ee09cafc303515c5f33024db6b9882` |
| Data commita | 2026-10-20T21:28:23Z |
| Gałąź | `main` |
| Data analizy | 2026-10-23 |
| Licencja | **MIT** — Copyright (c) 2026 Affaan Mustafa |
| Wersja | 2.2.3 (wg AGENTS.md) |
| Opis | Agent harness performance optimization system: skills, instincts, memory, security, and research-first development for Claude Code, Codex, Opencode, Cursor and beyond |

## Licencja — pełny tekst skrócony

> MIT License · Copyright (c) 2026 Affaan Mustafa
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software [...]

Pełny tekst: https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/LICENSE

## Struktura ECC — przegląd

| Katalog | Rozmiar | Zawartość |
|---|---|---|
| `skills/` | 311+ plików SKILL.md | Modularne playbooki workflow — planowanie, TDD, architektura, security, review, itp. |
| `agents/` | 71 agentów (.md) | Definicje subagentów — planner, architect, code-reviewer, security-reviewer, itp. |
| `rules/common/` | 10 plików | Uniwersalne zasady: coding-style, patterns, security, testing, development-workflow, performance, code-review, git-workflow, agents, hooks |
| `rules/<język>/` | 16 języków | Zasady per język (python, typescript, react, rust, go, java, swift, itp.) |
| `hooks/` | JSON + README | Event-driven automacje: PreToolUse, PostToolUse, SessionStart, Stop |
| `commands/` | 97 komend | Legacy slash-command shims (migrowane do skills/) |
| `docs/` | Architektura, tłumaczenia, specjalizacje | Dokumentacja, lokalizacje (ar, bn, de, es, fr, ja, ko, pt-BR, zh, zh-TW) |
| `AGENTS.md` | Główny plik reguł | Core Principles, Security Guidelines, Coding Style, Testing, Workflow |

## Przeczytane pliki — pełna lista

### Pliki najwyższego poziomu
- [x] `AGENTS.md` — główne zasady i instrukcje agentów (223 linie, przeczytano w całości)
- [x] `LICENSE` — MIT, Affaan Mustafa 2026

### rules/common/ (wszystkie przeczytane w całości)
- [x] `rules/common/coding-style.md`
- [x] `rules/common/patterns.md`
- [x] `rules/common/security.md`
- [x] `rules/common/testing.md`
- [x] `rules/common/development-workflow.md`
- [x] `rules/common/performance.md`
- [x] `rules/common/agents.md`
- [x] `rules/common/code-review.md`
- [x] `rules/common/git-workflow.md`
- [x] `rules/README.md`

### skills/ (przeczytane w całości — 16 kluczowych)
- [x] `skills/tdd-workflow/SKILL.md` — TDD workflow (584 linie)
- [x] `skills/architecture-decision-records/SKILL.md` — ADR (181 linii)
- [x] `skills/verification-loop/SKILL.md` — weryfikacja 6-fazowa (136 linii)
- [x] `skills/delivery-gate/SKILL.md` — mechaniczna brama jakości (130 linii)
- [x] `skills/context-and-decisions/SKILL.md` — kontekst domeny i ADR handoff (73 linie)
- [x] `skills/plan-orchestrate/SKILL.md` — rozkład planu na kroki (260 linii)
- [x] `skills/story-lifecycle/SKILL.md` — epic→story→sprint loop (386 linii)
- [x] `skills/blueprint/SKILL.md` — construction plan generator (98 linii)
- [x] `skills/error-handling/SKILL.md` — wzorce obsługi błędów (378 linii)
- [x] `skills/search-first/SKILL.md` — research before coding (184 linie)
- [x] `skills/strategic-compact/SKILL.md` — zarządzanie kontekstem (157 linii)
- [x] `skills/unified-memory/SKILL.md` — pamięć między sesjami (200 linii)
- [x] `skills/hexagonal-architecture/SKILL.md` — Ports & Adapters (278 linii)
- [x] `skills/database-migrations/SKILL.md` — migracje danych (431 linii)
- [x] `skills/orch-build-mvp/SKILL.md` — budowanie MVP (50 linii)
- [x] `skills/coding-standards/SKILL.md` (tytuł odczytany z web search)

### skills/ (przeczytane z opisu web search, nie otwarte bezpośrednio)
- [ ] `skills/agentic-engineering/SKILL.md` — odczytano opis
- [ ] `skills/continuous-learning/SKILL.md` — odczytano opis
- [ ] `skills/continuous-learning-v2/SKILL.md` — odczytano opis
- [ ] `skills/security-review/SKILL.md` — odczytano opis
- [ ] `skills/gateguard/SKILL.md` — odczytano opis
- [ ] `skills/safety-guard/SKILL.md` — odczytano opis

### agents/ (przeczytane w całości — 8 kluczowych)
- [x] `agents/planner.md` — planista implementacji (222 linie)
- [x] `agents/architect.md`
- [x] `agents/code-reviewer.md`
- [x] `agents/security-reviewer.md`
- [x] `agents/tdd-guide.md`
- [x] `agents/performance-optimizer.md`
- [x] `agents/silent-failure-hunter.md`
- [x] `agents/spec-miner.md`

### hooks/ (przeczytane w całości)
- [x] `hooks/README.md` — pełna dokumentacja hooków (317 linii)
- [x] `hooks/hooks.json`
- [x] `hooks/memory-persistence/hooks.json`
- [x] `hooks/memory-persistence/README.md`

### Przejrzane, ale nieotwarte (katalog, nazwy, opisy z web search)
- Pełna lista 311+ skills z drzewa repo (nazwy odczytane z GitHub API tree)
- Pełna lista 71 agentów (nazwy z GitHub API tree)
- Katalogi: `.claude-plugin/`, `.codex/`, `.cursor/`, `.opencode/`, `manifests/`, `scripts/`
- Katalogi docs/ z lokalizacjami i architekturą

## Pliki ECC celowo pominięte / odrzucone

| Kategoria | Powód pominięcia |
|---|---|
| `rules/<język>/` (poza common) | Zasady per Python/React/TypeScript/Go/etc. — HTE używa Luau, te reguły nie mają zastosowania |
| Agenty `*-reviewer.md` per język | python-reviewer, react-reviewer, itp. — nie dotyczą Luau |
| Agenty `*-build-resolver.md` | Rozwiązywanie błędów budowania per język — nie dotyczy |
| `skills/react-*`, `skills/vue-*`, `skills/django-*`, `skills/springboot-*` itp. | Frameworki webowe — nie dotyczy Roblox |
| `skills/e2e-testing/` | Testy Playwright/przeglądarkowe — nie dotyczy |
| `skills/frontend-*`, `skills/backend-patterns/` | Wzorce web frontend/backend — nie dotyczy |
| `skills/postgres-patterns/`, `skills/prisma-*`, `skills/redis-*` | Konkretne bazy danych — HTE używa Roblox DataStore |
| `skills/docker-*`, `skills/deployment-*` | Infrastruktura webowa — nie dotyczy |
| `skills/gan-*` | GAN harness (Playwright-based) — nie dotyczy |
| `skills/autonomous-loops/`, `skills/continuous-agent-loop/` | Agentowe pętle automatyczne — poza zakresem |
| `hooks/hooks.json` (konfiguracje) | Specyficzne dla Claude Code hooks — nie instalujemy |
| `.claude-plugin/`, `.codex/`, `.cursor/`, `.opencode/` | Konfiguracje per harness — nie instalujemy |
| `manifests/`, `scripts/` | Instalacja i CI ECC — nie instalujemy |
| `commands/` | Legacy slash-commands — nie stosujemy |
| Lokalizacje `docs/es/`, `docs/zh/`, itp. | Tłumaczenia ECC — nie potrzebne |
