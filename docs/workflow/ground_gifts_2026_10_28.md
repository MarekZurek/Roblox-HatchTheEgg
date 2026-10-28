# Spadające prezenty i uzupełnienie regresji — 28.10.2026

Baza:34f77932ea115651e27a047c810e59fb4c8fd758. Zlecenie użytkownika: generator prezentów, podejście/dotknięcie wyłącznie po lądowaniu, brak klikania,15s na ziemi, walidacja serwera, cztery wskazane luki testów i dowody FAIL→PASS. Bez zmiany odłożonych docs17–21/danych referencyjnych, publikacji Roblox lub zapisów chmurowych w tej dostawie. Użytkownik następnie zlecił commit i push kodu, testów, dokumentacji oraz dowodów; zdalne SHA jest potwierdzane po wysłaniu.

## Kontrakt i implementacja

- Prywatny GiftDrops korzysta z istniejącego Bootstrap.tick w Main (0.5s), nie dodaje kolejnej pętli. Pierwszy termin10s od gotowej sesji; kolejne bazowe przedziały N/S z docs/06:25%2–8s,75%12–47s. Maksymalnie jeden żywy prezent na właściciela; po przerwie nie ma stosu zaległych wypłat. To użycie bazowych reguł, nie nowa kalibracja ani wznowienie bilansu.
- Serwer wybiera punkt na kanonicznej działce: x=-12/0/12,z=18,y=1.15. Opadanie2.5s; landedAtMs=createdAtMs+2500; expiresAtMs=landedAtMs+15000. Klient otrzymuje punkt i oba terminy; późna klatka/reconnect nie przedłuża okna.
- Odbiór automatycznie po podejściu żywego właściciela w promień6studów, w oknie [landedAtMs,expiresAtMs). Pozycja pochodzi z prawdziwego Character/HumanoidRootPart i jest sprawdzana również podczas zatwierdzania zapisu. Payload nie wybiera pozycji, czasu, właściciela ani nagrody.
- Main blokuje HitDrone z RemoteEvent. Managed GROUND_GIFT wymaga wewnętrznego CollectGift; jego zwykły HitDrone jest odrzucany także w domenie. Z klienta usunięto raycast, ClickDetector, Touch/Prompt claim callbacki. Dotknięcie/podejście działa przez obserwację serwera, nie przez deklarację klienta.
- Wynik nagrody jest losowany i zamrażany przy wystawieniu. Kwoty w fixedReward zapisują się jako kanoniczne teksty ExactUInt/BigAmount, także po JSON roundtrip. Zmiana wydatków pomiędzy wystawieniem a odbiorem nie zmienia nagrody. Kwoty i dotychczasowe formuły nagród nie są kalibrowane.
- Nagroda, claimed i wynik operacji mają jeden commit koordynatora. Ponowienie/utrata odpowiedzi/rejoin nie dają drugiej wypłaty; odrzucona walidacja nie zatruwa kolejnej próby. Popup jest wysyłany dopiero po potwierdzeniu; wizualizacja znika po autorytatywnej projekcji lub terminie, bez optymistycznego odbioru.
- ProfileSchema i ProtocolSchemas sprawdzają nowe pola; historyczne rekordy dronów bez nowego kind pozostają czytelne. W produkcji nie można ich zbierać przez dawny klik. Przy wystawieniu nowego prezentu sprzątane są wyłącznie wygasłe rekordy GROUND_GIFT, bez usuwania księgi operacji/idempotencji. Zwykłe i bonusowe oferty2+1 zachowują własne reguły bez15-sekundowego wygaśnięcia.

## Cztery luki testów

