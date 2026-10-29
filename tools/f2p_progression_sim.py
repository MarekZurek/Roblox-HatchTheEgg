#!/usr/bin/env python3
"""
High-Precision F2P Progression Simulation for HatchTheEgg.
Authoritative source of truth for player pacing and progression.
"""

import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if not (ROOT / "docs" / "reference_data").exists():
    ROOT = Path(r"C:\Users\Marek\Documents\rob\HatchTheEgg")

with open(ROOT / "docs" / "reference_data" / "research.json", "r", encoding="utf-8") as f:
    RESEARCH_DATA = json.load(f)

with open(ROOT / "docs" / "reference_data" / "infrastructure.json", "r", encoding="utf-8") as f:
    INFRA_DATA = json.load(f)

TIER_THRESHOLDS = [0, 30, 80, 160, 280, 400, 520, 650, 800, 980, 1185, 1390, 1655]

EGGS = [
    {"index": 0, "name": "Kurze (Edible)", "value": 1.00, "advanceFV": 0},
    {"index": 1, "name": "Kacze (Superfood)", "value": 3.00, "advanceFV": 2.5e8},
    {"index": 2, "name": "Gęsie (Medical)", "value": 10.00, "advanceFV": 1.0e10},
    {"index": 3, "name": "Indycze (Rocket Fuel)", "value": 40.00, "advanceFV": 5.0e11},
    {"index": 4, "name": "Strusie (Super Material)", "value": 160.00, "advanceFV": 5.0e14},
    {"index": 5, "name": "Pawie (Fusion)", "value": 700.00, "advanceFV": 1.0e17},
    {"index": 6, "name": "Pingwinie (Quantum)", "value": 3000.00, "advanceFV": 5.0e19},
    {"index": 7, "name": "Krucze (Immortal)", "value": 15000.00, "advanceFV": 2.5e23},
    {"index": 8, "name": "Orle (Tachyon)", "value": 60000.00, "advanceFV": 5.0e26},
    {"index": 9, "name": "Kazuara (Dilithium)", "value": 250000.00, "advanceFV": 2.5e30},
    {"index": 10, "name": "Pterodaktyla (Prodigy)", "value": 1000000.00, "advanceFV": 1.0e34},
    {"index": 11, "name": "Raptora (Terraform)", "value": 5000000.00, "advanceFV": 5.0e37},
    {"index": 12, "name": "Tyranozaura (Antimatter)", "value": 25000000.00, "advanceFV": 5.0e41},
    {"index": 13, "name": "Gryfa (Dark Matter)", "value": 2500000000.00, "advanceFV": 2.5e45},
    {"index": 14, "name": "Hydry (A.I.)", "value": 100000000000.00, "advanceFV": 2.5e49},
    {"index": 15, "name": "Bazyliszka (Nebula)", "value": 1000000000000.00, "advanceFV": 1.0e53},
    {"index": 16, "name": "Feniksa (Universe)", "value": 15000000000000.00, "advanceFV": 2.5e57},
    {"index": 17, "name": "Smocze (Enlightenment)", "value": 150000000000000.00, "advanceFV": 5.0e61},
    {"index": 18, "name": "Astralny Lewiatan", "value": 1e-7, "advanceFV": 5.0e65},
]

HABITATS = INFRA_DATA["habitats"]
VEHICLES = INFRA_DATA["vehicles"]
COMMON_RESEARCH = RESEARCH_DATA["common"]

def calculate_soul_eggs(earnings):
    """Piecewise Soul Egg calculation according to docs/05 §1."""
    if earnings < 1:
        return 0.0
    if earnings >= 1e60:
        p = 0.21
    elif earnings >= 1e48:
        p = 0.20
    elif earnings >= 1e39:
        p = 0.19
    elif earnings >= 1e30:
        p = 0.18
    elif earnings >= 1e21:
        p = 0.17
    elif earnings >= 1e12:
        p = 0.16
    else:
        p = 0.15
    return earnings ** p

