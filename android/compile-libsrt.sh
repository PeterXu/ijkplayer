#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
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

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR=$(dirname "$DIR")
PLATFORM="android"

FF_TARGET=$1
FF_TARGET_EXTRA=$2
FF_ALL_ARCHS="x86_64 arm64"
FF_TOOLS=${BASEDIR}/tools
UNI_BUILD_ROOT=${BASEDIR}/$PLATFORM/contrib

#----------

case "$FF_TARGET" in
    x86_64|arm64)
        sh $FF_TOOLS/do-compile-libsrt.sh $PLATFORM $FF_TARGET
    ;;
    all)
        for ARCH in $FF_ALL_ARCHS
        do
            sh $FF_TOOLS/do-compile-libsrt.sh $PLATFORM $ARCH
        done
    ;;
    clean)
        for ARCH in $FF_ALL_ARCHS
        do
            if [ -d $UNI_BUILD_ROOT/libsrt-$ARCH ]; then
                cd $UNI_BUILD_ROOT/libsrt-$ARCH && git clean -xdf && cd -
            fi
        done
        rm -rf $UNI_BUILD_ROOT/build/libsrt-*
    ;;
    *)
        echo "Usage:"
        for ARCH in $FF_ALL_ARCHS
        do
            echo "  $0 $ARCH"
        done
        echo "  $0 lipo|all|clean"
        exit 1
    ;;
esac

