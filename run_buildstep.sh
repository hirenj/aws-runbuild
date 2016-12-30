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

# Read $SRCDIR/buildspec.yml

yml_values=$(parse_yaml $SRCDIR/buildspec.yml)

eval $yml_values

for cmd in "${phases_install_commands[@]}"
do
  echo "Executing $STEP $cmd"
  $cmd
done

# run_buildspec install
#install:
#pre_build:
# run_buildspec pre_build
# check_version > $SRCDIR/target_version.txt
#build:
#post_build:
# run_buildspec post_build
# for file in read_buildspec artifacts.files; do uploadfolder .... target_version.txt ; done