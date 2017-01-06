#!/bin/bash

npm install -g hirenj/node-checkversion
source /aws-runbuild/.bash

export -f build
export RUNBUILDPATH

/bin/bash