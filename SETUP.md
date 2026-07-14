# Loading and Evaluating the Test Measures

This guide walks through standing up one (or all) of the measures in this repository
on a FHIR server that supports the clinical-reasoning `Measure/$evaluate` operation
(e.g. a CQF-based server), and then running the bundled test cases through it.

The end-to-end flow is:

1. Load the terminology (value sets)
2. Load the measure (Library + Measure bundle)
3. Load the `Group` resource that describes a measure's test cases
4. Load the test-case patient data for that `Group`
5. Evaluate the measure over the `Group` to get **individual** results
6. Evaluate the measure over the `Group` to get **summary** results

All commands are PowerShell and are run from the repository root.

## Prerequisites

- A running FHIR R4 server that supports `Measure/$evaluate`.
- The helper scripts in this repo: `put_valuesets.ps1` and `post_bundles.ps1`.
- The generated bundles under `bundles/` (measure bundles ship in the repo; the
  per-test-case bundles under `bundles/tests/measure/` are produced by
  `generate_test_bundles.ps1`).

Pick the server you are loading into and set it once for the session. Every command
below uses `$base`:

```powershell
$base = 'http://localhost:8080/fhir'   # your FHIR server base URL
```

> All six measures use the same set of `id` values for the `Measure`, the `Group`,
> and the measure folder name, and all use the **2026** reporting period
> (`2026-01-01` .. `2026-12-31`). Pick the measure you want to work with:

```powershell
$measure = 'CMS71FHIRSTKAnticoagAFFlutter'
$period  = 'periodStart=2026-01-01&periodEnd=2026-12-31'
```

