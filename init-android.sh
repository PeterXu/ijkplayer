#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 Bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
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

PLATFORM="android"

FF_ALL_ARCHS="x86_64 armv7 arm64"
FF_TARGET=$1

case "$FF_TARGET" in
    x86_64|armv7|arm64|all)
        ./init/init-ffmpeg.sh $PLATFORM $FF_TARGET
        ./init/init-boringssl.sh $PLATFORM "universe"
    ;;
    *)
        for ARCH in $FF_ALL_ARCHS
        do
            echo "$0 $ARCH"
        done
        echo "$0 all"
        exit 1
    ;;
esac

./init-config.sh $PLATFORM lite
./init/init-libyuv.sh
./init/init-soundtouch.sh

#cp extra/CMakeLists.txt.yuv ijkmedia/ijkyuv/CMakeLists.txt
cp extra/CMakeLists.txt.soundtouch ijkmedia/ijksoundtouch/CMakeLists.txt
