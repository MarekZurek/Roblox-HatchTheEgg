# HatchTheEgg — dokumentacja

Stan: 23.10.2026. Dokumentacja i planowanie, bez implementacji gry. Bilans progresji, inkubatorów, petów i produktów pozostaje odłożony.

## Punkty startowe

- [CURRENT_SPEC](CURRENT_SPEC.md) — reguły i statusy N/S/R/P/H; dane referencyjne nie oznaczają testów implementacji.
- [WORKING_CONTEXT](WORKING_CONTEXT.md) — kontekst dalszej pracy.
- [TODO](TODO.md) — zadania i odłożone decyzje.
- [Workflow](workflow/README.md), [etapy](workflow/IMPLEMENTATION_STAGES.md) i [skills](workflow/SKILLS_PLAN.md) — organizacja przyszłej realizacji.

## Systemy

| Dokument | Zakres |
|---|---|
| [01](01_upgrades_and_research.md) | Badania Common i Epic |
| [02](02_eggs_and_farm_value.md) | Jaja, Farm Value i awans farmy |
| [03](03_habitats_and_population.md) | Kurniki, populacja i wylęg |
| [04](04_vehicles_and_shipping.md) | Transport i wagony Hyperloop |
| [05](05_prestige_soul_eggs_and_boosts.md) | Prestiż, SE/PE i boosty |
| [06](06_drones_silos_and_events.md) | Drony, silosy i wydarzenia |
| [07](07_roblox_architecture_and_roadmap.md) | Szkic architektury |
| [08](08_monetization_and_economy.md) | Produkty i ekonomia |
| [09](09_pets_system_and_artifacts.md) | Pety |
| [10](10_verified_simulation_and_server_config.md) | Symulacja offline i konfiguracja |
| [11](11_periodicals_calendar_events_and_boost_rules.md) | Kalendarz, wydarzenia i boosty |
| [12](12_calendar_scaling_and_video_doubler.md) | Podwajacz dochodu |
| [13](13_rewards_contracts_resets_and_gift_distributions.md) | Konwersje, resety i rozkłady nagród |
| [14](14_reward_claim_safety.md) | Bezpieczeństwo odbioru |
| [15](15_calendar_gameplay_formula_and_roblox_scope.md) | Skalowanie kalendarza |
| [16](16_pet_stacking_offline_and_package_schedule.md) | Składanie efektów i harmonogram prezentów |
| [UI](ui/ui_design_specification.md) | Propozycja interfejsu i makiety |

## Decyzje i scenariusze

[22 — D01–D07](22_gameplay_rules_for_approval.md), [23 — łączenie](23_pet_fusion_acceptance_review.md), [24 — podwajacz i prezenty](24_doubler_and_bonus_gift_acceptance_review.md), [25 — produkty](25_approved_product_structure.md), [26 — premiera i dostępność Pro](26_approved_launch_scope_and_pro_availability.md). Aktualne decyzje R rozstrzygają rozbieżności ze starszymi propozycjami.

## Odłożony bilans

[17](17_pet_balance_draft.md), [18](18_incubator_prices_and_acquisition_pacing.md), [19](19_integrated_farm_progression_simulation.md), [20](20_paying_player_balance_direction.md), [21](21_payer_progression_and_incubation.md) zawierają historyczne analizy i niezatwierdzone parametry. Redakcja opisów nie zmienia liczb ani nie wznawia strojenia.

## Materiały pomocnicze

[ECC](ecc/README.md) wspiera proces techniczny. [Historia redakcji](DOCUMENTATION_CLEANUP.md) wyjaśnia granice dokumentacji i wcześniejszych raportów. Raporty historyczne nie zastępują przyszłych testów kodu HatchTheEgg.

## Dane referencyjne w projekcie

[Dane referencyjne JSON](reference_data/README.md) zawierają pełne ceny i efekty badań, infrastrukturę, punkty krzywych, boosty, nagrody oraz reguły dronów i silosów. Są materiałem do przyszłej implementacji, nie konfiguracją wydania.

## Kontrakt przed implementacją

[27 — liczby, czas i model stanu gracza](27_numbers_time_and_player_state_contract.md): propozycja techniczna obejmująca formaty i jednostki, zegary, profil, resety i jednokrotne operacje. Bez kodu i nowych parametrów bilansu.

[28 — podział modułów i komunikacja serwer–klient](28_modules_and_client_server_contract.md) uzupełnia kontrakt 27 o granice odpowiedzialności, intencje i odpowiedzi, replikację widoku oraz odtwarzanie po rozłączeniu. Status P, bez kodu i zatwierdzania ekonomii.

[29 — pierwszy zakres implementacji: podstawowa farma](29_first_farm_implementation_plan.md) przekłada 27–28 na zadania F01–F09, konkretne zależności i scenariusze odbioru A01–A16. Jedno jajo, wylęg/RCB/IHR, transport, Common i bezpieczne zakupy/powrót; bez petów, prestiżu i płatności. Plan P; implementacja i scenariusze niewykonane.

[30 — manifest pierwszej farmy i wybory techniczne](30_first_farm_manifest_and_technical_choices.md) przygotowuje dokumentacyjną część F01: konkretne ID, źródła startu, TEST_ONLY profil, model wejścia/RCB, DTO i kierunki adapterów. U01–U06 jawnie ograniczają gotowość; nie jest konfiguracją wydania ani implementacją.

[31 — badania, ręczny wylęg, RCB i nowe konto](31_research_hatching_rcb_and_new_account.md) uzupełnia dostępne reguły i referencyjny start, odróżniając je od testowego profilu oraz zatwierdzonej konfiguracji. [32 — równoległy backlog](32_parallel_delivery_backlog.md) jest mapą ukończonych materiałów i przyszłych zadań z zależnościami.
