---
name: hte-validate-studio
description: Validate HatchTheEgg behavior requiring Roblox Studio scenes, client/server replication or runtime timing. Not for documentation-only, pure-math checks or authorizing publishing and cloud tests.
---

# Walidacja HatchTheEgg w Studio

Zastosuj tylko gdy zadanie potrzebuje faktycznej sceny, repliki, klientów lub czasu runtime. Przeczytaj odpowiedni zakres i poziomy dowodu z [workflow](../../../docs/workflow/WORKFLOW.md). Skill nie uruchamia testu poza aktualnym zleceniem.

## Procedura

1. Ustal oczekiwane zachowanie, najmniejszy scenariusz, testowane źródła/wersję i istniejące narzędzie. Nie wymyślaj nazw runnerów ani działającej automatyzacji, której nie ma w projekcie.
2. Zidentyfikuj właściwą instancję, jej bieżącego użytkownika i tryb danych. Nie zatrzymuj cudzego playtestu. Jedna instancja ma jednego wykonawcę w danym czasie; brak pewności własności blokuje dotykanie tej instancji, nie całą niezależną pracę.
3. Sprawdź zgodność źródeł i sceny (w tym statyczną granicę modułów `ReplicatedStorage/HatchTheEgg/Shared` vs `ServerScriptService/HatchTheEgg` weryfikowaną przez `tools/verify_build.py`). Dobierz celowane kontrole; nie odpalaj całego walkthrough progresji z powodu zmiany koloru lub etykiety. Nie ignoruj dotkniętej usterki tańszego sprawdzenia.
4. Wykonaj uzgodniony test. Potwierdzaj autorytatywny stan na serwerze, a widok na kliencie. Używaj sygnałów ukończenia i zegara testowanego systemu; sleep lub screenshot nie dowodzi poprawnego naliczenia.
5. Zapisz liczbę klientów/serwerów, tryb local/mock/DEV-cloud, wejścia i faktyczne wyniki. Studio lokalne nie dowodzi trwałej chmury. Test serwera nie dowodzi czytelności UI.
6. Zakończ własny Play i usuń własne tymczasowe fixture, oddając instancję w uzgodnionym stanie. Przy niepewności cleanup opisz pozostały stan; nie deklaruj czystego zakończenia.

## Wynik i granice

Gdy zlecona walidacja dotyczy wydania lub narzędzi developerskich, sprawdź w konfiguracji wydania brak testowych remotes i serwerowych handlerów przyznających zasoby lub obchodzących reguły gry. Sam brak debugowego UI nie jest dowodem izolacji. Kontroluj właściwą konfigurację i dostępne źródła bez publikowania na produkcję; test lokalny nie dowodzi konfiguracji faktycznie opublikowanej. Zwykła diagnostyka nie jest automatycznie narzędziem przyznającym przywileje.

Użyj [raportu](../../../docs/workflow/TASK_TEMPLATES.md) z dowodem i wersją plików. Nie zmieniaj źródeł tylko po to, by kontrola przeszła, i nie ukrywaj nieudanych prób.

Nie dziedzicz place/universe/namespace ze źródłowego GrowASnack. Skill nie pozwala publikować, tworzyć produktów, wydawać Robux, zmieniać produkcyjnych danych ani delegować testów. Zlecenie planowania lub utworzenia skills nie jest zleceniem uruchomienia Studio. Nie zmieniaj odłożonego bilansu i docs/17–21.
