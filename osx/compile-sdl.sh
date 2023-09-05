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

FF_TARGET=$1
FF_ALL_ARCHS="x86_64 arm64"

#----------

FF_TOOLS=${BASEDIR}/tools
UNI_BUILD_ROOT=${BASEDIR}/osx/contrib


do_build_sdl() {
    echo "ARCH:$1"
    ARCH=$1
    FF_ARCH=
    if [ "$ARCH" = "x86_64" ]; then
        FF_ARCH="x64"
    elif [ "$ARCH" = "arm64" ]; then
        FF_ARCH="arm64"
    elif [ "$ARCH" = "all" ]; then
        FF_ARCH="fat"
    fi

    FF_SDL_CFG=""
    FF_SDL_CFG="$FF_SDL_CFG --enable-shared=yes"

    SDL_SRC_PATH=$UNI_BUILD_ROOT/sdl
    echo "SDL_SRC_PATH: $SDL_SRC_PATH"
    echo "FF_ARCH:${FF_ARCH}"
    
    mkdir -p "$UNI_BUILD_ROOT/build/sdl-$ARCH"
    cd $UNI_BUILD_ROOT/build/sdl-$ARCH
    CC="$FF_TOOLS/clang-macosx.sh $FF_ARCH clang" $SDL_SRC_PATH/configure $FF_SDL_CFG
    make
    cd -
}

do_lipo_all() {
    ARCH=$1
    mkdir -p $UNI_BUILD_ROOT/build/universal/lib
    cp -f $UNI_BUILD_ROOT/build/sdl-${ARCH}/build/.libs/lib*.a $UNI_BUILD_ROOT/build/universal/lib/

    mkdir -p $UNI_BUILD_ROOT/build/universal/include
    cp -rf $UNI_BUILD_ROOT/sdl/include/* $UNI_BUILD_ROOT/build/universal/include/
}

#----------
case "$FF_TARGET" in
    x86_64|arm64|all)
        do_build_sdl $FF_TARGET
        do_lipo_all $FF_TARGET
    ;;
    clean)
        if [ -d $UNI_BUILD_ROOT/sdl ]; then
            cd $UNI_BUILD_ROOT/sdl && git clean -xdf && cd -
        fi
        rm -rf $UNI_BUILD_ROOT/build/sdl-*
    ;;
    *)
        echo "Usage:"
        for ARCH in $FF_ACT_ARCHS_ALL; do
            echo "  $0 $ARCH"
        done
        echo "  $0 all|clean"
        exit 1
    ;;
esac
