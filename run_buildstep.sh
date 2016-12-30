#!/usr/bin/env bash
#
# Based on https://gist.github.com/epiloque/8cf512c6d64641bde388

STEP=$1

SRCDIR=$CODEBUILD_SRC_DIR

SRCDIR="."

parse_yaml() {
    local prefix=$2
    local s
    local w
    local fs
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
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

yml_values=$(parse_yaml $SRCDIR/buildspec.yml "buildspec_")

eval $yml_values

install_command_variable="buildspec_phases_${STEP}_commands"
eval install_commands=(\${$install_command_variable[@]})

for cmd in "${install_commands[@]}"
do
  echo "Executing $STEP $cmd"
  $cmd && echo "Success" || (echo "Failure" && exit 1)
done

# pre_build
# check_version > $SRCDIR/target_version.txt

if [ "$STEP" == "post_build" ]; then
	for file in "${buildspec_artifacts_files[@]}"
	do
	  echo "Uploading $file"
	  uploadfolder "$file" --versionstring --bucket "$BUILD_OUTPUT_BUCKET" --prefix "$BUILD_OUTPUT_PREFIX"
	  if [ $? -gt 0 ]; then
	  	echo "Upload failure" && exit 1
	  else
	  	echo "Upload success"
	  fi
	done
fi