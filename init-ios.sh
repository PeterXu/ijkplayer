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

# arm64：iPhoneX | iphone8 plus｜iPhone8｜ iPhone7| iphone7 plus | iphone6s plus｜iPhone6｜ iPhone6 plus｜iPhone5S | 　　　　iPad Air｜ iPad mini2(iPad mini with Retina Display)
# armv7s：iPhone5｜iPhone5C｜iPad4(iPad with Retina Display)
# armv7：iPhone4｜iPhone4S｜iPad｜iPad2｜iPad3｜iPad mini｜iPod Touch 3G｜iPod Touch4
# i386 是针对intel通用的微处理器32位处理器
# x86_64是针对x86架构64位处理器

set -e

PLATFORM="ios"
FF_ALL_ARCHS="x86_64 arm64"
FF_TARGET=$1

case "$FF_TARGET" in
    x86_64|arm64|all)
        ./init/init-ffmpeg.sh $PLATFORM $FF_TARGET
        ./init/init-openssl.sh $PLATFORM $FF_TARGET
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
./init/init-gas.sh

