#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
# Copyright (C) 2018-2019 Befovy <befovy@gmail.com>
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

do_lipo_all() {
    echo
}

#----------

case $FF_TARGET in
    x86_64|arm64)
        sh $FF_TOOLS/do-compile-lobsoxr.sh $PLATFORM $FF_TARGET $FF_TARGET_EXTRA
    ;;
    all)
        for ARCH in $FF_ALL_ARCHS
        do
            sh $FF_TOOLS/do-compile-libsoxr.sh $PLATFORM $ARCH $FF_TARGET_EXTRA
        done
        do_lipo_all
    ;;
    lipo)
        do_lipo_all
    ;;
    clean)
        for ARCH in $FF_ALL_ARCHS
        do
            echo "clean libsoxr"
            echo "=================="
            if [ -d "$UNI_BUILD_ROOT/libsoxr" ]; then
                cd $UNI_BUILD_ROOT/libsoxr && git clean -xdf && cd -
            fi
        done
        echo "clean build cache"
        echo "================="
        rm -rf $UNI_BUILD_ROOT/build/libsoxr-*
        rm -rf $UNI_BUILD_ROOT/build/universal
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

