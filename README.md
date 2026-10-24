# HatchTheEgg

Projekt gry Roblox. Wykonano i odebrano **IMP-01–15 oraz QA-01: kompletna podstawowa farma domowa (warsztat, NumericCodec, katalog, protokół, repozytorium sesji, produkcja, IHR, wylęg/RCB, koordynator, neutralna symulacja czasu, zakupy, gateway, projekcja widoków, transport i store klienta, trasy 3D, HUD, bootstrap oraz odbiór A01–A16)**. Łącznie 21 914 asercji PASS.

- [Bieżące uruchomienie i odbiór pierwszej farmy](docs/40_first_farm_completion_delivery.md)
- [Poprzednia dostawa IMP-08/09](docs/39_imp08_imp09_delivery.md)
- [NumericCodec](docs/36_imp01_numeric_codec_delivery.md)
- [Specyfikacja](docs/CURRENT_SPEC.md)
- [Indeks docs](docs/README.md)
- [Backlog](docs/32_parallel_delivery_backlog.md)
- [Issues i zależności](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/1)
- [Workflow i skills](docs/workflow/README.md)

W PowerShell: ./tools/bootstrap.ps1, następnie ./tools/test.ps1 -PythonExecutable python (Python 3.10+, stdlib). Narzędzia trafiają lokalnie do ignorowanego .tools, wyniki do build. Weryfikacja L nie oznacza testów Studio lub DataStore.

REFERENCE_ONLY nie jest konfiguracją wydania. Bilans pozostaje odłożony. Issue nie jest automatycznym zleceniem realizacji lub publikacji gry. [Zakres kopii publicznej](PUBLIC_EXPORT.md).
