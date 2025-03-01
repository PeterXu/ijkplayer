#!/bin/sh
#
# Build Universal binaries on Mac OS X, thanks Ryan!
#

if [ $# -lt 2 ]; then
    cat >/dev/stdout <<EOF
  Usage: ./configure CC="sh $0 fat|arm64|x64 clang|clang++" && make && rm -rf arm64 x64

EOF
    exit 1
fi

ARCH="$1"
COMPILER="$2"
shift
shift

DEVELOPER="`xcode-select -print-path`/Platforms/MacOSX.platform/Developer"

# Intel 64-bit compiler flags (10.9 runtime compatibility)
CLANG_COMPILE_X64="$COMPILER -arch x86_64 -mmacosx-version-min=10.9 \
-DMAC_OS_X_VERSION_MIN_REQUIRED=1070 \
-I/usr/local/include"

CLANG_LINK_X64="-mmacosx-version-min=10.9"

# ARM 64-bit compiler flags (11.0 runtime compatibility)
CLANG_COMPILE_ARM64="$COMPILER -arch arm64 -mmacosx-version-min=11.0 \
-I/usr/local/include"

CLANG_LINK_ARM64="-mmacosx-version-min=11.0"


# Output both Intel and ARM object files
args="$*"
compile=yes
link=yes
while test x$1 != x; do
    case $1 in
        --version) exec $COMPILER $1;;
        -v) exec $COMPILER $1;;
        -V) exec $COMPILER $1;;
        -print-prog-name=*) exec $COMPILER $1;;
        -print-search-dirs) exec $COMPILER $1;;
        -E) CLANG_COMPILE_X64="$CLANG_COMPILE_X64 -E"
            CLANG_COMPILE_ARM64="$CLANG_COMPILE_ARM64 -E"
            compile=no; link=no;;
        -c) link=no;;
        -o) output=$2;;
        *.c|*.cc|*.cpp|*.S|*.m|*.mm) source=$1;;
    esac
    shift
done
if test x$link = xyes; then
    CLANG_COMPILE_X64="$CLANG_COMPILE_X64 $CLANG_LINK_X64"
    CLANG_COMPILE_ARM64="$CLANG_COMPILE_ARM64 $CLANG_LINK_ARM64"
fi
if test x"$output" = x; then
    if test x$link = xyes; then
        output=a.out
    elif test x$compile = xyes; then
        output=`echo $source | sed -e 's|.*/||' -e 's|\(.*\)\.[^\.]*|\1|'`.o
    fi
fi

# Compile Intel 64-bit
if test x"$ARCH" == x"x64" -o x"$ARCH" == x"fat"; then
if test x"$output" != x; then
    dir=x64/`dirname $output`
    if test -d $dir; then
        :
    else
        mkdir -p $dir
    fi
fi
set -- $args
while test x$1 != x; do
    if test -f "x64/$1" && test "$1" != "$output"; then
        x64_args="$x64_args x64/$1"
    else
        x64_args="$x64_args $1"
    fi
    shift
done
$CLANG_COMPILE_X64 $x64_args || exit $?
if test x"$output" != x; then
    cp $output x64/$output
fi
fi

# Compile ARM 64-bit
if test x"$ARCH" == x"arm64" -o x"$ARCH" == x"fat"; then
if test x"$output" != x; then
    dir=arm64/`dirname $output`
    if test -d $dir; then
        :
    else
        mkdir -p $dir
    fi
fi
set -- $args
while test x$1 != x; do
    if test -f "arm64/$1" && test "$1" != "$output"; then
        arm64_args="$arm64_args arm64/$1"
    else
        arm64_args="$arm64_args $1"
    fi
    shift
done
$CLANG_COMPILE_ARM64 $arm64_args || exit $?
if test x"$output" != x; then
    cp $output arm64/$output
fi
fi


if test x"$ARCH" == x"fat"; then
if test x"$output" != x; then
    lipo -create -o $output arm64/$output x64/$output
fi
fi

