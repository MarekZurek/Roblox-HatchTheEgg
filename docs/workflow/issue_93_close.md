## Zamknięcie zadania — Wdrożenie Decyzji R (29.10.2026)

Zadanie zostało w pełni zrealizowane zgodnie z wiążącą decyzją projektową (Decyzja R):

### 1. Usunięcie silosów i stały bonus offline (6h / 18h)
* **Wycofanie mechaniki silosów**: Zakup i rozbudowa silosów zostały całkowicie wycofane z gry.
* **Stały czas offline**:
  * Gracze F2P (bez Pro Permit): **6 godzin** (21 600 sekund).
  * Gracze z Przepustką PRO: **18 godzin** (64 800 sekund).
* **Wsteczna kompatybilność**: Pole `farm.siloOwned` w profilu gracza zachowane (domyślnie `1`), zapobiegając desynchronizacji schematu. Wartość `0` jest traktowana jako fixtura testowa dla braku produkcji offline.
* **Badania epickie**: `silo_capacity` dodano do `FeatureAvailability.blockedEpic`, blokując zakup na serwerze i oznaczając badanie jako „WKRÓTCE” w HUD.

### 2. Odłożenie i rebranding Hyperloop -> „Egg to the Moon 🚀”
* **Rebranding**: Hyperloop przemianowano na **„Egg to the Moon 🚀”** (rakiety startujące z jajkami w v1.1).
* **Blokada w HUD**:
  * W modalu floty (VehiclesModal): Przycisk ulepszenia do poziomu 12 (Egg to the Moon) jest nieaktywny (`Active = false`) z etykietami `WKRÓTCE` oraz `EGG TO THE MOON 🚀`.
  * W badaniach: Badanie `micro_coupling` przy blokadzie `HYPERLOOP_LOCKED` wyświetla `WKRÓTCE: EGG TO THE MOON 🚀`.
* **Serwer**: Autorytatywna blokada `HYPERLOOP_LOCKED` w `FarmActions.luau` pozostaje w mocy.

### 3. Aktualizacja nazw Boostów i opisów sklepu
* Zaktualizowano `BOOSTS_CATALOG` w `src/client/HUD.luau` o nowe, unikalne nazwy odcinające się od Egg, Inc.: *Worek Złotego Ziarna*, *Karmnik Obfitości*, *Eliksir Złotego Ziarna*, *Cieplarka Promiennikowa*, *Inkubator Przemysłowy*, *Mistyczny Rezonator*.
* Zaktualizowano opisy Przepustki PRO i plakietki VIP w HUD na `18h działania offline (zamiast 6h)` oraz `[👑 VIP (18H OFFLINE & 5 BOOSTÓW)]`.

### 4. Weryfikacja
* Zaktualizowano asercje w zestawach testowych `tests/timeline`, `tests/acceptance` (A12), `tests/effect_boundaries` oraz `tests/event_time`.
* Zaktualizowano weryfikację modułów w `tools/verify_release.py` do 45 modułów Rojo.
* **Wynik testów (`tools/test.ps1`)**:
  * Pełne 52 zestawy testowe Luau / Lune — **PASS**.
  * Rojo static build (45 modułów, 2 skrypty entrypoint) — **PASS_STATIC_BUILD**.
  * Zestaw acceptance (A01–A16) — **PASS**.
  * Release candidate integration suite — **PASS**.
  * Python oracles & static verification — **PASS**.
