# ============================================================
# generate_test_bundles.ps1
#
# For each measure test case (a sub-folder under
# input\tests\measure\<MeasureName>\<caseId>), collects the
# individual FHIR resource files and produces a single
# transaction bundle suitable for POSTing to a server.
#
# The MeasureReport (expected result) is excluded; all other
# resources are added as PUT entries (idempotent upsert).
#
# Usage:
#   .\generate_test_bundles.ps1
#   .\generate_test_bundles.ps1 -TestsDir "input\tests\measure" -OutputRoot "bundles\tests\measure"
# ============================================================

param(
    [string]$TestsDir   = "input\tests\measure",
    [string]$OutputRoot = "bundles\tests\measure",
    [string[]]$ExcludeTypes = @("MeasureReport")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TestsDir)) {
    Write-Error "Tests directory not found: $TestsDir"
    exit 1
}

Write-Host ""
Write-Host "====================================================="
Write-Host " FHIR Test Case Bundle Generator"
Write-Host "====================================================="
Write-Host " Tests   : $TestsDir"
Write-Host " Output  : $OutputRoot"
Write-Host " Exclude : $($ExcludeTypes -join ', ')"
Write-Host "====================================================="
Write-Host ""

$totalBundles = 0
$totalEntries = 0

# Each measure is a sub-folder of the tests directory
$measureDirs = Get-ChildItem -Path $TestsDir -Directory

foreach ($measureDir in $measureDirs) {

    Write-Host "Measure: $($measureDir.Name)"

    # Each test case is a sub-folder of the measure directory
    $caseDirs = Get-ChildItem -Path $measureDir.FullName -Directory

    foreach ($caseDir in $caseDirs) {

        $resourceFiles = Get-ChildItem -Path $caseDir.FullName -Filter "*.json" -File

        $entries = [System.Collections.Generic.List[object]]::new()

        foreach ($file in $resourceFiles) {

            try {
                $resource = Get-Content $file.FullName -Raw | ConvertFrom-Json
            } catch {
                Write-Warning "    Skipping (invalid JSON): $($file.Name)"
                continue
            }

            $type = $resource.resourceType
            if (-not $type) {
                Write-Warning "    Skipping (no resourceType): $($file.Name)"
                continue
            }
            if ($ExcludeTypes -contains $type) { continue }

            $id = $resource.id
            if (-not $id) {
                Write-Warning "    Skipping (no id): $($file.Name)"
                continue
            }

            $entries.Add([PSCustomObject]@{
                resource = $resource
                request  = [PSCustomObject]@{
                    method = "PUT"
                    url    = "$type/$id"
                }
            })
        }

        if ($entries.Count -eq 0) {
            Write-Warning "    No includable resources in $($caseDir.Name), skipping"
            continue
        }

        $bundle = [PSCustomObject]@{
            resourceType = "Bundle"
            id           = $caseDir.Name
            type         = "transaction"
            entry        = $entries.ToArray()
        }

        $outDir = Join-Path $OutputRoot $measureDir.Name
        if (-not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        }

        $outFile = Join-Path $outDir "$($caseDir.Name)-bundle.json"
        $bundle | ConvertTo-Json -Depth 64 | Set-Content -Path $outFile -Encoding UTF8

        $totalBundles++
        $totalEntries += $entries.Count
        Write-Host "    + $($caseDir.Name)-bundle.json ($($entries.Count) resources)"
    }
}

Write-Host ""
Write-Host "-----------------------------------------------------"
Write-Host " Bundles written : $totalBundles"
Write-Host " Total resources : $totalEntries"
Write-Host " Output root     : $OutputRoot"
Write-Host "-----------------------------------------------------"
Write-Host ""
