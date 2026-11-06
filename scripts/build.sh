#!/usr/bin/env bash

set -e
set -x

buildNumber=$( "$(dirname "$0")/resolve_build_number.sh" . )

if [[ -f "./cmake/mumble_dependency_provider.cmake" ]]; then
	MUMBLE_CMAKE_ARGS="$MUMBLE_CMAKE_ARGS -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=cmake/mumble_dependency_provider.cmake"
fi

cmake \
	-B build \
	-S .\
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_NUMBER=$buildNumber \
	-Dclient=OFF \
	-Dserver=ON \
	-Dice=ON \
	-Dtests=ON \
	-Dwarnings-as-errors=OFF \
	-Dzeroconf=OFF \
	-DCMAKE_UNITY_BUILD=ON \
	$MUMBLE_CMAKE_ARGS

cmake --build build -j $(nproc)

TEST_TIMEOUT=600 # seconds
export QTEST_FUNCTION_TIMEOUT="$(( $TEST_TIMEOUT * 1000 ))" # milliseconds
ctest build --timeout $TEST_TIMEOUT --output-on-failure . -j $(nproc)
