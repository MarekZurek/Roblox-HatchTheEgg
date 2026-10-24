param()
$ErrorActionPreference = 'Stop'
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64' -or $env:OS -ne 'Windows_NT') {
    throw 'This pinned bootstrap supports Windows x86_64 only.'
}
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
foreach ($taskName in @('lune', 'rojo')) {
    $taskSpec = $taskManifest.$taskName
    $taskDirectory = Join-Path $taskRoot ('.tools/' + $taskName + '-' + $taskSpec.version)
    $taskExecutable = Join-Path $taskDirectory ($taskName + '.exe')
    if (Test-Path -LiteralPath $taskExecutable) {
        if ((Get-FileHash -LiteralPath $taskExecutable -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskSpec.executableSha256) {
            throw ('Executable checksum mismatch: ' + $taskName)
        }
    } else {
        New-Item -ItemType Directory -Force -Path $taskDirectory | Out-Null
        $taskArchive = Join-Path $taskDirectory 'release.zip'
        Invoke-WebRequest -Uri $taskSpec.url -OutFile $taskArchive
        if ((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskSpec.archiveSha256) {
            throw ('Archive checksum mismatch: ' + $taskName)
        }
        Expand-Archive -LiteralPath $taskArchive -DestinationPath $taskDirectory -Force
        if ((Get-FileHash -LiteralPath $taskExecutable -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskSpec.executableSha256) {
            throw ('Extracted executable checksum mismatch: ' + $taskName)
        }
    }
    & $taskExecutable --version
    if ($LASTEXITCODE -ne 0) { throw ('Tool failed: ' + $taskName) }
}
