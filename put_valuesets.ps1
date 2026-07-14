# ============================================================
# put_valuesets.ps1
#
# PUTs each individual ValueSet resource file under a directory
# to a FHIR server, one request per file (avoids large-bundle
# size limits). Each resource is upserted at ValueSet/{id},
# where {id} is read from the resource itself.
#
# Usage:
#   .\put_valuesets.ps1 -Server "https://cloud.alphora.com/sandbox/r4/cqm/fhir"
#   .\put_valuesets.ps1 -Server "http://localhost:8080/fhir" -ValueSetDir "input\vocabulary\valueset\external"
#   .\put_valuesets.ps1 -Server "..." -WhatIf   # list what would be sent, send nothing
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Server,

    [string]$ValueSetDir = "input\vocabulary\valueset\external",

    # Optional bearer token for authenticated servers
    [string]$Token,

    # Per-request timeout in seconds
    [int]$TimeoutSec = 120,

    # List resources without sending
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ValueSetDir)) {
    Write-Error "ValueSet directory not found: $ValueSetDir"
    exit 1
}

$base  = $Server.TrimEnd('/')
$files = Get-ChildItem -Path $ValueSetDir -Filter "*.json" -File | Sort-Object Name

Write-Host ""
Write-Host "====================================================="
Write-Host " FHIR ValueSet PUT"
Write-Host "====================================================="
Write-Host " Server    : $Server"
Write-Host " Source    : $ValueSetDir"
Write-Host " ValueSets : $($files.Count)"
if ($WhatIf) { Write-Host " Mode      : WhatIf (no requests sent)" }
Write-Host "====================================================="
Write-Host ""

$headers = @{ "Content-Type" = "application/fhir+json" }
if ($Token) { $headers["Authorization"] = "Bearer $Token" }

$ok   = 0
$fail = 0
$skip = 0
$failed = [System.Collections.Generic.List[string]]::new()

$i = 0
foreach ($file in $files) {

    $i++
    $body = [System.IO.File]::ReadAllText($file.FullName)

    # Pull id (and type) from the resource so the PUT target is authoritative
    try {
        $resource = $body | ConvertFrom-Json
    } catch {
        $skip++
        Write-Warning "  SKIP  $($file.Name)  (invalid JSON)"
        continue
    }

    $type = $resource.resourceType
    $id   = $resource.id
    if ($type -ne "ValueSet" -or -not $id) {
        $skip++
        Write-Warning "  SKIP  $($file.Name)  (resourceType='$type', id='$id')"
        continue
    }

    $uri = "$base/ValueSet/$id"

    if ($WhatIf) {
        Write-Host "  would PUT  ValueSet/$id"
        continue
    }

    Write-Progress -Activity "PUT ValueSets" -Status "$i / $($files.Count)  ValueSet/$id" `
        -PercentComplete ([math]::Floor(($i / $files.Count) * 100))

    try {
        Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body `
            -TimeoutSec $TimeoutSec -ErrorAction Stop | Out-Null
        $ok++
    } catch {
        $fail++
        $status = $_.Exception.Response.StatusCode.value__
        Write-Warning "  FAIL  ValueSet/$id  (HTTP $status) $($_.Exception.Message)"
        $failed.Add("ValueSet/$id")
    }
}

Write-Progress -Activity "PUT ValueSets" -Completed

Write-Host ""
Write-Host "-----------------------------------------------------"
if ($WhatIf) {
    Write-Host " Would PUT $($files.Count - $skip) ValueSet(s); skipped $skip."
} else {
    Write-Host " Succeeded : $ok"
    Write-Host " Failed    : $fail"
    Write-Host " Skipped   : $skip"
    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Host " Failed ValueSets:"
        $failed | ForEach-Object { Write-Host "   - $_" }
    }
}
Write-Host "-----------------------------------------------------"
Write-Host ""

if ($fail -gt 0) { exit 1 }
