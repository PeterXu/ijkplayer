#!/bin/sh

TARGET="$1"
CONFIGURATION="$2"
[ "#$CONFIGURATION" = "#" ] && CONFIGURATION="Release"
OPTION="ONLY_ACTIVE_ARCH=NO -configuration $CONFIGURATION"

BUILD_DIR="IJKMediaPlayer/build"
PROJECT="IJKMediaPlayer/IJKMediaPlayer.xcodeproj"

if [ "#$TARGET" = "#" ]; then
  echo "usage: $0 clean|list|IJKMediaPlayer [Debug|Release]"
  exit 1
elif [ $TARGET = "clean" ]; then
  xcodebuild -project $PROJECT -alltargets clean
elif [ $TARGET = "list" ]; then
  xcodebuild -project $PROJECT -list
else
  xcodebuild -project $PROJECT -target $TARGET $OPTION -sdk iphoneos -arch arm64 build
  xcodebuild -project $PROJECT -target $TARGET $OPTION -sdk iphonesimulator -arch x86_64 build
  #exit 0

  #step0, prepare
  OUTPUT="build/fplayer-core"
  rm -rf $OUTPUT
  mkdir -p $OUTPUT
  cp -R "$BUILD_DIR/${CONFIGURATION}-iphoneos/${TARGET}.framework" "$OUTPUT/"

  #step1, process iphonesimulator
  fswift="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${TARGET}.framework/Modules/${TARGET}.swiftmodule"
  if [ -d "$fswift" ]; then
    cp -R "$fswift" "$OUTPUT/${TARGET}.framework/Modules/"
  fi
  fsimulator="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${TARGET}.framework/${TARGET}"
  fatinfo=`lipo -info "$fsimulator" | grep arm64`
  if [ "#$fatinfo" != "#" ]; then
    fsimulator_only="${fsimulator}.only"
    lipo -remove arm64 "$fsimulator" -o "$fsimulator_only"
    mv "$fsimulator_only" "$fsimulator"
  fi

  #step2, create
  LIBS=""
  ARCHS="iphoneos iphonesimulator"
  for item in $ARCHS; do
    LIBS="$LIBS $BUILD_DIR/${CONFIGURATION}-${item}/${TARGET}.framework/${TARGET}"
  done
  lipo -create -output "$OUTPUT/${TARGET}.framework/$TARGET" $LIBS
  cp -f ../COPYING.LGPLv3 $OUTPUT/LICENSE
  cp -f CocoaPodsConfig/fplayer-core-local.podspec $OUTPUT/fplayer-core.podspec
fi
