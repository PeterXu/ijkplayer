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
    echo "Usage: $0 ios|android|osx x86_64|arm64 ..."
    exit 1
fi

FF_PLATFORM=$1
FF_ARCH=$2
FF_BUILD_OPT=$3
echo "build_arch: $FF_PLATFORM/$FF_ARCH"
echo "build_opt:  $FF_BUILD_OPT"


FF_BUILD_ROOT=$BASEDIR/$FF_PLATFORM/contrib
FF_BUILD_SOURCE="$FF_BUILD_ROOT/libsrt-$FF_ARCH"
FF_BUILD_WSPACE="$FF_BUILD_ROOT/build/libsrt-$FF_ARCH"
FF_BUILD_OUTPUT="$FF_BUILD_ROOT/build/libsrt-$FF_ARCH/output"
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
    echo
    FF_CFG_FLAGS="$FF_CFG_FLAGS --use-openssl-pc=on"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-apps=on"
elif [ "$FF_PLATFORM" = "android" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --cmake-system-name=Android"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --android-toolchain=gcc"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --with-compiler-prefix=${IJK_CROSS_PREFIX}-"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --with-target-path=$FF_TOOLCHAIN_PATH"

    FF_CFG_FLAGS="$FF_CFG_FLAGS --android-abi=$IJK_NDK_ABI"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --cmake-android-arch-abi=$IJK_NDK_ABI"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --android-stl=c++_static"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --cmake-android-api=$CMAKE_ANDROID_API"

    FF_CFG_FLAGS="$FF_CFG_FLAGS --use-openssl-pc=off"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-apps=off"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --use-static-libstdc++=on"

    export CFLAGS="$CFLAGS -fPIE -fPIC"
    export LDFLAGS="$LDFLAGS -pie"
fi

FF_CFG_FLAGS="$FF_CFG_FLAGS --cmake-prefix-path=$FF_BUILD_OUTPUT"
FF_CFG_FLAGS="$FF_CFG_FLAGS --cmake-install-prefix=$FF_BUILD_OUTPUT"

FF_CFG_FLAGS="$FF_CFG_FLAGS --openssl-include-dir=$FF_BUILD_OUTPUT/include"
FF_CFG_FLAGS="$FF_CFG_FLAGS --openssl-ssl-library=$FF_BUILD_OUTPUT/lib/libssl.a"
FF_CFG_FLAGS="$FF_CFG_FLAGS --openssl-crypto-library=$FF_BUILD_OUTPUT/lib/libcrypto.a"

FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-shared=off --enable-c++11=off"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-static=on"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-c++-deps=on"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-cxx11=on"


#--------------------
echo "\n--------------------"
echo "[*] configurate libsrt"
echo "--------------------"

cd $FF_BUILD_SOURCE
echo "./configure $FF_CFG_FLAGS"
./configure $FF_CFG_FLAGS


#--------------------
echo "\n--------------------"
echo "[*] compile libsrt"
echo "--------------------"
make depend
make -j3
make install


if [ "$FF_PLATFORM" = "android" ]; then
    sed -i '' 's|-lsrt   |-lsrt -lc -lm -ldl -lcrypto -lssl -lstdc++|g' $FF_BUILD_OUTPUT/lib/pkgconfig/srt.pc
fi
