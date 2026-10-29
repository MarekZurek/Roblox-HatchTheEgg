# Zatwierdzony podział produktów Roblox

23.10.2026. **R — użytkownik zatwierdził mocne Pro, osobno Buy MAX i Auto-Hatch oraz powtarzalne zakupy Diamentów (Diamonds, 💎; GE) i Skarbonki (Piggy).** Dotyczy zawartości i podziału produktów; nie zatwierdza cen, parametrów odłożonego bilansu ani rozpoczęcia implementacji.

## Produkty i uprawnienia — R

| Produkt | Typ / rola | Zatwierdzona zawartość |
|---|---|---|
| Pro Permit | Jednorazowy trwały gamepass; główna przepustka rozwoju farmy | Stały limit 18h offline (zamiast 6h dla kont darmowych; R 29.10.2026), pełna jakość naliczania dochodu offline (100% zamiast 50%), więcej miejsc aktywnych boostów. Dodatkowo rozszerzenie slotów petów i +10 punktów procentowych powodzenia łączenia (max 100%, bez kumulacji i dopłat do prób). |
| Buy MAX | Osobny jednorazowy trwały gamepass, poza Pro | Szybki zakup maksymalnej dostępnej i opłacalnej środkami gracza liczby poziomów badań. Nie daje darmowych poziomów ani pominięcia bramek postępu. Szczegóły przycisków/UX nie są implementacją. |
| Auto-Hatch kurczaków / Egg Bot | Osobny jednorazowy trwały gamepass, poza Pro | Automatyzuje przycisk ręcznej wylęgarni kurczaków. Nadal obowiązują jej pojemność, regeneracja, tempo i wolne miejsca kurników. Nie dodaje nowego mnożnika i nie oznacza automatycznego otwierania petów ani nowej produkcji offline. |
| Pakiety Diamentów (Diamonds, 💎) | Powtarzalne zakupy | Przyznanie określonej ilości Diamentów (w kodzie i bazie zachowany klucz profilu profile.permanent.GE) do wydania w badaniach epickich, boostach i inkubacji. |
| Rozbicie Skarbonki (Piggy) | Powtarzalny zakup | Wypłata Diamentów zgromadzonych w Skarbonce (Piggy) według ustalonych dla tego systemu reguł. Piggy jest źródłem wypłacanych Diamentów, nie ich wydatkiem. Pojemność, wzrost i ceny pozostają odłożone. |

Pro ma być znaczącym rozszerzeniem możliwości i wygody, podobnie do roli Pro Permit w oryginale. Nie zawiera automatycznie Buy MAX i Auto-Hatch. Rozszerzenie petów jest częścią Pro; nie przyjęto osobnego +2 Pet Equip ani osobnego passa wyłącznie za +10 p.p. Posiadanie Buy MAX lub Auto-Hatch samo nie przyznaje Pro.

Pełna jakość offline oznacza udział w dochodzie wyliczonym z prawidłowej symulacji (100% zamiast 50%), a nie pominięcie transportu, pojemności czy historycznego czasu wydarzeń. Nie jest to nieograniczony offline. Decyzją z 29.10.2026 silosy wycofano na rzecz stałego limitu 18h dla Pro (oraz 6h dla standardu). Parametry miejsc boostów i petów pozostają w toku dalszych ustaleń.

## Co pozostaje bez zmian / poza tą akceptacją

- D04 nadal określa podwajacz i jawne bonusowe prezenty: pierwsze użycie dnia darmowe, następne GE/opcjonalnie Robux. Zatwierdzone rezerwacje i jednokrotne wypłaty nadal obowiązują.
- Cena Pro i pozostałych produktów, rozmiary pakietów, liczby slotów, inkubacja, siły i szanse petów oraz pozostały bilans nie są rozstrzygnięte. **Zapas inkubacji Pro 720 z 21 nie staje się zatwierdzoną korzyścią przez akceptację mocnego Pro.**
- Zakres wydania zatwierdzono następnie w [26](26_approved_launch_scope_and_pro_availability.md): Pro, Buy MAX i GE na premierę; Piggy warunkowo po gotowym bilansie; Auto-Hatch i VIP później. Rainbow kończy ewolucję v1.
- D01 +10 p.p. jest korzyścią Pro dostępną tylko przy odpowiedniej kwalifikacji. Zatwierdzono wariant A w [26](26_approved_launch_scope_and_pro_availability.md): brak niedostępnego bonusu, pozostałe Pro działa, jawny opis przed zakupem i bez zastępczej korzyści w v1.
- Automatyczne otwieranie inkubatorów petów jest inną funkcją, niewłączoną do tej akceptacji Auto-Hatch kurczaków.

Dokumenty 17–21 oraz materiały robocze zachowują historyczne warianty. Nie zmieniono ich parametrów ani wyników, nie przeprowadzono nowych symulacji i nie rozpoczęto implementacji. Backup sprzed aktualizacji: ZIP.

[Integracja własności #71](workflow/entitlement_farm_fixes_71_74.md): zaufane nadanie czeka na ukończenie wcześniejszego rozliczenia i jest ponawiane bez ponownego zakupu. Polityka +10 p.p. pozostaje osobna; nowy pass nie jest dopisywany wstecz do całego offline.
