# Historyczny czas wydarzeń dochodu — #61

Stan: 25.10.2026. Realizacja zatwierdzonej reguły z 16 §3 i 27 §3.2, bez zmian bilansu.

## Przyczyna i zmiana

Timeline wybierał mnożnik wydarzenia dochodu wyłącznie na końcu kroku. W kroku 0,3 s z wydarzeniem ×3 przez pierwsze 0,1 s wypłacał $0,25 zamiast około $0,4166666667 dla kontrolowanego stanu 100 kur na pierwszym jaju. Nowa regresja odtworzyła tę różnicę przed poprawką.

EffectsManager oblicza średnią warstwy wydarzenia dochodu po rzeczywistym przecięciu okien z krokiem. Dla pojedynczego wydarzenia jest to `(czas aktywny × mnożnik + pozostały czas × 1) / dt`. Dla nakładających się wpisów uśredniany jest istniejący iloczyn mnożników aktywnych w danym fragmencie czasu, a nie iloczyn osobnych średnich. Zachowano istniejące typy earnings/earnings-boost i odczyt deadlineMs albo durationSeconds. Nie dodano harmonogramu, oferty ani nowych reguł kwalifikacji do wydarzeń.

Przecięcia używają względnych sekund od zamrożonego początku okresu, aby uniknąć odejmowania dwóch zaokrąglonych końców kroku o wielkości daty epoki. Uwzględniane są ułamkowe milisekundy i rzeczywisty dt ostatniego kroku. Okna są półotwarte [start,end); okno puste nie wnosi efektu. Gdy uwzględnione okna pokrywają cały krok, zachowany jest ich stały iloczyn bez dodatkowego uśredniania.

Timeline mnoży bazowy dochód przez boost dochodu, VD oraz tę średnią. Dochód trafia do portfela i akumulatorów przychodu; istniejąca premia Phoenix/Soul Beacon nadal używa faktycznego zarobku. Brak dodatkowych kroków produkcji, dotarć, IHR lub odejmowania czasu boostów. VD nadal działa tylko gdy stepEnd < endsAt. IHR, event prestiżu i pozostałe rodzaje wydarzeń nie są uśredniane w dochodzie.

Limit silosów przycina okres produkcji przed integracją; nie powstają wypłaty za wydarzenia po jego wyczerpaniu. Checkpoint zachowuje dotychczasowy format i zamrożoną konfigurację. Wznowienie AFTER_PRODUCTION nie nalicza ponownie zakończonej produkcji. To korekta przyszłego rozliczenia, bez migracji i korygowania wcześniej wypłaconych środków.

## Weryfikacja i granice

Nowy zestaw tests/event_time ma 109 asercji: granice początku/końca i wnętrza kroku, nakładanie, mnożnik zero, krótszy ostatni krok, duża data epoki, ułamki ms, VD i boosty, premia przychodu prestiżowego, kolejność IHR, zamrożenie konfiguracji, checkpoint każdej fazy, silosy i brak podwójnego naliczenia. Test Bootstrap sprawdza również rzeczywisty most konfiguracja → Timeline → stan koordynatora. Oczekiwania wynikają z jawnego tempa 5/6 dolara na sekundę i niezależnych długości przedziałów, nie z funkcji testowanej.

Trzy nowe mutacje przywracają odczyt końca kroku, ignorowanie deadline i stosowanie wydarzenia poza jego aktywnym fragmentem. Dotychczasowe effect_boundaries, timeline i production_context pozostają częścią runnera. Wyłącznie lokalne L i build statyczny; bez Studio, chmury i odbioru człowieka. Zgodnie z #60 lokalny PASS nie zatwierdza wydania.

Bilans 17–21 i dane referencyjne pozostają bez zmian. Funkcje niedostępne bez zatwierdzonej konfiguracji pozostają niedostępne. Dawne raporty zawierające otwarte #61 opisują stan ich commitów; nie zostały przepisane jako nowe dowody. [Weryfikacja dostawy](earnings_event_time_61_verification.json).

Wynik dostawy: **35 zestawów Luau / 80 360 asercji PASS L**, dodatkowo **11 testów raportowania Python PASS**, **25/25 wybranych mutacji wykrytych**. Statyczny build: 39 modułów / 2 entrypointy. Bez deklaracji procentowego pokrycia lub gotowości wydania.
