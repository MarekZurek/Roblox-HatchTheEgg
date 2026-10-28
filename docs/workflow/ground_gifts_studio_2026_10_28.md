# Prezenty — lokalny odbiór Studio, 28.10.2026

Wynik: **PASS w zleconym zakresie** — naturalny generator, brak odbioru w powietrzu, automatyczny odbiór przez bliskość po lądowaniu i znikanie nieodebranego prezentu po 15 sekundach na ziemi. Źródła: `d570bebabcdd18aa002d3c9a035d19aad7847819`. [Surowe zdarzenia, sondy i pomiary](ground_gifts_studio_2026_10_28.evidence.json).

## Środowisko i metoda

Jedna instancja `HatchTheEgg.rbxlx`, początkowo Edit; jeden lokalny serwer i jeden klient (`theZuraz`). PlaceId=0, `Main.UseLocalMemoryStore=true`: bez trwałego postępu i zakupów platformowych. Zsynchronizowano i porównano tekst wszystkich 45 skryptów (43 moduły, 2 entrypointy); nie zakładano zgodności pozostałej sceny z HEAD. Świat w Play zbudował właściwy kod gry.

Sondy dopisane tymczasowo do końca Main odczytywały rzeczywisty Bootstrap, snapshot koordynatora i aktywne modele klienta. Logowały zdarzenia z zegara serwera oraz czasu klienta. Nie podmieniano RNG, generatora, zegara ani reguł odbioru; nie przyznawano nagród poleceniem testowym. Postać została ustawiona z dala od prezentów, a następnie pod drugim prezentem w czasie spadania. Do trzeciego podeszła przez `Humanoid:MoveTo`, uruchomione po lądowaniu. Ruch był sterowany testem, reguły zbierania pozostały produkcyjne. Ograniczone pętle obserwacji były zakończone wraz z własnym Play.

## Wyniki

| Scenariusz | Serwer | Klient |
|---|---|---|
| Prezent 1, postać daleko | Naturalny spawn, 2500 ms spadania, `expires-landed=15000 ms`; `claimed=false`, brak wypłaty | Model widoczny, lądowanie i tekst „PODBIEGNIJ BY PODNIEŚĆ (15s...)”; zniknięcie 46 ms po terminie serwera, czyli 15,046 s po wyznaczonym lądowaniu |
| Prezent 2, postać pod nim przed lądowaniem | 40 próbek przed lądowaniem bez odbioru; na początku okna lądowania nadal cash=0. Odbiór 113 ms po lądowaniu, cash=1.0985605596759453 | Model ląduje, następnie znika po odbiorze; bez kliknięcia |
| Prezent 3, podejście po lądowaniu | Start marszu 1015 ms po lądowaniu, odbiór 3214 ms po lądowaniu. Cash=2.1971211193518907, po jednej nagrodzie dla prezentów 2 i 3 | Model usunięty po odbiorze; HUD `BottomLeftCluster.CashLabel` pokazał `$2.2` |

Wszystkie trzy modele miały zero ClickDetector/ProximityPrompt; zgodnościowy `shootDrone(id,true)` zwracał false i nie usuwał prezentu. Odbiór przez podejście odbył się w prawdziwej pętli Main. Podgląd sceny `GroundGiftFirst` pokazał czerwono-złoty prezent na działce; screenshot sam nie stanowi dowodu wypłaty. Wizualne usunięcie na granicy terminu następuje przy odświeżeniu klienta, nie z dokładnością do pojedynczej milisekundy.

## Uwagi i sprzątanie

- Konsola zgłasza nieprawidłowy typ assetów dźwiękowych `rbxassetid://9069609203` i `rbxassetid://9069609204`. Prezenty i wypłaty działały pomimo braku tych dźwięków; audio wymaga osobnej poprawki.
- Pierwsze próby lokalnego HTTP zakończyły się wyłączonym HTTP / timeoutem. Zastosowano bezpośredni zapis źródeł przez Studio MCP. HttpEnabled przywrócono do false. Początkowa próba odczytu przez `shared` polecenia nie widziała środowiska skryptów; właściwe sondy raportowały przez atrybuty i dopiero ich wyniki zaliczono.
- Własny Play zakończony. Sondy usunięte, ponowne porównanie **45/45 źródeł PASS**, Studio oddane w Edit z UseLocalMemoryStore=true i HttpEnabled=false. Pliki źródłowe gry niezmienione przez tę walidację.
- To lokalne sprawdzenie klienta i serwera, bez publikacji Roblox, odbioru chmury, wieloosobowej izolacji, pełnego audytu UI ani zatwierdzenia wydania. Wcześniejsze dowody Lune i mutacji pozostają osobnymi dowodami; nie powtarzano całej historycznej macierzy.
