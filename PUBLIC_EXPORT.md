# Zakres kopii publicznej

24.10.2026. Dokumentacja, skills, referencyjne JSON-y i istniejące makiety PNG. Po realizacji IMP-01/02/03/07 dodano NumericCodec, wybrany katalog wewnętrzny, schematy DTO, repozytorium sesji, ich testy i źródła lokalnego warsztatu. Po IMP-04/05/06 opublikowano także czyste moduły FarmMath, PopulationMath, testy, niezależne wektory uint64 i aktualne docs. Pełna pętla gry i integracje pozostają niezrealizowane. Prywatne archiwum, materiały źródłowe, pobrane narzędzia i wygenerowane pliki build pozostają poza publikacją.

Lokalne ścieżki usunięto wyłącznie w kopii publicznej plików (adresy do plików zastąpiono odnośnikami względnymi):

- docs/workflow/README.md
- docs/workflow/skills_audit_opus.md
- docs/workflow/skills_supplement_audit_opus.md
- docs/workflow/SOURCE_ADAPTATION.md
- docs/workflow/source_snapshot.json

Oryginalne lokalne raporty historyczne pozostały nienaruszone. JSON-y referencyjne i dokumenty odłożonego bilansu zachowano bajtowo. Dawne manifesty opisują historyczne wersje, nie nowe sumy publicznego eksportu. Nie przepisano historii Git.

Po IMP-08/09 opublikowano także PlayerCoordinator, TimelineSimulation, ich testy i test współpracy z repozytorium. Adapter pamięć–wire w teście nie jest produkcyjną integracją; usług chmurowych i Studio nie uruchamiano. Archiwum, binaria i build pozostają poza publikacją.

Po IMP-10–15 oraz QA-01 opublikowano pełną implementację podstawowej farmy: FarmActions, ViewProjector, NetworkGateway, ClientTransport, ClientStateStore, RoutePresentation, IntentControllers, HUD, ServerBootstrap, ClientBootstrap, testy integracyjne pętli gry oraz zestaw 16 scenariuszy akceptacyjnych A01–A16 (21 914 asercji PASS). Archiwum, binaria i build pozostają poza publikacją.