| Wymaganie / źródło | Niezależny fixture i oczekiwanie | Mutacja |
|---|---|---|
| docs/24: rezerwacja należy do tokenu | Zły token odrzucony, RESERVED i właściwy token zachowane, brak wypłaty | Wyłączony TOKEN_MISMATCH przy confirm |
| docs/22 D04/D05 i docs/16: boost do ekwipunku | Nagroda w inventory; effects.boosts nadal puste, także na zwykłym jaju | Automatyczna aktywacja nagrody |
| docs/22 D01:0% nie daje sukcesu | Roll0 przy szansie0 daje porażkę, zachowany bazowy, zużyte kopie, licznik+1; fixture testowy bez zatwierdzania cen/szans premiery | Porównanie roll<=chance |
| docs/16 §1: niezależne wymiary petów | Dla siedmiu archetypów sprawdzane są efekt właściwy i sześć neutralnych pól1 | Alien dostaje dodatkowy bonus elity |

Ich poprawna implementacja istniała; wzmocniono testy, które wcześniej przepuszczały te błędy w kopiach. Zaktualizowano też stary test Main: klik nie daje3GE, osobna paczka nadal daje3GE (10→13), ponowienie nie płaci ponownie. To zmiana źródła oczekiwań zgodnie z bieżącą decyzją, nie dopasowanie do przypadkowego wyniku.

## Weryfikacja

Odtwarzanie: [README testów](../../tests/gift_drops/README.md). Wszystkie mutacje działają w izolowanych kopiach. Celowo nie wyłączano pojedynczej osłony, gdy druga nadal zapewnia prawidłowe zachowanie: mutacja odbioru w powietrzu omija trzy niezależne granice; mutacja podwójnej wypłaty omija claimed w domenie i walidatorze.

Wyniki końcowe:

- `gift_drops`: **103 asercje PASS**. Rzeczywista pętla Main, generator, odbiór i popup; czasy/pozycje, zły stan postaci, świeża walidacja zapisu, retry, fencing/rejoin po utracie odpowiedzi, brak stosu, dokładne kwoty i JSON roundtrip, oba warianty konstrukcji wizualizacji.
- Wzmocnione suite: offers73, fusion108, pet_effects224, presentation451 oraz farm_gaps145 asercji PASS.
- **22/22 wybrane mutacje KILLED**: baseline exit0 → wskazana asercja exit1 → corrected exit0. Obejmują cztery wcześniejsze SURVIVED oraz brak generatora/wywołania w Main, brak automatycznego odbioru, martwą postać, złe odległości/czasy, ominięcie walidacji w commicie, podwójną wypłatę, ponowne wyliczenie zamrożonej nagrody, przedwczesne znikanie, powrót kliknięć, popup oraz niepoprawne okno zapisu/wire.
- `verify_evidence.py`: **PASS**; aktualne hashe testów, źródeł i grafu fixture porównane z użytymi kopiami; pierwszy błąd jest właściwą asercją. Kontrola generatora została dodatkowo wzmocniona po tym, jak początkowo trafiała na nil zamiast kontrolowanego FAIL; nie zaliczano tego jako wykrycia.
- Końcowy `tools/test.ps1 -PythonExecutable C:/Users/Marek/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`: **53 zestawy Luau +11 Python runnera +11 Python raportowania PASS**, exit0. Rojo7.7.1: **43 moduły +2 entrypointy PASS_STATIC_BUILD**. Lune0.11.1, Python3.12.14.
- [Trwały zapis FAIL→PASS](ground_gifts_2026_10_28.evidence.json) zawiera dokładne mutacje, asercje, kody0/1/0, komendy i hashe. Logi lokalne: build/ground_gifts_full.log i build/ground_gift_mutations.log. To22 wybrane mutacje tej dostawy; nie ponawiano całego historycznego zestawu mutacji ani nie deklarowano pełnego mutation coverage gry.

Granice: lokalny Lune/Python oraz statyczny build Rojo. Testy używają prawdziwych modułów i wejścia Main z kontrolowanymi portami, a nie żywych usług Roblox. Bez nowego odbioru Studio, renderera, fizyki, chmury, realnych płatności i zatwierdzenia wydania. Historycznych raportów i dowodów poprzednich dostaw nie regenerowano.
