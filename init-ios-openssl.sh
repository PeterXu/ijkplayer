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

IJK_OPENSSL_UPSTREAM=https://github.com/openssl/openssl
IJK_OPENSSL_FORK=https://github.com/Bilibili/openssl.git
IJK_OPENSSL_COMMIT=b34cf4eb61  #tag: OpenSSL_1_0_2r
IJK_OPENSSL_LOCAL_REPO=extra/openssl

set -e
TOOLS=tools

FF_ALL_ARCHS_IOS12_SDK="arm64 x86_64"
FF_ALL_ARCHS=$FF_ALL_ARCHS_IOS12_SDK
FF_TARGET=$1

function pull_common()
{
    echo "== pull openssl base =="
    [ ! -e $IJK_OPENSSL_LOCAL_REPO ] && sh $TOOLS/pull-repo-base.sh $IJK_OPENSSL_UPSTREAM $IJK_OPENSSL_LOCAL_REPO || echo
}

function pull_fork()
{
    echo "== pull openssl fork $1 =="
    sh $TOOLS/pull-repo-ref.sh $IJK_OPENSSL_FORK ios/openssl-$1 ${IJK_OPENSSL_LOCAL_REPO}
    cd ios/openssl-$1
    git checkout ${IJK_OPENSSL_COMMIT} -B ijkplayer
    cd -
}


if [ "#$FF_TARGET" = "#" ]; then
    for ARCH in $FF_ALL_ARCHS
    do
        echo "$0 $ARCH"
    done
    echo "$0 all"
    exit 1
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

