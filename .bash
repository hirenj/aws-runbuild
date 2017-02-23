#!/usr/bin/env bash

pushd `dirname $BASH_SOURCE` > /dev/null
RUNBUILDPATH=`pwd`
WORKDIR_BASE=/tmp
popd > /dev/null

build() {
	STEP="$1"
	export CODEBUILD_SRC_DIR="$PWD"
	export BUILD_OUTPUT_BUCKET="$2"
	export BUILD_OUTPUT_PREFIX="$3"
	export WORKDIR="$WORKDIR_BASE/$BUILD_OUTPUT_PREFIX"
	mkdir -p $WORKDIR
	if [ ! -z "$STEP" ]; then
		$RUNBUILDPATH/run_buildstep.sh $STEP
	else
		$RUNBUILDPATH/run_buildstep.sh pre_build && $RUNBUILDPATH/run_buildstep.sh build && $RUNBUILDPATH/run_buildstep.sh post_build
	fi
}

build_test() {
	export BUILD_TEST=1
	build $@
}