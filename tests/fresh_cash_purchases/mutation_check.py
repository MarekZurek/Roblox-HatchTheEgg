"""Selected transaction faults, exclusively in isolated copies under build/."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from mutation_support import run_mutations
MUTATIONS = {'validate_durable_only': ['local '
                           'validator=settledValidator(h.snapshot,candidate,outcome.validate)',
                           'local validator=outcome.validate'],
 'omit_pending_fields': ['fresh[change.path[1]][change.path[2]]=data.copy(change.value)',
                         '-- mutation: pending simulation omitted'],
 'ignore_changed_base': ['if actual~=expected[i] then return false,"SIMULATION_BASE_CHANGED" end',
                         'if false then return false,"SIMULATION_BASE_CHANGED" end'],
 'omit_income_cursor_patch': ['local changes=patches(h.snapshot,final)',
                              'local changes=patches(candidate,final)'],
 'allow_stale_checkpoint': ['freezeWork("SIMULATION_BASE_CHANGED")',
                            '-- mutation: keep divergent working state available'],
 'validate_post_purchase': ['local '
                            'validator=settledValidator(h.snapshot,candidate,outcome.validate)',
                            'local validator=settledValidator(h.snapshot,final,outcome.validate)']}
EXPECTED_FAILURES = {'validate_durable_only': 'spend new earnings without a checkpoint expected APPLIED got REJECTED',
 'omit_pending_fields': 'spend new earnings without a checkpoint expected APPLIED got REJECTED',
 'ignore_changed_base': 'SPEC/reject changed simulation base expected REJECTED got APPLIED',
 'omit_income_cursor_patch': 'spending does not reduce earned accumulator expected 6 got 0',
 'allow_stale_checkpoint': 'divergent provisional state hidden expected nil got table:',
 'validate_post_purchase': 'spend new earnings without a checkpoint expected APPLIED got REJECTED'}

EXPECTED_CASE_LINES = {'validate_durable_only': 63,
 'omit_pending_fields': 63,
 'ignore_changed_base': 235,
 'omit_income_cursor_patch': 66,
 'allow_stale_checkpoint': 238,
 'validate_post_purchase': 63}

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--only',action='append',choices=list(MUTATIONS))
 args=parser.parse_args()
 cases=[{'name':name,'suite':'fresh_cash_purchases','faults':[('src/server/PlayerCoordinator.luau',*fault)],'expectedFailure':EXPECTED_FAILURES[name],'expectedCaseLine':EXPECTED_CASE_LINES[name]}
        for name,fault in MUTATIONS.items() if not args.only or name in args.only]
 run_mutations(ROOT,cases,'fresh_cash_mutations-results')
if __name__=='__main__':main()
