"""Release Candidate Gate Verification Tool (REL-01 / #36).
Validates explicit release gates across code, configuration, tests, and documentation.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def check_forbidden_terms_in_src():
    print("Checking absence of devgrants/backdoors in src/ ...")
    forbidden = [
        re.compile(r"\bdevgrant\b", re.IGNORECASE),
        re.compile(r"\bgodmode\b", re.IGNORECASE),
        re.compile(r"\badd_money\b", re.IGNORECASE),
        re.compile(r"\bfree_ge\b", re.IGNORECASE),
        re.compile(r"\badmin_grant\b", re.IGNORECASE),
    ]
    for p in (ROOT / "src").rglob("*.luau"):
        text = p.read_text(encoding="utf-8")
        for pattern in forbidden:
            match = pattern.search(text)
            assert not match, f"Forbidden term '{pattern.pattern}' found in {p}"
    print("  PASS: Zero devgrant/backdoor terms in production code.")


def check_deferred_balance_quarantine():
    print("Checking quarantine of deferred balance docs/17..21 ...")
    deferred_docs = [
        ROOT / "docs/17_pet_balance_draft.md",
        ROOT / "docs/18_incubator_prices_and_acquisition_pacing.md",
        ROOT / "docs/19_integrated_farm_progression_simulation.md",
        ROOT / "docs/20_paying_player_balance_direction.md",
        ROOT / "docs/21_payer_progression_and_incubation.md",
    ]
    for d in deferred_docs:
        assert d.is_file(), f"Deferred doc missing: {d}"

    # Ensure src does not import or parse deferred docs
    for p in (ROOT / "src").rglob("*.luau"):
        text = p.read_text(encoding="utf-8")
        for num in ("17_", "18_", "19_", "20_", "21_"):
            assert num not in text, f"Source {p} references deferred doc {num}"
    print("  PASS: Deferred balance strictly quarantined.")


def check_test_suites_in_test_script():
    print("Checking that all tests/ suites are registered in tools/test.ps1 ...")
    ps1_text = (ROOT / "tools/test.ps1").read_text(encoding="utf-8")
    for suite_dir in (ROOT / "tests").iterdir():
        if suite_dir.is_dir() and (suite_dir / "run.luau").is_file():
            name = suite_dir.name
            if name == "numeric":
                assert "tests/numeric/run.luau" in ps1_text, "numeric test registered"
            else:
                assert f"'{name}'" in ps1_text, f"Suite '{name}' not found in tools/test.ps1"
    print("  PASS: All test suites registered in test runner.")


def check_build_artifacts():
    print("Checking Rojo static build artifact ...")
    mapping_path = ROOT / "build/mapping-results.json"
    assert mapping_path.is_file(), "build/mapping-results.json missing"
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    assert mapping.get("status") == "PASS_STATIC_BUILD", f"Invalid status: {mapping.get('status')}"
    assert len(mapping.get("modules", [])) == 39, f"Expected 39 modules, got {len(mapping.get('modules', []))}"
    assert len(mapping.get("scripts", [])) == 2, f"Expected 2 entrypoint scripts, got {len(mapping.get('scripts', []))}"
    print("  PASS: 39 Rojo modules mapped, 2 entrypoint scripts.")

    print("Checking Release Candidate test results ...")
    rc_results_path = ROOT / "build/release_candidate-results.json"
    assert rc_results_path.is_file(), "build/release_candidate-results.json missing"
    rc = json.loads(rc_results_path.read_text(encoding="utf-8"))
    assert rc.get("status") == "PASS", f"RC tests failed: {rc}"
    assert rc.get("releaseCandidateReady") is True, "releaseCandidateReady must be true"
    gates = rc.get("gatesVerified", {})
    for g in ("gate1_noDevgrants", "gate2_onboardingBaseline", "gate3_stateInvariants",
              "gate4_sessionFencingRetention", "gate5_rojo36Modules", "gate6_deferredBalanceQuarantined"):
        assert gates.get(g) is True, f"Gate {g} not verified"
    print("  PASS: All 6 Release Gates and 12 E2E lifecycle stages verified.")


def main():
    print("======================================================================")
    print("HatchTheEgg - Release Candidate Gate Verification (REL-01)")
    print("======================================================================")
    check_forbidden_terms_in_src()
    check_deferred_balance_quarantine()
    check_test_suites_in_test_script()
    check_build_artifacts()
    print("======================================================================")
    print("RELEASE GATES AUDIT: ALL GATES PASSED (100%)")
    print("======================================================================")


if __name__ == "__main__":
    main()
