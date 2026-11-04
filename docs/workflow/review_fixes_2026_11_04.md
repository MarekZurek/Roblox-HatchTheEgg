# Naprawy po review — 04.11.2026

Zakres: ostatnie zmiany do `a94b85c7d85cabe6dd1745681f9abc90e22fd6aa`, poprawione lokalnie bez commitu ani publikacji. Zlecenie: naprawić błędy, opisy, checklistę i testy, zachowując ceny i balans.

## Obowiązujące doprecyzowanie

Użytkownik pozostawił dzień 28 jako **Mystery** bez nagrody zastępczej. Zachowano dotychczasową wypłatę: PE w pierwszych 24 cyklach, następnie istniejące GE. Nie usuwano zapisanych PE ani ich dotychczasowego wpływu. To świadomy wyjątek od szerszego odłożenia prezentacji PE w #105, nie implementacja nowej nagrody.

## Wykonane zmiany

- Wspólna dostępność blokuje nowe zakupy `prophecy_bonus` za diamenty i jednostki Robux. `ClaimTrophy` zwraca `FEATURE_UNAVAILABLE`; UI nie otwiera zakładki ani nie wysyła odbioru przez zachowane ukryte przyciski. Istniejące dane pozostają zachowane.
- PRO opisuje 18h/100% offline i 5 boostów, a niedostępną fuzję i jej bonus +10 punktów procentowych ujawnia przed zakupem. Podgląd nie deklaruje aktywnego bonusu fuzji. Polityka konta i zapisane uprawnienia nie są usuwane. Osobne opcjonalne pole odpowiedzi `paidRandomAllowed` zachowuje kontrolę zmiany polityki przed potwierdzeniem; brak aktywnego bonusu nie blokuje zakupu podstawowego PRO. Kontrakt pola dopisano do 28; nie jest to argument klienta ani uprawnienie do wypłaty.
- Zakup boostów ma status SOON i nie wywołuje komendy. Aktywowanie posiadanych boostów zachowano.
- Soul Food i Prestige Bonus odnoszą się do Soul Eggs. Soul Beacony opisują mnożnik dochodu wejściowego do prestiżu, bez obietnicy mnożenia diamentów lub liniowego mnożenia końcowych Soul Eggs.
- `ui/HoldToBuy.luau` rozdziela obsłużone wciśnięcie wskaźnika od `Activated`; puszczenie nie dodaje zakupu. Harmonogram 0,35s/0,20s zachowano. Gamepad nie jest tłumiony czasowym debounce od ostatniego kliknięcia myszy.
- Checklista wymienia aktywne `epic_upgrade_9/19/39/79`, dziewięć atrybutów Number skryptu Main oraz kontrole ponowienia płatności. Usunięto błędne hasło bonusu dużego pakietu. Dotychczasowe propozycje cen passów/pakietów i aktualne ceny próbne Epic pozostały niezmienione.

## Oczekiwania i dowody regresji

| Wymaganie / źródło | Niezależne oczekiwanie | Dowód przed / po |
|---|---|---|
| Odłożenie #105 w CURRENT_SPEC | Brak obciążenia i nowych poziomów `prophecy_bonus`; brak wypłaty trofeum | Przed: zakup za diamenty i odbiór trofeum APPLIED. Po: REJECTED, powtórka bez obciążenia, zachowane jednostki Robux |
| Rzeczywista oferta, TODO: produkcyjna fuzja i zakup boostów odłożone | SOON bez komendy zakupu; PRO nie deklaruje aktywnego bonusu fuzji | Przed: aktywny BUY i `paidBonusAvailable=true`. Po: blokada i jawny opis |
| PRO bez aktywnej fuzji; świeża polityka przed monitowaniem | Oba znane warianty polityki mogą potwierdzić podstawowy PRO; zmiana polityki nadal blokuje stary podgląd | Izolowane przywrócenie starego porównania klienta: FAIL expected 1 prompt, got 0. Po: PASS; pro_policy 207 PASS |
| Nazwy domeny SE/GE i działanie dimension 9 | Soul Eggs dla badań; Prestige Earnings dla Beaconów | Przed: Golden Eggs. Po: właściwa waluta / wejście prestiżowe |
| #103: jeden zakup na wciśnięcie, start serii po 0,35s | Po puszczeniu w 0,32s: 1 zakup. Po 0,6s: 3 zakupy. Puszczenie nie dodaje czwartego | Przed: odpowiednio 2 i 4. Po: 1 i 3 |
| Niezależne aktywowanie gamepadem po anulowaniu myszy | Gamepad wykonuje własną akcję; seria myszy pozostaje zatrzymana | Przed: akcja gamepada stłumiona. Po: oddzielna akcja |
| Instrukcja konfiguracji zgodna z Main/EpicPricing | Każdy wymagany atrybut i aktywny produkt Epic obecny w tabeli; brak fałszywego +50% | Przed: 3 testy Python FAIL. Po: 3 PASS |
| Decyzja użytkownika 04.11: zachować Mystery | Przy 27 odbiorach i 7 PE: Mystery w UI, po odbiorze 8 PE, po powtórce i reconnect nadal 8 | Ten sam przypadek PASS przed i po; kontrola zachowania, nie wykryta regresja |

