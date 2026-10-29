# 42. Symulacja Progresji Gracza F2P — Źródło Prawdy (Source of Truth)

> **Status R — Źródło Prawdy (29.10.2026):** Oficjalny model analityczny tempa rozwoju konta Free-to-Play (F2P) spędzającego w grze średnio **20 minut dziennie**. Model bazuje na autorytatywnych wzorach silnika ([`FvSe.calculateFarmValue`](../src/server/FarmMath/fv_se.luau), piecewise Soul Eggs, katalogu infrastruktury oraz decyzjach R z 29.10.2026 o stałym limicie offline 6h dla graczy darmowych). Narzędzie weryfikacyjne: [`tools/f2p_progression_sim.py`](../tools/f2p_progression_sim.py).

---

## 1. Wyjaśnienie Indeksowania i Nazewnictwa

W celu uniknięcia rozbieżności pomiędzy językiem gracza a implementacją techniczną w kodzie:

| Kolejność dla Gracza | Indeks w Silniku (`eggIndex`) | Nazwa Gatunku | Wartość Bazowa Jaja | Wymagane FV Awansu |
| :---: | :---: | :--- | :---: | :---: |
| **1. Jajo** | `0` | **Kurze** *(Edible)* | $0.50 | Start ($0) |
| **2. Jajo** | `1` | **Kacze** *(Superfood)* | $1.25 | $5 000 000 ($5M) |
| **3. Jajo** | `2` | **Gęsie** *(Medical)* | $6.25 | $5 300 000 000 ($5.3B) |
| **4. Jajo** | `3` | **Indycze** *(Rocket Fuel)* | $30.00 | $240 000 000 000 ($240B) |
| **5. Jajo** | `4` | **Strusie** *(Super Material)* | $150.00 | $1.7 × 10¹⁴ ($170T) |
| **6. Jajo** | `5` | **Pawie** *(Fusion)* | $700.00 | $5.0 × 10¹⁶ ($50q) |
| **7. Jajo** | `6` | **Pingwinie** *(Quantum)* | $3 000.00 | $2.3 × 10¹⁹ ($23Q) |
| **8. Jajo** | `7` | **Krucze** *(Immortal)* | $12 500.00 | $9.4 × 10²² ($94s) |
| **9. Jajo** | `8` | **Orle** *(Tachyon)* | $50 000.00 | $1.7 × 10²⁶ ($170S) |
| **10. Jajo (Połowa)** | `9` | **Kazuara** *(Dilithium)* | $175 000.00 | **$9.8 × 10²⁹ ($980O)** |
| **11. Jajo** | `10` | **Pterodaktyla** *(Prodigy)* | $525 000.00 | $4.8 × 10³³ ($4.8N) |
| **12. Jajo** | `11` | **Raptora** *(Terraform)* | $1 500 000.00 | $1.6 × 10³⁷ ($1.6d) |
| **13. Jajo** | `12` | **Tyranozaura** *(Antimatter)* | $10 000 000.00 | $2.0 × 10⁴⁰ ($20U) |
| **14. Jajo** | `13` | **Gryfa** *(Dark Matter)* | $1 000 000 000.00 | $1.3 × 10⁴⁴ ($130D) |
| **15. Jajo** | `14` | **Hydry** *(A.I.)* | $100 000 000 000.00 | $1.2 × 10⁴⁸ ($1.2T) |
| **16. Jajo** | `15` | **Bazyliszka** *(Nebula)* | $1.0 × 10¹² | $3.2 × 10⁵² ($32Qd) |
| **17. Jajo** | `16` | **Feniksa** *(Universe)* | $1.5 × 10¹³ | $2.0 × 10⁵⁶ ($200Qn) |
| **18. Jajo** | `17` | **Smocze** *(Enlightenment)* | $1.0 × 10¹⁴ | $4.0 × 10⁶⁰ ($4Sx) |
| **19. Jajo (Finał)** | `18` | **Astralny Lewiatan** | $1.0 × 10⁻⁷ | $3.6 × 10⁶⁵ ($360Sp) |

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
| **2. Kacze** *(Superfood)* | **Minuta 1–2** | **Minuta 1–2** | 0 | 0 |
| **3. Gęsie** *(Medical)* | **Minuta 4** | **Minuta 4** | 0 | 0 |
| **4. Indycze** *(Rocket Fuel)* | **Minuta 8** | **Minuta 8** | 0 | 0 |
| **5. Strusie** *(Super Material)* | **Minuta 12** | Dzień 1 (sesja 2) | 0–1 | 0–38 |
| **6. Pawie** *(Fusion)* | **Dzień 1** *(po 1. nocy offline)* | Dzień 1 (sesja 2) | 0–1 | 0–38 |
| **7. Pingwinie** *(Quantum)* | **Dzień 2** *(minuta 10)* | Dzień 2 (sesja 1) | 1–2 | 170–260 |
| **8. Krucze** *(Immortal)* | **Dzień 2** *(minuta 16)* | Dzień 3 (sesja 1) | 1–3 | 260–470 |
| **9. Orle** *(Tachyon)* | **Dzień 3** *(minuta 12)* | Dzień 4 (sesja 1) | 2–3 | ~6 000 |
| **10. Kazuara** *(Dilithium — Połowa)* | **Dzień 5–6** | **Dzień 4–6** | **3–4** | **~25 000 – 42 000** |
| **11. Pterodaktyla** *(Prodigy)* | **Dzień 11** | Dzień 18–22 | 8 | ~1 200 000 |
| **12. Raptora** *(Terraform)* | **Dzień 20–25** | Dzień 24–28 | 11–35 | ~5 000 000 – 6 500 000 |

---

## 3. Szczegółowa Analiza Pacingu Pierwszej Sesji (Dzień 1)

W pierwszych 20 minutach gry gracz przechodzi przez wczesną fazę wykładniczą. Formuła Farm Value opiera się w tym momencie na wzroście populacji kurcząt oraz pierwszych ulepszeniach wartości jaja i kurników:

```
[Minuta 00:00] Start: 1x Coop (pojemność 250), Farma Kurza, FV $27 464.
[Minuta 01:20] Zapełnienie pierwszego Coopa, zakup drugiego kurnika.
               FV przekracza $5 000 000 ➔ Odblokowanie 2. Jaja (Kacze / Superfood)!
[Minuta 04:10] Na farmie Kaczej: zakup Shacków, populacja >1 500 kur.
               FV przekracza $5.3 Miliarda ➔ Odblokowanie 3. Jaja (Gęsie / Medical)!
[Minuta 08:30] Na farmie Gęsiej: zakup Super Shacków, odblokowanie IHR.
               FV przekracza $240 Miliardów ➔ Odblokowanie 4. Jaja (Indycze / Rocket Fuel)!
[Minuta 12:15] Na farmie Indyczej: zakup Short House, populacja >4 000 kur.
               FV przekracza $170 Bilionów ➔ Odblokowanie 5. Jaja (Strusie / Super Material)!
[Minuta 20:00] Zakończenie 1. sesji. Gracz zostawia farmę Strusią na noc offline.
[Noc offline]  6 godzin produkcji IHR zapełnia kurniki i akumuluje dochód.
               Rano FV osiąga próg Pawiego (Fusion: $50q) bez żadnego prestiżu!
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
