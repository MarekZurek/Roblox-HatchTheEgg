# Rzeczywiste operacje przycisków i testy zachowania — #56

25.10.2026. Dostawa L i statyczny build, bez publikacji gry, prawdziwych zakupów, DataStore ani testów Studio. Bilans 17–21 i JSON-y referencyjne pozostają bez zmian. Ta dostawa nie zamyka #57–61 ani nowej luki [#62](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/62).

## Podłączenie

Przyciski kalendarza, trofeów, fuzji, wyposażenia, blokady peta, boostów i produktów wysyłają intencję przez ClientTransport → ProtocolSchemas → Gateway → PlayerCoordinator → SessionRepository. Usunięto lokalne APPLIED/SUCCESS i zastępcze callbacki sukcesu. Brak sesji lub transportu oznacza odmowę. Wysłany pakiet nie jest wynikiem operacji.

Nowe komendy mają wspólny envelope `protocolVersion/requestId/kind/operationId/expectedRevision/args`. Dozwolone argumenty:

| Komenda | Argumenty klienta | Źródło rozstrzygnięcia |
|---|---|---|
| ClaimDailyGift | `{}` | Następny dzień i UTC z profilu/zegara serwera |
| ClaimTrophy | eggIndex 0–18, tierIndex 1–5 | Aktualne jajo, rzeczywista całkowita populacja, tabela i znaczniki odbioru |
| FusePets | basePetId, materialIds | Własność, zgodność, lock/wyposażenie, trwały licznik; bez produkcyjnej receptury FEATURE_UNAVAILABLE |
| EquipPet | petUid | Posiadany UID, istniejące reguły slotów, kolejny wolny slot |
| UnequipPet | slotIndex 1–5 | UID odczytany z wyposażenia serwera |
| TogglePetLock | petUid | Zmiana locka raz na operationId |
| BuyBoost | boostId | Serwerowy katalog oferty; bez konfiguracji FEATURE_UNAVAILABLE |
| PurchaseProduct | productId | Utrwalony podgląd skonfigurowanego produktu, bez nadania korzyści |
| Prestige | `{}` | Istniejący ProgressActions; klient nie podaje mnożnika ani nagrody |

UpgradeEgg także ma teraz walidowany wynik zgodny z rzeczywistym modułem domeny. Zaufane wystawianie dronów/ofert i realizacja receipt pozostają odrębnymi portami hosta, nie komendami nadania zasobu dla klienta.

Każda terminalna odpowiedź uruchamia odświeżenie własnego widoku. Prywatna sekcja `farm.progress` zawiera GE/SE/PE, postęp kalendarza, listę odebranych trofeów i ograniczoną listę petów z rzeczywistymi UID. Nie zawiera tokenów, rejestru operacji ani danych innych graczy; publiczny widok jej nie otrzymuje. Pierwsze 32 UID są sortowane deterministycznie, bieżący panel pokazuje pierwsze cztery; pełne stronicowanie ekwipunku pozostaje ograniczeniem UI.

UI nie podmienia materiałów fuzji po zmianie stanu. Kliknięcie nazwy wybiera bazę, kolejne nazwy zaznaczają/odznaczają materiały; ponowne kliknięcie bazy czyści wybór. Zablokowane/wyposażone wejścia trzeba najpierw przygotować. Zniknięcie materiału oznacza odmowę serwera. Wszystkie 19×5 trofeów jest dostępnych w przewijanym panelu, a wynik/odmowa trafia do komunikatu HUD.

## Referencje i uczciwa niedostępność

`tools/generate_action_catalog.py --check` porównuje wygenerowany moduł ActionReferenceData z niezmienionymi JSON-ami kalendarza, wszystkich 95 trofeów i końcowych cen 24 badań Epic. Serwer używa tych danych zamiast częściowych fixture'ów modułów liściowych. REFERENCE_ONLY nadal nie zatwierdza konfiguracji wydania.

Obsłużono GE, SE, PE, boosty z rotacją, poziomy Epic z konwersją nadmiaru oraz surowy Piggy/poziom Piggy. Pięć nagród skaluje się z cyklem i właściwym capem; dzień 28 zmienia PE na 100000 GE od cyklu 25. Liczby boostów i nowe przyrosty Piggy używają ExactUInt, z odczytem wcześniejszego bezpiecznego formatu liczbowego. Odbiór/znacznik/wynik to jeden zapis z ochroną replay.

