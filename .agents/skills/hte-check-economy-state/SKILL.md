---
name: hte-check-economy-state
description: Check HatchTheEgg changes affecting balances, rewards, resets, fusion, persistence or purchases for state integrity and idempotency. Not an economy calibration or a general review of unrelated code.
---

# Integralność stanu ekonomii i transakcji

Stosuj do konkretnej operacji lub zmiany, nie jako nowy audyt całej gry. Ustal właściciela stanu, wejście, granicę trwałości i wynik. Czytaj tylko właściwe D01/D04/D05/D07 w [22](../../../docs/22_gameplay_rules_for_approval.md) oraz [25](../../../docs/25_approved_product_structure.md) i [26](../../../docs/26_approved_launch_scope_and_pro_availability.md), gdy dotyczą produktu.

## Kontrola zależna od zmiany

- Serwer sprawdza aktualny stan, własność i dostępność materiałów; kwota klienta nie jest autorytetem. Koszt, korzyść, ID i rezultat są rozliczone spójnie. Dla powtórzonej operacji nie obciążaj i nie losuj ponownie, zwróć utrwalony rezultat.
- Timeout nie dowodzi anulowania. Rozróżnij brak wykonania, już wykonano, odrzucono i nieznany wynik. Samo pcall=true nie dowodzi rozliczenia; callback może anulować zapis.
- Przy sesjach sprawdzaj aktualną własność podczas zapisu, odnowienia i zwolnienia, nie samo TTL. Stary właściciel nie może zapisać stanu po przejęciu przez nową sesję. Nie usuwaj dowolnie dawnych ID transakcji limitem FIFO bez bezpiecznej polityki powtórek.
- Dla łączenia zachowaj chronionego bazowego, wskazane materiały, klucz gwarancji i ochronę wyboru. Zmiana UID bazowego nie daje nowego licznika ani prawa do podmiany kopii.
- Dla resetu rozdziel portfel, przychód prestiżowy i zasoby trwałe. Dla prezentu zachowaj jego stały wynik, rezerwację i zajęte miejsce; oddziel naliczenie od wizualizacji.
- Trwałe gamepassy i powtarzalne zakupy to różne uprawnienia/operacje. Respektuj wariant A Pro, realną zawartość przed zakupem oraz zamówienie sprzed północy bez zużywania nowego darmowego prawa. Nie przekształcaj zakupu w inną korzyść samodzielnie.
- Zachowaj spójność kontraktów danych ([NumericCodec](../../../src/shared/NumericCodec.luau), [ProfileSchema](../../../src/server/ProfileSchema.luau), [ProtocolSchemas](../../../src/shared/ProtocolSchemas.luau), [SessionRepository](../../../src/server/SessionRepository.luau), [PlayerCoordinator](../../../src/server/PlayerCoordinator.luau) i [TimelineSimulation](../../../src/server/TimelineSimulation.luau)): rozdzielaj `BigAmount`/`Real64` (round-trip binary64) od kanonicznego `ExactUInt` (tekst uint64 bez `tonumber`), stan `durable` od `working`, portfel (`farm.cash`) od akumulatora przychodu sesji (`accounting.currentFarmCash`), `commitRevision` od `viewSeq` oraz `operationId` od `requestId`/`quoteId`. Nowe pola (np. monotoniczny `hatchGroupSequence`) i carry `fractionalIHR >= 0` nie mogą być po cichu kasowane, zerowane przy resecie ani pomijane w walidacji schematu i mostach pamięć–wire.

## Referencje i wynik

Złożone przypadki: ECC [zapis/sesje](../../../docs/ecc/adaptations/datastore_migration_and_session_lock.md), [błędy](../../../docs/ecc/adaptations/error_handling_and_result_pattern.md) i [sieć](../../../docs/ecc/adaptations/server_validation_and_security_checklist.md). To szkice P, nie dowód działania przyszłego kodu. Szczegóły API weryfikuj w oficjalnej dokumentacji przy ich faktycznym użyciu, nie przepisuj limitów z przykładu.

Zwróć ustalenie z miejscem i skutkiem, zastosowane/nieuruchomione kontrole oraz pozostałą lukę według [workflow](../../../docs/workflow/WORKFLOW.md). Analiza nie uruchamia realnych wypłat, zakupów, chmury lub migracji. Nie wybieraj nowego bilansu, biblioteki albo architektury zamiast zadania. Nie zmieniaj docs/17–21 i nie otwieraj ponownie zamkniętych ustaleń niezwiązanych z zadaniem.
