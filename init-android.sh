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

# IJK_FFMPEG_UPSTREAM=git://git.videolan.org/ffmpeg.git
IJK_FFMPEG_UPSTREAM=https://github.com/Bilibili/FFmpeg.git
IJK_FFMPEG_FORK=https://github.com/befovy/FFmpeg.git
IJK_FFMPEG_COMMIT=ff4.0--ijk0.8.8--20211030--926
IJK_FFMPEG_LOCAL_REPO=extra/ffmpeg

set -e
TOOLS=tools

FF_ALL_ARCHS="armv7a arm64 x86 x86_64"
FF_TARGET=$1

function pull_common()
{
    git --version
    echo "== pull ffmpeg base =="
    [ ! -e $IJK_FFMPEG_LOCAL_REPO ] && sh $TOOLS/pull-repo-base.sh $IJK_FFMPEG_UPSTREAM $IJK_FFMPEG_LOCAL_REPO || echo
}

function pull_fork()
{
    echo "== pull ffmpeg fork $1 =="
    sh $TOOLS/pull-repo-ref.sh $IJK_FFMPEG_FORK android/contrib/ffmpeg-$1 ${IJK_FFMPEG_LOCAL_REPO}
    cd android/contrib/ffmpeg-$1
    git checkout ${IJK_FFMPEG_COMMIT} -B ijkplayer
    cd -
}

if [ "#$FF_TARGET" = "#" ]; then
    for ARCH in $FF_ALL_ARCHS
    do
        echo "$0 $ARCH"
    done
    echo "$0 clean|all"
    exit 1
elif [ "$FF_TARGET" = "clean" ]; then
    echo
    exit 0
elif [ "$FF_TARGET" = "all" ]; then
    pull_common
    for ARCH in $FF_ALL_ARCHS
    do
        pull_fork "$ARCH"
    done
else
    pull_common
    pull_fork "$FF_TARGET"
fi

./init-config.sh
./init/init-libyuv.sh
./init/init-android-soundtouch.sh
./init/init-android-boringssl.sh

cp extra/CMakeLists.txt.yuv ijkmedia/ijkyuv/CMakeLists.txt
cp extra/CMakeLists.txt.soundtouch ijkmedia/ijksoundtouch/CMakeLists.txt