**Nie domknięto resolvera dni 4/10/15/18/22.** Typów cash zależnego od kontekstu i typu 14 nie zastępuje się arbitralnym 5000 cash lub inną nagrodą. Odpowiedź FEATURE_UNAVAILABLE niczego nie wypłaca i nie przesuwa dnia. Nowe konto zatrzyma kalendarz na dniu 4 — [#62](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/62) pozostaje warunkiem wydania.

Fuzja i zakup boostu mają testowy port konfiguracji wyłącznie z `mode=INTERNAL_TEST_ONLY`. Nie uruchomiono fixture'owych cen/receptur na produkcyjnym Main. Przed włączeniem fuzji trzeba wdrożyć wymagany przez 28 serwerowy podgląd/quote z potwierdzeniem, a następnie zatwierdzoną konfigurację w odrębnym zakresie. expectedRevision nie zastępuje quoteId. Obecna komenda w konfiguracji domyślnej zwraca FEATURE_UNAVAILABLE. Testy wewnętrzne weryfikują atomowość i reguły fuzji, nie gotowość tej funkcji do premiery.

## Zakupy Robux

HUD nie uruchamia już niezależnie płatności dla fikcyjnych ID 1001/2001. Main serwera przyjmuje wyłącznie jawnie skonfigurowane atrybuty `<catalogId>_PlatformId` dla Pro/Buy MAX i paczek GE; bez nich podgląd jest niedostępny. Piggy nie jest udostępniany przez tę ścieżkę. Nie ustalono nowych cen Robux lub ilości GE.

PurchaseProduct zatwierdza **podgląd**, nie zakup. Wyświetla się osobne potwierdzenie z warunkami serwera; dopiero potwierdzenie otwiera natywne okno. Sam podgląd, anulowanie i zamknięcie okna nie nadają zasobów. Pro wymaga ustalonego wyniku polityki; wariant A ma ujawnione niedostępne +10 p.p. przed otwarciem zakupu. Brak odpowiedzi polityki blokuje podgląd Pro. Ponowna odpowiedź tej samej operacji nie otwiera kolejnego okna.

Zaufana realizacja korzysta z istniejącego ProcessReceipt/obsługi gamepassów. To nie jest pełne domknięcie historycznych problemów uprawnień #58 ani potwierdzenie działania płatności w Roblox. [MarketplaceService — oficjalne zasady promptów i ProcessReceipt](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService).

## Utrata odpowiedzi

PENDING i UNKNOWN zachowują callback operacji. Odmowa osobnego zapytania o status nie jest odmową pierwotnej operacji i nie usuwa jej callbacku. Odczyt rejestru po utracie ACK może potwierdzić zapis, podczas gdy aktor wciąż ma starszy snapshot i jest zablokowany. Gateway zwraca wtedy UNKNOWN/RECOVERY_REQUIRED, zamiast tworzyć sprzeczny wynik z nowszą resultRevision i starszą currentCommitRevision. Odzyskanie własności/stanu wymaga portu hosta, bez łamania lease. Po odzyskaniu ponowienie zwraca zapisany wynik bez ponownej wypłaty.

## Dowody i granice

Nowa warstwa `tests/game_behavior/run.luau` ma 2012 asercji opartych na oczekiwanym zachowaniu: rzeczywisty Bootstrap klienta/serwera, transport, protokół, koordynator i storage z kontrolowanym zegarem. Nie zastępuje domeny sukcesowym stubem. Porównuje wypłaty z osobno wczytanymi JSON-ami i prostymi niezależnymi równaniami; sprawdza też brak zmian, izolację, granice, utratę ACK i replay. Zmieniono trzy wcześniejsze testy UI wymagające zmyślonych UID na wymaganie braku akcji bez rzeczywistego wyboru.

Testy mutacyjne wykonują odizolowane kopie w build/: lokalny fikcyjny sukces, usunięta trasa trofeów, wyłączenie obu zabezpieczeń UTC, zbyt mała populacja, darmowe materiały fuzji, kredytowanie zamiast pobrania GE oraz zawyżona wypłata trofeum. Błąd składni/importu nie liczy się jako wykrycie. To siedem wybranych wad semantycznych, nie wynik procentowego pokrycia całej gry.

Uruchomienie pełnego zestawu: `./tools/test.ps1 -PythonExecutable python -MutationChecks`. Wynik końcowy: **31 zestawów, 69 953 asercje PASS L**, w tym 2012 nowej warstwy; wszystkie siedem wybranych mutacji wykryte. Build powstaje przed testami korzystającymi z mapowania, także przy pustym build/. [Zapis weryfikacji i sumy kontrolne](action_wiring_56_verification.json). Dokumenty 17–21 i dane referencyjne porównano bajtowo z wersją bazową: bez zmian.

Mapa zakresów i ograniczeń: [testy zachowania](../../tests/game_behavior/README.md). Historyczny audytor REL-01 nadal drukuje szerokie deklaracje gotowości opisane w #60; nie są dowodem testów Studio/chmury ani gotowości całej gry. W tej dostawie wykonano poziom L i statyczne mapowanie 39 modułów/2 entrypointów.
