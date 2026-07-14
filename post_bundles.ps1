# ============================================================
# post_bundles.ps1
#
# POSTs FHIR transaction bundles (*-bundle.json) under a given
# directory to a FHIR server base endpoint, with per-bundle
# status reporting, filtering, auth, and a dry-run mode.
#
# Works for both the large measure bundles and the per-test-case
# bundles:
#
#   # Measure bundles (default)
#   .\post_bundles.ps1 -Server "https://cloud.alphora.com/sandbox/r4/cqm/fhir"
#
#   # Test case bundles
#   .\post_bundles.ps1 -Server "..." -BundleDir "bundles\tests\measure"
#
#   # One measure only, from either set
#   .\post_bundles.ps1 -Server "..." -BundleDir "bundles\tests\measure" -Filter CMS165FHIRControllingHighBP
#
#   # Preview without sending
#   .\post_bundles.ps1 -Server "..." -WhatIf
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Server,

    # Root directory to search for *-bundle.json files
    [string]$BundleDir = "bundles\measure",

    # Optional: restrict to a sub-folder of BundleDir (e.g. a measure name)
    [string]$Filter,

    # Optional bearer token for authenticated servers
    [string]$Token,

    # Request timeout in seconds (measure bundles can be large)
    [int]$TimeoutSec = 300,

    # List bundles without posting
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BundleDir)) {
    Write-Error "Bundle directory not found: $BundleDir"
    exit 1
}

$searchDir = $BundleDir
if ($Filter) {
    $searchDir = Join-Path $BundleDir $Filter
    if (-not (Test-Path $searchDir)) {
        Write-Error "Filter directory not found: $searchDir"
        exit 1
    }
}

$rootFull = (Resolve-Path $BundleDir).Path
$bundles  = Get-ChildItem -Path $searchDir -Recurse -Filter "*-bundle.json" -File | Sort-Object FullName

Write-Host ""
Write-Host "====================================================="
Write-Host " FHIR Bundle Poster"
Write-Host "====================================================="
Write-Host " Server  : $Server"
Write-Host " Source  : $searchDir"
Write-Host " Bundles : $($bundles.Count)"
if ($WhatIf) { Write-Host " Mode    : WhatIf (no requests sent)" }
Write-Host "====================================================="
Write-Host ""

$headers = @{ "Content-Type" = "application/fhir+json" }
if ($Token) { $headers["Authorization"] = "Bearer $Token" }

$ok   = 0
$fail = 0
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($file in $bundles) {

    # Path relative to the bundle root, plus size, as a readable label
    $rel  = $file.FullName.Substring($rootFull.Length).TrimStart('\','/')
    $size = if ($file.Length -ge 1MB) {
        "$([math]::Round($file.Length / 1MB, 1)) MB"
    } else {
        "$([math]::Round($file.Length / 1KB, 1)) KB"
    }
    $label = "$rel ($size)"

    if ($WhatIf) {
        Write-Host "  would POST  $label"
        continue
    }

    Write-Host "  posting     $label ..."
    try {
        # Read as raw UTF-8 exactly as written on disk
        $body = [System.IO.File]::ReadAllText($file.FullName)
        Invoke-RestMethod -Method Post -Uri $Server -Headers $headers -Body $body `
            -TimeoutSec $TimeoutSec -ErrorAction Stop | Out-Null
        $ok++
        Write-Host "  OK          $label"
    } catch {
        $fail++
        $status = $_.Exception.Response.StatusCode.value__
        Write-Warning "  FAIL        $label  (HTTP $status) $($_.Exception.Message)"
        $failed.Add($rel)
    }
}

Write-Host ""
Write-Host "-----------------------------------------------------"
if ($WhatIf) {
    Write-Host " Would post $($bundles.Count) bundle(s)."
} else {
    Write-Host " Succeeded : $ok"
    Write-Host " Failed    : $fail"
    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Host " Failed bundles:"
        $failed | ForEach-Object { Write-Host "   - $_" }
    }
}
Write-Host "-----------------------------------------------------"
Write-Host ""

if ($fail -gt 0) { exit 1 }
