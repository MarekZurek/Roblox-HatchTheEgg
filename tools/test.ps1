param()
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
    & (Join-Path $taskRoot ('.tools/lune-' + $taskManifest.lune.version + '/lune.exe')) run tests/numeric/run.luau
    if ($LASTEXITCODE -ne 0) { throw 'Numeric tests failed.' }
    & (Join-Path $taskRoot ('.tools/rojo-' + $taskManifest.rojo.version + '/rojo.exe')) build default.project.json --output build/HatchTheEgg.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed.' }
    & (Join-Path $taskRoot ('.tools/rojo-' + $taskManifest.rojo.version + '/rojo.exe')) sourcemap default.project.json --output build/sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap failed.' }
} finally { Pop-Location }
