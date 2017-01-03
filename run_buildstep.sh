#!/usr/bin/env bash
#
# Based on https://gist.github.com/epiloque/8cf512c6d64641bde388

STEP=$1

SRCDIR=$CODEBUILD_SRC_DIR

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
    else
        echo "Failure"
        exit 1
    fi
}

testversion() {
    filename=$1
    shift
    checkversion --fail-on-match --print-remote --s3path "s3:::${BUILD_OUTPUT_BUCKET}/${BUILD_OUTPUT_PREFIX}/${filename}"  "$@" > $SRCDIR/target_version.txt
    if [ $? -gt 0 ]; then
        echo "No need to run build" && exit 1
    else
        echo "Running build updating target version to"
        cat "$SRCDIR/target_version.txt"
        exit 0
    fi
}


BUILDSPEC="$SRCDIR/.buildspec.yml"
if [ -e "$SRCDIR/target_version.txt" ]; then
    TARGETVERSION=$(<"$SRCDIR/target_version.txt")
fi

echo "Source dir is $SRCDIR"

if [ -e "$SRCDIR/buildspec.yml" ]; then
    BUILDSPEC="$SRCDIR/buildspec.yml"
fi

yml_values=$(parse_yaml $BUILDSPEC "buildspec_")

eval $yml_values

IFS=""
install_command_variable="buildspec_phases_${STEP}_commands"
eval install_commands=(\${$install_command_variable[@]})

for cmd in "${install_commands[@]}"
do
  echo "Executing $STEP $cmd"
  run_cmd "$cmd"
done

# pre_build

if [ "$STEP" == "post_build" ]; then
	for file in "${buildspec_artifacts_files[@]}"
	do
	  echo "Uploading $file"
	  uploadfolder "$file" --versionstring $TARGETVERSION --bucket "$BUILD_OUTPUT_BUCKET" --prefix "$BUILD_OUTPUT_PREFIX"
	  if [ $? -gt 0 ]; then
	  	echo "Upload failure" && exit 1
	  else
	  	echo "Upload success"
	  fi
	done
fi