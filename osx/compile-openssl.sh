#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
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
PLATFORM="osx"

FF_TARGET=$1
FF_ALL_ARCHS="x86_64 arm64"
FF_LIBS="libssl libcrypto"
FF_TOOLS=${BASEDIR}/tools
UNI_BUILD_ROOT=${BASEDIR}/$PLATFORM/contrib

#----------

do_lipo() {
    LIB_FILE=$1
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        LIPO_FLAGS="$LIPO_FLAGS $UNI_BUILD_ROOT/build/openssl-$ARCH/output/lib/$LIB_FILE"
    done

    mkdir -p $UNI_BUILD_ROOT/build/universal/lib
    xcrun lipo -create $LIPO_FLAGS -output $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE
    xcrun lipo -info $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE
}

do_lipo_all() {
    mkdir -p $UNI_BUILD_ROOT/build/universal/lib
    echo "lipo archs: $FF_ALL_ARCHS"
    for FF_LIB in $FF_LIBS
    do
        do_lipo "$FF_LIB.a";
    done

    #only copy one
    cp -R $UNI_BUILD_ROOT/build/openssl-arm64/output/include $UNI_BUILD_ROOT/build/universal/
}

#----------

case "$FF_TARGET" in
    x86_64|arm64)
        sh $FF_TOOLS/do-compile-openssl.sh $PLATFORM $FF_TARGET
    ;;
    all)
        for ARCH in $FF_ALL_ARCHS
        do
            sh $FF_TOOLS/do-compile-openssl.sh $PLATFORM $ARCH
        done
        do_lipo_all
    ;;
    lipo)
        do_lipo_all
    ;;
    clean)
        for ARCH in $FF_ALL_ARCHS
        do
            echo "clean openssl-$ARCH"
            echo "=================="
            if [ -d "$UNI_BUILD_ROOT/openssl-$ARCH" ]; then
                cd $UNI_BUILD_ROOT/openssl-$ARCH && git clean -xdf && cd -
            fi
        done
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
