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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR=$(dirname "$DIR")

if [ $# -ne 2 ]; then
    echo "Usage: $0 ios|android|osx x86_64|armv7|arm64|all"
    exit 1
fi

# IJK_FFMPEG_UPSTREAM=git://git.videolan.org/ffmpeg.git
IJK_FFMPEG_UPSTREAM=https://github.com/PeterXu/FFmpeg.git
IJK_FFMPEG_FORK=https://github.com/PeterXu/FFmpeg.git
IJK_FFMPEG_COMMIT=92e2682cb #befovy-ff4.0--ijk0.8.8--20211030--926

$BASEDIR/init/init-repo.sh $IJK_FFMPEG_UPSTREAM $IJK_FFMPEG_FORK $IJK_FFMPEG_COMMIT $1 $2

if test x"$1" = x"ios"; then
    sed -i '' "s/static const char \*kIJKFFRequiredFFmpegVersion\ \=\ .*/static const char *kIJKFFRequiredFFmpegVersion = \"${IJK_FFMPEG_COMMIT}\";/g" ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerController.m
fi

