# Integracja nagród, badań i wylęgu — #66–70

Stan: 25.10.2026. Naprawy istniejących zasad, bez wznowienia bilansu 17–21 i bez uruchamiania niezatwierdzonych produktów.

## #66 — prezentacja rzeczywiście wystawionych nagród

Usunięto lokalny harmonogram dronów co 14 s, lokalne ID drone-N oraz sztuczną elitarność co trzeciego drona. Usunięto stałe offer_2plus1 z punktu paczki. Własny widok gracza ma opcjonalne listy issuedDrones oraz ordinaryOffers. Zawiera wyłącznie ID i dane prezentacji własnych, nieodebranych/nieprzeterminowanych dronów oraz oczekujących zwykłych paczek. Nie zawiera rolls, terms, konfiguracji wypłaty ani cudzych ofert. Kanał zwykły zachowuje limit dwóch miejsc; bonusowy nie został podłączony do zwykłego punktu odbioru.

ClientBootstrap tworzy aktora z serwerowego ID, terminów i elitarności; usuwa go po wygaśnięciu lub zniknięciu rekordu. Nie tworzy kolejnych aktorów z kolejnych kopii tego samego snapshotu. Punkt dostaw wybiera rzeczywisty ordinaryOffers[1].id. Prompt ClaimOfferPrompt i billboard paczki są nieaktywne, gdy nie ma należnej paczki. Lista kontrolek jest buforowana zamiast przeszukiwania sceny co klatkę.

**Wybrano dopuszczoną w #66 ścieżkę bezpiecznej nieaktywności niedostarczonego kanału.** Nie dodano automatycznego serwerowego harmonogramu i nie wymyślono jego kwot, częstości czy parametrów losowania. Bez skonfigurowanego wystawiania rekordów gracz nie widzi fikcyjnych aktywnych nagród. Zaufane host API issueDrone/issueOffer pozostaje źródłem rekordów i respektuje istniejące limity oraz jednokrotny odbiór. Ta dostawa nie oznacza ukończenia pełnego produkcyjnego harmonogramu D05 lub płatnego bonusowego prezentu za Robux.

## #67 — Accounting Tricks w Farm Value

Adapter FV pobiera valuationMult z istniejącego catalog.epicEffects(accounting_tricks,level). Poziom 0 pozostaje neutralny, poziom 1 daje ×1.05, poziom 20 ×2. Nie dodano bonusu do dochodu ani petów/boostów do wejść ResearchEngine. Ten sam FV zasila próg awansu i procentowe nagrody kalendarza, więc poprawione są również ich podglądy i wypłaty. Inne pola adaptera FV nie są przedmiotem tej zmiany.

## #68 — autorytatywny Hold to Hatch

Start/refresh/stop nadal są intencjami, a tempo pochodzi z istniejącego Epic hold_to_hatch. Poprzedni czas jest najpierw rozliczany według poprzedniej intencji; nowy start nie wypuszcza kur za zaległy czas. Gdy rozliczenie wymaga dalszego budżetu, wejście dostaje NOT_ACCEPTED/SESSION_NOT_READY zamiast pozornego sukcesu.

Powtórzenia odbywają się w fazie kroku Timeline przed produkcją, bez dodatkowych kroków IHR. Korzystają z istniejącego holdStep: akumulator float32, ścisłe >1/rate, kontrola zapasu i miejsca, te same trwałe ID grup. Brak Epic nie uruchamia bezpłatnego 3/s; refill pozostaje osobnym procesem. Każda grupa ma zaufaną trasę i serwerowy czas początku kroku zaokrąglony do całkowitego ServerInstantMs.

Techniczna dzierżawa intencji wynosi **2000 ms**, odświeżana przez aktywny kontroler klienta co **500 ms**. Nie zmienia to tempa z badań. Timeout wewnątrz kroku przycina czas samego hold, nie dzieli produkcji/IHR. Refresh nie wskrzesza wygasłej intencji. Stop, nowy strumień, udany reset, away i nowa sesja kończą przytrzymanie.

