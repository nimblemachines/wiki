#!/bin/sh

# $1 is modtime in Unix seconds-since-epoch UTC

# One application is this:
#   ./modtime.sh $(cat <page>/modtime)

date -u -r $1 "+%Y-%m-%d %T UTC"
date    -r $1 "+%Y-%m-%d %T %Z"
