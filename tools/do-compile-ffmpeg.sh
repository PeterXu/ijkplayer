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
FF_BUILD_SOURCE="$FF_BUILD_ROOT/ffmpeg-$FF_ARCH"
FF_BUILD_WSPACE="$FF_BUILD_ROOT/build/ffmpeg-$FF_ARCH"
FF_BUILD_OUTPUT="$FF_BUILD_ROOT/build/ffmpeg-$FF_ARCH/output"
mkdir -p $FF_BUILD_OUTPUT
echo "build_root: $FF_BUILD_ROOT"
echo "build_source: $FF_BUILD_SOURCE"
echo "build_output: $FF_BUILD_OUTPUT"


#--------------------
echo "===================="
echo "[*] config arch: $FF_ARCH"
echo "===================="

# detect env
source $DIR/do-arch.sh $FF_PLATFORM $FF_ARCH
#compiler options
FF_AS="$IJK_AS"
FF_CC="$IJK_CC"
FF_CXX="$IJK_CXX"
FF_CFLAGS="$IJK_CFLAGS"
FF_LDFLAGS="$IJK_LDFLAGS"
FF_DEP_LIBS=""

#ffmpeg options
FF_CFG_FLAGS=""
FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=$IJK_ARCH"
FF_CFG_FLAGS="$FF_CFG_FLAGS --target-os=$IJK_TARGET_OS"
[ "#$IJK_CPU" != "#" ] && FF_CFG_FLAGS="$FF_CFG_FLAGS --cpu=$IJK_CPU"


#extra options
if [ "$FF_PLATFORM" = "ios" -o "$FF_PLATFORM" = "osx" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-cross-compile"
    if [ "$FF_PLATFORM" = "ios" ]; then
        if [ "$FF_ARCH" = "x86_64" ]; then
            FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-asm"
            FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-mmx"
            FF_CFG_FLAGS="$FF_CFG_FLAGS --assert-level=2"
        fi
    else
        echo
    fi
elif [ "$FF_PLATFORM" = "android" ]; then
    FF_CFLAGS="$FF_CFLAGS -O3 -Wall -pipe -std=c99 -fPIE -fPIC"
    FF_CFLAGS="$FF_CFLAGS -ffast-math -fstrict-aliasing -Werror=strict-aliasing"
    FF_CFLAGS="$FF_CFLAGS -DANDROID -DNDEBUG"

    FF_CFG_FLAGS="$FF_CFG_FLAGS --cross-prefix=${IJK_CROSS_PREFIX}-"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-cross-compile"

    FF_CFG_FLAGS="$FF_CFG_FLAGS --pkg-config=pkg-config"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --pkgconfigdir=${FF_BUILD_OUTPUT}/lib/pkgconfig"

    #FF_CFG_FLAGS="$FF_CFG_FLAGS --ld=$FF_CC"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --nm=$IJK_CROSS_ROOT/llvm-nm"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --ar=$IJK_CROSS_ROOT/llvm-ar"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --ranlib=$IJK_CROSS_ROOT/llvm-ranlib"
fi

if [ "$FF_BUILD_OPT" = "debug" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-optimizations"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-small"
else
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-optimizations"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-debug"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-small"
fi


#--------------------
echo "\n--------------------"
echo "[*] configure ffmpeg"
echo "--------------------"

# set prefix
FF_CFG_FLAGS="$FF_CFG_FLAGS --prefix=$FF_BUILD_OUTPUT"

# load ffmpeg build params
export COMMON_FF_CFG_FLAGS=
source $FF_BUILD_ROOT/../../config/module-$FF_PLATFORM.sh
FF_CFG_FLAGS="$FF_CFG_FLAGS $COMMON_FF_CFG_FLAGS"

# Developer options (useful when working on FFmpeg itself):
FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-stripping"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-static"
FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-shared"

echo "\n[*] check libsrt"
FF_DEP_LIBSRT=${FF_BUILD_ROOT}/build/libsrt-$FF_ARCH/output
if [ -f "${FF_DEP_LIBSRT}/lib/libsrt.a" ]; then
    echo "detect libsrt"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-libsrt"
    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_LIBSRT}/include"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_LIBSRT}/lib -lsrt"
fi

echo "\n[*] check libsoxr"
FF_DEP_LIBSOXR=${FF_BUILD_ROOT}/build/libsoxr-$FF_ARCH/output
if [ -f "${FF_DEP_LIBSOXR}/lib/libsoxr.a" ]; then
    echo "libsoxr detected"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-libsoxr"
    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_LIBSOXR}/include"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_LIBSOXR}/lib -lsoxr"
fi

echo "\n[*] check OpenSSL"
FF_DEP_OPENSSL=$FF_BUILD_ROOT/build/openssl-$FF_ARCH/output
FF_DEP_BORINGSSL=$FF_BUILD_ROOT/build/boringssl-$FF_ARCH/output
if [ -f "${FF_DEP_OPENSSL}/lib/libssl.a" ]; then
    echo "detect OpenSSL"
    #export PKG_CONFIG_PATH="$FF_DEP_OPENSSL/lib/pkgconfig:$PKG_CONFIG_PATH"
