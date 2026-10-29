"""Isolated semantic faults for the user-approved Epic purchase contract."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from mutation_support import run_mutations
CASES=[
 {'name':'no_level_grant','suite':'epic_robux','faults':[('src/server/EpicPurchases.luau','p.permanent.epic[intent.researchId] = intent.level','p.permanent.epic[intent.researchId] = intent.level-1')],'expectedFailure':'selected research gets exactly one level'},
 {'name':'receipt_recreates_unit','suite':'epic_robux','faults':[('src/server/EpicPurchases.luau','local saved=p.accounting.processedReceipts[token]\n if saved then','local saved=p.accounting.processedReceipts[token]\n if false then')],'expectedFailure':'durable receipt guard prevents duplicate paid unit'},
 {'name':'reconnect_loses_intent','suite':'epic_robux','faults':[('src/server/Bootstrap.luau','local handle = opened.handle','local handle = opened.handle\n if handle.snapshot.permanent.epicPurchases then handle.snapshot.permanent.epicPurchases.pending=nil end')],'expectedFailure':'reconnect grants originally selected research'},
 {'name':'unselected_payment_lost','suite':'epic_robux','faults':[('src/server/EpicPurchases.luau','local pending=s.pending','local pending=s.pending\n if not pending then s.credits[productId]="0" end')],'expectedFailure':'one paid credit'},
 {'name':'old_ge_prices','suite':'epic_robux','faults':[('src/shared/EpicPricing.luau','math.ceil(referencePrice / 2)','math.ceil(referencePrice)')],'expectedFailure':'halved GE ceil'},
 {'name':'old_robux_price','suite':'epic_robux','faults':[('src/shared/EpicPricing.luau','return P.productIds[1], 9','return P.productIds[1], 19')],'expectedFailure':'nominal Robux'},
 {'name':'client_prompt_missing','suite':'epic_robux','faults':[('src/client/Bootstrap.luau','prompt(response.result)','local ignored=response.result')],'expectedFailure':'confirmation opens one platform prompt'},
]
if __name__=='__main__':run_mutations(ROOT,CASES,'epic-robux-mutations')
