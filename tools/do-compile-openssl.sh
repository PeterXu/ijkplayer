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

# This script is based on projects below
# https://github.com/x2on/OpenSSL-for-iPhone

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
FF_BUILD_NAME="openssl-$FF_ARCH"
FF_BUILD_SOURCE="$FF_BUILD_ROOT/openssl-$FF_ARCH"
FF_BUILD_WSPACE="$FF_BUILD_ROOT/build/openssl-$FF_ARCH"
FF_BUILD_OUTPUT="$FF_BUILD_ROOT/build/openssl-$FF_ARCH/output"
mkdir -p $FF_BUILD_OUTPUT
echo "build_root: $FF_BUILD_ROOT"
echo "build_source: $FF_BUILD_SOURCE"
echo "build_output: $FF_BUILD_OUTPUT"


#--------------------
echo "===================="
echo "[*] config arch $FF_ARCH"
echo "===================="

# detect env
source $DIR/do-arch.sh $FF_PLATFORM $FF_ARCH

#compiler options
export CROSS_TOP="$IJK_CROSS_TOP"
export CROSS_SDK="$IJK_CROSS_SDK"
export CC="$IJK_CC"
export CXX="$IJK_CXX"

#openssl options
OPENSSL_CFG_FLAGS=""
if [ "$IJK_TARGET_OS" = "darwin" ]; then
    OPENSSL_CFG_FLAGS="${IJK_TARGET_OS}64-${IJK_ARCH}-cc $OPENSSL_CFG_FLAGS"
fi
if [ "$FF_PLATFORM" = "ios" ]; then
    if [ "$FF_ARCH" = "arm64" -o "$FF_ARCH" = "armv7" -o "$FF_ARCH" = "armv7s" ]; then
        OPENSSL_CFG_FLAGS="iphoneos-cross $OPENSSL_CFG_FLAGS"
    fi
fi


#--------------------
echo "\n--------------------"
echo "[*] configure openssl"
echo "--------------------"

OPENSSL_CFG_FLAGS="$OPENSSL_CFG_FLAGS --openssldir=$FF_BUILD_OUTPUT"

cd $FF_BUILD_SOURCE
if [ -f "./Makefile" ]; then
    echo 'reuse configure'
else
    echo "config: $OPENSSL_CFG_FLAGS"
    ./Configure \
        $OPENSSL_CFG_FLAGS
    make clean
fi


#--------------------
echo "\n--------------------"
echo "[*] compile openssl"
echo "--------------------"

set +e
make
make install_sw

