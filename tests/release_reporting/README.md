# Regresje zakresu dowodów — #60

Po wygenerowaniu aktualnych wyników acceptance/release_candidate uruchom `python tests/release_reporting/test_reporting.py`. Wspólny tools/test.ps1 wykonuje je automatycznie.

11 testów używa rzeczywistych raportów i ich uszkodzonych kopii: mieszanego poziomu L/S/D, flag Studio/chmury/człowieka, zatwierdzenia wydania bez dowodów, brakującego scenariusza lub wiringu Main, zmienionych wymagań H, niezgodnych liczników i procentu pokrycia. Testy sprawdzają semantykę danych, nie tekst implementacji.

Kontrola verify_release.py jest walidacją lokalnych raportów. Jej sukces nie zatwierdza wydania; brakujące S/D/H pozostają NOT_VERIFIED. [Zakres i macierz](../../docs/workflow/release_evidence_60.md).
