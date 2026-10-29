## Wymaganie użytkownika

Zgodnie z Decyzją R (29.10.2026) silosy zostały całkowicie wycofane z mechaniki gry i zastąpione stałym limitem offline konta (6h F2P / 18h Pro Permit). W ślad za wycofaniem mechaniki należy usunąć fizyczne modele 3D silosów z mapy farmy.

## Zakres i kryteria odbioru

- Usunąć generowanie 10 modeli wież silosów (`_buildSiloTower`, `SILO_POSITIONS`, `siloModels`, `siloLabels`) z proceduralnego generatora świata `src/server/world/FarmPlotBuilder.luau`.
- Usunąć aktualizację etykiet silosów w `FarmPlotBuilder:updateFromFarmView`.
- Zapewnić, że metody pomocnicze (`getSilos`, `getSiloLabels`) zwracają puste kolekcje dla zachowania wstecznej kompatybilności API generatora lub bezpiecznie zaktualizować asercje w powiązanych testach prezentacji (`tests/presentation/run.luau`).
- Przestrzeń po silosach na wyspie farmy staje się otwartą, zieloną przestrzenią (np. pod przyszłe instalacje „Egg to the Moon 🚀”).
- Zweryfikować brak wiszących instancji w Workspace oraz pełne zaliczenie testów `tools/test.ps1` i budowy Rojo.

## Granice

- Zadanie dotyczy wyłącznie warstwy wizualnej/przestrzennej generatora świata 3D (`FarmPlotBuilder`).
- Logika ekonomii, profil gracza oraz stałe limity offline 6h/18h pozostają bez zmian (zrealizowane w #93).