Checkpoint zawiera zamrożony kontekst tras, akumulator i granicę ważności. Kontekst jest związany z generacją właściciela i strumieniem. Nowy właściciel może dokończyć już obliczone fazy i istniejące grupy, lecz nie kontynuuje dawnego hold. Po ukończeniu okresu intencja nie jest zapisywana jako automatyczny wylęg do odtworzenia offline.

## #69 — IHR Sharing i odtwarzalny wybór celu

Timeline przekazuje rzeczywisty internalHatcherySharing z katalogowego poziomu Epic, zamiast stałego zera. Wykorzystuje istniejący algorytm ihr.step i PopulationMath.select: pełny slot przekazuje część tempa jednemu celowi wybranemu według wolnego miejsca, bez równego podziału. Zasiedlone kury nadal produkują przed wzrostem IHR.

Wybór celu ma odtwarzalny kursor xorshift32, z którego budowane są dwa słowa ExactUInt do istniejącego wyboru modulo. Początkowy seed pochodzi z zamrożonego początku okresu lub jawnego wejścia testowego; kursor jest zachowany w checkpointach i opcjonalnym timeline.selectionState jako kanoniczny tekst ExactUInt w podzakresie 1..4294967295. To stan techniczny wyboru kurnika, nie RNG nagród lub fuzji. Starszy profil bez pola zachowuje stan konta i inicjalizuje kursor przy pierwszym wyborze; nie kasuje się populacji ani historii. Istniejący profil z błędnym polem jest odrzucany przez walidację.

## #70 — bramka stacji Hyperloop

Pojazd typu 11 wymaga permanent.hyperloop==true przy quote, przygotowaniu zakupu i ponownej walidacji świeżego profilu. false lub brak pola daje HYPERLOOP_LOCKED bez obciążenia. Odblokowanie pozostaje trwałe przy zmianie jaja i prestiżu. Nie zmieniono ceny pociągu, stacji lub wagonów. Nie dodano operacji kupna stacji/wagonu — bez dostarczonej stacji pociąg nie jest już sprzedawany jako zwykły pojazd bez bramki.

## Weryfikacja i granice

Nowy zestaw tests/farm_gaps/run.luau ma **144 asercje**. Niezależne równania sprawdzają FV i 50% nagrody dnia 4, próg jaja, tempo hold, zapas i brak miejsca, timeout, refresh, stop, reset, away i reconnect. Sharing jest badany przy poziomach 0/1/10, jednym/wielu wolnych celach i pełnej farmie. Wznowienie każdej fazy porównuje bitowy wynik checkpointu z nieprzerwanym obliczeniem; nowy właściciel nie odtwarza hold. Hyperloop ma próby false/true/brak pola, utratę odblokowania w callbacku oraz resety. Rzeczywisty Main.server sprawdza odbiór wystawionych rekordów i replay; ClientBootstrap oraz kontrolka z FarmPlotBuilder sprawdzają prezentację i jej wyłączenie.

Sześć mutacji przywraca brak wizualizacji wystawionego drona, pomija Accounting Tricks, wyłącza hold, ignoruje timeout, zeruje sharing lub usuwa trzy warstwy bramki Hyperloop. Nie zmieniono oczekiwań starszych testów dla ukrycia regresji. Weryfikacja jest lokalna L i statyczna: nie wykonano natywnego renderowania Main.client w Studio, chmurowego zapisu, zakupów lub odbioru człowieka. releaseCandidateReady pozostaje false.

Bilans 17–21, reference_data i historyczne raporty pozostają bez zmian. [Dowody i sumy kontrolne](farm_gaps_66_70_verification.json).

Końcowy pełny runner po domknięciu kontrolek kanału: **37 zestawów Luau / 80 646 asercji PASS**, dodatkowo **11 testów raportowania Python PASS**, **35/35 wybranych mutacji wykrytych**. Build statyczny: 39 modułów / 2 entrypointy. Wcześniejszy przebieg sprawdzał 138 asercji nowego zestawu, końcowy sprawdza 144; raport opisuje końcowy stan źródeł.
