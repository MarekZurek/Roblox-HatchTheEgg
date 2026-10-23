# F01 — wkład Cline, QA AGY i kontrola redakcji

23.10.2026. Zakres: [30 — manifest pierwszej farmy](../30_first_farm_manifest_and_technical_choices.md), bez implementacji lub wznowienia bilansu. Nie jest to pełny audyt repo ani świadectwo gotowości wykonawczej F01.

## Przekazany zakres i wykonane zadania

Użytkownik jawnie zatwierdził przekazanie skrótu F01 do Cline/DeepSeek oraz dokumentu i potrzebnych fragmentów 27–29 do AGY/Gemini. Nie przekazano kluczy, prywatnego archiwum ani innych plików projektu. Obie analizy były tekstowe, bez narzędzi i modyfikacji projektu przez modele.

- **Cline / DeepSeek v4.1 Flash:** propozycja na podstawie skrótu wybranych ID/parametrów i reguł. Zakończona odpowiedzią, bez wywołań narzędzi. Autor wykorzystał siedem Common i listę niewiadomych; sprawdził ID, poziomy i efekty bezpośrednio w JSON. Odrzucił arbitralny silos, dodatkowe etapy inkubacji, oznaczanie niewiadomych N i mieszanie quoteId/operationId. Nie przedstawia tego jako audytu plików wykonanego przez Cline.
- **AGY / Gemini 3.8 Flash Medium:** pełny tekst pierwszej redakcji 30, fragment typów 27, fragment koperty 28, początek zakresu 29 oraz skrót obowiązujących reguł. Otrzymano rzeczywistą odpowiedź: **CONDITIONAL PASS — cztery sugestie doprecyzowania tekstu**. Nie udostępniono pełnego repo lub wszystkich kontraktów, więc nie jest to pełne porównanie plików.

## Rozpatrzenie uwag AGY

| Sugestia | Ocena autora i zastosowana korekta |
|---|---|
| DTO eggId a farm.eggIndex | Ujednolicono OwnFarmView do eggIndex: SmallIndex od zera. Odmienna nazwa wire sama nie dowodzi błędu, lecz brak jawnego mapowania był zbędną niejasnością. |
| Replay przed expectedRevision | Dopisano lokalnie kolejność, łącznie z wygaśnięciem quoteId i konfliktem argumentów. Zasada już obowiązywała przez odwołanie do 28; nie jest nową luką domenową. |
| Produkcja przed wzrostem i away/silosy | Dopisano kolejność produkcja → wzrost IHR, próg >60 s i limit tylko away. Nie zaakceptowano rozszerzenia tej reguły na nieustalony moment dotarcia ręcznych kur; U03 pozostaje otwarte. |
| Sesja nie serializuje automatycznie wywołań | Dopisano rolę kolejki koordynatora dla komend/ticków/checkpointów/odtworzenia. Pierwsza redakcja już wymagała 28 i odróżniała transport od serializacji; to doprecyzowanie, nie dowód nowego błędu. |

**Stan po redakcji:** autor sprawdził uwzględnienie uwag. Końcowej wersji nie wysyłano ponownie do AGY; nie deklarujemy nowego modelowego PASS. U01–U06 nadal jawnie ograniczają gotowość wykonawczą. Nie testowano codec Luau, sieci, sesji, chmury, Studio ani gry. Oficjalne źródła techniczne wykorzystane przy wyborach P są podlinkowane w 30; nie zmieniają statusu testów.

Kontrola lokalna obejmuje ID/tabele opisane w 30, odnośniki i sumy plików. Historyczne manifesty, 27–28, referencyjne JSON-y, skills i bilans 17–21 nie wymagają regenerowania na potrzeby tego zadania. Wyniki statyczne nie są zaliczeniem A01–A16.
