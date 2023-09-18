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
FF_BUILD_SOURCE="$BASEDIR/desktop/glfw"
FF_BUILD_WSPACE="$FF_BUILD_ROOT/build/glfw-$FF_ARCH"
FF_BUILD_OUTPUT="$FF_BUILD_ROOT/build/glfw-$FF_ARCH/output"
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
if [ "$FF_PLATFORM" = "osx" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS -B$FF_BUILD_WSPACE"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_OSX_ARCHITECTURES=$FF_ARCH"
    [ "$FF_BUILD_OPT" = "debug" ] && BUILD_TYPE="Debug" || BUILD_TYPE="Release"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DCMAKE_INSTALL_PREFIX=$FF_BUILD_OUTPUT"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DGLFW_BUILD_EXAMPLES=OFF"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DGLFW_BUILD_TESTS=OFF"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DGLFW_INSTALL=ON"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -DGLFW_BUILD_DOCS=OFF"
    FF_CFG_FLAGS="$FF_CFG_FLAGS -GNinja ${FF_BUILD_SOURCE}"
else
    echo "WARN: unsupportted now!!!"
    exit 1
fi

#--------------------
echo "\n--------------------"
echo "[*] configurate glfw"
echo "--------------------"
echo "flags: $FF_CFG_FLAGS"
cmake $FF_CFG_FLAGS

#--------------------
echo "\n--------------------"
echo "[*] compile glfw"
echo "--------------------"
cmake --build $FF_BUILD_WSPACE
cmake --install $FF_BUILD_WSPACE


if [ "$FF_PLATFORM" = "osx" ]; then
    cp -a "$FF_BUILD_SOURCE/deps/glad" "$FF_BUILD_OUTPUT/include"
    echo
fi

