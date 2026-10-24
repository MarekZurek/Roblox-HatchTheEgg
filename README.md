# HatchTheEgg

Projekt gry Roblox. Wykonano **IMP-01–09: warsztat, NumericCodec, katalog, protokół, repozytorium sesji oraz produkcja, IHR, wylęg/RCB, koordynator i neutralna symulacja czasu**, z testami lokalnymi L. Uruchomienie farmy i integracje sieci/sceny pozostają zaplanowane.

- [Bieżące uruchomienie, API i ograniczenia](docs/39_imp08_imp09_delivery.md)
- [NumericCodec](docs/36_imp01_numeric_codec_delivery.md)
- [Specyfikacja](docs/CURRENT_SPEC.md)
- [Indeks docs](docs/README.md)
- [Backlog](docs/32_parallel_delivery_backlog.md)
- [Issues i zależności](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/1)
- [Workflow i skills](docs/workflow/README.md)

W PowerShell: ./tools/bootstrap.ps1, następnie ./tools/test.ps1 -PythonExecutable python (Python 3.10+, stdlib). Narzędzia trafiają lokalnie do ignorowanego .tools, wyniki do build. Weryfikacja L nie oznacza testów Studio lub DataStore.

REFERENCE_ONLY nie jest konfiguracją wydania. Bilans pozostaje odłożony. Issue nie jest automatycznym zleceniem realizacji lub publikacji gry. [Zakres kopii publicznej](PUBLIC_EXPORT.md).
