#!/usr/bin/env bash
#
# Based on https://gist.github.com/epiloque/8cf512c6d64641bde388

step=$1

srcdir=$CODEBUILD_SRC_DIR
if [ -z "$WORKDIR" ]; then
    WORKDIR="/codebuild/output"
fi

pushd `dirname $0` > /dev/null
scriptpath=`pwd`
popd > /dev/null

export PATH="$PATH:$scriptpath"

parse_yaml() {
    local prefix=$2
    local s
    local w
    local fs
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -e 's/"/\\"/g' \
        -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
        }
    }' | sed 's/_=/+=/g'
}

run_cmd() {
    if eval "$@"; then
        echo "Success"
        return 0
    else
        retval="$?"
        echo "Failure with code $retval"
        return "$retval"
    fi
}

GIT_STATUS=$(cd $srcdir; git describe --abbrev=0 --tags)

testversion() {
    testversion_with_exit '' $@
}

testversion_skip_exit() {
    testversion_with_exit '1' $@
}


testversion_with_exit() {
    noexit=$1
    shift
    filename=$1
    shift
    echo "$GIT_STATUS"
    checkversion --s3-version-suffix="-${GIT_STATUS}" --fail-on-match --print-remote --s3path "s3:::${BUILD_OUTPUT_BUCKET}/${BUILD_OUTPUT_PREFIX}/${filename}"  "$@" > $srcdir/target_version.txt
    if [ $? -gt 0 ]; then
        if [ -z $noexit ]; then
            touch "$srcdir/VERSION_MATCHING"
            echo "No need to run build" && exit 0
        fi
        false
    else
        echo "Running build updating target version to"
        cat "$srcdir/target_version.txt"
        if [ -z $noexit ]; then
            exit 0
        fi
        true
    fi
}

buildspec="$srcdir/.buildspec.yml"
if [ -e "$srcdir/target_version.txt" ]; then
    TARGETVERSION=$(<"$srcdir/target_version.txt")
    UPLOADVERSION="${TARGETVERSION}-${GIT_STATUS}"
fi

export -f testversion
export -f testversion_skip_exit
export -f testversion_with_exit
export srcdir
export TARGETVERSION
export UPLOADVERSION
export GIT_STATUS
export WORKDIR


echo "Source dir is $srcdir"

if [[ -f "$srcdir/VERSION_MATCHING" ]]; then
    echo "Skipping build step because of matching version"
    exit 0
fi

if [ -e "$srcdir/buildspec.yml" ]; then
    buildspec="$srcdir/buildspec.yml"
fi

yml_values=$(parse_yaml $buildspec "buildspec_")

eval $yml_values

IFS=""
install_command_variable="buildspec_phases_${step}_commands"
eval install_commands=(\${$install_command_variable[@]})

for cmd in "${install_commands[@]}"
do
  echo "Executing $step $cmd"
  run_cmd "$cmd"
  retvalue="$?"
  if [ "$retvalue" -gt 0 ]; then
    if [[ ! -f "$srcdir/VERSION_MATCHING" && "$retvalue" -ne 2 ]]; then
        touch "$srcdir/FAILED"
        exit "$retvalue"
    fi
  fi
done

# pre_build

if [[ "$step" == "post_build" && ! -z "$BUILD_OUTPUT_BUCKET" && ! -f "$srcdir/FAILED" && ! -f "$srcdir/VERSION_MATCHING" ]]; then
    echo "Doing custom uploads"
    for file in "${buildspec_artifacts_files[@]}"
    do
        echo "Uploading $file with version $UPLOADVERSION"
        if [ -d "$file" ]; then
            aws s3 sync --metadata "version=$UPLOADVERSION" "${file}/" "s3://${BUILD_OUTPUT_BUCKET}/${BUILD_OUTPUT_PREFIX}/"
        else
            aws s3 cp --metadata "version=$UPLOADVERSION" "${file}" "s3://${BUILD_OUTPUT_BUCKET}/${BUILD_OUTPUT_PREFIX}/${file}"
        fi
        if [ $? -gt 0 ]; then
            echo "Upload failure" && exit 1
        else
            echo "Upload success"
        fi
    done
fi