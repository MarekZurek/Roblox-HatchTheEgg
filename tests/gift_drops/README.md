# Ground gift contract and regression evidence

Current requirement: user decision2026-10-28, [CURRENT_SPEC](../../docs/CURRENT_SPEC.md), [delivery](../../docs/workflow/ground_gifts_2026_10_28.md). Spadający prezent zbiera właściciel przez podejście po lądowaniu; znika po15s na ziemi. Oferty2+1 są osobnym systemem i zachowują trwałość/rezerwacje.

```powershell
.tools/lune-0.11.1/lune.exe run tests/gift_drops/run.luau
python tests/gift_drops/mutation_check.py
python tests/gift_drops/verify_evidence.py
./tools/test.ps1 -PythonExecutable python
# Optional complete mutation gate, including historical suites:
./tools/test.ps1 -MutationChecks -PythonExecutable python
```

W Codex dostępny Python można wskazać pełną ścieżką; wersje i checksum narzędzi wybiera tools/toolchain.json. Selektor `mutation_check.py --only <nazwa>` można powtarzać. `verify_evidence.py` wymaga kompletu22 przypadków; odrzuca stare hashe, niepełny wybór, obcą asercję, timeout i błędy składni/importu.

Oczekiwania są niezależne: początek1000000ms, lądowanie1002500ms, koniec1017500ms; przed końcem przyznanie6GE daje10→16; powtórzenie/rejoin nie zmienia16. Osobny fixture gotówki ma2+1.25=3.25 i księgę4+1.25=5.25 po JSON roundtrip. Przedziały generatora z docs/06 dają5s i29.5s dla jawnych wejść; testy nie pobierają progów z funkcji testowanej.

Pozostałe kontrole obejmują rzeczywistą pętlę Main z ograniczonym task.wait, martwą/brakującą postać, odległość6studów i jej granicę, ponowną walidację przy zapisie, utraconą odpowiedź, brak stosu prezentów, serwerową projekcję pozycji/terminów oraz prawdziwą gałąź konstrukcji wizualizacji Roblox z atrapami Instance. To Lune, nie render/physics/replication acceptance w Studio.

Cztery regresje z poprzedniego audytu są w swoich zestawach: offers, fusion i pet_effects. Mutacje wraz z baseline i corrected wykonują się w kopiach build/. Brak zmian roboczego src podczas mutowania i brak operacji chmurowych/płatności.
