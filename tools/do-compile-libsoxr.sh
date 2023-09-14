#! /usr/bin/env bash
#
# Copyright (C) 2014 Miguel Botón <waninkoko@gmail.com>
# Copyright (C) 2014 Zhang Rui <bbcallen@gmail.com>
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
    echo "Usage: $0 ios|android|osx x86_64|arm64 ..."
    exit 1
fi

FF_PLATFORM=$1
FF_ARCH=$2
FF_BUILD_OPT=$3
echo "build_arch: $FF_PLATFORM/$FF_ARCH"
echo "build_opt:  $FF_BUILD_OPT"


FF_BUILD_ROOT=$BASEDIR/$FF_PLATFORM/contrib
FF_BUILD_SOURCE="$FF_BUILD_ROOT/libsoxr"
FF_BUILD_WSPACE="$FF_BUILD_ROOT/build/libsoxr-$FF_ARCH"
FF_BUILD_OUTPUT="$FF_BUILD_ROOT/build/libsoxr-$FF_ARCH/output"
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
FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_INSTALL_PREFIX=$FF_BUILD_OUTPUT"
if [ "$FF_PLATFORM" = "ios" -o "$FF_PLATFORM" = "osx" ]; then
    echo
elif [ "$FF_PLATFORM" = "android" ]; then
    case "$FF_ARCH" in
        armv7)  EXTRA_FLAGS="-DHAVE_WORDS_BIGENDIAN_EXITCODE=1 -DWITH_SIMD=0";;
        x86)    EXTRA_FLAGS="-DHAVE_WORDS_BIGENDIAN_EXITCODE=1";;
        x86_64) ;;
        arm64) ;;
    esac
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DANDROID_ABI=$IJK_NDK_ABI $EXTRA_FLAGS"
    #FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_TOOLCHAIN_FILE=$FF_BUILD_SOURCE/android.toolchain.cmake"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_TOOLCHAIN_FILE=$IJK_NDK_HOME/build/cmake/android.toolchain.cmake"
fi

if [ "$FF_BUILD_OPT" = "debug" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_BUILD_TYPE=Debug"
else
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_BUILD_TYPE=Release"
fi

FF_CFG_FLAGS="$FF_CFG_FLAGS -DBUILD_EXAMPLES=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DBUILD_LSR_TESTS=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DBUILD_SHARED_LIBS=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DBUILD_TESTS=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DWITH_LSR_BINDINGS=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DWITH_OPENMP=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DBUILD_TESTS=0"
FF_CFG_FLAGS="$FF_CFG_FLAGS -DWITH_PFFFT=0"


cmake \
    -B$FF_BUILD_WSPACE \
    $FF_CFG_FLAGS \
    -GNinja ${FF_BUILD_SOURCE}



#--------------------
echo "\n--------------------"
echo "[*] compile libsoxr"
echo "--------------------"
make -j3
make install

