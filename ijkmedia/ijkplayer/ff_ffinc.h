/*
 * ff_ffinc.h
 *      ffmpeg headers
 *
 * Copyright (c) 2013 Bilibili
 * Copyright (c) 2013 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 *
 * ijkPlayer is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ijkPlayer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ijkPlayer; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef FFPLAY__FF_FFINC_H
#define FFPLAY__FF_FFINC_H

#include <stdbool.h>
#include <assert.h>

//#define HAVE_AV_CONFIG_H
#include "libavutil/config.h"
#include "libavutil/config_components.h"

// FIXME: merge filter related code and enable it
// remove these lines to enable avfilter
#ifdef CONFIG_AVFILTER
#undef CONFIG_AVFILTER
#endif
#define CONFIG_AVFILTER 0

#ifndef FFMPEG_LOG_TAG
#define FFMPEG_LOG_TAG "IJKFFMPEG"
#endif


#include "libavutil/attributes.h"
#include "libavutil/avassert.h"
#include "libavutil/avstring.h"
#include "libavutil/base64.h"
#include "libavutil/bprint.h"
#include "libavutil/dict.h"
#include "libavutil/display.h"
#include "libavutil/error.h"
#include "libavutil/eval.h"
#include "libavutil/fifo.h"
#include "libavutil/frame.h"
#include "libavutil/imgutils.h"
#include "libavutil/log.h"
#include "libavutil/mathematics.h"
#include "libavutil/opt.h"
#include "libavutil/parseutils.h"
#include "libavutil/pixdesc.h"
#include "libavutil/pixfmt.h"
#include "libavutil/samplefmt.h"
#include "libavutil/thread.h"
#include "libavutil/time.h"
#include "libavutil/version.h"

#include "libavutil/common.h"
#include "libavutil/application.h"

#if CONFIG_AVDEVICE
#include "libavdevice/avdevice.h"
#endif

#if CONFIG_AVFILTER
# include "libavfilter/avfilter.h"
# include "libavfilter/buffersink.h"
# include "libavfilter/buffersrc.h"
#endif

#include "libavcodec/avcodec.h"
#include "libavcodec/avfft.h"
#include "libavcodec/bsf.h"
#include "libavformat/avformat.h"
#include "libavformat/avc.h"
#include "libavformat/url.h"
#include "libavformat/version.h"
#include "libavformat/internal.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"


typedef int (*ijk_inject_callback)(void *opaque, int type, void *data, size_t data_size);

#define FFP_OPT_CATEGORY_FORMAT 1
#define FFP_OPT_CATEGORY_CODEC  2
#define FFP_OPT_CATEGORY_SWS    3
#define FFP_OPT_CATEGORY_PLAYER 4
#define FFP_OPT_CATEGORY_SWR    5

#endif
