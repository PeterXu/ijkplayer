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
    echo "usage: $0 ios|android|osx universe"
    exit 1
fi

IJK_LIBSOXR_UPSTREAM=https://github.com/PeterXu/libsoxr.git
IJK_LIBSOXR_FORK=https://github.com/PeterXu/libsoxr.git
IJK_LIBSOXR_COMMIT=master

$BASEDIR/init/init-repo.sh $IJK_LIBSOXR_UPSTREAM $IJK_LIBSOXR_FORK $IJK_LIBSOXR_COMMIT $1 $2


if test x"$1" = x"android"; then
    #ANDROID_CMAKE_UPSTREAM=https://github.com/PeterXu/android-cmake.git
    #ANDROID_CMAKE_COMMIT=master
    #$BASEDIR/init/init-repo.sh $ANDROID_CMAKE_UPSTREAM $ANDROID_CMAKE_UPSTREAM $ANDROID_CMAKE_COMMIT "any" "none"
    #cp $BASEDIR/extra/android-cmake/android.toolchain.cmake $BASEDIR/android/contrib/libsoxr-$2
    echo
fi