See the [Measure reference](#measure-reference) table at the bottom for the full list.

---

## 1. Load the terminology

The measures reference value sets by canonical URL; the server must have them loaded
before it can evaluate CQL. `put_valuesets.ps1` PUTs each `ValueSet` in
`input/vocabulary/valueset/external` individually (avoiding any single-bundle size
limit), upserting to `ValueSet/{id}`.

```powershell
.\put_valuesets.ps1 -Server $base
```

This sends 1528 value sets one at a time and reports progress. It is idempotent, so
it is safe to re-run. Preview without sending using `-WhatIf`.

> The value sets in this repo are capped at expansions of 1000 codes. Full expansions
> require an NLM license (see the note in [README.md](README.md)).

## 2. Load the measure

Each measure's `Library` + `Measure` transaction bundle lives under `bundles/measure/`.
Use `post_bundles.ps1` with `-Filter` to POST just the one you're working with:

```powershell
.\post_bundles.ps1 -Server $base -Filter $measure
```

(Omit `-Filter` to load all six measure bundles.)

## 3. Load the Group resource

Each measure has a `Group` at the root of its test-data folder
(`input/tests/measure/<measure>/Group-<measure>.json`). The `Group` lists every test
patient as a member and points at the measure it exercises via the
`artifact-testArtifact` extension. Evaluating this `Group` is how you run all of a
measure's test cases at once.

The `Group` has a stable `id`, so PUT it to `Group/{id}`:

```powershell
$groupFile = "input\tests\measure\$measure\Group-$measure.json"
$body = [System.IO.File]::ReadAllText($groupFile)
Invoke-RestMethod -Method Put -Uri "$base/Group/$measure" `
    -Headers @{ 'Content-Type' = 'application/fhir+json' } -Body $body
```

To load **every** measure's `Group` in one pass:

```powershell
Get-ChildItem input\tests\measure -Recurse -Filter 'Group-*.json' | ForEach-Object {
    $id   = ($_.BaseName -replace '^Group-', '')
    $body = [System.IO.File]::ReadAllText($_.FullName)
    Invoke-RestMethod -Method Put -Uri "$base/Group/$id" `
        -Headers @{ 'Content-Type' = 'application/fhir+json' } -Body $body
    Write-Host "PUT Group/$id"
}
```

## 4. Load the test-case data for the Group

Each test case is a small transaction bundle under
`bundles/tests/measure/<measure>/<caseId>-bundle.json` (Patient + supporting
resources; the expected `MeasureReport` is intentionally excluded). Load them all for
the current measure with `post_bundles.ps1`:

```powershell
.\post_bundles.ps1 -Server $base -BundleDir 'bundles\tests\measure' -Filter $measure
```

This posts every test-case bundle for the measure, so all the patients referenced by
the `Group` now exist on the server. (Omit `-Filter` to load the test data for all
measures.)

## 5. Evaluate the Group — individual results

Evaluating with the `Group` as the `subject` and `reportType=subject` produces an
**individual** `MeasureReport` for each patient in the group, returned as a searchset
`Bundle`.

```powershell
# NOTE: single-quoted template so PowerShell doesn't treat $evaluate as a variable
$uri = '{0}/Measure/{1}/$evaluate?{2}&subject=Group/{1}&reportType=subject' -f $base, $measure, $period

Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Accept = 'application/fhir+json' } |
    ConvertTo-Json -Depth 64 | Set-Content "$measure-individual.json" -Encoding UTF8
```

The equivalent raw request:

```
GET {base}/Measure/CMS71FHIRSTKAnticoagAFFlutter/$evaluate
        ?periodStart=2026-01-01&periodEnd=2026-12-31
        &subject=Group/CMS71FHIRSTKAnticoagAFFlutter
        &reportType=subject
```

Each per-patient report can be cross-checked against that patient's expected
`MeasureReport` in `input/tests/measure/<measure>/<caseId>/`, and against the
pass/fail intent encoded in the `Group` member `display` values (e.g. `NUMERPass`,
`DENEXFail`).

## 6. Evaluate the Group — summary results

Use `reportType=population` to get a single aggregated **summary** `MeasureReport`
with population counts (initial-population, denominator, numerator, exclusions, …)
across all members of the group:

```powershell
$uri = '{0}/Measure/{1}/$evaluate?{2}&subject=Group/{1}&reportType=population' -f $base, $measure, $period

Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Accept = 'application/fhir+json' } |
    ConvertTo-Json -Depth 64 | Set-Content "$measure-summary.json" -Encoding UTF8
```

The equivalent raw request:

```
GET {base}/Measure/CMS71FHIRSTKAnticoagAFFlutter/$evaluate
        ?periodStart=2026-01-01&periodEnd=2026-12-31
        &subject=Group/CMS71FHIRSTKAnticoagAFFlutter
        &reportType=population
```

> Want the population counts **and** the list of which subjects fell into each
> population? Use `reportType=subject-list` instead — it returns one summary report
> whose populations reference the member subjects.

---

## Loading everything at once

To stand up all six measures end-to-end, run the terminology load once, then load
every measure bundle, every `Group`, and all test data without a `-Filter`:

```powershell
$base = 'http://localhost:8080/fhir'

# 1. Terminology (once)
.\put_valuesets.ps1 -Server $base

# 2. All measure bundles
.\post_bundles.ps1 -Server $base

# 3. All Groups
Get-ChildItem input\tests\measure -Recurse -Filter 'Group-*.json' | ForEach-Object {
    $id   = ($_.BaseName -replace '^Group-', '')
    $body = [System.IO.File]::ReadAllText($_.FullName)
    Invoke-RestMethod -Method Put -Uri "$base/Group/$id" `
        -Headers @{ 'Content-Type' = 'application/fhir+json' } -Body $body
}

# 4. All test data
.\post_bundles.ps1 -Server $base -BundleDir 'bundles\tests\measure'
```

Then run steps 5 and 6 for each measure `id`.

## Measure reference

All measures use reporting period `2026-01-01` .. `2026-12-31`. The `Measure` id,
`Group` id, and test-data folder name are identical for each.

| Measure id (`$measure`)          | Description                                         |
| -------------------------------- | --------------------------------------------------- |
| `CMS122FHIRDiabetesAssessGT9Pct` | Diabetes: Hemoglobin A1c Poor Control (> 9%)        |
| `CMS124FHIRCervicalCancerScreen` | Cervical Cancer Screening                           |
| `CMS125FHIRBreastCancerScreen`   | Breast Cancer Screening                             |
| `CMS165FHIRControllingHighBP`    | Controlling High Blood Pressure                     |
| `CMS71FHIRSTKAnticoagAFFlutter`  | Anticoagulation Therapy for Atrial Fibrillation/Flutter |
| `CMS1028FHIRPCSevereOBComps`     | Severe Obstetric Complications                      |

## Notes

- **Order matters.** Terminology (step 1) and the measure (step 2) must be present
  before evaluation, and the `Group` (step 3) plus its patient data (step 4) must both
  be loaded before `$evaluate` in steps 5–6.
- **Idempotent.** Every load step uses PUT/`id`-based upsert, so re-running is safe.
- **`$evaluate` escaping.** In PowerShell double-quoted strings `$evaluate` looks like
  a variable. The examples above use single-quoted `-f` format templates to keep it
  literal; if you build the URL another way, escape it as `` `$evaluate `` or use
  single quotes.
- **Server variation.** Exact `reportType` support (`subject` / `subject-list` /
  `population`) and whether `$evaluate` is invoked by instance (`Measure/{id}/$evaluate`)
  or type level (`Measure/$evaluate?measure=<canonical>`) can vary by server and
  version. If instance-level evaluation isn't available, pass the canonical URL
  (`https://madie.cms.gov/Measure/<id>`) via a `measure` parameter to the type-level
  operation instead.
```
