# IMP-08 i IMP-09 — koordynator i neutralna symulacja czasu

24.10.2026. Wykonanie zleconych modułów serwera i testów lokalnych L. [Kontrakt stanu i czasu](27_numbers_time_and_player_state_contract.md), [granice modułów](28_modules_and_client_server_contract.md), [sesje](34_pre02_sessions_and_retention.md) oraz [dotarcia](35_pre03_routes_and_arrivals.md) pozostają podstawą. Bilans 17–21 i dane referencyjne nie zostały zmienione. Wewnętrzny tryb testowy nie zatwierdza konfiguracji premiery.

## IMP-08 — jeden autor stanu

[PlayerCoordinator](../src/server/PlayerCoordinator.luau) otrzymuje nabyty handle SessionRepository, ten sam port Clock, NumericCodec/PersistenceData, jawny techniczny maxQueue oraz porty simulation.advance i domain.apply. Nie pobiera usług, nie uruchamia schedulera ani handlerów sieciowych przy imporcie.

submit, tick, checkpoint, renew i release przechodzą przez drain. Wyłączność obejmuje także oczekiwanie na repozytorium; drugi drain nie zaczyna równoległej mutacji. Porty liczenia i domeny nie mogą yieldować. Repozytorium może powtarzać transformację zapisu, ale nie losuje wtedy ponownie ani nie wywołuje domeny. Szczegółowe API i ograniczenia: [notatka IMP-08](workflow/imp08_notes.md).

PENDING wskazuje śledzoną pracę, a NOT_ACCEPTED odmowę przyjęcia. Zapisany wynik i konflikt treści ID mają pierwszeństwo przed gotowością oraz bieżącą revision. QueryStatus nie wykonuje operacji. UNKNOWN zatrzymuje mutacje i wymaga odczytu oraz nowej potwierdzonej generacji sesji; utrata lokalnej kolejki nie pozostawia wiecznego PENDING. Wykluczenie starego autora poprzedza rozstrzygnięcie braku wykonania.

Trwały snapshot jest oddzielony od working. Revision oznacza trwałą bazę, więc sam tick jej nie unieważnia. Zwykłe odrzucenie domenowe zapisuje wynik odrzucenia bez korzyści, zachowując rozliczony postęp w working do późniejszego checkpointu. Częściowe rozliczenie blokuje nowe komendy, ale pozwala kontynuować tick i zapisać spójny checkpoint.

Każda lokalna mutacja sprawdza potwierdzoną sesję i zegar; ostrożne zatrzymanie następuje najpóźniej 20 s przed endsAt według 34. Host odpowiada za odnowienia; nie dodano automatycznego timera. RuntimeElapsed służy kontroli zegara, nie drugiemu naliczeniu dochodu.

## IMP-09 — stały okres i siatka kroków

[TimelineSimulation](../src/server/TimelineSimulation.luau) składa istniejące moduły produkcji, wylęgu i IHR. begin zamraża stan wejściowy, start/cel UTC i neutralną konfigurację. advance przyjmuje budżet faz, nie limit należnego czasu. Obsługiwane są wyłącznie neutralne warunki pierwszej farmy; pełne boosty, pety, wydarzenia i historia uprawnień należą do osobnych zadań.

Gałąź online obowiązuje dla przerwy <=60 s bez ograniczenia silosami. Away dla >60 s zamyka grupy w drodze, ogranicza produkcję do siloOwned × (3600 + 360 × level) i stosuje dochód 0.5 bez Pro albo 1 z Pro. Po zakończeniu zamyka cały okres ścienny, również czas bez produkcji po limicie. Cofnięcie zegara nie daje dochodu ani nie cofa settledWallThrough.

Każdy krok używa dt=min(remaining,0.3), w tym ostatniego krótszego kroku. Kolejność: neutralne księgowanie managera, produkcja ze starej populacji i transport, dochód, dotarcia, refill, IHR. Wzrost zaczyna produkować w następnym kroku. Gotówka portfela i akumulator zarobionego przychodu są oddzielne; koszt wcześniejszego zakupu nie zmniejsza przychodu sesji.

Checkpoint może zakończyć pracę w fazie AFTER_PRODUCTION. Zawiera już naliczony dochód, zamrożony dt oraz cursor; wznowienie wykonuje dotarcia i wzrost bez ponownej wypłaty. Wersjonowany encodeCheckpoint/decodeCheckpoint zachowuje wartości binary64 przez NumericCodec. Nie jest to niezaufany payload klienta ani podpis kryptograficzny. [Format i reguły](workflow/imp09_notes.md).

## Połączenie modułów i dowody

[Test integracyjny](../tests/integration89/run.luau) używa rzeczywistych Coordinator, TimelineSimulation, SessionRepository, ProfileSchema i FarmMath, z kontrolowanym zegarem i storage. Testowy adapter przekształca pamięć–wire, zapisuje ekonomię z checkpointem i odtwarza częściowe away po zwolnieniu sesji i nowym claim. Wynik jest porównany bitowo z przebiegiem nieprzerwanym. Drugi scenariusz gubi odpowiedź po zapisie i sprawdza replay bez ponownego wykonania domeny.

Adapter w tym teście jest **wyłącznie testowy**; nie stanowi wdrożonego bootstrapu, transportu lub pełnego produkcyjnego mostu profilu. Odrzuca aktywne efekty i wyposażone pety przed użyciem neutralnego modelu. Integracja uruchomienia gry pozostaje przy IMP-15, a domena zakupów i Gateway przy IMP-10/11. Nie dodano testowych remotes przyznających zasoby.

Wspólny runner: ./tools/test.ps1 -PythonExecutable python. [Raport wyników, hashy i zakresu QA](workflow/coordinator_timeline_verification.json) opisuje aktualną dostawę. Historycznych manifestów nie przepisano. Testy L i statyczny build nie oznaczają wykonania Studio, prawdziwego DataStore, replikacji, fizyki tras lub typecheckera. Kolejne zadania wymagają osobnego zlecenia; bilans pozostaje odłożony.
