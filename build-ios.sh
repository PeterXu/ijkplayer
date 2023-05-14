#! /usr/bin/env bash

set -e

ARCH="$1"

echo "[*] init ffmpeg ..."
sh init-ios.sh $ARCH

echo
echo "[*] init openssl ..."
sh init-ios-openssl.sh  $ARCH

cd ios/

echo
echo "[*] compile openssl ..."
sh compile-openssl.sh $ARCH

echo
echo "[*] compile ffmpeg ..."
sh compile-ffmpeg.sh $ARCH

exit 0
