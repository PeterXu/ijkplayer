#! /usr/bin/env bash

set -e

PARAM="$1"
ARCH_LIST="x86_64 arm64"


if [ "#$PARAM" = "#" ]; then
    echo "usage: $0 init|native|aar|clean|distclean"
    exit 1
elif [ "$PARAM" = "init" ]; then
    echo "[*] init android ...: $ARCH_LIST"
    for ARCH in $ARCH_LIST; do
        sh init-android.sh $ARCH
    done
elif [ "$PARAM" = "native" ]; then
    echo "[*] compile  openssl/ffmpeg ...: $ARCH_LIST"
    for ARCH in $ARCH_LIST; do
        cd android/contrib
        sh compile-boringssl.sh $ARCH
        sh compile-ffmpeg.sh $ARCH
        cd ../..
    done
elif [ "$PARAM" = "aar" ]; then
    echo "[*] generate aar..."
    cd android/
    sh compile-aar.sh all
    cd ..
elif [ "$PARAM" = "clean" ]; then
    cd android/
    sh compile-aar.sh clean
    cd ..
elif [ "$PARAM" = "distclean" ]; then
    cd android/contrib
    rm -rf ./build/output-*
    sh compile-boringssl.sh clean
    sh compile-ffmpeg.sh clean
    cd ../..

    cd android
    sh compile-aar.sh clean
    cd ..
fi


exit 0
