"""Selected semantic mutations of the pending-simulation transaction boundary."""
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src/server/PlayerCoordinator.luau"
LUNE = ROOT / ".tools/lune-0.11.1/lune.exe"
MUTATIONS = {
    "validate_durable_only": (
        "local validator=settledValidator(h.snapshot,candidate,outcome.validate)",
        "local validator=outcome.validate",
    ),
    "omit_pending_fields": (
        "fresh[change.path[1]][change.path[2]]=data.copy(change.value)",
        "-- mutation: pending simulation omitted",
    ),
    "ignore_changed_base": (
        'if actual~=expected[i] then return false,"SIMULATION_BASE_CHANGED" end',
        'if false then return false,"SIMULATION_BASE_CHANGED" end',
    ),
    "omit_income_cursor_patch": (
        "local changes=patches(h.snapshot,final)",
        "local changes=patches(candidate,final)",
    ),
    "allow_stale_checkpoint": (
        'freezeWork("SIMULATION_BASE_CHANGED")',
        '-- mutation: keep divergent working state available',
    ),
    "validate_post_purchase": (
        "local validator=settledValidator(h.snapshot,candidate,outcome.validate)",
        "local validator=settledValidator(h.snapshot,final,outcome.validate)",
    ),
}


def main():
    original = SOURCE.read_bytes()
    detected = []
    try:
        for name, (old, new) in MUTATIONS.items():
            needle = old.encode()
            assert original.count(needle) == 1, f"Ambiguous mutation: {name}"
            SOURCE.write_bytes(original.replace(needle, new.encode(), 1))
            result = subprocess.run(
                [str(LUNE), "run", "tests/fresh_cash_purchases/run.luau"],
                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                timeout=60,
            )
            assert result.returncode != 0, f"Mutation survived: {name}"
            assert b"expected" in result.stdout, f"Mutation failed outside an assertion: {name}"
            detected.append(name)
            print(f"Detected: {name}", flush=True)
    finally:
        SOURCE.write_bytes(original)
    assert SOURCE.read_bytes() == original
    # Mutants fail before writing a PASS report. Reconfirm the restored source.
    subprocess.run([str(LUNE), "run", "tests/fresh_cash_purchases/run.luau"], cwd=ROOT, check=True)
    (ROOT / "build/fresh_cash_mutations-results.json").write_text(
        json.dumps({"detected": detected, "count": len(detected), "sourceRestored": True}, indent=2),
        encoding="utf-8",
    )
    print(f"Fresh cash selected mutations: {len(detected)}/{len(MUTATIONS)} detected")


if __name__ == "__main__":
    main()
