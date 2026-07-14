#!/bin/bash
#DO NOT EDIT WITH WINDOWS
tooling_jar=tooling-cli-3.9.1.jar
input_cache_path=./input-cache
mat_bundle=input/tests/measure/CMS1244FHIRECATHOQR


set -e

tooling=$input_cache_path/$tooling_jar


if test -f "$tooling"; then
	echo running: JAVA -jar $tooling -BundleToResources -p=$mat_bundle -v=r4 -op=$mat_bundle -db=true
	java -jar $tooling -BundleToResources -p=$mat_bundle -v=r4 -op=$mat_bundle -db=true
else
	tooling=../$tooling_jar
	echo $tooling
	if test -f "$tooling"; then
		echo running: JAVA -jar $tooling -BundleToResources -p=$mat_bundle -v=r4 -op=$mat_bundle -db=true
		java -jar $tooling -BundleToResources -p=$mat_bundle -v=r4 -op=$mat_bundle -db=true
	else
		echo Tooling JAR NOT FOUND in input-cache or parent folder.  Please run _updateCQFTooling.  Aborting...
	fi
fi