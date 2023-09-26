#! /usr/bin/env bash
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR=$(dirname "$DIR")
PLATFORM="android"

FF_TARGET=$1
FF_TARGET_EXTRA=$2
FF_TOOLS=${BASEDIR}/tools
UNI_BUILD_ROOT=${BASEDIR}/$PLATFORM

#----------

do_build_output() {
    INPUT="$1"
    OUTPUT="$UNI_BUILD_ROOT/build/fplayer-core"
    mkdir -p "$OUTPUT"
    echo "Output: $INPUT -> $OUTPUT"
    [ -d "$INPUT/aar" ] && cp -rf "$INPUT/aar" "$OUTPUT"
    [ -d "$INPUT/apk" ] && cp -rf "$INPUT/apk" "$OUTPUT"
    return 0
}

# usage: $0 java/exo/example [build|clean]
do_build_aar() {
    TARGET="$1"
    ACTION="$2"
    [ "#$ACTION" = "#" ] && ACTION="build"
    cd $UNI_BUILD_ROOT/ijkplayer
    ./gradlew :ijkplayer-$TARGET:$ACTION
    cd -
    do_build_output "$UNI_BUILD_ROOT/ijkplayer/ijkplayer-$TARGET/build/outputs"
}

# usage: $0 [build|clean]
do_build_full() {
    ACTION="$1"
    [ "#$ACTION" = "#" ] && ACTION="build"
    cd $UNI_BUILD_ROOT/ijkplayer
    ./gradlew :fijkplayer-full:$ACTION
    cd -
    do_build_output "$UNI_BUILD_ROOT/ijkplayer/fijkplayer-full/build/outputs"
}


do_build_all() {
    ACTION="$1"
    [ "#$ACTION" = "#" ] && ACTION="build"
    do_build_full $ACTION
    do_build_aar exo $ACTION
    do_build_aar example $ACTION
    if [ "$ACTION" = "clean" ]; then
        rm -rf "$UNI_BUILD_ROOT/ijkplayer/fijkplayer-full/build"
        rm -rf "$UNI_BUILD_ROOT/ijkplayer/fijkplayer-full/.cxx"
    fi
}

#----------

case "$FF_TARGET" in
    java|exo|example)
        do_build_aar $FF_TARGET build
    ;;
    full)
        do_build_full
    ;;
    all)
        do_build_all
    ;;
    clean)
        do_build_all clean
    ;;
    *)
        echo "Usage:"
        echo "  $0 full"
        echo "  $0 java|exo|example"
        echo "  $0 all|clean"
        exit 1
    ;;
esac

