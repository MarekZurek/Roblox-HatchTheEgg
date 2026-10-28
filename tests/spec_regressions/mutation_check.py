"""Previously surviving faults and missing regression evidence. Sources: docs/workflow/test_oracle_repairs_2026_10_28.md."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from mutation_support import run_mutations
CASES = [{'name': 'missing_common_descriptor',
  'suite': 'upgrade_previews',
  'faults': [('src/server/ViewProjector.luau',
              '\t\t\tif not can and reason ~= nil then',
              '\t\t\tif id == "excoskeletons" then entry.effects = {} end\n'
              '\t\t\tif not can and reason ~= nil then')],
  'expectedFailure': 'SPEC/common effect missing: excoskeletons/'},
 {'name': 'wrong_habitat_price',
  'suite': 'purchases',
  'faults': [('src/server/CatalogRegistry/init.luau',
              'return api.getHabitat(typeIndex).prices[index(slotIndex, 3) + 1]',
              'return api.getHabitat(typeIndex).prices[index(slotIndex, 3) + 1] * 1.01')],
  'expectedFailure': 'SPEC/habitat same-type reference price'},
 {'name': 'wrong_epic_discount',
  'suite': 'epic_research',
  'faults': [('src/server/CatalogRegistry/init.luau',
              'return row.effectsByLevel[index(level, row.maxLevel) + 1]\n'
              '\tend\n'
              '\tfunction api.tierThreshold',
              'local out = row.effectsByLevel[index(level, row.maxLevel) + 1]\n'
              '\t\tif id == "cheaper_contractors" and level == 5 then local changed = '
              'table.clone(out);changed.habCostMult *= 0.9;return changed end\n'
              '\t\treturn out\n'
              '\tend\n'
              '\tfunction api.tierThreshold')],
  'expectedFailure': 'SPEC/habitat discount 0.75'},
 {'name': 'wrong_high_tier_threshold',
  'suite': 'math',
  'faults': [('src/server/CatalogRegistry/init.luau',
              'return d.tierThresholds[index(tierRaw, #d.tierThresholds - 1) + 1]',
              'local value=d.tierThresholds[index(tierRaw, #d.tierThresholds - 1) + 1];return if '
              'tierRaw >= 3 then 9999 else value')],
  'expectedFailure': 'SPEC/tier boundary '},
 {'name': 'tiny_home_target',
  'suite': 'rates_panel',
  'faults': [('src/client/HUD.luau',
              'Name = "DomButton",\n\t\tSize = isRoblox and UDim2.new(0, 44, 0, 44) or nil,',
              'Name = "DomButton",\n\t\tSize = isRoblox and UDim2.new(0, 1, 0, 1) or nil,')],
  'expectedFailure': 'SPEC/header target width: DomButton'},
 {'name': 'unsupported_epic_allowed',
  'suite': 'remaining_fixes',
  'faults': [('src/server/Bootstrap.luau',
              'elseif not Availability.isEpicAvailable(canonicalId) then',
              'elseif false then')],
  'expectedFailure': 'unsupported effect rejected'},
 {'name': 'planned_purchase_reserved',
  'suite': 'remaining_fixes',
  'faults': [('src/server/platform/products.luau',
              'if not preview.isAvailable then',
              'if false then')],
  'expectedFailure': 'planned product cannot reserve a purchase'},
 {'name': 'planned_purchase_granted',
  'suite': 'remaining_fixes',
  'faults': [('src/server/platform/products.luau',
              'if not def or not def.availableAtLaunch then',
              'if not def then')],
  'expectedFailure': 'old pending reservation cannot grant unavailable product'},
 {'name': 'prestige_preview_without_event',
  'suite': 'remaining_fixes',
  'faults': [('src/server/ViewProjector.luau',
              'local prestigeEventMult = Effects.calculateMultipliers(nil, farm, serverObservedAt, '
              'self.liveEvents).eventPrestigeMult',
              'local prestigeEventMult = 1')],
  'expectedFailure': 'event start and deadline semantics'},
 {'name': 'retired_timer_gives_income',
  'suite': 'retired_doubler',
  'faults': [('src/server/EffectsManager.luau',
              'local vdMult = 1.0',
              'local vdMult = if effects and effects.videoDoublerEndsAtMs then 2.0 else 1.0')],
  'expectedFailure': 'SPEC/legacy timer has neutral multiplier'},
 {'name': 'retired_research_readmitted',
  'suite': 'retired_doubler',
  'faults': [('src/server/CatalogRegistry/init.luau',
              'if id == "video_doubler_time" then fail("RESEARCH_REMOVED") end',
              '-- Mutation: retired research readmitted')],
  'expectedFailure': 'retired catalog access rejected'},
 {'name': 'permanent_cash_pass_removed',
  'suite': 'retired_doubler',
  'faults': [('src/server/TimelineSimulation.luau',
              'if (cp.state.entitlements and cp.state.entitlements.double_cash == true) or '
              '(cp.config and cp.config.double_cash == true) then',
              'if false then')],
  'expectedFailure': '30 hens * 1/30 eggs/s * $1.25 * 3s * 2x permanent pass, no timed bonus'},
 {'name': 'retired_activation_allowed',
  'suite': 'retired_doubler',
  'faults': [('src/server/EffectsManager.luau',
              'return false, "FEATURE_REMOVED"',
              'return true, "FEATURE_REMOVED"')],
  'expectedFailure': 'SPEC/retired activation rejected'}]

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--only',action='append',choices=[c['name'] for c in CASES])
 args=parser.parse_args()
 run_mutations(ROOT,[c for c in CASES if not args.only or c['name'] in args.only],'spec-regression-mutations')
if __name__=='__main__':main()
