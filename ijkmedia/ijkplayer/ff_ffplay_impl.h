//
//  Header.h
//  IJKMediaPlayer
//
//  Created by Peter on 2023/9/13.
//  Copyright © 2023 bilibili. All rights reserved.
//

#ifndef FFPLAY__FF_FFPLAY_IMPL_H
#define FFPLAY__FF_FFPLAY_IMPL_H

#include "config.h"
#include <inttypes.h>
#include <math.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/types.h>

#ifdef WIN32
#include <Windows.h>
#include <io.h>
#else
#include <unistd.h>
#endif

#include "libavutil/avstring.h"
#include "libavutil/eval.h"
#include "libavutil/mathematics.h"
#include "libavutil/pixdesc.h"
#include "libavutil/imgutils.h"
#include "libavutil/dict.h"
#include "libavutil/parseutils.h"
#include "libavutil/samplefmt.h"
#include "libavutil/avassert.h"
#include "libavutil/time.h"
#include "libavutil/attributes.h"
#include "libavformat/avformat.h"
#if CONFIG_AVDEVICE
#include "libavdevice/avdevice.h"
#endif
#include "libswscale/swscale.h"
#include "libavutil/opt.h"
#include "libavcodec/avfft.h"
#include "libswresample/swresample.h"

#if CONFIG_AVFILTER
# include "libavcodec/avcodec.h"
# include "libavfilter/avfilter.h"
# include "libavfilter/buffersink.h"
# include "libavfilter/buffersrc.h"
#endif

#include "ijksdl/ijksdl_log.h"
#include "ijkavformat/ijkavformat.h"
#include "ff_cmdutils.h"
#include "ff_fferror.h"
#include "ff_ffpipeline.h"
#include "ff_ffpipenode.h"
#include "ff_ffplay_debug.h"
#include "ff_ffplay_options.h"
#include "ijkmeta.h"
#include "ijkversion.h"
#include "ijkplayer.h"


#define IJKVERSION_GET_MAJOR(x)     ((x >> 16) & 0xFF)
#define IJKVERSION_GET_MINOR(x)     ((x >>  8) & 0xFF)
#define IJKVERSION_GET_MICRO(x)     ((x      ) & 0xFF)


/* some internal interfaces wrapped for ffplay */

AVPacket *ffplay_flush_pkt();

int ffplay_get_master_sync_type(VideoState *is);
double ffplay_get_master_clock(VideoState *is);

int ffplay_packet_queue_init(PacketQueue *q);
void ffplay_packet_queue_destroy(PacketQueue *q);
void ffplay_packet_queue_abort(PacketQueue *q);
void ffplay_packet_queue_start(PacketQueue *q);
void ffplay_packet_queue_flush(PacketQueue *q);
int ffplay_packet_queue_get(PacketQueue *q, AVPacket *pkt, int block, int *serial);
int ffplay_packet_queue_put(PacketQueue *q, AVPacket *pkt);

VideoState *ffplay_stream_open(FFPlayer *ffp, const char *filename, AVInputFormat *iformat);
void ffplay_stream_close(FFPlayer *ffp);
void ffplay_stream_seek(FFPlayer *ffp, int64_t pos, int64_t rel, int seek_by_bytes);
void ffplay_toggle_pause(FFPlayer *ffp, int pause_on);
void ffplay_stream_update_pause_l(FFPlayer *ffp);
int ffplay_stream_component_open(FFPlayer *ffp, int stream_index);
void ffplay_stream_component_close(FFPlayer *ffp, int stream_index);

void ffplay_free_picture(Frame *vp);
void ffplay_frame_queue_push(FrameQueue *f);
Frame *ffplay_frame_queue_peek_writable(FrameQueue *f);
void ffplay_refresh_video(FFPlayer *ffp, double *remaining_time);
int ffplay_queue_picture(FFPlayer *ffp, AVFrame *src_frame, double pts, double duration, int64_t pos, int serial);
int ffplay_video_thread(void *arg);


/* some internal interfaces implemented for ffplay */

void ffplay_clock_msg_notify_cycle(FFPlayer *ffp, int64_t time_ms);
int ffplay_packet_queue_get_or_buffering(FFPlayer *ffp, PacketQueue *q, AVPacket *pkt, int *serial, int *finished);
int ffplay_convert_image(FFPlayer *ffp, AVFrame *src_frame, int64_t src_frame_pts, int width, int height);
size_t ffplay_parse_ass_subtitle(const char *ass, char *output);
void ffplay_alloc_picture(FFPlayer *ffp, int frame_format);
int ffplay_video_refresh_thread(void *arg);


#endif /* FFPLAY__FF_FFPLAY_IMPL_H */
