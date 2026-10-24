# IMP-01 — warsztat i NumericCodec v1

24.10.2026. Wykonano zakres [#10](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/10) na polecenie użytkownika: lokalny warsztat, codec i testy L. Nie jest to implementacja farmy ani zgoda na pozostałe IMP-*. Bilans 17–21 i dane referencyjne bez zmian.

## Dostarczone pliki i uruchomienie

- [NumericCodec](../src/shared/NumericCodec.luau) — czysty ModuleScript bez usług, czasu, losu, ekwipunku lub cen.
- [Konfiguracja Rojo](../default.project.json) — tylko ReplicatedStorage/HatchTheEgg/Shared. Zachowuje obce instancje; testy, docs i narzędzia nie są mapowane.
- [Manifest narzędzi](../tools/toolchain.json), [bootstrap](../tools/bootstrap.ps1), [test](../tools/test.ps1) — Windows x86_64, przypięte Lune 0.11.1 i Rojo 7.7.1, sprawdzanie SHA-256. Bez instalacji globalnej lub zmiany PATH.
- [Testy i instrukcja](../tests/numeric/README.md), [runner](../tests/numeric/run.luau), [niezależny generator wektorów](../tools/generate_numeric_vectors.py).

W PowerShell z katalogu projektu: najpierw `./tools/bootstrap.ps1`, potem `./tools/test.ps1 -PythonExecutable python` (w pierwotnym zakresie samego IMP-01 skrypt nie wywoływał jeszcze Pythona; od IMP-02 wspólny runner wymaga Python 3.10+ stdlib do weryfikacji generatorów i statycznego drzewa Rojo). Pierwszy krok wymaga sieci i pobiera oficjalne binaria do ignorowanego `.tools`; drugi wykonuje kontrole generatorów, Lune, lokalny build Rojo i sourcemap. Artefakty w `build` są ignorowane. Wektory mają jawny generator i stały seed, bez zależności od parametrów gospodarki.

Nie skonfigurowano aktywnego miejsca: servePlaceIds jest puste, nie uruchamiano serve ani połączenia ze Studio. Synchronizacja wymaga później wpisania konkretnego dopuszczonego miejsca testowego; nie usuwać tego ograniczenia dla wygody. Build pliku .rbxlx nie publikuje gry. src/server, src/client i scena nie powstały w tym zadaniu; będą dodawane przez swoich właścicieli z mapowaniem opisanym w 33.

## API wersji 1

| Powierzchnia | Wejście / wynik i gwarancja |
|---|---|
| VERSION | 1; konsument zapisuje wersję codec razem z własnym schematem według 27. Codec nie tworzy profilu ani migracji. |
| Real64.validate / encode / decode | Skończony number / tekst dziesiętny. W pamięci binary64, zapis %.17g. Real64 jest podpisany; BigAmount nieujemny. Zero normalizowane do +0. |
| Real64.add / subtract / multiply / divide | Sprawdzane wejścia i wynik finite. Błąd dzielenia przez zero, overflow i podciek mnożenia/dzielenia niezerowych wejść do zera. Bez floor i epsilon. |
| BigAmount.validate / encode / decode i te same operacje | Odrzucenie wartości ujemnej; subtract wymaga saldo>=koszt. Pozostaje referencyjne zaokrąglenie binary64, nie arytmetyka dokładnych groszy. |
| Real64.roundFloat32 | Jawna konwersja buffer f32, ponownie odczytana jako double. Zanik bardzo małego wejścia do zera to zamierzona konwersja IEEE, nie zachowanie serializacji Real64. Overflow do Inf jest błędem. |
| ExactUInt.decode / encode | Kanoniczny ASCII tekst 0 albo cyfry bez zera wiodącego, zakres 0..18446744073709551615. Bez tonumber całego uint64. |
| ExactUInt.fromParts | Dwie sprawdzone całkowite hi/lo z zakresu 0..4294967295; wynik jest zamrożony. Wewnętrzna reprezentacja nie jest formatem wire. |
| ExactUInt.add / subtract / compare | Dokładny wynik bez zawijania lub mutacji wejść; compare zwraca -1/0/1. Overflow i ujemny wynik są błędami. |
| ExactUInt.fromSafeNumber / toSafeNumber | Wyłącznie całkowite 0..9007199254740991; nawet reprezentowalne 2^53 jest odrzucane tą ścieżką. |
| ExactUInt.toReal64Rounded | Jawna konwersja do binary64 nearest-even oraz drugi wynik exact:boolean. Nie zastępuje dokładnego stanu. Np. 2^64−1 zaokrągla się do 2^64 z exact=false. |

Parser Real64 dopuszcza dziesiętną mantysę z opcjonalnym minusem i częścią ułamkową oraz opcjonalny e/E z całkowitym wykładnikiem. Odrzuca whitespace, plus przed mantysą, hex, locale comma, NaN/Inf i tekst dłuższy niż 64 bajty. Własny encoder mieści się w tym limicie. Niezerowy tekst zaokrąglony do 0 jest DECIMAL_UNDERFLOW; tekst -0 normalizuje się do +0. Wejściowe warianty dziesiętne mogą być niekanoniczne; encoder nadaje wersjonowany format. ExactUInt ma odrębny ścisły format bez wykładnika.

Błędy są synchronicznymi wyjątkami z prefiksem NumericCodec/ i stabilnym kodem, np. NON_FINITE, INVALID_DECIMAL, UINT64_OVERFLOW, UINT64_UNDERFLOW, UNSAFE_INTEGER lub INSUFFICIENT_AMOUNT. Konsument przechwytuje je na granicy operacji i nie zapisuje częściowego stanu; codec sam nie obciąża salda. Nie wolno traktować całej treści komunikatu wraz ze ścieżką pliku jako protokołu sieciowego.

## Decyzje i granice numeryczne

Zachowano [27](27_numbers_time_and_player_state_contract.md): binary64 dla kwot i SE, dokładne części uint32 dla liczników, wire tekstowy i jawne lokalne float32. Potrącenie 1 od 1e20 może zwrócić 1e20 zgodnie z referencyjną arytmetyką; test ten zachowuje, nie naprawia bilansem lub epsilonem. Minimalna dodatnia subnormalna binary64 zachowuje bity przy serializacji. Wzory FV/SE, progi badań, clock adapter i inicjalizacja konta są poza NumericCodec; ich zakresy i testy należą do odpowiednich IMP/NEXT.

Sprawdzono Lune oraz budowanie Rojo. Nie uruchomiono analizy typów osobnym luau-analyze, Studio, synchronizacji, wielu klientów ani DataStore. Dyrektywa strict w module nie jest deklaracją wykonania typecheckera. Sam test L nie dowodzi identycznego działania innego przyszłego runtime; test S pozostaje przy integracji. Szczegóły dowodów i hashy: [raport](workflow/numeric_codec_verification.json).

Podstawy API: [biblioteka Luau — formatowanie i buffer IEEE-754](https://luau.org/library/), [format projektu Rojo](https://rojo.space/docs/v7/project-format/). Znaczenie allowlist sprawdzono w [ApiContext przypiętego Rojo 7.7.1](https://github.com/rojo-rbx/rojo/blob/v7.7.1/plugin/src/ApiContext.lua); nie jest to test połączenia ze Studio.

## Aktualizacja warsztatu po IMP-02/03/07

[37](37_imp02_imp03_imp07_delivery.md) rozszerza runner o katalog, protokół, persistence i statyczną kontrolę mapowania. Pełny runner wymaga teraz Python 3.10+ przez parametr -PythonExecutable. Pierwotny raport IMP-01 pozostaje snapshotem, nie aktualną sumą zmienionego tools/test.ps1; sam NumericCodec nie został zmieniony.
