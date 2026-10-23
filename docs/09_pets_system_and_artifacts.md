# System petów — zasady zatwierdzone i projekt roboczy

Pety są elementem projektu HatchTheEgg. Nadal bez implementacji. Szczegółowa mapa efektów i dowody kontrolowanych wejść: [16](16_pet_stacking_offline_and_package_schedule.md). [CURRENT_SPEC](CURRENT_SPEC.md) rozdziela statusy.

## 1. Zatwierdzone zasady — R

- Premie petów tej samej statystyki sumują się: `P[d]=1+sum(b_i[d])`. Dwa +50% dają ×2.
- Drone Hawk zwiększa szansę elity: `min(1,pBase×P)`, zamiast zwiększać częstość dronów. Bazowa szansa zależy od postępu według modelu referencyjnego. Konkretne siły petów i ewolucji nie zostały tym zatwierdzone.
- Wydarzenia offline rozliczamy za faktyczny czas ich trwania w oknie produkcji; szczegóły i ograniczenia silosów w 16.

## 2. Mapowanie projektu na potwierdzone wymiary

Mapowanie jest specyfikacją adaptacji popartą testami funkcji z kontrolowanymi wejściami. Nie oznacza, że pety zostały wykonane w gotowej grze Roblox.

| Archetyp | Warstwa działania | Czego nie zmienia bezpośrednio |
|---|---|---|
| Farm Pup / Farmer Dog | Wartość sprzedawanego jaja | researchEggValueMult we wzorze FV |
| Rooster King / Robo-Cock | Znoszenie przed ograniczeniem transportem | Przepustowość floty ani researchLayingRate w FV |
| Speedy Chick / Golden Pecker | IHR, także away; Calm osobno | Research IHR we wzorze FV |
| Heavy Cow / Mega Rooster | Pojemność produkcyjna, końcowe ceil | Pojemność ResearchEngine wybraną przez FV |
| Drone Hawk | Szansa elity z limitem 100% | Częstość, jakość i kwota nagrody drona |
| Cosmic Phoenix | Przyszłe przyrosty przychodu prestiżowego | Końcowe SE, bezpośrednie dary SE i historia przychodu wstecz |
| Alien Clucker | Siła aktywnych kategorii boostów, raz | Puste kategorie, Money Printer i czas boostu |

Pety mogą pośrednio zmieniać FV przez rzeczywisty postęp, np. populację. Nie dodajemy równolegle odpowiadających im artefaktów. Przed zmianą wyposażenia rozliczamy czas starym zestawem; nowy zestaw nie działa wstecz na całe offline.

## 3. Nieustalone parametry — P

**Odłożony bilans:** waluta i ceny inkubacji, rozkłady, siły petów, ładunki i ich limit, koszty/tempo ulepszania. Dokumenty [17](17_pet_balance_draft.md), [18](18_incubator_prices_and_acquisition_pacing.md), [19](19_integrated_farm_progression_simulation.md), [20](20_paying_player_balance_direction.md) i [21](21_payer_progression_and_incubation.md) pozostają bez zmian. Nie ma zatwierdzonej końcowej tabeli. [TODO](TODO.md) określa zakres odłożenia.

Starszy opis płacenia „aktualnymi jajami lub gotówką” był sprzeczny; to były alternatywy, nie gotowa reguła. Późniejsze modele używały gotówki jako **założenia symulacji**, nie zatwierdzenia waluty. Nie rozstrzygamy jej teraz.

**R:** rozszerzenie slotów petów i +10 p.p. do łączenia są częścią Pro, według [25](25_approved_product_structure.md), nie osobnymi passami. Konkretne liczby 3/5 nadal są założeniem dawnych scenariuszy, nie nowo zatwierdzonym bilansem. Kupno osobnego Buy MAX lub Auto-Hatch nie przyznaje Pro.

Golden/Rainbow muszą określać, względem jakiej premii liczone jest wzmocnienie. Neutralnej jedynki w P nie mnożymy jako premii peta. Receptury i liczby w 17–21 są propozycjami, a nie opisanymi zasadami modelu referencyjnego. Nadal otwarte: docelowa interpretacja ewolucji, nasycenie Hawka i ograniczenia na Enlightenment.

## 4. Dodatkowe koncepcje — P

Ekspedycje petów, odłamki, premium eggs za GE/Robux i gwarantowane rzadkości nie są zatwierdzonym zakresem pierwszej wersji. Nie przypisujemy im z automatu cen, nagród ani badań rakiet. Oprawa wylęgu i podążanie za awatarem są koncepcją prezentacji.

Modele i biblioteki wymieniane dawniej jako gotowe zasoby nie zostały zweryfikowane w tym audycie pod kątem licencji, jakości i aktualnego utrzymania. Nie ma zatwierdzonego wyboru pakietu ani biblioteki; należy go sprawdzić dopiero przy osobnym zleceniu tej pracy.
