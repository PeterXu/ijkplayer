#! /usr/bin/env bash
#
# Copyright (C) 2020-present befovy <befovy@gmail.com>
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

#--------------------
# common defines

if [ $# -lt 2 ]; then
    echo "Usage: $0 ios|android|osx x86_64|armv7|arm64 ..."
    exit 1
fi

FF_PLATFORM=$1
FF_ARCH=$2
FF_BUILD_OPT=$3
echo "build_arch: $FF_PLATFORM/$FF_ARCH"
echo "build_opt:  $FF_BUILD_OPT"


FF_BUILD_ROOT=$BASEDIR/$FF_PLATFORM/contrib
FF_BUILD_SOURCE="$FF_BUILD_ROOT/boringssl"
FF_BUILD_WSPACE="$FF_BUILD_ROOT/build/boringssl-$FF_ARCH"
FF_BUILD_OUTPUT="$FF_BUILD_ROOT/build/boringssl-$FF_ARCH/output"
mkdir -p $FF_BUILD_OUTPUT
echo "build_root: $FF_BUILD_ROOT"
echo "build_source: $FF_BUILD_SOURCE"
echo "build_output: $FF_BUILD_OUTPUT"


#--------------------
echo "===================="
echo "[*] config arch: $FF_ARCH"
echo "===================="

export PKG_CONFIG_PATH="${FF_BUILD_ROOT}/build/lib/pkgconfig"
echo "PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"

# detect env
source $DIR/do-arch.sh $FF_PLATFORM $FF_ARCH

# set cfg
FF_CFG_FLAGS=
if [ "$FF_PLATFORM" = "ios" -o "$FF_PLATFORM" = "osx" ]; then
    echo "WARN: unsupportted now!!!"
    exit 1
elif [ "$FF_PLATFORM" = "android" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS -B$FF_BUILD_WSPACE"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DANDROID_NDK=$IJK_NDK_HOME"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DANDROID_ABI=$IJK_NDK_ABI"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DANDROID_NATIVE_API_LEVEL=$IJK_NDK_API"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_MAKE_PROGRAM=$IJK_NDK_NINJA"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_TOOLCHAIN_FILE=$IJK_NDK_HOME/build/cmake/android.toolchain.cmake"
    [ "$FF_BUILD_OPT" = "debug" ] && BUILD_TYPE="Debug" || BUILD_TYPE="Release"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DANDROID_STL=c++_static"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DANDROID_TOOLCHAIN=clang"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -GNinja ${FF_BUILD_SOURCE}"
fi

#--------------------
echo "\n--------------------"
echo "[*] configurate boringssl"
echo "--------------------"
cmake $FF_CFG_FLAGS

#--------------------
echo "\n--------------------"
echo "[*] compile boringssl"
echo "--------------------"
cmake --build $FF_BUILD_WSPACE


if [ "$FF_PLATFORM" = "android" ]; then
    #copy lib
    mkdir -p $FF_BUILD_OUTPUT/lib
    cp $FF_BUILD_WSPACE/ssl/libssl.a $FF_BUILD_OUTPUT/lib
    cp $FF_BUILD_WSPACE/crypto/libcrypto.a $FF_BUILD_OUTPUT/lib

    # copy headers
    mkdir -p $FF_BUILD_OUTPUT/include
    cp -r $FF_BUILD_SOURCE/include/* $FF_BUILD_OUTPUT/include
fi

