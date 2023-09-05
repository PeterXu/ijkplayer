#! /usr/bin/env bash

# ffmpeg module config for build fijkplayer


#--------------------
# Standard options:
export COMMON_FF_CFG_FLAGS=
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --prefix=PREFIX"

# Licensing options:
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-gpl"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-version3"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-nonfree"

# Configuration options:
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-static"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-shared"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-small"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-runtime-cpudetect"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-gray"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-swscale-alpha"

# Program options:
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-programs"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-ffmpeg"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-ffplay"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-ffprobe"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-ffserver"

# Documentation options:
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-doc"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-htmlpages"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-manpages"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-podpages"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-txtpages"

# Component options:
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-avdevice"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-avcodec"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-avformat"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-avutil"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-swresample"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-swscale"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-postproc"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-avfilter"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-avresample"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-pthreads"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-w32threads"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-os2threads"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-network"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-dct"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-dwt"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-lsp"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-lzo"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-mdct"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-rdft"
# export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-fft"


#================================
#================================

# Hardware accelerators:
hw_accelerators=""
hw_accelerators1="v4l2-m2m vaapi vdpau"
for i in $hw_accelerators; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-$i"
done
for i in $hw_accelerators1; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-$i"
done

# ./configure --list-decoders
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-decoders"
decoders="aac* ac3* amrnb amrwb ape ass cook"
decoders="$decoders dvaudio dvbsub dvdsub dvvideo eac3* flac flashsv* flv gif gsm*"
decoders="$decoders h261 h263 h263i h263p h264 h264_mediacodec hevc hevc_mediacodec"
decoders="$decoders mjpeg movtext mp1* mp2* mp3* mpc7 mpc8"
decoders="$decoders mpeg1video mpeg2video mpeg2_mediacodec mpeg4 mpeg4_mediacodec mpegvideo"
decoders="$decoders msmpeg4v1 msmpeg4v2 msmpeg4v3"
decoders="$decoders opus pcm_alaw* pcm_mulaw* pgssub"
decoders="$decoders ra_144 ra_288 rawvideo realtext rv10 rv20 rv30 rv40"
decoders="$decoders sami srt ssa subrip svq1 svq3 text theora vc1 vorbis"
decoders="$decoders vp6 vp6a vp6f vp8 vp8_mediacodec vp9 vp9_mediacodec wavpack webvtt"
decoders="$decoders wmalossless wmapro wmav1 wmav2 wmavoice wmv1 wmv2 wmv3"
decoders="$decoders yuv4"
for i in $decoders; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-decoder=$i"
done

#./configure --list-encoders
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-encoders"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-encoder=png"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-encoder=mjpeg"

# ./configure --list-hwaccels
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-hwaccels"


# ./configure --list-demuxers
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-demuxers"
demuxers="aac ac3 ape asf* ass avi caf cavsvideo concat dash data dv dvbsub dvbtxt"
demuxers="$demuxers eac3 ffmetadata flac flv gif gsm h264 hevc hls live_flv loas lrc"
demuxers="$demuxers m4v matroska mjpeg mov mp3 mpc* mpegps mpegts mpegvideo"
demuxers="$demuxers ogg rawvideo realtext rm rtp rtsp sami sdp srt swf"
demuxers="$demuxers wav webm_dash_manifest webvtt"
for i in $demuxers; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-demuxer=$i"
done

# ./configure --list-muxers
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-muxers"
muxers="dash f4v flv hls matroska mov mp4 mpegts webm"
for i in $muxers; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-muxer=$i"
done

# ./configure --list-parsers
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-parsers"
parsers="aac aac_latm ac3 cook dca dirac dvaudio dvbsub dvdsub flac gsm"
parsers="$parsers h261 h263 h264 hevc mpeg4 mpeg4video mpegvideo png rv30 rv40"
for i in $parsers; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-parser=$i"
done

# ./configure --list-protocols
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-protocols"
protocols="async concat crypto data ffrtmphttp file ftp hls http httpproxy https"
protocols="$protocols ijk* pipe rtmp rtmpt rtp tcp udp"
for i in $protocols; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-protocol=$i"
done

# ./configure --list-bsf
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-bsfs"
bsfs1="mjpeg2jpeg mjpeg2jpeg mjpega_dump_header mov2textsub text2movsub eac3_core"
for i in $bsfs1; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-bsf=$i"
done

# ./configure --list-indevs
# ./configure --list-outdevs
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-devices"

# ./configure --list-filters
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-filters"


#================================
#================================

# Others
others="pic"
for i in $others; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-$i"
done

others1="iconv linux-perf bzlib"
for i in $others1; do
  export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-$i"
done

