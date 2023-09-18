#!/bin/sh

TARGET="$1"
CONFIGURATION="$2"
[ "#$CONFIGURATION" = "#" ] && CONFIGURATION="Release"
OPTION="ONLY_ACTIVE_ARCH=NO -configuration $CONFIGURATION"

BUILD_DIR="IJKMediaPlayer/build"
PROJECT="IJKMediaPlayer/IJKMediaPlayer.xcodeproj"

if [ "#$TARGET" = "#" ]; then
  echo "usage: $0 clean|list|IJKPlayer [Debug|Release]"
  exit 1
elif [ $TARGET = "clean" ]; then
  xcodebuild -project $PROJECT -alltargets clean
elif [ $TARGET = "list" ]; then
  xcodebuild -project $PROJECT -list
else
  #step0, prepare
  OUTPUT="build/fplayer-core"
  rm -rf $OUTPUT
  mkdir -p $OUTPUT
  PROGRAM="$TARGET.framework/Versions/A/$TARGET"
  PROGRAM_DSYM="$TARGET.framework.dSYM/Contents/Resources/DWARF/$TARGET"

  LIBS=""
  LIBS_DSYM=""
  VALID_ARCHS="x86_64 arm64"
  for ARCH in $VALID_ARCHS; do
    xcodebuild -project $PROJECT -target $TARGET $OPTION -sdk macosx -arch $ARCH build
    rm -rf "$OUTPUT/${TARGET}.framework"
    rm -rf "$OUTPUT/${TARGET}.framework.dSYM"
    cp -R "$BUILD_DIR/${CONFIGURATION}/${TARGET}.framework" "$OUTPUT/"
    cp -R "$BUILD_DIR/${CONFIGURATION}/${TARGET}.framework.dSYM" "$OUTPUT/"

    cp $BUILD_DIR/${CONFIGURATION}/$PROGRAM /tmp/$TARGET.$ARCH
    cp $BUILD_DIR/${CONFIGURATION}/$PROGRAM_DSYM /tmp/$TARGET.dSYM.$ARCH
    LIBS="$LIBS /tmp/$TARGET.$ARCH"
    LIBS_DSYM="$LIBS_DSYM /tmp/$TARGET.dSYM.$ARCH"
    rm -rf "$BUILD_DIR/"
  done

  lipo -create -output "$OUTPUT/$PROGRAM" $LIBS
  lipo -create -output "$OUTPUT/$PROGRAM_DSYM" $LIBS_DSYM
  cp -f ../COPYING.LGPLv3 $OUTPUT/LICENSE
  cp -f CocoaPodsConfig/fplayer-core-local.podspec $OUTPUT/fplayer-core.podspec
fi

