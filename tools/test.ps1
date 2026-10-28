param([string]$PythonExecutable = 'python', [switch]$MutationChecks)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
foreach ($taskName in @('lune', 'rojo')) {
    $taskSpec = $taskManifest.$taskName
    $taskExecutable = Join-Path $taskRoot ('.tools/' + $taskName + '-' + $taskSpec.version + '/' + $taskName + '.exe')
    if (-not (Test-Path -LiteralPath $taskExecutable)) { throw 'Run tools/bootstrap.ps1 first.' }
    if ((Get-FileHash -LiteralPath $taskExecutable -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskSpec.executableSha256) {
        throw ('Executable checksum mismatch: ' + $taskName)
    }
}
Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force -Path 'build' | Out-Null
    & $PythonExecutable tools/generate_action_catalog.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Action reference generation check failed.' }
    & $PythonExecutable tools/generate_catalog.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Catalog generation check failed.' }
    & $PythonExecutable tests/catalog/build_oracle.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Independent catalog oracle check failed.' }
    & $PythonExecutable tools/generate_population_vectors.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Independent population oracle check failed.' }
    & $PythonExecutable tests/calendar_cycle/build_oracle.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Independent calendar oracle check failed.' }
    # Build before suites that inspect the current mapping; no stale artifact dependency.
    & (Join-Path $taskRoot ('.tools/rojo-' + $taskManifest.rojo.version + '/rojo.exe')) build default.project.json --output build/HatchTheEgg.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed.' }
    & (Join-Path $taskRoot ('.tools/rojo-' + $taskManifest.rojo.version + '/rojo.exe')) sourcemap default.project.json --output build/sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap failed.' }
    & $PythonExecutable tools/verify_build.py
    if ($LASTEXITCODE -ne 0) { throw 'Static mapping verification failed.' }
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run tests/numeric/run.luau
    if ($LASTEXITCODE -ne 0) { throw 'Numeric tests failed.' }
    $taskSuite = 'client_performance'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'Client performance regressions failed.' }
    $taskSuite = 'plate_acceptance'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'Independent plate acceptance failed.' }
    $taskSuite = 'ui7780_acceptance'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'UI #77-80 independent acceptance failed.' }
    $taskSuite = 'fresh_cash_purchases'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'Fresh cash purchase regressions failed.' }
    $taskSuite = 'remaining_fixes'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'Remaining fixes regressions failed.' }
    $taskSuite = 'retired_doubler'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'Retired doubler regressions failed.' }
    $taskSuite = 'upgrade_previews'
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
    if ($LASTEXITCODE -ne 0) { throw 'Upgrade preview regressions failed.' }
    foreach ($taskSuite in @('catalog', 'protocol', 'persistence', 'math', 'fv_se', 'ihr', 'hatching', 'coordinator', 'timeline', 'integration89', 'purchases', 'resets', 'effect_boundaries', 'pet_effects', 'fusion', 'drones', 'offers', 'claims', 'purchase_recovery', 'tutorial', 'gateway', 'client_state', 'presentation', 'plate_hatching', 'plate_visuals', 'rates_panel', 'ui', 'ui_tasks_77_80', 'ui_assets', 'integration', 'acceptance', 'release_candidate', 'reward_security', 'production_context', 'game_behavior', 'calendar_cycle', 'persistence_startup', 'pro_policy', 'event_time', 'session_prestige_rcb', 'rcb_income', 'farm_gaps', 'entitlement_farm_regressions', 'epic_research')) {
        & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run ('tests/' + $taskSuite + '/run.luau')
        if ($LASTEXITCODE -ne 0) { throw ('Tests failed: ' + $taskSuite) }
    }
    if ($MutationChecks) {
        & $PythonExecutable tests/game_behavior/mutation_check.py
        if ($LASTEXITCODE -ne 0) { throw 'Behavior mutation checks failed.' }
        & $PythonExecutable tests/fresh_cash_purchases/mutation_check.py
        if ($LASTEXITCODE -ne 0) { throw 'Fresh cash mutation checks failed.' }
        & $PythonExecutable tests/spec_regressions/mutation_check.py
        if ($LASTEXITCODE -ne 0) { throw 'Spec regression mutation checks failed.' }
        & $PythonExecutable tests/spec_regressions/runner_fault_check.py
        if ($LASTEXITCODE -ne 0) { throw 'Mutation gate negative controls failed.' }
        & $PythonExecutable tests/spec_regressions/verify_evidence.py
        if ($LASTEXITCODE -ne 0) { throw 'Mutation evidence verification failed.' }
    }
    & $PythonExecutable tests/spec_regressions/test_mutation_support.py
    if ($LASTEXITCODE -ne 0) { throw 'Mutation evidence runner regressions failed.' }
    & $PythonExecutable tests/release_reporting/test_reporting.py
    if ($LASTEXITCODE -ne 0) { throw 'Release evidence regression tests failed.' }
    & $PythonExecutable tools/verify_release.py
    if ($LASTEXITCODE -ne 0) { throw 'Release verification failed.' }
} finally { Pop-Location }
