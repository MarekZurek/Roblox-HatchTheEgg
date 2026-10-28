# Roblox: spec-derived expectations and regression evidence

Use this contract when planning, implementing or reviewing HatchTheEgg tests. It does not authorize code changes, publishing, real purchases or cloud writes.

## Scope and authoritative requirements

Read `docs/CURRENT_SPEC.md` and the current user decision before choosing expectations. Name the requirement, source section and source revision. Distinguish approved behavior from reference-only data, proposals and historical reports. A withdrawn feature is not a requirement to restore: active RCB and timed Video Doubler remain retired. Leave deferred balance docs17–21 unchanged unless explicitly authorized.

Accept explicit test files, a GitHub issue or a scoped diff as the review scope when there are no story files. Build a requirement-to-test table for that scope; do not invent stories, or report a clean review over an empty set. An unresolvable scope is NOT ASSESSED.

## Independent expectations

For each relevant criterion record:

|Criterion/source|Fixture and action|Expected observable result|Oracle provenance|Regression evidence|
|---|---|---|---|---|
|Requirement + section/revision|Inputs, clock, state|Output, rejection, state or displayed message|Why independent of the implementation|Unfixed/mutant FAIL, fixed PASS, commands and versions|

- Derive the expected result from the approved rule: hand-calculated constants, separately implemented arithmetic from that rule, or independently maintained golden vectors. State rounding, boundaries and numeric units where material.
- Never obtain the expected value by calling the function under test or by copying the changed algorithm. Do not change an expectation merely to make a failing test pass; resolve the requirement first. For a user-approved rule change, update its source and then derive new expectations.
- Catalogue equality, projection/grant equality and metamorphic invariants are useful integration tests. Label their purpose honestly: reading a price from the same catalogue as the purchase does not independently validate that price. Pair a critical formula/invariant with at least one independently known expected result.
- A regenerated oracle derived from an edited data file proves serialization/consistency with that file, not approval of its balance. Keep this distinction in the report.
- Assert observable behavior, not only a counter or callback. For missing FV, verify the unknown-value message and pending action; for authoritative zero, verify zero and the insufficient-value message. These are distinct cases. A high assertion count cannot substitute for a missing criterion.

## Required regression FAIL → PASS

For each bug regression, run the same test and fixture against the unfixed behavior and the fix. Retain the command, tested source revision or exact fault diff, exit status and failing assertion. A regression seen only passing is INCOMPLETE evidence.

When the fix already exists, use an isolated checkout/copy of the old implementation. If the old version cannot run with the test's dependencies, use a documented semantic fault that reproduces the bug in an isolated copy. Never mutate the active source, Studio session, cloud state or real purchases to manufacture a failure.

- **DETECTED:** the faulty behavior fails the intended requirement assertion, and the corrected behavior passes.
- **SURVIVED:** the faulty behavior passes; strengthen the fixture/assertions before calling that regression adequate.
- **INVALID:** syntax/import failure, missing tools, timeout or unrelated failure. This does not prove the regression detects the bug.
- Missing old source or an unavailable runtime is NOT VERIFIED, never an invented FAIL. Report the gap; do not claim complete regression evidence.

Do not require arbitrary assertion counts per helper. Luau suites often use top-level `do`/`for` cases and `eq`/`near` helpers instead of TestEZ `it` functions. Review distinct requirements, actions, negative controls and state effects, including rejection/retry and clock boundaries when relevant.

## Roblox execution and evidence levels

- Use `tests/<suite>/run.luau` for the existing Lune suites; TestEZ `*.spec.luau` is optional when the project actually uses TestEZ. Register a new suite in `tools/test.ps1`.
- Read executable versions and hashes from `tools/toolchain.json`; do not substitute example pins from another engine or a stale config. The normal local gate is `./tools/test.ps1`, with `-PythonExecutable <available-python>` when needed. Report the exact command and exit code.
- For a targeted suite use the manifest-selected Lune executable with `run tests/<suite>/run.luau`. For existing mutation checks use their documented selector; a semantic assertion failure is required. Do not count an import error as a detected bug.
- Lune proves only the exercised module/mock paths. Rojo build/sourcemap proves static mapping. Neither is a full strict typecheck, native UI/layout acceptance, replication test or cloud purchase/persistence result.
- Native Roblox behavior needs separate Studio evidence, following `hte-validate-studio`. Inspect the current instance and mode before changes; do not assume a scene matches HEAD or stop another Play without authorization. Local memory mode cannot verify real persistence or payments.
- A numeric-only smoke command is a numeric check, not the whole game's smoke gate. An exit0 with no relevant cases is NOT ASSESSED. Report unavailable tools or incomplete execution explicitly.

## Review outcome

ADEQUATE requires the in-scope behavior, independent expectations where required, and valid FAIL/PASS regression evidence. Use INCOMPLETE for missing criteria, circular expectations presented as spec verification, or surviving faults. Name which evidence is Lune/local, static build, Studio or cloud; do not promote one to another. Static skill checks and keyword matches assess instructions, not actual agent behavior.
