---
name: hte-design-visuals
description: Plan or review HatchTheEgg farm scenes, mobile UI and reusable visual assets. Use for visual briefs, concrete scene reviews or asset selection, not gameplay rules, economic tuning or network design.
---

# Projekt i review wizualne HatchTheEgg

Ustal tryb: brief wizualny, ocena istniejącego widoku albo dobór assetów. Przeczytaj właściwe [makiety](../../../docs/ui/ui_design_specification.md) jako P i [zakres premiery](../../../docs/26_approved_launch_scope_and_pro_availability.md). Makieta nie przyznaje nowych funkcji i produktów.

## Procedura zależna od celu

- **Brief:** opisz, co gracz ma rozpoznać i zrobić, hierarchię HUD/prompts, stałe punkty interakcji, sylwetki obiektów i stany odblokowania. Nie kopiuj kolorów, kątów ramp, liczby części lub układu przenośników innej gry.
- **Review:** oceń rzeczywisty render/scenę na odpowiednich stanach: zakrycie tekstu, konkurencję prompts, dotyk, scroll, kontrast i porządek liczb. Sprawdź cleanup po zmianie jaja/prestiżu i rekonstruowanie widoku, jeżeli zmiana ich dotyczy. Pojedynczy desktopowy obraz nie dowodzi czytelności telefonu ani braku migotania.
- **Assety:** najpierw sprawdź istniejące zasoby projektu. Dla nowych kandydatów ustal dokładne źródło, autora, cenę, licencję komercyjnego użycia, wymagania atrybucji i koszt adaptacji. Przy external research sprawdź aktualne źródło; sama etykieta free nie określa praw. Porównaj format, styl, geometrię/tekstury, skrypty i obciążenie mobilne. Brak dobrego assetu nie wymusza zakupu lub adopcji całego template.

## Wynik i granice

Przy review dekoracji sprawdź `CanCollide`, `CanTouch` i `CanQuery`. Dla czysto wizualnych części, które nie obsługują interakcji, zaznaczania ani wykrywania, wyłącz te trzy właściwości. Nie stosuj tej reguły zbiorczo do kur, jaj i innych obiektów funkcjonalnych; najpierw ustal ich rolę. Samo ustawienie flag nie jest dowodem poprawy wydajności.

Zwróć krótki brief/ustalenia albo shortlistę reuse/adapt/build z uzasadnieniem. Oddziel obserwację od hipotezy i od subiektywnej decyzji estetycznej użytkownika. Użyj [szablonu](../../../docs/workflow/TASK_TEMPLATES.md) tylko w potrzebnej części.

Zmiana prezentacji nie może niejawnie zmienić czasu/odległości funkcjonalnych, ekonomii, reguł produktu lub zapisu. Research nie uprawnia do płatnego zakupu, importowania nieprzejrzanych skryptów, publikacji lub nowej zależności. Realizuj tylko zlecony artefakt; nie uruchamiaj gry z samej prośby o plan wizualny. Nie zmieniaj docs/17–21 ani nie wznawiaj bilansu.
