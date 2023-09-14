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

IJK_LIBSRT_UPSTREAM=https://github.com/PeterXu/libsrt.git
IJK_LIBSRT_FORK=https://github.com/PeterXu/libsrt.git
IJK_LIBSRT_COMMIT=7bf96c716d1ab8e75422b9cb7118fc82f497a5b3

$BASEDIR/init/init-repo.sh $IJK_LIBSRT_UPSTREAM $IJK_LIBSRT_FORK $IJK_LIBSRT_COMMIT $1 $2

