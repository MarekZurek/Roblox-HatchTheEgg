# Adaptacja: Architektura heksagonalna (Ports & Adapters) w Luau

> **Informacja licencyjna i źródło**  
> Źródła pierwotne:  
> - [skills/hexagonal-architecture/SKILL.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/skills/hexagonal-architecture/SKILL.md)  
> - [rules/common/patterns.md](https://github.com/affaan-m/ECC/blob/90606c8315ee09cafc303515c5f33024db6b9882/rules/common/patterns.md) (sekcja Repository Pattern)  
> Projekt źródłowy: Everything Claude Code (ECC) by Affaan Mustafa  
> Commit SHA: `90606c8315ee09cafc303515c5f33024db6b9882`  
> Licencja: MIT License, Copyright (c) 2026 Affaan Mustafa  

---

## 1. Treść zaczerpnięta z ECC

Architektura heksagonalna (Ports & Adapters) dąży do pełnego odseparowania logiki biznesowej od szczegółów infrastruktury, transportu i bazy danych:
- **Model domeny (Domain)**: Czyste reguły biznesowe, struktury danych i kalkulacje. Zero zależności od frameworków zewnętrznych, baz danych czy sieci.
- **Przypadki użycia (Use Cases / Application)**: Koordynacja przepływu biznesowego, wywoływanie reguł domenowych i portów.
- **Porty (Inbound / Outbound Ports)**: Abstrakcyjne kontrakty określające, czego aplikacja potrzebuje (np. interfejs repozytorium, zegara, bramki płatności) lub co udostępnia.
- **Adaptery (Adapters)**: Konkretne implementacje portów powiązane z technologią (np. klient bazy SQL, kontroler HTTP).
- **Composition Root**: Pojedyncze miejsce wiązania zależności na starcie aplikacji.

---

## 2. Propozycja adaptacji dla HatchTheEgg (Roblox / Luau)

W grach Roblox typowym błędem jest bezpośrednie wywoływanie `game:GetService("DataStoreService")`, `game:GetService("Players")` czy instancji `Workspace` wewnątrz kalkulacji ekonomicznych. Powoduje to, że kodu gry nie da się przetestować poza działającym serwerem Roblox Studio.

Dla HatchTheEgg adaptujemy architekturę heksagonalną do specyfiki Luau:

### A. Podział na warstwy w ModuleScripts

```text
ServerScriptService/
├── Domain/                         -- CZYSTY LUAU: Zero wywołań game:GetService!
│   ├── EconomyFormula.luau         -- Wzory FV, SE, produkcja jaj, transport
│   ├── OfflineCalculator.luau      -- Symulacja kroków 0.3s, silosy, okno czasu
│   ├── PetStacking.luau            -- P = 1 + sum(b), Hawk min(1, pBase * P)
│   ├── FusionRules.luau            -- Tier x docelowy wariant, szanse, licznik gwarancji
│   └── CalendarLogic.luau          -- 28-dniowy cykl min(cap, base * 2^m)
│
├── Application/                    -- Przypadki użycia (orkiestracja)
│   ├── Ports/                      -- Kontrakty portów (tabele typów Luau)
│   │   ├── IPlayerStore.luau       -- GetSave(userId), SetSave(userId, data)
│   │   └── ITimeService.luau       -- GetCurrentTimeUtc()
│   ├── PurchaseResearchUseCase.luau
│   ├── ClaimCalendarRewardUseCase.luau
│   └── ProcessOfflineIncomeUseCase.luau
│
├── Adapters/                       -- Warstwa Roblox API (opakowanie usług)
│   ├── RobloxDataStoreAdapter.luau -- Implementacja IPlayerStore przez DataStoreService
│   ├── RobloxTimeAdapter.luau      -- Implementacja ITimeService przez os.time() / DateTime
│   └── NetworkAdapter.luau         -- Obsługa RemoteFunction i RemoteEvent
│
└── ServerMain.server.luau          -- COMPOSITION ROOT: powiązanie zależności i start
```

### B. Kluczowe zalety dla HatchTheEgg:
1. **Błyskawiczne testowanie referencyjne**: Moduły w `Domain/` są czystymi funkcjami matematycznymi. Można je testować w ułamku sekundy przeciwko danym referencyjnym z dokumentów `docs/02`, `docs/05`, `docs/10`, `docs/15` nawet w środowisku standalone Luau (poza Studio).
2. **Mockowanie DataStore**: Możliwość przetestowania zapisu i migracji danych na fikcyjnym adapterze w pamięci (`InMemoryPlayerStore`), sprawdzając scenariusze awarii sieci, limitu zapytań i podwójnego logowania bez czekania na limity Roblox API.
3. **Determinizm symulacji offline**: `OfflineCalculator` otrzymuje czas przez port `ITimeService`, co pozwala zasymulować dowolny upływ czasu (np. 8 godzin, przejście przez północ UTC, wygaśnięcie wydarzenia) w kontrolowanym teście.

---

## 3. Szkic architektoniczny w Luau (Niewykonywalny szkic poglądowy)

> [!NOTE]
> Poniższe fragmenty kodu stanowią wyłącznie **niewykonywalny szkic koncepcyjny** obrazujący podział odpowiedzialności między warstwami. Nie jest to implementacja gry ani gotowy kod produkcyjny.

### Kontrakt portu (IPlayerStore.luau — szkic interfejsu)
```lua
-- Application/Ports/IPlayerStore.luau
export type PlayerData = {
    schemaVersion: number,
    farm: {
        eggTier: number,
        cash: number,
        habs: { [number]: number },
    },
    meta: {
        lastSaveUtc: number,
        sessionLockToken: string?,
    }
}

export type IPlayerStore = {
    loadData: (userId: number) -> (boolean, PlayerData?, string?),
    saveData: (userId: number, data: PlayerData, lockToken: string) -> (boolean, string?),
}

return nil
```

### Czysty moduł domeny (Domain/EconomyFormula.luau)
```lua
-- Domain/EconomyFormula.luau
-- Czysty moduł Luau - zero zależności od silnika Roblox!
local EconomyFormula = {}

function EconomyFormula.calculateEggLayingRate(baseRate: number, researchMultiplier: number, petMultiplier: number): number
    return baseRate * researchMultiplier * petMultiplier
end

function EconomyFormula.calculateDroneHawkChance(pBase: number, hawkBonusSum: number): number
    -- Zgodnie z zatwierdzoną zasadą D02: min(1, pBase * (1 + sum(b)))
    local P = 1 + hawkBonusSum
    local finalChance = pBase * P
    return math.min(1.0, math.max(0.0, finalChance))
end

return EconomyFormula
```

### Composition Root (ServerMain.server.luau)
```lua
-- ServerMain.server.luau
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local RobloxDataStoreAdapter = require(script.Parent.Adapters.RobloxDataStoreAdapter)
local RobloxTimeAdapter = require(script.Parent.Adapters.RobloxTimeAdapter)
local ProcessOfflineIncomeUseCase = require(script.Parent.Application.ProcessOfflineIncomeUseCase)

-- Inicjalizacja adapterów infrastruktury
local playerStore = RobloxDataStoreAdapter.new(DataStoreService:GetDataStore("PlayerSave_v1"))
local timeService = RobloxTimeAdapter.new()

-- Wstrzyknięcie do przypadku użycia
local offlineUseCase = ProcessOfflineIncomeUseCase.new(playerStore, timeService)

-- Rejestracja zdarzeń gry
Players.PlayerAdded:Connect(function(player)
    offlineUseCase:executeForPlayer(player.UserId)
end)
```
