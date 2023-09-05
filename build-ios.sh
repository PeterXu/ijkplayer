#! /usr/bin/env bash

set -e

PARAM="$1"
ARCH_LIST="x86_64 arm64"


if [ "#$PARAM" = "#" ]; then
    echo "usage: $0 init|native|framework|clean|distclean"
    exit 1
elif [ "$PARAM" = "init" ]; then
    echo "[*] init ios ...: $ARCH_LIST"
    for ARCH in $ARCH_LIST; do
        sh init-ios.sh $ARCH
    done
elif [ "$PARAM" = "native" ]; then
    echo "[*] compile  openssl/ffmpeg ...: $ARCH_LIST"
    for ARCH in $ARCH_LIST; do
        cd ios/
        sh compile-openssl.sh $ARCH
        sh compile-ffmpeg.sh $ARCH
        cd ..
    done
    cd ios/
    sh compile-openssl.sh lipo
    sh compile-ffmpeg.sh lipo
    cd ..
elif [ "$PARAM" = "framework" ]; then
    cd ios/
    sh compile-framework.sh IJKMediaPlayer
    cd ..
elif [ "$PARAM" = "clean" ]; then
    cd ios/
    sh compile-framework.sh clean
    cd ..
elif [ "$PARAM" = "distclean" ]; then
    cd ios/
    sh compile-framework.sh clean
    sh compile-openssl.sh clean
    sh compile-ffmpeg.sh clean
    cd ..
fi

exit 0
