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
PLATFORM="osx"

FF_TARGET=$1
FF_TARGET_EXTRA=$2
FF_ALL_ARCHS="x86_64 arm64"
FF_LIBS="libcompat libavcodec libavfilter libavformat libavutil libswscale libswresample"
FF_TOOLS=${BASEDIR}/tools
UNI_BUILD_ROOT=${BASEDIR}/$PLATFORM/contrib

#----------

do_lipo() {
    LIB_FILE=$1
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
            return 0
        fi
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

    ANY_ARCH=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_INC_DIR="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/include"
        if [ -d "$ARCH_INC_DIR" ]; then
            if [ -z "$ANY_ARCH" ]; then
                ANY_ARCH=$ARCH
                cp -R "$ARCH_INC_DIR" "$UNI_BUILD_ROOT/build/universal/"
            fi

            UNI_INC_DIR="$UNI_BUILD_ROOT/build/universal/include"

            mkdir -p "$UNI_INC_DIR/libavutil/$ARCH"
            cp -f "$ARCH_INC_DIR/libavutil/avconfig.h"  "$UNI_INC_DIR/libavutil/$ARCH/avconfig.h"
            cp -f $FF_TOOLS/ffconfig/avconfig.h         "$UNI_INC_DIR/libavutil/avconfig.h"
            cp -f "$ARCH_INC_DIR/libavutil/ffversion.h" "$UNI_INC_DIR/libavutil/$ARCH/ffversion.h"
            cp -f $FF_TOOLS/ffconfig/ffversion.h        "$UNI_INC_DIR/libavutil/ffversion.h"
            mkdir -p "$UNI_INC_DIR/libffmpeg/$ARCH"
            cp -f "$ARCH_INC_DIR/libffmpeg/config.h"    "$UNI_INC_DIR/libffmpeg/$ARCH/config.h"
            cp -f $FF_TOOLS/ffconfig/config.h           "$UNI_INC_DIR/libffmpeg/config.h"
        fi
    done
}

#----------

case $FF_TARGET in
    x86_64|arm64)
        sh $FF_TOOLS/do-compile-ffmpeg.sh $PLATFORM $FF_TARGET $FF_TARGET_EXTRA
    ;;
    all)
        for ARCH in $FF_ALL_ARCHS
        do
            sh $FF_TOOLS/do-compile-ffmpeg.sh $PLATFORM $ARCH $FF_TARGET_EXTRA
        done
        do_lipo_all
    ;;
    lipo)
        do_lipo_all
    ;;
    clean)
        for ARCH in $FF_ALL_ARCHS
        do
            echo "clean ffmpeg-$ARCH"
            echo "=================="
            if [ -d "$UNI_BUILD_ROOT/ffmpeg-$ARCH" ]; then
                cd $UNI_BUILD_ROOT/ffmpeg-$ARCH && git clean -xdf && cd -
            fi
        done
        echo "clean build cache"
        echo "================="
        rm -rf $UNI_BUILD_ROOT/build/ffmpeg-*
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

