# ============================================================
# generate_delete_bundle.ps1
#
# Scans all sub-folders under a given directory for FHIR bundle
# JSON files, extracts Measure, Library, and ValueSet resources,
# and produces a single transaction bundle of DELETE requests.
#
# Usage:
#   .\generate_delete_bundle.ps1 -BundleDir "C:\dqm-content-qicore-2025\bundles\measure" -OutputFile "delete_bundle.json"
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BundleDir,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "delete_bundle.json"
)

$resourceTypes = @("Measure", "Library", "ValueSet")
$entries = [System.Collections.Generic.List[object]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new()

Write-Host ""
Write-Host "====================================================="
Write-Host " FHIR Delete Bundle Generator"
Write-Host "====================================================="
Write-Host " Scanning : $BundleDir"
Write-Host "====================================================="
Write-Host ""

# Find all JSON files one level deep (one per sub-folder)
$bundleFiles = Get-ChildItem -Path $BundleDir -Recurse -Filter "*.json" -File

if ($bundleFiles.Count -eq 0) {
    Write-Error "No JSON files found under $BundleDir"
    exit 1
}

foreach ($file in $bundleFiles) {
    Write-Host "Processing: $($file.FullName)"

    try {
        $bundle = Get-Content $file.FullName -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "  Skipping (invalid JSON): $($file.Name)"
        continue
    }

    if ($bundle.resourceType -ne "Bundle") {
        Write-Warning "  Skipping (not a Bundle): $($file.Name)"
        continue
    }

    foreach ($entry in $bundle.entry) {
        $resource = $entry.resource
        if (-not $resource) { continue }

        $type = $resource.resourceType
        if ($type -notin $resourceTypes) { continue }

        $url = $resource.url

        if (-not $url) {
            Write-Warning "  Could not determine url for $type in $($file.Name), skipping"
            continue
        }

        $key = "$type/$url"

        if ($seen.Contains($key)) {
            Write-Host "  Duplicate skipped: $key"
            continue
        }

        [void]$seen.Add($key)

        $entries.Add([PSCustomObject]@{
            request = [PSCustomObject]@{
                method = "DELETE"
                url    = "ValueSet/?url=$url"
            }
        })

        Write-Host "  + DELETE $key"
    }
}

Write-Host ""
Write-Host "-----------------------------------------------------"
Write-Host " Total DELETE entries: $($entries.Count)"
Write-Host "-----------------------------------------------------"

if ($entries.Count -eq 0) {
    Write-Warning "No Measure/Library/ValueSet resources found. Check your bundle directory."
    exit 1
}

# Build the transaction bundle
$deleteBundle = [PSCustomObject]@{
    resourceType = "Bundle"
    type         = "transaction"
    entry        = $entries.ToArray()
}

$json = $deleteBundle | ConvertTo-Json -Depth 10
Set-Content -Path $OutputFile -Value $json -Encoding UTF8

Write-Host ""
Write-Host " Output written to: $OutputFile"
Write-Host "====================================================="
Write-Host ""
