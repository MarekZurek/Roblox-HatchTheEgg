# Automatyczne testy oczekiwanego zachowania

`run.luau` testuje pełną dostępną ścieżkę intencji i ekonomii. Podstawą wyniku jest kontrakt produktu, niezależny odczyt `docs/reference_data/*.json`, proste równania i niezmienniki. Oczekiwana nagroda nie pochodzi z preview ani kalkulatora, który jest przedmiotem testu. Kontrolowane porty obejmują zegar, pamięć z awariami i sam prompt platformy. Bootstrap, protokół, Gateway, koordynator i mutacje są rzeczywiste.

## Mapa weryfikacji całej gry

| Zachowanie | Automatyczna ścieżka | Ograniczenie |
|---|---|---|
| Liczby, granice i precyzja | numeric, catalog; niezależne wektory Pythona | Nie jest to typecheck Luau |
| Nowe konto, tutorial | tutorial, integration, acceptance | Samouczek w silniku nieuruchomiony |
| Wylęg/RCB, grupy, IHR | hatching, ihr, integration89, timeline | Reset sekwencji grup nadal #59 |
| Produkcja, badania, transport | math, catalog, purchases, production_context, game_behavior | Bez kalibracji tempa progresji |
| Jajo, SE/PE, wyposażenie i boosty | production_context; rachunki niezależne, granice kontekstu | Nie zastępuje historycznego eventu w części kroku (#61) |
| Wydarzenia, offline, silosy i VD | effect_boundaries, timeline, production_context | Częściowe kroki eventów #61; brak natywnych zegarów Studio |
| Zakupy infrastruktury/badań | purchases, gateway, integration, acceptance | Buy MAX jako produkt wymaga odrębnego domknięcia logiki |
| Zmiana jaja i prestiż | resets, fv_se; realna komenda prestige w game_behavior | Dalsze znane problemy pozostają w Issues |
| Pety, lock/wyposażenie, fuzja | pet_effects, fusion, game_behavior z jawnym fixture | Produkcyjna fuzja niedostępna; quote/config nieukończone |
| Drony, paczki, nieuprawnione nagrody | drones, offers, reward_security przez rzeczywisty ingress | Harmonogramy i prezentacja nie są testem chmury |
| Kalendarz: skala, UTC, Epic, PE | claims + game_behavior; JSON i równania | Dni 4/10/15/18/22 niedostępne (#62); brak udawanego testu 28/28 |
| Wszystkie 95 trofeów i granice populacji | game_behavior, osobno odczytany infrastructure.json | UI testowany bez renderera Studio |
| Zakupy, brak pieniędzy, replay | game_behavior, purchase_recovery, persistence | Kwoty testowe nie stają się parametrami premiery |
| Produkty: podgląd/potwierdzenie/anulowanie/receipt | game_behavior, purchase_recovery, pet_effects | Żadnych realnych zakupów; uprawnienia #58 nadal otwarte |
| Sesje, UNKNOWN, reconnect, atomowość | persistence, coordinator, integration89, reward_security, game_behavior | Produkcyjny fallback pamięci #57 nadal otwarty |
| Rzeczywiste sygnały przycisków i transport | game_behavior + ui; brak injected success-stub | Bez S/D i weryfikacji dotyku na urządzeniu |
| Sceny, trasy, dźwięk i HUD | presentation, ui, release_candidate — lokalne testy modułów | Nazwa testu nie dowodzi renderowania ani odbioru Studio; #60 |

Ta mapa nie oznacza 100% gotowości gry. Obecność fixture'ów i przechodzących testów funkcji liściowych nie dowodzi kompletnej integracji produkcyjnej. Znane otwarte problemy i jawne FEATURE_UNAVAILABLE pozostają blokadami, a nie pominiętymi testami uznanymi za sukces.

## Uruchomienie i mutacje

Pełny runner: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Szybko: `.tools/lune-0.11.1/lune.exe run tests/game_behavior/run.luau`.

`mutation_check.py` tworzy kopie src/testów/reference JSON pod ignorowanym build/ i wprowadza siedem konkretnych błędów zachowania. Test musi zakończyć się niepowodzeniem z powodu obserwowalnej regresji, a nie błędu składni/importu. Mutacja UTC wyłącza oba niezależne zabezpieczenia: wyłączenie tylko jednego nie zmienia zachowania dzięki drugiemu i nie jest poprawnym przykładem usterki na poziomie przycisku. Zestaw nie deklaruje pełnego mutation score repozytorium.

Raporty lokalne: `build/game-behavior-results.json`, `build/game-behavior-mutations.json`. Bez binariów, prywatnych danych ani prawdziwej waluty. [Szczegóły dostawy](../../docs/workflow/action_wiring_56.md).
