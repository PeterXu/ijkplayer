#! /usr/bin/env bash
#

set -e

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK, ANDROID_SDK before starting."
    echo "They must point to your NDK and SDK directories.\n"
    exit 1
fi


REQUEST_TARGET=$1

do_build_output() {
    INPUT="$1"
    OUTPUT="build/fplayer-core"
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
    cd ijkplayer
    ./gradlew :ijkplayer-$TARGET:$ACTION
    cd ..
    do_build_output "ijkplayer/ijkplayer-$TARGET/build/outputs"
}

# usage: $0 [build|clean]
do_build_full() {
    ACTION="$1"
    [ "#$ACTION" = "#" ] && ACTION="build"
    cd ijkplayer
    ./gradlew :fijkplayer-full:$ACTION
    cd ..
    do_build_output "ijkplayer/fijkplayer-full/build/outputs"
}


do_build_all() {
    ACTION="$1"
    [ "#$ACTION" = "#" ] && ACTION="build"
    do_build_full $ACTION
    do_build_aar exo $ACTION
    do_build_aar example $ACTION
}


case "$REQUEST_TARGET" in
    java|exo|example)
        do_build_aar $REQUEST_TARGET build
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
        echo "  $0 java|exo|example"
        echo "  $0 full"
        echo "  $0 all|clean"
        exit 1
    ;;
esac

