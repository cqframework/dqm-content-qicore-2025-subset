REM curl -d "@bundles/measure/ColorectalCancerScreeningCQM/ColorectalCancerScreeningCQM-bundle.json" -H "Content-Type: application/json" -X POST https://cloud.alphora.com/sandbox/r4/cqm/fhir

for /d %%a in (bundles\measure\*) do (
    for %%f in (bundles\measure\%%~na\*.json) do (
        curl -d "@%%f" -H "Content-Type: application/json" -X POST https://cloud.alphora.com/sandbox/r4/cqm/fhir
    )
)