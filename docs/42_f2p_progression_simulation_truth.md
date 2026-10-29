# 42. Symulacja Progresji Gracza F2P — Źródło Prawdy (Source of Truth)

> **Status R — Źródło Prawdy (29.10.2026):** Oficjalny model analityczny tempa rozwoju konta Free-to-Play (F2P) spędzającego w grze średnio **20 minut dziennie**. Model bazuje na autorytatywnych wzorach silnika ([`FvSe.calculateFarmValue`](../src/server/FarmMath/fv_se.luau), piecewise Soul Eggs, katalogu infrastruktury oraz decyzjach R z 29.10.2026 o stałym limicie offline 6h dla graczy darmowych). Narzędzie weryfikacyjne: [`tools/f2p_progression_sim.py`](../tools/f2p_progression_sim.py).

---

## 1. Wyjaśnienie Indeksowania i Nazewnictwa

W celu uniknięcia rozbieżności pomiędzy językiem gracza a implementacją techniczną w kodzie:

| Kolejność dla Gracza | Indeks w Silniku (`eggIndex`) | Nazwa Gatunku | Wartość Bazowa Jaja | Wymagane FV Awansu |
| :---: | :---: | :--- | :---: | :---: |
| **1. Jajo** | `0` | **Kurze** *(Edible)* | $1.00 | Start ($0) |
| **2. Jajo** | `1` | **Kacze** *(Superfood)* | $3.00 | $250 000 000 ($250M) |
| **3. Jajo** | `2` | **Gęsie** *(Medical)* | $10.00 | $10 000 000 000 ($10B) |
| **4. Jajo** | `3` | **Indycze** *(Rocket Fuel)* | $40.00 | $500 000 000 000 ($500B) |
| **5. Jajo** | `4` | **Strusie** *(Super Material)* | $160.00 | $5.0 × 10¹⁴ ($500T) |
| **6. Jajo** | `5` | **Pawie** *(Fusion)* | $700.00 | $1.0 × 10¹⁷ ($100q) |
| **7. Jajo** | `6` | **Pingwinie** *(Quantum)* | $3 000.00 | $5.0 × 10¹⁹ ($50Q) |
| **8. Jajo** | `7` | **Krucze** *(Immortal)* | $15 000.00 | $2.5 × 10²³ ($250s) |
| **9. Jajo** | `8` | **Orle** *(Tachyon)* | $60 000.00 | $5.0 × 10²⁶ ($500S) |
| **10. Jajo (Połowa)** | `9` | **Kazuara** *(Dilithium)* | $250 000.00 | **$2.5 × 10³⁰ ($2.5N)** |
| **11. Jajo** | `10` | **Pterodaktyla** *(Prodigy)* | $1 000 000.00 | $1.0 × 10³⁴ ($10d) |
| **12. Jajo** | `11` | **Raptora** *(Terraform)* | $5 000 000.00 | $5.0 × 10³⁷ ($50U) |
| **13. Jajo** | `12` | **Tyranozaura** *(Antimatter)* | $25 000 000.00 | $5.0 × 10⁴¹ ($500D) |
| **14. Jajo (Paywall / Monetyzacja)** | `13` | **Gryfa** *(Dark Matter)* | **$2 500 000 000.00 (100× skok!)** | **$2.5 × 10⁴⁵ ($2.5Qd)** |
| **15. Jajo** | `14` | **Hydry** *(A.I.)* | $100 000 000 000.00 | $2.5 × 10⁴⁹ ($2.5Qn) |
| **16. Jajo** | `15` | **Bazyliszka** *(Nebula)* | $1.0 × 10¹² | $1.0 × 10⁵³ ($100Sx) |
| **17. Jajo** | `16` | **Feniksa** *(Universe)* | $1.5 × 10¹³ | $2.5 × 10⁵⁷ ($2.5Sp) |
| **18. Jajo** | `17` | **Smocze** *(Enlightenment)* | $1.5 × 10¹⁴ | $5.0 × 10⁶¹ ($50O) |
| **19. Jajo (Finał)** | `18` | **Astralny Lewiatan** | $1.0 × 10⁻⁷ | $5.0 × 10⁶⁵ ($500N) |

> [!NOTE]
> Indeksowanie w silniku od zera wynika z formuły wyceny farmy: $K = 1200 + 600 \times \text{eggIndex}$. Dla jaja startowego (Kurzego) $\text{eggIndex} = 0 \implies K = 1200$.

---

## 2. Pacing Rozwoju Gracza F2P (20 minut dziennie)

Zbadano dwa realistyczne wzorce gracza niepłacącego:
* **Wariant A (1 sesja dziennie):** 20 minut ciągłej, aktywnej gry wieczorem + 6 godzin produkcji offline w nocy (stały limit F2P, sprawność away 0.5).
* **Wariant B (2 sesje dziennie):** 2 × 10 minut aktywnej gry (rano i wieczorem) + 2 × 6h offline (łącznie 12h offline na dobę).

### Tabela Kamieni Milowych Osiągania Gatunków Jaj