def calculate_farm_value(egg_index, egg_value_base, population, hab_capacity, shipping_per_min,
                         r_egg_value_mult, r_laying_rate_mult, r_ihr_base, r_ihr_mult,
                         r_max_rcb_base, r_max_rcb_mult, se_count):
    """Exact Farm Value matching src/server/FarmMath/fv_se.luau."""
    L = r_laying_rate_mult / 30.0
    C = math.floor((shipping_per_min / 60.0) / max(1e-9, L))
    P = population if population <= C else math.floor(C + 0.2 * (population - C))
    F = max(0, hab_capacity - population) ** 0.6
    I = 4 * r_ihr_base * r_ihr_mult / 60.0
    T = 21600.0 # 6h offline cap per Decision R 29.10.2026
    R = max(1.0, (5 + r_max_rcb_base) * r_max_rcb_mult - 4) ** 0.25
    K = 1200 + 600 * egg_index if egg_index < 18 else 3600
    
    eb = se_count * 0.10 # +10% per Soul Egg
    mystical_mult = 1.0 + eb
    
    FV = 50.0 * K * 1.0 * mystical_mult * L * egg_value_base * r_egg_value_mult * (P + F + 0.25 * I * T) * R
    return FV

def run_f2p_sim(sessions_per_day=1, active_mins_per_session=20, max_days=35):
    active_sec = active_mins_per_session * 60
    offline_sec = 6 * 3600
    away_efficiency = 0.5
    
    se_count = 0.0
    total_prestiges = 0
    egg_index = 0
    
    cash = 0.0
    session_earnings = 0.0
    chickens = 0
    habs = [0, -1, -1, -1]
    vehicles = [0]
    research_levels = {r["id"]: 0 for r in COMMON_RESEARCH}
    
    milestones = {}
    milestones[0] = {
        "day": 1,
        "time_desc": "Start gry (0 min)",
        "prestiges": 0,
        "se": 0,
        "fv": 27464.0
    }
    
    def reset_to_egg(target_egg):
        nonlocal cash, chickens, habs, vehicles, research_levels, egg_index
        egg_index = target_egg
        cash = 0.0
        chickens = 0
        habs = [0, -1, -1, -1]
        vehicles = [0]
        research_levels = {r["id"]: 0 for r in COMMON_RESEARCH}
        
    def compute_effects():
        common_points = sum(research_levels.values())
        r_egg_value_mult = 1.0
        r_laying_rate_mult = 30.0
        r_ihr_base = 0.0
        r_ihr_mult = 1.0
        r_hab_capacity_mult = 1.0
        r_vehicle_capacity_mult = 1.0
        r_max_rcb_base = 0.0
        r_max_rcb_mult = 1.0
        
        for r in COMMON_RESEARCH:
            lvl = research_levels[r["id"]]
            if lvl > 0:
                effs = r.get("effectsByLevel", [])
                if lvl < len(effs):
                    e = effs[lvl]
                    if "eggValueMult" in e: r_egg_value_mult *= e["eggValueMult"]
                    if "eggLayingRateMult" in e: r_laying_rate_mult *= e["eggLayingRateMult"]
                    if "internalHatcheryRate" in e: r_ihr_base += e["internalHatcheryRate"]
                    if "habCapacityMult" in e: r_hab_capacity_mult *= e["habCapacityMult"]
                    if "vehicleCapacityMult" in e: r_vehicle_capacity_mult *= e["vehicleCapacityMult"]
                    if "onscreenChickenMult" in e: r_max_rcb_base += e["onscreenChickenMult"]
                    if "onscreenChickenMultMax" in e: r_max_rcb_mult *= e["onscreenChickenMultMax"]
        return common_points, r_egg_value_mult, r_laying_rate_mult, r_ihr_base, r_ihr_mult, r_hab_capacity_mult, r_vehicle_capacity_mult, r_max_rcb_base, r_max_rcb_mult

    def buy_upgrades():
        nonlocal cash
        improved = True
        while improved:
            improved = False
            common_points, r_evm, r_lrm, r_ihr, r_ihrm, r_hcm, r_vcm, r_rcb_b, r_rcb_m = compute_effects()
            tot_cap = sum(HABITATS[h]["capacity"] for h in habs if h >= 0) * r_hcm
            if chickens >= 0.70 * tot_cap:
                for s in range(4):
                    cur_h = habs[s]
                    next_h = cur_h + 1
                    if next_h < len(HABITATS):
                        cost = HABITATS[next_h]["prices"][s]
                        if cost <= cash:
                            cash -= cost
                            habs[s] = next_h
                            improved = True
                            break
            tot_ship = sum(VEHICLES[v]["capacity"] / 60.0 for v in vehicles) * r_vcm
            lays = (r_lrm / 60.0) * chickens
            if lays >= 0.75 * tot_ship:
                for s in range(len(vehicles)):
                    cur_v = vehicles[s]
                    next_v = cur_v + 1
                    if next_v < len(VEHICLES):
                        cost = VEHICLES[next_v]["prices"][s]
                        if cost <= cash:
                            cash -= cost
                            vehicles[s] = next_v
                            improved = True
                            break
                if not improved and len(vehicles) < 4:
                    s = len(vehicles)
                    cost = VEHICLES[0]["prices"][s]
                    if cost <= cash:
                        cash -= cost
                        vehicles.append(0)
                        improved = True
            candidates = []
            for r in COMMON_RESEARCH:
                t = r["tier_raw"]
                if common_points >= TIER_THRESHOLDS[t]:
                    cur_lvl = research_levels[r["id"]]
                    prices = r.get("prices", [])
                    if cur_lvl < len(prices):
                        cost = prices[cur_lvl]
                        if cost <= cash:
                            candidates.append((cost, r["id"]))
            if candidates:
                candidates.sort()
                best_cost, best_id = candidates[0]
                cash -= best_cost
                research_levels[best_id] += 1
                improved = True

    for day in range(1, max_days + 1):
        for session in range(sessions_per_day):
            for m in range(1, active_mins_per_session + 1):
                common_points, r_evm, r_lrm, r_ihr, r_ihrm, r_hcm, r_vcm, r_rcb_b, r_rcb_m = compute_effects()
                tot_cap = sum(HABITATS[h]["capacity"] for h in habs if h >= 0) * r_hcm
                tot_ship_sec = sum(VEHICLES[v]["capacity"] / 60.0 for v in vehicles) * r_vcm
                laying_sec = (r_lrm / 60.0)
                
                hatch_rate = 8.0 + (4 * r_ihr * r_ihrm / 60.0)
                new_chickens = min(tot_cap, chickens + hatch_rate * 60.0)
                avg_pop = (chickens + new_chickens) / 2.0
                chickens = new_chickens
                
                eb = se_count * 0.10
                rcb_mult = max(1.0, r_rcb_b * r_rcb_m)
                rate = min(laying_sec * avg_pop, tot_ship_sec) * EGGS[egg_index]["value"] * r_evm * (1.0 + eb) * rcb_mult
                earned = rate * 60.0
                
                fv = calculate_farm_value(egg_index, EGGS[egg_index]["value"], chickens, tot_cap, tot_ship_sec * 60,
                                         r_evm, r_lrm, r_ihr, r_ihrm, r_rcb_b, r_rcb_m, se_count)
                if m % 2 == 0:
                    struggle = 0.1 if chickens <= 100 else 1.5
                    b = 0.02
                    drone_cash = fv * (b / 50.0) * struggle
                    earned += drone_cash
                    
                cash += earned
                session_earnings += earned
                buy_upgrades()
                
                common_points, r_evm, r_lrm, r_ihr, r_ihrm, r_hcm, r_vcm, r_rcb_b, r_rcb_m = compute_effects()
                tot_cap = sum(HABITATS[h]["capacity"] for h in habs if h >= 0) * r_hcm
                tot_ship_sec = sum(VEHICLES[v]["capacity"] / 60.0 for v in vehicles) * r_vcm
                fv = calculate_farm_value(egg_index, EGGS[egg_index]["value"], chickens, tot_cap, tot_ship_sec * 60,
                                         r_evm, r_lrm, r_ihr, r_ihrm, r_rcb_b, r_rcb_m, se_count)
                
                for next_idx in range(len(EGGS) - 1, egg_index, -1):
                    if fv >= EGGS[next_idx]["advanceFV"]:
                        egg_index = next_idx
                        if next_idx not in milestones:
                            milestones[next_idx] = {
                                "day": day,
                                "time_desc": f"Dzień {day}, sesja {session+1}, minuta {m}",
                                "prestiges": total_prestiges,
                                "se": se_count,
                                "fv": fv
                            }
                        reset_to_egg(egg_index)
                        break
            
            common_points, r_evm, r_lrm, r_ihr, r_ihrm, r_hcm, r_vcm, r_rcb_b, r_rcb_m = compute_effects()
            tot_cap = sum(HABITATS[h]["capacity"] for h in habs if h >= 0) * r_hcm
            tot_ship_sec = sum(VEHICLES[v]["capacity"] / 60.0 for v in vehicles) * r_vcm
            laying_sec = (r_lrm / 60.0)
            
            offline_ihr = 4 * r_ihr * r_ihrm / 60.0
            new_chickens = min(tot_cap, chickens + offline_ihr * offline_sec)
            avg_pop_off = (chickens + new_chickens) / 2.0
            chickens = new_chickens
            
            eb = se_count * 0.10
            rcb_mult = max(1.0, r_rcb_b * r_rcb_m)
            rate_off = min(laying_sec * avg_pop_off, tot_ship_sec) * EGGS[egg_index]["value"] * r_evm * (1.0 + eb) * rcb_mult
            earned_off = rate_off * offline_sec * away_efficiency
            cash += earned_off
            session_earnings += earned_off
            
            fv = calculate_farm_value(egg_index, EGGS[egg_index]["value"], chickens, tot_cap, tot_ship_sec * 60,
                                     r_evm, r_lrm, r_ihr, r_ihrm, r_rcb_b, r_rcb_m, se_count)
            
            for next_idx in range(len(EGGS) - 1, egg_index, -1):
                if fv >= EGGS[next_idx]["advanceFV"]:
                    egg_index = next_idx
                    if next_idx not in milestones:
                        milestones[next_idx] = {
                            "day": day,
                            "time_desc": f"Dzień {day} (po nocy offline {session+1})",
                            "prestiges": total_prestiges,
                            "se": se_count,
                            "fv": fv
                        }
                    reset_to_egg(egg_index)
                    break
                    
            pending_se = calculate_soul_eggs(session_earnings)
            should_prestige = False
            if egg_index < len(EGGS) - 1:
                next_req = EGGS[egg_index + 1]["advanceFV"]
                gap = next_req / max(1.0, fv)
                
                if total_prestiges == 0:
                    if gap > 20 and pending_se >= 25:
                        should_prestige = True
                else:
                    if gap > 30 and (pending_se >= se_count * 0.70 or chickens >= 0.85 * tot_cap):
                        should_prestige = True
            
            if should_prestige:
                se_count += pending_se
                total_prestiges += 1
                session_earnings = 0.0
                reset_to_egg(0)
                
                while True:
                    common_points, r_evm, r_lrm, r_ihr, r_ihrm, r_hcm, r_vcm, r_rcb_b, r_rcb_m = compute_effects()
                    tot_cap = sum(HABITATS[h]["capacity"] for h in habs if h >= 0) * r_hcm
                    tot_ship_sec = sum(VEHICLES[v]["capacity"] / 60.0 for v in vehicles) * r_vcm
                    cur_fv = calculate_farm_value(egg_index, EGGS[egg_index]["value"], max(250, chickens), tot_cap, tot_ship_sec * 60,
                                                 r_evm, r_lrm, r_ihr, r_ihrm, r_rcb_b, r_rcb_m, se_count)
                    advanced = False
                    for n_idx in range(len(EGGS) - 1, egg_index, -1):
                        if cur_fv >= EGGS[n_idx]["advanceFV"]:
                            egg_index = n_idx
                            reset_to_egg(egg_index)
                            advanced = True
                            break
                    if not advanced:
                        break
                        
        if 9 in milestones and 10 in milestones:
            if day > 25:
                break
                
    return milestones, total_prestiges, se_count

if __name__ == "__main__":
    m1, p1, se1 = run_f2p_sim(sessions_per_day=1, active_mins_per_session=20, max_days=35)
    print("--- 1x 20 min/dzień ---")
    print(f"Total prestiges: {p1}, SE: {se1:.2e}")
    for idx in sorted(m1.keys()):
        print(f"Egg {idx:2d} ({EGGS[idx]['name']:<25}): {m1[idx]['time_desc']}, SE: {m1[idx]['se']:.1f}, FV: {m1[idx]['fv']:.2e}")

    m2, p2, se2 = run_f2p_sim(sessions_per_day=2, active_mins_per_session=10, max_days=35)
    print("\n--- 2x 10 min/dzień ---")
    print(f"Total prestiges: {p2}, SE: {se2:.2e}")
    for idx in sorted(m2.keys()):
        print(f"Egg {idx:2d} ({EGGS[idx]['name']:<25}): {m2[idx]['time_desc']}, SE: {m2[idx]['se']:.1f}, FV: {m2[idx]['fv']:.2e}")
    
    print("\nSimulations complete.")
