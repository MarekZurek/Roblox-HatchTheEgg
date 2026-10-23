# Adaptacja: Szablon i przewodnik Architecture Decision Records (ADR)

> **Informacja licencyjna i źródło**  
> Źródło pierwotne: [skills/architecture-decision-records/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/architecture-decision-records/SKILL.md)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

W ECC proces ADR służy utrwalaniu trudnych do odwrócenia decyzji technicznych, które w przeciwnym razie uległyby zapomnieniu w logach czatu lub komentarzach.

### Kluczowe zasady z ECC:
- **Format Michaela Nygarda**: Tytuł, Data, Status, Osoby decyzyjne, Kontekst, Decyzja, Odrzucone alternatywy (z zaletami i wadami), Konsekwencje (pozytywne, negatywne, ryzyka).
- **Cykl życia**: `proposed` → `accepted` → [`deprecated` | `superseded by ADR-NNNN`].
- **Index**: Plik indeksu `README.md` rejestrujący numer, tytuł, status i datę.
- **Kiedy tworzyć**: Przy wyborze technologii, schematu danych, bibliotek zewnętrznych, granic modułów i strategii testowej. Nie tworzyć dla trywialnych zmian kodu ani zmiennych.

---

## 2. Propozycja adaptacji dla HatchTheEgg (Roblox / Luau)

W projekcie HatchTheEgg decyzje gameplayowe i zakres są już skodyfikowane w dokumentach `docs/22_gameplay_rules_for_approval.md`, `docs/25_approved_product_structure.md`, `docs/26_approved_launch_scope_and_pro_availability.md` oraz `docs/CURRENT_SPEC.md` ze statusem **R**.

ADR-y w HatchTheEgg mają służyć **wyłącznie decyzjom inżynieryjno-technologicznym w środowisku Roblox/Luau**, które mają status **P** (propozycja techniczna), aby ujednolicić pracę asystentów AI i programistów bez sprzeczności z zatwierdzonymi zasadami.

### Docelowa lokalizacja w projekcie
Decyzje techniczne zapisujemy w dedykowanym katalogu:
`docs/adr/NNNN-tytul-decyzji.md` z indeksem w `docs/adr/README.md`.

### Wymagane pierwsze ADR-y przed rozpoczęciem implementacji:
1. `ADR-0001-struktura-zapisu-datastore-i-wersjonowanie.md`: klucz gracza, podział na sekcje (farm, inventory, meta), format wersji, token generacji blokady sesji (D07).
2. `ADR-0002-reprezentacja-liczb-precyzja-i-zaokraglenia.md`: rozdzielenie zakresu (do ~1.79e308 w double vs wyższe kwoty), precyzji całkowitoliczbowej ($2^{53}-1$ jako granica dokładnego zliczania dyskretnych jednostek: GE, ekwipunek, gwarancje D01, ID transakcji), tolerancji zaokrągleń oraz serializacji zapisu; zachowanie typu double dla Soul Eggs i wejść ResearchEngine dla Farm Value zgodnie z referencyjnym kodem modelu referencyjnym, bez wyboru biblioteki BigNum przed testami.
3. `ADR-0003-podzial-kodu-klient-serwer-i-network-envelope.md`: organizacja w ServerScriptService / ReplicatedStorage, format odpowiedzi `{success, data, errorCode, userMessage}`.
4. `ADR-0004-ramy-testow-referencyjnych-luau.md`: środowisko uruchamiania testów jednostkowych i asercji referencyjnych (np. TestEZ lub skrypt testowy w Studio) dla wektorów ze specyfikacji.

---

## 3. Szablon ADR dla HatchTheEgg

```markdown
# ADR-NNNN: [Tytuł decyzji technicznej]

**Data**: YYYY-MM-DD
**Status**: proposed | accepted | deprecated | superseded by ADR-XXXX
**Autorzy / Decydenci**: [Rola / Asystent / Użytkownik]
**Powiązanie ze specyfikacją**: [np. CURRENT_SPEC.md sekcja X, D07, itp.]

## Kontekst i problem techniczny

[Opis problemu technicznego w środowisku Roblox/Luau. Jakie ograniczenia platformy
(np. DataStore limit 4MB/klucz, brak typów generycznych w starszym Luau, single-thread task scheduler)
wymuszają tę decyzję?]

## Decyzja techniczna

[Konkretna, jednoznaczna decyzja: jak rozwiązujemy problem w kodzie Luau.]

## Odrzucone alternatywy

### Alternatywa 1: [Nazwa alternatywy]
- **Zalety**: ...
- **Wady**: ...
- **Dlaczego odrzucono**: [Konkretny powód techniczny lub konflikt z zasadami D01–D07]

### Alternatywa 2: [Nazwa alternatywy]
- **Zalety**: ...
- **Wady**: ...
- **Dlaczego odrzucono**: ...

## Konsekwencje dla implementacji

### Pozytywne
- [np. Łatwość testowania w izolacji bez Roblox Studio API]
- [np. Gwarancja idempotencji operacji]

### Negatywne / Narzuty
- [np. Konieczność manualnej serializacji danych]
- [np. Dodatkowa warstwa abstrakcji nad RemoteEvents]

### Ryzyka i mitygacja
- **Ryzyko**: [np. Throttling DataStore przy częstych zapisach]
- **Mitygacja**: [np. Buforowanie w pamięci serwera + Flush przy PlayerRemoving i BindToClose]
```
