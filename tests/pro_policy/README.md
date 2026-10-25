# Regresje polityki Pro — #58

Uruchomienie: `.tools/lune-0.11.1/lune.exe run tests/pro_policy/run.luau` lub wspólny `tools/test.ps1 -MutationChecks -PythonExecutable python`.

207 asercji sprawdza własność niezależną od kwalifikacji, nieznaną/ograniczoną politykę, aktualną decyzję przed użyciem, oba porządki odczytów, stare odpowiedzi i sesje, zachowanie pozostałych korzyści oraz informację przed zakupem. Testy ładują rzeczywisty Main przez wspólny tests/support/MainHarness.luau z kontrolowanymi usługami zewnętrznymi. Porównanie wyniku fuzji z niezależnym rzutem 0.45 odróżnia bazowe 40% od 50% z bonusem; wartości są wyłącznie fixture, bez zatwierdzania bilansu.

Pięć mutacji polityki jest częścią tests/game_behavior/mutation_check.py. Wyłącznie lokalna weryfikacja L, bez Studio, chmury i rzeczywistych płatności. [Zakres dostawy](../../docs/workflow/pro_policy_58.md).
