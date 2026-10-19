$ErrorActionPreference = "Stop"
$dir = Join-Path $PSScriptRoot "delivery"
$m = Get-Content -Raw (Join-Path $dir "manifest.json") | ConvertFrom-Json
$out = Join-Path $dir $m.file
foreach ($p in $m.parts) {
    $f = Join-Path $dir $p.file
    if ((Get-FileHash -Algorithm SHA256 $f).Hash.ToLower() -ne $p.sha256) { throw "Part checksum mismatch: $($p.file)" }
}
$stream = [System.IO.File]::Create($out)
try {
    foreach ($p in $m.parts) {
        $inputStream = [System.IO.File]::OpenRead((Join-Path $dir $p.file))
        try { $inputStream.CopyTo($stream) } finally { $inputStream.Dispose() }
    }
} finally { $stream.Dispose() }
if ((Get-FileHash -Algorithm SHA256 $out).Hash.ToLower() -ne $m.sha256) { throw "Archive checksum mismatch" }
Write-Host "Restored and verified: $out"