elif [ -f "${FF_DEP_BORINGSSL}/lib/libssl.a" ]; then
    echo "detect BoringSSL"
    FF_DEP_OPENSSL="$FF_DEP_BORINGSSL"
fi
if [ -f "${FF_DEP_OPENSSL}/lib/libssl.a" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-openssl"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-protocol=crypto"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-protocol=https"
    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_OPENSSL}/include"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_OPENSSL}/lib -lssl -lcrypto"
fi


#--------------------
echo "\n--------------------"
echo "[*] configure"
echo "----------------------"

if [ ! -d $FF_BUILD_SOURCE ]; then
    echo
    echo "!! ERROR"
    echo "!! Can not find FFmpeg directory for $FF_ARCH"
    echo "!! Init first"
    echo
    exit 1
fi

cd $FF_BUILD_SOURCE
if [ -f "./config.h" ]; then
    echo 'reuse configure'
else
    echo "as: $FF_AS"
    echo "cc: $FF_CC"
    echo "cxx: $FF_CXX"
    echo "cflags: $FF_CFLAGS"
    echo "ldflags: $FF_LDFLAGS"
    echo "dep-libs: $FF_DEP_LIBS"
    echo "config: $FF_CFG_FLAGS"
    ./configure \
        --as="$FF_AS" \
        --cc="$FF_CC" \
        --cxx="$FF_CXX" \
        $FF_CFG_FLAGS \
        --extra-cflags="$FF_CFLAGS" \
        --extra-cxxflags="$FF_CFLAGS" \
        --extra-ldflags="$FF_LDFLAGS $FF_DEP_LIBS"
    make clean
fi


#--------------------
echo "\n--------------------"
echo "[*] compile ffmpeg"
echo "--------------------"

cp config.* $FF_BUILD_OUTPUT
make -j3
make install
mkdir -p $FF_BUILD_OUTPUT/include/libffmpeg
cp -f config.h $FF_BUILD_OUTPUT/include/libffmpeg/config.h


# link *.o to so for android
if [ "$FF_PLATFORM" = "android" ]; then
    echo "\n--------------------"
    echo "[*] link ffmpeg"
    echo "--------------------"
    FF_C_OBJ_FILES=
    FF_ASM_OBJ_FILES=
    MODULES="compat libavdevice libavcodec libavfilter libavformat libavutil libswresample libswscale libpostproc libavresample"
    ASM_SUB_MODULES="x86 arm neon aarch64"
    for MOD in $MODULES; do
        C_OBJ_FILES="$MOD/*.o"
        if ls $C_OBJ_FILES 1> /dev/null 2>&1; then
            echo "link $C_OBJ_FILES"
            FF_C_OBJ_FILES="$FF_C_OBJ_FILES $C_OBJ_FILES"
        fi
        for SMOD in $ASM_SUB_MODULES; do
            ASM_OBJ_FILES="$MOD/$SMOD/*.o"
            if ls $ASM_OBJ_FILES 1> /dev/null 2>&1; then
                echo "link $ASM_OBJ_FILES"
                FF_ASM_OBJ_FILES="$FF_ASM_OBJ_FILES $ASM_OBJ_FILES"
            fi
        done
    done

    echo "link LIBS: $FF_DEP_LIBS"
    TARGET_SO="libijkffmpeg.so"
    $FF_CC $FF_LDFLAGS \
        -lm -lz -shared -Wl,-Bsymbolic -Wl,--no-undefined -Wl,-z,noexecstack \
        -Wl,-soname,$TARGET_SO \
        $FF_C_OBJ_FILES \
        $FF_ASM_OBJ_FILES \
        $FF_DEP_LIBS \
        -o $FF_BUILD_OUTPUT/$TARGET_SO

    mysedi() {
        tos=`uname -s`
        [ "$tos" != "Darwin" ] && topts="-i"
        f=$1
        exp=$2
        n=`basename $f`
        cp $f /tmp/$n
        sed $topts $exp /tmp/$n > $f
        rm /tmp/$n
    }

    echo "\n--------------------"
    echo "[*] create files for shared ffmpeg(so)"
    echo "--------------------"
    mkdir -p $FF_BUILD_OUTPUT/pkgconfig
    for f in $FF_BUILD_OUTPUT/lib/pkgconfig/*.pc; do
        [ ! -f $f ] && continue
        cp $f $FF_BUILD_OUTPUT/pkgconfig
        f=$FF_BUILD_OUTPUT/pkgconfig/`basename $f`
        # OSX sed doesn't have in-place(-i)
        mysedi $f 's#/output/lib#/output#g'
        mysedi $f 's#-lavcodec#-lijkffmpeg#g'
        mysedi $f 's#-lavfilter#-lijkffmpeg#g'
        mysedi $f 's#-lavformat#-lijkffmpeg#g'
        mysedi $f 's#-lavutil#-lijkffmpeg#g'
        mysedi $f 's#-lswresample#-lijkffmpeg#g'
        mysedi $f 's#-lswscale#-lijkffmpeg#g'
    done
fi
