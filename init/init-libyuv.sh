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

#IJK_LIBYUV_UPSTREAM=https://github.com/Bilibili/libyuv.git
#IJK_LIBYUV_FORK=https://github.com/Bilibili/libyuv.git
#IJK_LIBYUV_COMMIT=ijk-r0.2.1-dev

#https://chromium.googlesource.com/libyuv/libyuv,main
IJK_LIBYUV_UPSTREAM=https://github.com/PeterXu/libyuv.git
IJK_LIBYUV_FORK=https://github.com/PeterXu/libyuv.git
IJK_LIBYUV_COMMIT=58a4a8014

$BASEDIR/init/init-repo.sh $IJK_LIBYUV_UPSTREAM $IJK_LIBYUV_FORK $IJK_LIBYUV_COMMIT "any" "common" "ijkmedia/ijkyuv"