Nowy zestaw `tests/review_fixes/run.luau` uruchomiono przed zmianą źródeł: **8 przypadków FAIL**, prawidłowe błędy asercji, bez błędu importu. Następnie powtórzono test w izolowanej kopii źródeł `a94b85c`: ponownie te same 8 FAIL, przy zachowanym PASS Mystery i zatrzymaniu na wyłączonym przycisku. Stara funkcja hold była wykonywana bez zmiany jej logiki, z kontrolowanym zegarem i schedulerem. Nowy moduł wykorzystuje te same sekwencje zdarzeń. Dodatkowo w izolowanej kopii przywrócono semantyczny błąd porównania potwierdzenia PRO (`~=response.result.paidBonusAvailable` zamiast porównania polityki); test rzeczywistego klienta odrzucił ten wariant właściwą asercją liczby monitów. Kopie testowe usunięto po zebraniu wyników.

Polecenia celowane:

```powershell
& .\.tools\lune-0.11.1\lune.exe run tests/review_fixes/run.luau
& 'C:\Users\Marek\AppData\Local\Python\pythoncore-3.14-64\python.exe' tests/review_fixes/test_checklist.py
```

Wynik po poprawce: **78 asercji Luau PASS, 3 testy checklisty PASS**. Zaktualizowano również istniejące testy UI, podglądu Pro i Epic oraz mapowanie nowego modułu. Test integracyjny trofeów sprawdza odmowę wszystkich 95 produkcyjnych ścieżek, zachowując referencyjne oczekiwania nagród w izolowanych kopiach domeny. Test `game_behavior` przechodzi 2296 asercji. Pełna odpowiedź podglądu PRO jest sprawdzana przez walidator protokołu: skrócony opis mieści się w istniejącym limicie 256 bajtów również dla konta z niedostępnym płatnym modyfikatorem; limitu nie zwiększano. Dane liczbowe katalogów UI/produktów porównano z bazą po wyłączeniu tekstów opisowych: bez zmian. `docs/17–21`, `docs/reference_data`, wygenerowane tabele i `EpicPricing.luau` są niezmienione.

Pełny runner `./tools/test.ps1 -PythonExecutable 'C:\Users\Marek\AppData\Local\Python\pythoncore-3.14-64\python.exe'`: **exit 0**, 55 zestawów Lune PASS, 3 nowe testy checklisty oraz 22 istniejące testy Python PASS, generatory/wyrocznie `--check` PASS, Rojo **46 modułów + 2 entrypointy PASS_STATIC_BUILD**, lokalna kontrola raportów PASS. Pierwsze przebiegi wykryły nieaktualne oczekiwania testów trofeów, zależność testowego portu nagłówka od listy modułów oraz problemy nowego opisu i potwierdzenia PRO; przed końcowym przebiegiem poprawiono wszystkie te przypadki.

[Wersje ocenianych plików, sumy SHA256 i wyniki](review_fixes_2026_11_04.evidence.json). Status: **poprawne w ocenionym zakresie lokalnym**.

## Granice

Lune i kontrolowane adaptery nie dowodzą działania natywnych zdarzeń dotyku, renderowania, rzeczywistych płatności ani trwałości chmury. Nie wykonano nowej sesji Studio ani publikacji Roblox. Kalibracja relacji cen Epic/pakietów pozostaje odłożona. Checklista nie jest akceptacją wydania.
