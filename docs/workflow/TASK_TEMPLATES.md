# Szablony małego zadania i przekazania pracy

**P — stosować proporcjonalnie.** Jeden krótki brief wystarcza; nie trzeba tworzyć issue, pakietu JSON i kilku raportów dla każdej korekty. Szablon nie nadaje uprawnień ani nie uruchamia innego agenta.

## Brief / task

```text
CEL: konkretny wynik użytkowy lub techniczny
ZAKRES ZAPISU: pliki/system, które wolno zmienić
NIE OBEJMUJE: odłożony bilans, sąsiednie funkcje, inne istotne wyłączenia
ŹRÓDŁA: konkretne reguły R/N/S i dane potrzebne do tego zadania
WEJŚCIE / ZALEŻNOŚĆ: brak albo dokładny wymagany rezultat innego zadania
GOTOWE GDY: obserwowalne kryteria tego zakresu
WERYFIKACJA: właściwy poziom dowodu i kontrole; jeśli runner nie istnieje, napisz to
RYZYKO / STOP: konkretna zmiana decyzji R, niezatwierdzonego balansu lub danych
```

Dla przekazania Opusowi/Gemini dopisz rolę (np. review-only) i zakres zapisu raportu. Treść ma być samowystarczalna, ale nie powinna kopiować całej dokumentacji. Zachowaj polecenie użytkownika i stan, nie jego domyślną rozszerzoną interpretację. Delegację lub wysłanie promptu wykonuje się tylko przy właściwej autoryzacji.

## Wynik i dowody / handoff

```text
WYNIK: co rzeczywiście wykonano
STATUS: zaplanowane / wykonane w zakresie / wymaga poprawy / niezweryfikowane
PLIKI / WERSJA: zmienione ścieżki oraz commit albo fingerprint
SPRAWDZONO: faktyczne komendy/narzędzia, wynik i poziom dowodu
NIE SPRAWDZONO: brakujące kontrole wraz z powodem
ZMIANA DECYZJI: brak albo rzeczywista akceptacja użytkownika z odniesieniem
POZOSTAŁO: konkretne nieukończone kryterium, nie nowa lista pomysłów
NASTĘPNY KROK: jedna właściwa akcja w ramach zlecenia
NIE POWTARZAJ: już wykonana kontrola na niezmienionej wersji, jeśli nadal aktualna
```

Domyślna wartość dowodu to **NIE URUCHOMIONO / NIE SPRAWDZONO**, nie PASS. „Wykonane w zakresie” nie oznacza publikacji ani zgody na kolejny etap. Reviewer nie wpisuje za użytkownika „zaakceptowane przez człowieka”.

## Rozbieżność / brak postępu

```text
OCZEKIWANE: konkretna reguła i jej źródło
OBSERWOWANE: objaw oraz poziom dowodu
REPRO: najmniejsze znane wejście i działanie
PRÓBY: co sprawdzono i co nowego wynikało z każdej próby
GRANICA: nieustalona decyzja produktu / odłożony bilans / brak możliwości środowiska
MOŻLIWE DALEJ: niezależna praca mieszcząca się w zleceniu
```

Przy niedostępności narzędzia nie fabrykuj jego wyników. Przy luce detalu technicznego wybierz uzasadnione rozwiązanie w granicach specyfikacji; nie zamieniaj każdej niedookreślonej nazwy w pytanie produktowe.
