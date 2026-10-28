# Naprawa dźwięków prezentów — 28.10.2026

**PASS w lokalnym Studio.** Baza: d570beb; zmiana dotyczy wyłącznie domyślnych assetów `coin` i `pop` w AudioController. [Surowe wyniki i sondy](gift_audio_2026_10_28.evidence.json), [odtwarzalny test native](../../tests/audio/README.md).

## Przyczyna i zmiana

MarketplaceService potwierdził, że stare9069609203 i9069609204 są assetami typu9 (Place), zamiast typu3 (Audio). Stąd komunikat „Asset type does not match requested type” przy odbiorze prezentu. Zastąpiono je darmowymi assetami Creator Store:

- `coin`: [Coin Collect — G00byBBQSauce](https://create.roblox.com/store/asset/135483737426662), 0,874 s.
- `pop`: [Pop Sound Effect — Siegegeddon](https://create.roblox.com/store/asset/140323850218372), 0,202 s.

Nie zmieniano wyzwalania efektów, logiki prezentów, nagród, głośności ani pozostałych domyślnych dźwięków. Te same dwa efekty są używane również przez popup zwykłej paczki.

## Dowody

Jeden serwer i jeden klient, HatchTheEgg.rbxlx, PlaceId=0, Main.UseLocalMemoryStore=true. Stan początkowy Edit; uruchamiano i kończono własne Play.

Test native sprawdza typ Audio, preload Success, IsLoaded, dodatnią długość, Played, postęp TimePosition i usunięcie przy końcu odtwarzania. Osobne semantyczne cofnięcie każdego ID do starego Place daje właściwy FAIL dla coin/pop; poprawna wersja ponownie PASS. Nie jest to test zgodności literalnych ID ani liczników Lune. Pierwsze próby w Edit nie dawały wiarygodnego postępu odtwarzania; przeniesiono test na klienta Play. Odczyt Ended obserwatora był odłączany przez wcześniejsze Destroy w handlerze kontrolera, dlatego finalny test obserwuje postęp i czas życia instancji. Te wcześniejsze nieudane próby nie są zaliczone jako dowód regresji produktu.

W odrębnym Play z normalnym Main naturalny prezent `gift-1-1793219553833-1` wylądował o1793219556334. Postać podeszła przez Humanoid:MoveTo; serwer potwierdził odbiór o1793219559032 i cash1.0985605596759453. Klient odebrał jeden DroneRewardPopup i utworzył dokładnie jeden SFX_pop oraz jeden SFX_coin o1793219559033:

| Efekt | IsLoaded | Maks. TimePosition | Maks. PlaybackLoudness | Volume / SoundGroup.Volume | Cleanup |
|---|---|---|---|---|---|
| pop | true | 0,192 s | 380,58 | 1 / 0,8 | tak |
| coin | true | 0,874 s | 78,66 | 1 / 0,8 | tak |

Konsola tej próby zawierała tylko informację o pamięci lokalnej; brak błędów ładowania dźwięków. Pomiary potwierdzają rzeczywiste odtwarzanie i niezerowy dekodowany sygnał, bez deklaracji subiektywnego odsłuchu lub nagrania wyjścia systemowego.

Lune: UI452 oraz gift_drops103 asercje PASS. Rojo build i mapowanie43 moduły+2 entrypointy PASS_STATIC_BUILD; git diff --check bez błędów whitespace. Celowane testy wystarczyły dla zmiany dwóch referencji; nie powtarzano całej historycznej macierzy testów/mutacji.

## Stan końcowy

Własny Play zakończony, wszystkie sondy usunięte. Dotknięte trzy źródła Studio (AudioController i oba Main) ponownie porównane z plikami; Main klienta włączony. Studio pozostaje Edit, UseLocalMemoryStore=true, HttpEnabled=false, bez folderu testowego audio. Bez publikacji Roblox, chmury, zakupów, commitu i pushu. Dostępność w opublikowanym universe wymaga osobnej kontroli tego środowiska.

SHA256 plików weryfikowanych: AudioController `00a247e3f002117a59a04012ae4698b689bc39046af4de4368dd859e94364c9c`; test native `078c97933851c5e9737c76daba31a6e7eaf28b93cb24746c98d29e6361011b28`.
