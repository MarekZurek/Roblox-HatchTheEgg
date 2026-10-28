"""Scoped local evidence validation; never certifies release readiness (#60)."""
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
    print("  PASS: Selected forbidden tokens absent; this scan does not prove absence of all privileged handlers.")


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
    print("  PASS: Deferred files exist; selected import references absent (not a balance audit).")


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
    assert len(mapping.get("modules", [])) == 42, f"Expected 42 modules, got {len(mapping.get('modules', []))}"
    assert len(mapping.get("scripts", [])) == 2, f"Expected 2 entrypoint scripts, got {len(mapping.get('scripts', []))}"
    print("  PASS: 42 Rojo modules mapped, 2 entrypoint scripts.")

    print("Checking Release Candidate test results ...")
    rc_results_path = ROOT / "build/release_candidate-results.json"
    assert rc_results_path.is_file(), "build/release_candidate-results.json missing"
    rc = json.loads(rc_results_path.read_text(encoding="utf-8"))
    assert rc.get("status") == "PASS", f"RC tests failed: {rc}"
    acceptance = json.loads((ROOT / "build/acceptance-results.json").read_text(encoding="utf-8"))
    validate_local_evidence(acceptance, rc)
    report = {
        "status": "PASS_LOCAL_CHECKS", "level": "L", "releaseCandidateReady": False,
        "completeProductionCoverage": False,
        "scope": "local report consistency, selected source token scan, import quarantine and static Rojo mapping",
        "unverifiedLevels": ["S", "D", "H"],
        "limitations": ["No Studio, real cloud persistence or human acceptance evidence recorded per scenario",
                        "Counts and scenario names do not measure requirement coverage",
                        "Local Main harness uses controlled external services and world presentation",
                        "Unavailable production features and missing S/D/H acceptance are not cleared by this tool"],
        "scenarioEvidence": acceptance["scenarioEvidence"],
    }
    (ROOT / "build/release-verification-results.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("  PASS: local evidence metadata consistent; S/D/H NOT_VERIFIED; release readiness NOT_APPROVED.")


REQUIRED_LEVELS = {
    "A01": ["L", "S"], "A02": ["L", "S"], "A03": ["L", "S"], "A04": ["L"], "A05": ["L"],
    "A06": ["L", "S"], "A07": ["L", "S"], "A08": ["L", "S"], "A09": ["L", "S", "D"],
    "A10": ["L", "S"], "A11": ["L", "D"], "A12": ["L", "S", "D"], "A13": ["L", "D"],
    "A14": ["L", "S"], "A15": ["S"], "A16": ["S", "H"],
}


def validate_local_evidence(acceptance, rc):
    """This runner has only L evidence. Higher levels need a separate evidenced runner."""
    for result in (acceptance, rc):
        assert result.get("status") == "PASS", "local suite did not pass"
        assert result.get("level") == "L", "local runner may claim only L"
        for flag in ("studioTested", "dataStoreTested", "humanAcceptanceTested"):
            assert result.get(flag) is False, f"unsupported evidence flag {flag}"
        assert "coveragePercent" not in result, "assertion counts do not prove coverage"
    assert rc.get("releaseCandidateReady") is False, "local tests cannot approve a release"
    assert "gatesVerified" not in rc, "blanket release gate booleans are not evidence"
    wiring = rc.get("productionWiring", {})
    assert wiring.get("status") == "PASS_L", "missing actual Main ingress regressions"
    assert wiring.get("evidence") == "tests/release_candidate/run.luau", "missing wiring evidence path"
    assert set(wiring.get("cases", [])) == {"bootstrap", "calendar_once", "calendar_replay_after_restart", "unissued_drone_rejected"}, "missing wiring cases"
    scenarios = acceptance.get("scenarios", {})
    evidence = acceptance.get("scenarioEvidence", {})
    assert set(scenarios) == set(REQUIRED_LEVELS) == set(evidence), "missing scenario evidence"
    for key, required in REQUIRED_LEVELS.items():
        row = evidence[key]
        assert row.get("requiredLevels") == required, f"wrong planned levels for {key}"
        assert type(scenarios[key]) is int and scenarios[key] > 0, "missing assertions"
        assert row.get("assertions") == scenarios[key], "inconsistent assertion count"
        levels = row.get("levels", {})
        assert set(levels) == {"L", "S", "D", "H"}, "incomplete evidence matrix"
        assert levels["L"].get("status") == "PASS", "missing local result"
        assert levels["L"].get("evidence") == "tests/acceptance/run.luau", "missing local evidence path"
        for level in ("S", "D", "H"):
            assert levels[level].get("status") == "NOT_VERIFIED", f"unsupported {level} PASS for {key}"
            assert levels[level].get("reason"), "unverified evidence needs a reason"
    assert acceptance.get("totalAssertions") == sum(scenarios.values()), "incorrect assertion sum"



def main():
    print("======================================================================")
    print("HatchTheEgg - Scoped Local Evidence Checks (REL-01 / #60)")
    print("======================================================================")
    check_forbidden_terms_in_src()
    check_deferred_balance_quarantine()
    check_test_suites_in_test_script()
    check_build_artifacts()
    print("======================================================================")
    print("LOCAL CHECKS PASSED; RELEASE NOT APPROVED; S/D/H NOT VERIFIED")
    print("======================================================================")


if __name__ == "__main__":
    main()