| Gatunek Jaja (dla gracza) | Czas wariantu A (1× 20 min) | Czas wariantu B (2× 10 min) | Liczba Prestiży | Zgromadzone Soul Eggs |
| :--- | :---: | :---: | :---: | :---: |
| **1. Kurze** *(Edible)* | **Minuta 0** | **Minuta 0** | 0 | 0 |
| **2. Kacze** *(Superfood)* | **Minuta 2** | **Minuta 2** | 0 | 0 |
| **3. Gęsie** *(Medical)* | **Minuta 4** | **Minuta 4** | 0 | 0 |
| **4. Indycze** *(Rocket Fuel)* | **Minuta 8** | **Minuta 8** | 0 | 0 |
| **5. Strusie** *(Super Material)* | **Minuta 12** | Dzień 1 (sesja 2, min 6) | 0–1 | 0–43 |
| **6. Pawie** *(Fusion)* | **Dzień 2** *(minuta 1)* | Dzień 1 (sesja 2, min 10) | 0–1 | 0–43 |
| **7. Pingwinie** *(Quantum)* | **Dzień 2** *(minuta 14)* | Dzień 2 (sesja 2, min 1) | 0–2 | 0–186 |
| **8. Krucze** *(Immortal)* | **Dzień 3** *(minuta 12)* | Dzień 3 (sesja 1, min 1) | 1–3 | 186–1 113 |
| **9. Orle** *(Tachyon)* | **Dzień 4** *(minuta 16)* | Dzień 4 (sesja 1, min 1) | 1–4 | 1 113–9 536 |
| **10. Kazuara** *(Dilithium — Połowa)* | **Dzień 7** *(minuta 1)* | **Dzień 6** *(sesja 2, min 1)* | **2–8** | **~68 000 – 110 000** |
| **11. Pterodaktyla** *(Prodigy)* | **Dzień 12** *(minuta 5)* | Dzień 32 | 4–20 | ~1 470 000 – 5 700 000 |

---

## 3. Szczegółowa Analiza Pacingu Pierwszej Sesji (Dzień 1)

W pierwszych 20 minutach gry gracz przechodzi przez wczesną fazę wykładniczą. Formuła Farm Value opiera się w tym momencie na wzroście populacji kurcząt oraz pierwszych ulepszeniach wartości jaja i kurników:

```
[Minuta 00:00] Start: 1x Coop (pojemność 250), Farma Kurza, FV $54 928 (baza $1.00).
[Minuta 02:00] Zapełnienie pierwszych kurników, zakup ulepszeń wartości.
               FV przekracza $250 000 000 ($250M) ➔ Odblokowanie 2. Jaja (Kacze / Superfood)!
[Minuta 04:00] Na farmie Kaczej: zakup Shacków, populacja >1 500 kur.
               FV przekracza $10 Miliardów ($10B) ➔ Odblokowanie 3. Jaja (Gęsie / Medical)!
[Minuta 08:00] Na farmie Gęsiej: zakup Super Shacków, odblokowanie IHR.
               FV przekracza $500 Miliardów ($500B) ➔ Odblokowanie 4. Jaja (Indycze / Rocket Fuel)!
[Minuta 12:00] Na farmie Indyczej: zakup Short House, populacja >4 000 kur.
               FV przekracza $500 Bilionów ($500T) ➔ Odblokowanie 5. Jaja (Strusie / Super Material)!
[Minuta 20:00] Zakończenie 1. sesji. Gracz zostawia farmę Strusią na noc offline.
[Noc offline]  6 godzin produkcji IHR zapełnia kurniki i akumuluje gotówkę.
               Dzień 2 rano: FV przekracza $100q ➔ Odblokowanie 6. Jaja (Pawie / Fusion)!
```

---

## 4. Zasady Optymalnego Prestiżu (Heurystyka Gracza)

1. **Brak prestiżu w Dniu 1:**
   * Gracz nie powinien resetować farmy dla 1–5 Jaj Duszy (Soul Eggs). Zyski z przechodzenia na wyższe gatunki jaj (gdzie wartość bazowa rośnie kilkukrotnie na każdym kroku: $0.50 ➔ $1.25 ➔ $6.25 ➔ $30 ➔ $150 ➔ $700) są o rzędy wielkości większe niż +10–50% ze wczesnych SE.
2. **Pierwszy Prestiż (Dzień 2):**
   * Wykonywany na etapie Strusim / Pawim, gdy kurniki zaczynają być zbyt drogie w rozbudowie.
   * Daje natychmiastowy skok o **+200 do +600 Soul Eggs**, co zwiększa przyszły dochód o **+2 000% do +6 000%** (20×–60× mnożnik zarobków!).
3. **Czas powrotu na szczyt po prestiżu:**
   * Dzięki mnożnikowi Soul Eggs ponowne przejście przez jaja 1 ➔ 5 zajmuje łącznie **poniżej 3 minut**.

---

## 5. Wpływ na Nowy System Badań (4 Kategorie)

Dane symulacji stanowią podstawę pod zatwierdzoną przebudowę systemu badań:
1. **Likwidacja 13 sztucznych progów punktowych (Tier 0–12):**
   * Gracze osiągają 5. i 6. jajo w ciągu 1–2 dni. Blokowanie wyższych tierów wymogiem zakupu setek bezużytecznych mikroulepszeń jest sprzeczne z naturalną dynamiką gry.
2. **4 Kategorie Tematyczne (po ~5 wyrazistych badań):**
   * 🧬 **Genetyka i Wartość Jaj**
   * 🐣 **Wylęg i Populacja**
   * 🏠 **Kurniki i Przestrzeń**
   * 🚚 **Flota i Logistyka**
3. **Skalowanie badań z gatunkiem jaja:**
   * Nowe badania w kategoriach odblokowują się proporcjonalnie do aktualnie posiadanego gatunku jaja oraz rzędu wielkości dochodu farmy, zapewniając satysfakcjonujące skoki rozwoju w każdej 20-minutowej sesji.
