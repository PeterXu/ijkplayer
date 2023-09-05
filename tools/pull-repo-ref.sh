#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
REF_REPO=$3
REF_DIRECT=$(printenv IJKPLAYER_REF_DIRECT)

if [ -z $1 -o -z $2 -o -z $3 ]; then
    echo "invalid call pull-repo.sh '$1' '$2' '$3'"
elif [ ! -d $LOCAL_WORKSPACE ]; then
    if [ "$REF_DIRECT" = "1" ]; then
        if [ -d "$REF_REPO" ]; then
            git clone $REF_REPO $LOCAL_WORKSPACE
        else
            git clone $REMOTE_REPO $LOCAL_WORKSPACE
        fi
    else
        git clone --reference $REF_REPO $REMOTE_REPO $LOCAL_WORKSPACE
    fi
    cd $LOCAL_WORKSPACE
    git repack -a
else
    cd $LOCAL_WORKSPACE
    git fetch --all --tags
    cd -
fi
