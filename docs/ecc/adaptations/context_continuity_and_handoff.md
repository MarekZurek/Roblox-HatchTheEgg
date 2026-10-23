# Adaptacja: Ciągłość kontekstu, kompakcja i handoff między asystentami

> **Informacja licencyjna i źródło**  
> Źródła pierwotne:  
> - [skills/strategic-compact/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/strategic-compact/SKILL.md)  
> - [skills/unified-memory/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/unified-memory/SKILL.md)  
> - [skills/context-and-decisions/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/context-and-decisions/SKILL.md)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

W ECC ciągłość wiedzy i zarządzanie oknem kontekstowym opiera się na:
- **Strategicznej kompakcji (`/compact`)**: ręczne wywoływanie podsumowania na logicznych granicach zadań (np. po zakończeniu badań, przed kodowaniem), a nie w losowym momencie automatycznego cięcia okna.
- **Zasadzie "Zapisz na dysku przed kompakcją"**: pamięć ulotna i narzędzia todo giną podczas kompakcji; trwały stan to plik na dysku.
- **Ustrukturyzowanym protokole przekazania (Handoff)**: dokumentacja stanu, zebranych dowodów, otwartych pytań i następnego konkretnego kroku.
- **Oddzieleniu terminologii domeny od decyzji architektonicznych**: słownik pojęć biznesowych nie miesza się z technicznym uzasadnieniem kompromisów.

---

## 2. Propozycja adaptacji dla HatchTheEgg

W HatchTheEgg przy projekcie pracują różni asystenci AI (Claude Opus, Sonnet, Gemini itp.) oraz ludzie. Głównym ryzykiem jest:
1. "Gubienie" zatwierdzonych decyzji R (D01–D07, 25, 26).
2. Samowolne wznawianie odłożonego bilansu lub ponowne otwieranie zamkniętych ustaleń
3. Zaśmiecanie okna kontekstowego setkami linii kodu, co obniża jakość myślenia modelu.

### Zasady zarządzania kontekstem w HatchTheEgg:

#### A. Żelazna hierarchia prawdy (Source of Truth)
Każdy nowy asystent rozpoczynający pracę **musi najpierw przeczytać**:
1. `docs/WORKING_CONTEXT.md` — bieżący status, zakazy i granice.
2. `docs/CURRENT_SPEC.md` — rozstrzyganie sprzeczności (N vs S vs R vs P).
3. `docs/TODO.md` — zadania aktywne vs odłożone.

Żadne wnioski wyciągnięte "z pamięci modelu" lub z surowych plików analizy konfiguracji referencyjnej nie mogą unieważnić decyzji oznaczonych jako **R**!

#### B. Strategiczna kompakcja (`/compact`) w HatchTheEgg

| Moment sesji | Czy wywołać `/compact`? | Uzasadnienie |
|---|---|---|
| Po zakończeniu analizy docs / planu | **TAK** | Wnioski zapisano w pliku .md; uwalniamy okno na implementację. |
| W trakcie pisania kodu pojedynczego modułu | **NIE** | Utrata nazw zmiennych i kontekstu edycji grozi błędami. |
| Po zakończeniu Story i pętli weryfikacji | **TAK** | Raport weryfikacji zapisany na dysku; czysty start dla kolejnego Story. |
| Po długim debugowaniu błędu | **TAK** | Usunięcie mylnych śladów i logów błędów przed dalszą pracą. |

---

## 3. Szablon notatki przekazania (Handoff Protocol)

Zanim zakończysz sesję pracy asystenta lub przed wywołaniem `/compact`, zaktualizuj plik roboczy (lub `docs/WORKING_CONTEXT.md`) według szablonu:

```markdown
# Session Handoff — [YYYY-MM-DD HH:MM]

## 1. Wykonane prace w tej sesji
- [Opis zrealizowanych zadań lub modyfikacji dokumentacji / modułów]
- [Status weryfikacji: np. sporządzono szkic testu referencyjnego (Status: NIE URUCHOMIONO) lub link do raportu po faktycznym wykonaniu]

## 2. Decyzje techniczne podjęte w tej sesji (Status P)
- [Opis propozycji technicznych lub link do nowego ADR w docs/adr/, np. ADR-0002 rozdzielający zakres double do 1.79e308, precyzję całkowitoliczbową do 2^53-1 dla dokładnych liczników i zaokrąglenia, bez naruszania wzorów SE i FV]

## 3. Stan zatwierdzonych zasad (Status R)
- Brak zmian w zasadach D01–D07, 25, 26. Odłożony bilans pozostał nienaruszony.

## 4. Następny konkretny krok (Next Action)
- Rozpocząć implementację Story 1.2: `PlayerDataStore.luau` z mechanizmem Session Lock (D07) według adaptacji w `docs/ecc/adaptations/datastore_migration_and_session_lock.md`.

## 5. Otwarte blokady / pytania do użytkownika
- Brak pytań blokujących.
```

---

## 4. Nieaktywne instrukcje dla przyszłych asystentów (Draft)

*(Uwaga: Zgodnie z instrukcją użytkownika, w głównym katalogu projektu nie tworzymy aktywnych plików AGENTS.md, CLAUDE.md ani hooków. Poniższa treść stanowi nieaktywny szkic wytycznych do wykorzystania w promptach startowych)*:

```text
[PROMPT STARTOWY DLA ASYSTENTA HATCHTHEEGG]:
1. Jesteś asystentem inżynieryjnym projektu HatchTheEgg w Roblox.
2. ZASADY ZATWIERDZONE: Dokumenty 22, 25, 26 oraz CURRENT_SPEC.md zawierają decyzje R użytkownika. Nie zmieniaj ich.
3. ZAKAZY: Nie wznawiaj odłożonego bilansu. Nie modyfikuj dokumentów 17–21 ani materiałów roboczych. Nie otwieraj ponownie zamkniętych ustaleń
4. ARCHITEKTURA: Stosuj architekturę heksagonalną (docs/ecc/adaptations/hexagonal_luau_architecture.md). Czysta logika biznesowa nie może zależeć od Roblox API.
5. BEZPIECZEŃSTWO: Serwer jest jedynym źródłem prawdy (docs/ecc/adaptations/server_validation_and_security_checklist.md).
6. TESTY: Każdy krok weryfikuj przeciwko wektorom referencyjnym z dokumentacji.
```
