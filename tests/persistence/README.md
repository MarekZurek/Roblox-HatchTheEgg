# SessionRepository — testy L

Uruchomienie: ./tools/test.ps1 -PythonExecutable python albo bezpośrednio .tools/lune-0.11.1/lune.exe run tests/persistence/run.luau z istniejącym katalogiem build.

[Runner](run.luau) używa kontrolowanego fake UpdateAsync z ponowieniem callbacku, opóźnionym wykonaniem, utraconą odpowiedzią po commit i potwierdzonym anulowaniem. To test tej samej logiki [repozytorium](../../src/server/SessionRepository.luau), nie test chmury. Adapter [RobloxDataStorePort](../../src/server/RobloxDataStorePort.luau) jest sprawdzany przez fałszywy obiekt API: nazwa metody, UseCache=false, zachowanie metadanych; nie oznacza wykonania prawdziwego GetAsync/UpdateAsync.

Kryteria: jeden rekord kosztu/korzyści/cursora/wyniku; replay przed revision i ważnością quote; konflikt ID; terminalny reject w ledger; serializacja wywołań jednego handle; utrata lease, stary callback i zwolnienie; brak rekordu vs UNKNOWN; odzyskanie po nowym fence; nowszy/uszkodzony schemat zachowany; migracja z zachowaniem obcych sekcji; licznik generacji >2^53; granice 2 i 3 MiB dokładnie oraz ±1 bajt, UTF-8; podtrzymanie replay przy pełnym ledgerze; brak yield i niejawnego zapisu przez query.

Wszystkie profile są jawnymi INTERNAL_TEST_ONLY i nie są konfiguracją premiery. Referencyjny stan nowego konta z 31 nie zastępuje zatwierdzenia konfiguracji. Brak testów Studio, DataStore i wieloserwerowej trwałości. Długotrwała retencja pozostaje bramką wydania, a obecny limit działa fail-closed bez kasowania historii.
