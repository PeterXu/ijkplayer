#! /usr/bin/env bash

set -e

ARCH="$1"

echo "[*] init ffmpeg ..."
sh init-android.sh $ARCH


cd android/contrib

echo
echo "[*] compile openssl ..."
sh compile-boringssl.sh $ARCH

echo
echo "[*] compile ffmpeg ..."
sh compile-ffmpeg.sh $ARCH


echo
echo "[*] compile ijk ..."
cd -
cd android
sh compile-ijk.sh $ARCH

exit 0
