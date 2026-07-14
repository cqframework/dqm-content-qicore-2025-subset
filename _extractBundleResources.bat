@ECHO OFF
SET tooling_jar=tooling-cli-3.9.1.jar
SET input_cache_path=%~dp0input-cache
IF -%1-==-- (
	SET mat_bundle=input\tests\measure\CMS986FHIRMalnutritionScore
) ELSE (
	SET mat_bundle=%1
)

SET JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

IF EXIST "%input_cache_path%\%tooling_jar%" (
	ECHO running: JAVA -jar "%input_cache_path%\%tooling_jar%" -BundleToResources -p=%mat_bundle% -v=r4 -op=%mat_bundle% -db=true
	JAVA -jar "%input_cache_path%\%tooling_jar%" -BundleToResources -p=%mat_bundle% -v=r4 -op=%mat_bundle% -db=true
) ELSE If exist "..\%tooling_jar%" (
	ECHO running: JAVA -jar "..\%tooling_jar%" -BundleToResources -p=%mat_bundle% -v=r4 -op=%mat_bundle% -db=true
	JAVA -jar "..\%tooling_jar%" -BundleToResources -p=%mat_bundle% -v=r4 -op=%mat_bundle% -db=true
) ELSE (
	ECHO Tooling JAR NOT FOUND in input-cache or parent folder.  Please run _updateCQFTooling.  Aborting...
)

PAUSE
