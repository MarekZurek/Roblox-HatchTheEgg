"""Regression tests for evidence semantics using actual generated runner results."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("verify_release", ROOT / "tools/verify_release.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.acceptance = json.loads((ROOT / "build/acceptance-results.json").read_text())
        self.rc = json.loads((ROOT / "build/release_candidate-results.json").read_text())

    def validate(self):
        verifier.validate_local_evidence(self.acceptance, self.rc)

    def test_actual_local_results_do_not_approve_release(self):
        self.validate()
        self.assertFalse(self.rc["releaseCandidateReady"])

    def test_mixed_level_from_old_runner_is_rejected(self):
        self.acceptance["level"] = "L/S/D"
        with self.assertRaises(AssertionError):
            self.validate()

    def test_passing_tests_do_not_override_missing_external_evidence(self):
        self.rc["releaseCandidateReady"] = True
        with self.assertRaises(AssertionError):
            self.validate()

    def test_external_level_requires_its_own_evidence(self):
        for level in ("S", "D", "H"):
            with self.subTest(level=level):
                saved = copy.deepcopy(self.acceptance)
                self.acceptance["scenarioEvidence"]["A16"]["levels"][level]["status"] = "PASS"
                with self.assertRaises(AssertionError):
                    self.validate()
                self.acceptance = saved

    def test_mock_cloud_or_studio_flag_is_rejected(self):
        for flag in ("studioTested", "dataStoreTested", "humanAcceptanceTested"):
            with self.subTest(flag=flag):
                self.rc[flag] = True
                with self.assertRaises(AssertionError):
                    self.validate()
                self.rc[flag] = False

    def test_missing_scenario_cannot_be_hidden_by_total(self):
        del self.acceptance["scenarioEvidence"]["A11"]
        with self.assertRaises(AssertionError):
            self.validate()

    def test_missing_main_wiring_not_accepted(self):
        del self.rc["productionWiring"]
        with self.assertRaises(AssertionError):
            self.validate()

    def test_human_scenario_cannot_be_downgraded_to_local_requirement(self):
        self.acceptance["scenarioEvidence"]["A16"]["requiredLevels"] = ["L"]
        with self.assertRaises(AssertionError):
            self.validate()

    def test_assertions_cannot_be_promoted_to_coverage_percent(self):
        self.acceptance["coveragePercent"] = 100
        with self.assertRaises(AssertionError):
            self.validate()

    def test_blanket_release_flags_are_rejected(self):
        self.rc["gatesVerified"] = {"everything": True}
        with self.assertRaises(AssertionError):
            self.validate()

    def test_assertion_sum_must_match_cases(self):
        self.acceptance["totalAssertions"] += 1
        with self.assertRaises(AssertionError):
            self.validate()


if __name__ == "__main__":
    unittest.main(verbosity=2)
