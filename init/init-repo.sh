#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 Bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR=$(dirname "$DIR")

if [ $# -lt 5 ]; then
    echo "Usage: $0 repo fork commit ios|android|osx x86_64|armv7|arm64|all"
    echo "Usage: $0 repo fork commit ios|android|osx universe"
    echo "Usage: $0 repo fork commit any none"
    echo "Usage: $0 repo fork commit any common dest"
    exit 1
fi
FF_REPO=$1
FF_FORK=$2
FF_COMMIT=$3
FF_PLATFORM=$4
FF_TARGET=$5
FF_DEST_0=$6

FF_NAME=`echo $FF_REPO | awk -F"/" '{print $NF}' | cut -d. -f1 | tr A-Z a-z`
echo
echo "==============================="
echo "INFO: $FF_PLATFORM, $FF_TARGET, $FF_NAME"


if [ "$FF_PLATFORM" = "osx" ]; then
    FF_ALL_ARCHS_OSX_SDK="x86_64 arm64"
    FF_ALL_ARCHS=$FF_ALL_ARCHS_OSX_SDK
    FF_DEST=osx/contrib/$FF_NAME
elif [ "$FF_PLATFORM" = "ios" ]; then
    FF_ALL_ARCHS_IOS12_SDK="x86_64 arm64"
    FF_ALL_ARCHS=$FF_ALL_ARCHS_IOS12_SDK
    FF_DEST=ios/contrib/$FF_NAME
elif [ "$FF_PLATFORM" = "android" ]; then
    FF_ALL_ARCHS_ANDROID_SDK="x86_64 armv7 arm64"
    FF_ALL_ARCHS=$FF_ALL_ARCHS_ANDROID_SDK
    FF_DEST=android/contrib/$FF_NAME
elif [ "$FF_PLATFORM" = "any" ]; then
    echo
else
    echo "usage: $0 repo fork commit ios|android|osx ..."
    exit 1
fi


IJK_UPSTREAM=$FF_REPO
IJK_FORK=$FF_FORK
IJK_COMMIT=$FF_COMMIT
IJK_LOCAL_REPO=$BASEDIR/extra/$FF_NAME

set -e
TOOLS=$BASEDIR/tools

function pull_common()
{
    echo "== pull $FF_NAME base ==  $IJK_LOCAL_REPO"
    [ ! -e $IJK_LOCAL_REPO ] && sh $TOOLS/pull-repo-base.sh $IJK_UPSTREAM $IJK_LOCAL_REPO || echo
}

function pull_fork()
{
    IJK_WORK_REPO="$BASEDIR/$FF_DEST-$1"
    [ "$1" = "none" ] && return 0
    [ "$1" = "universe" ] && IJK_WORK_REPO="$BASEDIR/$FF_DEST"
    [ "$1" = "common" ] && IJK_WORK_REPO="$BASEDIR/$FF_DEST_0"

    echo "== pull $FF_NAME fork $1 ==  $IJK_WORK_REPO"
    sh $TOOLS/pull-repo-ref.sh $IJK_FORK $IJK_WORK_REPO $IJK_LOCAL_REPO
    cd $IJK_WORK_REPO
    git checkout ${IJK_COMMIT} -B ijkplayer
    cd -
}


if [ "#$FF_TARGET" = "#" ]; then
    for ARCH in $FF_ALL_ARCHS; do
        echo "$0 $ARCH"
    done
    echo "$0 all"
    exit 1
elif [ "$FF_TARGET" = "all" ]; then
    pull_common
    for ARCH in $FF_ALL_ARCHS; do
        pull_fork "$ARCH"
    done
else
    pull_common
    pull_fork "$FF_TARGET"
fi
