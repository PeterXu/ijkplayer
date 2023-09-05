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

# This script is based on projects below
# https://github.com/kolyvan/kxmovie
# https://github.com/yixia/FFmpeg-Android
# http://git.videolan.org/?p=vlc-ports/android.git;a=summary
# https://github.com/kewlbear/FFmpeg-iOS-build-script/

set -e

_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_BASEDIR=$(dirname "$_DIR")

if [ $# -lt 2 ]; then
    echo "Usage: $0 ios|android|osx x86_64|arm64"
    exit 1
fi
_PLATFORM=$1
_ARCH=$2
_EXTRA_ROOT="$_BASEDIR/extra"


#--------------------
#compiler options
IJK_TARGET_OS=
IJK_ARCH=
#cpu: --cpu=cortex-a8 for armv7, --cpu=swift for armv7s
IJK_CPU=

IJK_AS=
IJK_CC=
IJK_CXX=

IJK_CROSS_ROOT=
IJK_CROSS_PREFIX=

IJK_CROSS_TYPE=
IJK_CROSS_TOP=
IJK_CROSS_SDK=

#cflags/ldflags
IJK_CFLAGS=
IJK_LDFLAGS=

if [ "$_PLATFORM" = "ios" -o "$_PLATFORM" = "osx" ]; then
    IJK_TARGET_OS="darwin"
    IJK_ARCH="$_ARCH"
    # xcode configuration
    export DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

    _XCRUN_SDK=
    _XCRUN_OSVERSION=
    _XCODE_BITCODE=
    _EXTRA_FLAGS=

    if [ "$_PLATFORM" = "ios" ]; then
        if [ "$_ARCH" = "x86_64" ]; then
            _XCRUN_SDK="iPhoneSimulator"
            _XCRUN_OSVERSION="-mios-simulator-version-min=10.0"
            IJK_CROSS_TYPE="darwin64-x86_64-cc"
        fi
        if [ "$_ARCH" = "arm64" ]; then
            _XCRUN_SDK="iPhoneOS"
            _XCRUN_OSVERSION="-miphoneos-version-min=10.0"
            #_XCODE_BITCODE="-fembed-bitcode"
            IJK_CROSS_TYPE="iphoneos-cross"
        fi
    else
        _XCRUN_SDK="MacOSX"
        if [ "$_ARCH" = "x86_64" ]; then
            _XCRUN_OSVERSION="-mmacosx-version-min=10.10"
            IJK_CROSS_TYPE="darwin64-x86_64-cc"
        fi
        if [ "$_ARCH" = "arm64" ]; then
            _XCRUN_OSVERSION="-mmacosx-version-min=11.0"
            IJK_CROSS_TYPE="darwin64-arm64-cc"
        fi
    fi
    IJK_CFLAGS="$IJK_CFLAGS $_XCRUN_OSVERSION"
    IJK_CFLAGS="$IJK_CFLAGS $_XCODE_BITCODE"
    IJK_CFLAGS="$IJK_CFLAGS $_EXTRA_FLAGS"

    _XCRUN_SDK=`echo $_XCRUN_SDK | tr '[:upper:]' '[:lower:]'`
    _XCRUN_SDK_PLATFORM_PATH=`xcrun -sdk $_XCRUN_SDK --show-sdk-platform-path`
    _XCRUN_SDK_PATH=`xcrun -sdk $_XCRUN_SDK --show-sdk-path`

    IJK_CC="xcrun -sdk $_XCRUN_SDK clang $_XCRUN_OSVERSION"
    IJK_CXX="xcrun -sdk $_XCRUN_SDK clang++ $_XCRUN_OSVERSION"
    IJK_CROSS_TOP="$_XCRUN_SDK_PLATFORM_PATH/Developer"
    IJK_CROSS_SDK=`echo ${_XCRUN_SDK_PATH/#$IJK_CROSS_TOP\/SDKs\//}`

    if [ -d "$_EXTRA_ROOT/gas-preprocessor" ]; then
        export PATH="$_EXTRA_ROOT/gas-preprocessor:$PATH"
        echo "gas-p: $_EXTRA_ROOT/gas-preprocessor/gas-preprocessor.pl"
        if [ "$_ARCH" = "arm64" ]; then
            export GASPP_FIX_XCODE5=1
            IJK_AS="gas-preprocessor.pl -arch aarch64 -- $IJK_CC"
        else
            IJK_AS="gas-preprocessor.pl -- $IJK_CC"
        fi
    fi
elif [ "$_PLATFORM" = "android" ]; then
    if [ -z "$ANDROID_NDK" ]; then
        echo "You must define ANDROID_NDK before starting."
        exit 1
    fi
    NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $ANDROID_NDK/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
    case "$NDK_REL" in
      22*|23*|24*|25*|26*|27*|28*|29*|30*)
        echo "NDKr$NDK_REL detected"
        ;;
      *)
        echo "You need the NDKr22+, but have: $NDK_REL"
        exit 1
        ;;
    esac

    NDK_PLATFORM=21
    IJK_TARGET_OS="linux"
    IJK_ARCH="$_ARCH"
    case $_ARCH in
        x86_64) IJK_ARCH="x86_64";;
        arm64) IJK_ARCH="aarch64";;
    esac
    IJK_CROSS_ROOT=$(dirname `ndk-which clang`)
    IJK_CROSS_PREFIX="$IJK_ARCH-linux-android$NDK_PLATFORM"
    IJK_AS="$IJK_CROSS_ROOT/$IJK_CROSS_PREFIX-clang"
    IJK_CC="$IJK_CROSS_ROOT/$IJK_CROSS_PREFIX-clang"
    IJK_CXX="$IJK_CROSS_ROOT/$IJK_CROSS_PREFIX-clang++"
fi
IJK_LDFLAGS="$IJK_CFLAGS"

export IJK_TARGET_OS
export IJK_ARCH
export IJK_CPU

export IJK_AS
export IJK_CC
export IJK_CXX

export IJK_CROSS_ROOT
export IJK_CROSS_PREFIX

export IJK_CROSS_TYPE
export IJK_CROSS_TOP
export IJK_CROSS_SDK

export IJK_CFLAGS
export IJK_LDFLAGS

