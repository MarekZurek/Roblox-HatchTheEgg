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

## Kierunek wizualny tej gry

Preferencja użytkownika (26.10.2026): wyraziste, zabawkowe UI Roblox, spójne z farmą. Stosuj czytelne obramowania i kontrastowe nagłówki, przyciski z widoczną głębią i stanami pressed/disabled oraz oszczędny motyw studów. Powtarzaj tę samą rodzinę ramek, ikon i odstępów między sklepem, Daily i pozostałymi oknami. Generyczne karty webowego dashboardu, przypadkowe emoji i mieszanie stylów ikon nie są docelowym kierunkiem. Nie generuj nowych grafik AI bez kolejnego wyraźnego zlecenia; preferuj wybrane zasoby i adaptację istniejących elementów.

Wybrane źródła: [StudUI Lite](https://semajh.itch.io/studui-lite) dla komponentów okien oraz [gvesster Free Icon Pack](https://gvesster.itch.io/free-icon-pack) dla ikon. To preferencja tego projektu, nie automatyczna zgoda na zakup lub import. Sprawdź plik licencji pobranego wydania i zinwentaryzuj zawartość przed użyciem; zachowaj manifest pochodzenia i wymagane kredyty. Lite nie zapewnia gotowego darmowego Daily ani automatycznego dopasowania mobilnego; buduj Daily z adaptowanych komponentów i istniejącej logiki gry. Darmowe ikony dobieraj z dostępnych PNG; nie zakładaj dostępu do płatnych SVG ani wszystkich reklamowanych wariantów. Autor StudUI deklaruje AI Assisted; zachowaj świadomy wybór użytkownika zamiast zastępować paczkę nowo generowaną grafiką.

Najpierw pokaż spójny fragment rzeczywistego okna z docelowymi ikonami, tekstem i cenami. Dobierz skalę tekstur, 9-slice i proporcje ikon bez rozciągania ornamentów. Rozmiar okna wynika z treści i bezpiecznego obszaru, z przewijaniem długich list; sprawdź desktop oraz telefon portrait/landscape, czytelność cen, touch targets, close i stany loading/unavailable/claimed. Zestaw darmowych ramek nie zastępuje tych kontroli. Nie importuj demonstracyjnej logiki sklepu, walut ani Daily z template ponad zlecony zakres.

## Wynik i granice

Przy review dekoracji sprawdź `CanCollide`, `CanTouch` i `CanQuery`. Dla czysto wizualnych części, które nie obsługują interakcji, zaznaczania ani wykrywania, wyłącz te trzy właściwości. Nie stosuj tej reguły zbiorczo do kur, jaj i innych obiektów funkcjonalnych; najpierw ustal ich rolę. Samo ustawienie flag nie jest dowodem poprawy wydajności.

Zwróć krótki brief/ustalenia albo shortlistę reuse/adapt/build z uzasadnieniem. Oddziel obserwację od hipotezy i od subiektywnej decyzji estetycznej użytkownika. Użyj [szablonu](../../../docs/workflow/TASK_TEMPLATES.md) tylko w potrzebnej części.

Zmiana prezentacji nie może niejawnie zmienić czasu/odległości funkcjonalnych, ekonomii, reguł produktu lub zapisu. Liczba renderowanych modeli kur, animacja i klientowskie `Touched` nie są autorytatywną populacją ani czasem dotarcia (o stanie decydują `RouteProvider` i `TimelineSimulation` na serwerze), a skróty formatowania UI (`K`/`M`/`B`) nigdy nie wracają do obliczeń ani zapisu. Research nie uprawnia do płatnego zakupu, importowania nieprzejrzanych skryptów, publikacji lub nowej zależności. Realizuj tylko zlecony artefakt; nie uruchamiaj gry z samej prośby o plan wizualny. Nie zmieniaj docs/17–21 ani nie wznawiaj bilansu.
