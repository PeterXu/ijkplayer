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
    echo "usage: $0 ios|android|osx x86_64|arm64|all|universe"
    exit 1
fi

IJK_SDL_UPSTREAM=https://github.com/libsdl-org/SDL.git
IJK_SDL_FORK=https://github.com/libsdl-org/SDL.git
IJK_SDL_COMMIT=ac13ca9ab6  #tag: release-2.26.5

$BASEDIR/init/init-repo.sh $IJK_SDL_UPSTREAM $IJK_SDL_FORK $IJK_SDL_COMMIT $1 $2

