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
    echo "Usage: $0 ios x86|armv7s|armv7|x86_64|arm64"
    echo "Usage: $0 osx x86|x86_64|arm64"
    echo "Usage: $0 android x86|armv7|x86_64|arm64"
    exit 1
fi
_PLATFORM=$1
_ARCH=$2
_EXTRA_ROOT="$_BASEDIR/extra"


#--------------------
#compiler options
IJK_TARGET_OS=
IJK_ARCH=
IJK_CPU=

#only for android
IJK_NDK_HOME=
IJK_NDK_REL=
IJK_NDK_ABI=
IJK_NDK_API=
IJK_NDK_NINJA=

IJK_AS=
IJK_CC=
IJK_CXX=
IJK_LIPO=

#android
IJK_CROSS_ROOT=
IJK_CROSS_PREFIX=

#ios/osx
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

    if [ "$_PLATFORM" = "ios" ]; then
        if [ "$_ARCH" = "x86" ]; then
            IJK_ARCH="i386"
            _XCRUN_SDK="iPhoneSimulator"
            _XCRUN_OSVERSION="-miphoneos-version-min=10.0"
        elif [ "$_ARCH" = "armv7s" ]; then
            IJK_CPU="swift"
            _XCRUN_SDK="iPhoneOS"
            _XCRUN_OSVERSION="-miphoneos-version-min=10.0"
        elif [ "$_ARCH" = "armv7" ]; then
            #IJK_CPU="cortex-a8"
            _XCRUN_SDK="iPhoneOS"
            _XCRUN_OSVERSION="-miphoneos-version-min=10.0"
        elif [ "$_ARCH" = "x86_64" ]; then
            _XCRUN_SDK="iPhoneSimulator"
            _XCRUN_OSVERSION="-mios-simulator-version-min=10.0"
        elif [ "$_ARCH" = "arm64" ]; then
            _XCRUN_SDK="iPhoneOS"
            _XCRUN_OSVERSION="-miphoneos-version-min=10.0"
            #_XCODE_BITCODE="-fembed-bitcode"
        else
            echo "WARN: unsupported arch: $_ARCH/$_PLATFORM"
            exit 1
        fi
    else
        _XCRUN_SDK="MacOSX"
        if [ "$_ARCH" = "x86" ]; then
            IJK_ARCH="i386"
            _XCRUN_OSVERSION="-mmacosx-version-min=10.9"
        elif [ "$_ARCH" = "x86_64" ]; then
            _XCRUN_OSVERSION="-mmacosx-version-min=10.9"
        elif [ "$_ARCH" = "arm64" ]; then
            _XCRUN_OSVERSION="-mmacosx-version-min=11.0"
        else
            echo "WARN: unsupported arch: $_ARCH/$_PLATFORM"
            exit 1
        fi
    fi
    IJK_CFLAGS="$IJK_CFLAGS $_XCRUN_OSVERSION"
    IJK_CFLAGS="$IJK_CFLAGS $_XCODE_BITCODE"

    # check xcrun
    _XCRUN_SDK=`echo $_XCRUN_SDK | tr '[:upper:]' '[:lower:]'`
    _XCRUN_SDK_PLATFORM_PATH=`xcrun -sdk $_XCRUN_SDK --show-sdk-platform-path`
    _XCRUN_SDK_PATH=`xcrun -sdk $_XCRUN_SDK --show-sdk-path`
    IJK_CROSS_TOP="$_XCRUN_SDK_PLATFORM_PATH/Developer"
    IJK_CROSS_SDK=`echo ${_XCRUN_SDK_PATH/#$IJK_CROSS_TOP\/SDKs\//}`

    IJK_CC="xcrun -sdk $_XCRUN_SDK clang $_XCRUN_OSVERSION"
    IJK_CXX="xcrun -sdk $_XCRUN_SDK clang++ $_XCRUN_OSVERSION"
    IJK_LIPO="lipo"

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
    if [ -z "$ANDROID_HOME" ]; then
        echo "You must define ANDROID_HOME before starting."
        exit 1
    fi
    if [ -z "$ANDROID_NDK" ]; then
        echo "You must define ANDROID_NDK before starting."
        exit 1
    fi
    IJK_NDK_HOME="$ANDROID_NDK"
    IJK_NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $ANDROID_NDK/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
    case "$IJK_NDK_REL" in
      22*|23*|24*|25*|26*|27*|28*|29*|30*)
        echo "NDKr$IJK_NDK_REL detected"
        ;;
      *)
        echo "You need the NDKr22+, but have: $IJK_NDK_REL"
        exit 1
        ;;
    esac

    IJK_TARGET_OS="linux"
    IJK_ARCH="$_ARCH"
    IJK_NDK_API=21
    IJK_NDK_NINJA=$(find $ANDROID_HOME/ | grep "bin/ninja" | head -1)
    IJK_CROSS_ROOT=$(dirname `ndk-which addr2line`)
    case $_ARCH in
        x86)
            IJK_ARCH="x86"
            IJK_CPU="i686"
            IJK_NDK_ABI="x86"
            IJK_CROSS_PREFIX="i686-linux-android$IJK_NDK_API"
            ;;
        armv7)
            IJK_ARCH="arm"
            IJK_CPU="cortex-a8"
            IJK_NDK_ABI="armeabi-v7a"
            IJK_CROSS_PREFIX="armv7a-linux-androideabi$IJK_NDK_API"
            ;;
        x86_64)
            IJK_ARCH="x86_64"
            IJK_CPU="" #none
            IJK_NDK_ABI="x86_64"
            IJK_CROSS_PREFIX="x86_64-linux-android$IJK_NDK_API"
            ;;
        arm64)
            IJK_ARCH="aarch64"
            IJK_CPU="" #none
            IJK_NDK_ABI="arm64-v8a"
            IJK_CROSS_PREFIX="aarch64-linux-android$IJK_NDK_API"
            ;;
        *)
            echo "WARN: unsupported arch: $_ARCH/$_PLATFORM"
            exit 1
            ;;
    esac
    IJK_AS="$IJK_CROSS_ROOT/$IJK_CROSS_PREFIX-clang"
    IJK_CC="$IJK_CROSS_ROOT/$IJK_CROSS_PREFIX-clang"
    IJK_CXX="$IJK_CROSS_ROOT/$IJK_CROSS_PREFIX-clang++"
    IJK_LIPO=$(ndk-which lipo)
    [ ! -f "$IJK_LIPO" ] && IJK_LIPO=""
fi
IJK_LDFLAGS="$IJK_CFLAGS"

export IJK_TARGET_OS
export IJK_ARCH
export IJK_CPU

export IJK_NDK_HOME
export IJK_NDK_REL
export IJK_NDK_ABI
export IJK_NDK_API
export IJK_NDK_NINJA

export IJK_AS
export IJK_CC
export IJK_CXX
export IJK_LIPO

export IJK_CROSS_ROOT
export IJK_CROSS_PREFIX

export IJK_CROSS_TOP
export IJK_CROSS_SDK

export IJK_CFLAGS
export IJK_LDFLAGS

