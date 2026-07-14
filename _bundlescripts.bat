REM create test directories for each measure resource
for %%a in (input\resources\measure\*.json) do md input\tests\measure\%%~na

REM run _extractBundleResources on each measure test directory
for /d %%a in (input\tests\measure\*.*) do _extractBundleResources %%a

REM post all bundles in the current directory

curl -d "@bundles/measure/ColorectalCancerScreeningCQM/ColorectalCancerScreeningCQM-bundle.json" -H "Content-Type: application/json" -X POST https://cloud.alphora.com/sandbox/r4/cqm/fhir

for /d %%a in (bundles\measure\*) do (
    for %%f in (bundles\measure\%%a\*.json) do echo %%f
)