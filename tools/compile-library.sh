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

FF_NAME=$1
FF_PLATFORM=$2
FF_TARGET=$3
FF_TARGET_EXTRA=$4

FF_ALL_ARCHS="x86_64 armv7 arm64"
FF_TOOLS=${BASEDIR}/tools
UNI_BUILD_ROOT=${BASEDIR}/$FF_PLATFORM/contrib


print_usage() {
    CMDLINE="compile-library.sh"
    if [ "$FF_NAME" != "" -a "$FF_PLATFORM" != "" ]; then
        CMDLINE="$FF_PLATFORM/compile-$FF_NAME.sh"
    else
        CMDLINE="compile-library.sh name ios|osx|android"
    fi

    echo
    for ARCH in $FF_ALL_ARCHS; do
        echo "Usage: $CMDLINE $ARCH"
    done
    echo "Usage: $CMDLINE lipo|all|clean"
}

if [ $# -lt 3 ]; then
    print_usage
    exit 1
fi

#----------

do_lipo_all() {
    source $FF_TOOLS/do-arch.sh $FF_PLATFORM arm64
    if [ "$IJK_LIPO" = "" ]; then
        echo "WARN: no lipo found!!!"
        exit 1
    fi
    echo "INFO: lipo found"

    BUILD_UNIVERSAL="$UNI_BUILD_ROOT/build/universal"
    BUILD_INC="$UNI_BUILD_ROOT/build/$FF_NAME-arm64/output/include"
    BUILD_LIBS="$UNI_BUILD_ROOT/build/$FF_NAME-arm64/output/lib/*.a"
    for LIB in $BUILD_LIBS; do
        LIBNAME=$(basename $LIB)
        $IJK_LIPO -info $LIB >/dev/null 2>&1 && iret=1 || iret=0
        if test x"$iret" = x"0"; then
            echo "WARN: static library not support lipo"
            break
        fi

        LIPO_FLAGS=
        for ARCH in $FF_ALL_ARCHS; do
            ONELIB="$UNI_BUILD_ROOT/build/$FF_NAME-$ARCH/output/lib/$LIBNAME"
            [ -f "$ONELIB" ] && LIPO_FLAGS="$LIPO_FLAGS $ONELIB"
        done

        #merge lib
        mkdir -p $BUILD_UNIVERSAL/lib
        $IJK_LIPO -create $LIPO_FLAGS -output $BUILD_UNIVERSAL/lib/$LIBNAME
        $IJK_LIPO -info $BUILD_UNIVERSAL/lib/$LIBNAME

        #copy headers
        mkdir -p $BUILD_UNIVERSAL/include
        cp -af  $BUILD_INC/* $BUILD_UNIVERSAL/include/
    done
}

do_clean() {
    for ARCH in $FF_ALL_ARCHS
    do
        echo "clean source $FF_NAME:$ARCH"
        echo "=================="
        if [ -d "$UNI_BUILD_ROOT/$FF_NAME" ]; then
            cd $UNI_BUILD_ROOT/$FF_NAME && git clean -xdf && cd -
            break
        fi
        if [ -d "$UNI_BUILD_ROOT/$FF_NAME-$ARCH" ]; then
            cd $UNI_BUILD_ROOT/$FF_NAME-$ARCH && git clean -xdf && cd -
        fi
    done

    echo "clean build $FF_NAME"
    echo "================="
    rm -rf $UNI_BUILD_ROOT/build/$FF_NAME-*
    rm -rf $UNI_BUILD_ROOT/build/universal
}

#----------

case $FF_TARGET in
    x86_64|armv7|arm64)
        sh $FF_TOOLS/do-compile-$FF_NAME.sh $FF_PLATFORM $FF_TARGET $FF_TARGET_EXTRA
    ;;
    all)
        for ARCH in $FF_ALL_ARCHS
        do
            sh $FF_TOOLS/do-compile-$FF_NAME.sh $FF_PLATFORM $ARCH $FF_TARGET_EXTRA
        done
        do_lipo_all
    ;;
    lipo)
        do_lipo_all
    ;;
    clean)
        do_clean
    ;;
    *)
        print_usage
        exit 1
    ;;
esac

