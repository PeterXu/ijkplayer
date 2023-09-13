//
//  ff_ffplay_impl.c
//  IJKMediaPlayer
//
//  Created by Peter on 2023/9/13.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include "ff_ffplay_impl.h"
#include "ff_ffplay.h"


void ffplay_clock_msg_notify_cycle(FFPlayer *ffp, int64_t time_ms) {
    if (ffp->enable_position_notify &&
            (time_ms < 0 || time_ms - ffp->clock_notify_time > ffp->pos_update_interval)) {
        ffp->clock_notify_time = time_ms;
        int64_t position = ffp_get_current_position_l(ffp);
        ffp_notify_msg2(ffp, FFP_MSG_CURRENT_POSITION_UPDATE, (int) position);
    }
}

int ffplay_packet_queue_get_or_buffering(FFPlayer *ffp, PacketQueue *q, AVPacket *pkt, int *serial, int *finished) {
    assert(finished);
    if (!ffp->packet_buffering)
        return ffplay_packet_queue_get(q, pkt, 1, serial);

    while (1) {
        int new_packet = ffplay_packet_queue_get(q, pkt, 0, serial);
        if (new_packet < 0)
            return -1;
        else if (new_packet == 0) {
            if (q->is_buffer_indicator && !*finished)
                ffp_toggle_buffering(ffp, 1);
            new_packet = ffplay_packet_queue_get(q, pkt, 1, serial);
            if (new_packet < 0)
                return -1;
        }

        if (*finished == *serial) {
            av_packet_unref(pkt);
            continue;
        }
        else
            break;
    }

    return 1;
}

int ffplay_convert_image(FFPlayer *ffp, AVFrame *src_frame, int64_t src_frame_pts, int width, int height) {
    GetImgInfo *img_info = ffp->get_img_info;
    VideoState *is = ffp->is;
    AVFrame *dst_frame = NULL;
    AVPacket avpkt;
    int got_packet = 0;
    int dst_width = 0;
    int dst_height = 0;
    int bytes = 0;
    void *buffer = NULL;
    char file_path[1024] = {0};
    char file_name[16] = {0};
    int fd = -1;
    int ret = 0;
    int tmp = 0;
    float origin_dar = 0;
    float dar = 0;
    AVRational display_aspect_ratio;
    int file_name_length = 0;

    if (!height || !width || !img_info->width || !img_info->height) {
        ret = -1;
        return ret;
    }

    dar = (float) img_info->width / img_info->height;

    if (is->viddec.avctx) {
        av_reduce(&display_aspect_ratio.num, &display_aspect_ratio.den,
                is->viddec.avctx->width * (int64_t)is->viddec.avctx->sample_aspect_ratio.num,
                is->viddec.avctx->height * (int64_t)is->viddec.avctx->sample_aspect_ratio.den,
                1024 * 1024);

        if (!display_aspect_ratio.num || !display_aspect_ratio.den) {
            origin_dar = (float) width / height;
        } else {
            origin_dar = (float) display_aspect_ratio.num / display_aspect_ratio.den;
        }
    } else {
        ret = -1;
        return ret;
    }

    if ((int)(origin_dar * 100) != (int)(dar * 100)) {
        tmp = img_info->width / origin_dar;
        if (tmp > img_info->height) {
            img_info->width = img_info->height * origin_dar;
        } else {
            img_info->height = tmp;
        }
        av_log(NULL, AV_LOG_INFO, "%s img_info->width = %d, img_info->height = %d\n", __func__, img_info->width, img_info->height);
    }

    dst_width = img_info->width;
    dst_height = img_info->height;

    av_init_packet(&avpkt);
    avpkt.size = 0;
    avpkt.data = NULL;

    if (!img_info->frame_img_convert_ctx) {
        img_info->frame_img_convert_ctx = sws_getContext(width,
                height,
                src_frame->format,
                dst_width,
                dst_height,
                AV_PIX_FMT_RGB24,
                SWS_BICUBIC,
                NULL,
                NULL,
                NULL);

        if (!img_info->frame_img_convert_ctx) {
            ret = -1;
            av_log(NULL, AV_LOG_ERROR, "%s sws_getContext failed\n", __func__);
            goto fail0;
        }
    }

    if (!img_info->frame_img_codec_ctx) {
        AVCodec *image_codec = avcodec_find_encoder(AV_CODEC_ID_PNG);
        if (!image_codec) {
            ret = -1;
            av_log(NULL, AV_LOG_ERROR, "%s avcodec_find_encoder failed\n", __func__);
            goto fail0;
        }
        img_info->frame_img_codec_ctx = avcodec_alloc_context3(image_codec);
        if (!img_info->frame_img_codec_ctx) {
            ret = -1;
            av_log(NULL, AV_LOG_ERROR, "%s avcodec_alloc_context3 failed\n", __func__);
            goto fail0;
        }
        img_info->frame_img_codec_ctx->bit_rate = ffp->stat.bit_rate;
        img_info->frame_img_codec_ctx->width = dst_width;
        img_info->frame_img_codec_ctx->height = dst_height;
        img_info->frame_img_codec_ctx->pix_fmt = AV_PIX_FMT_RGB24;
        img_info->frame_img_codec_ctx->codec_type = AVMEDIA_TYPE_VIDEO;
        img_info->frame_img_codec_ctx->time_base.num = ffp->is->video_st->time_base.num;
        img_info->frame_img_codec_ctx->time_base.den = ffp->is->video_st->time_base.den;
        avcodec_open2(img_info->frame_img_codec_ctx, image_codec, NULL);
    }

    dst_frame = av_frame_alloc();
    if (!dst_frame) {
        ret = -1;
        av_log(NULL, AV_LOG_ERROR, "%s av_frame_alloc failed\n", __func__);
        goto fail0;
    }
    bytes = av_image_get_buffer_size(AV_PIX_FMT_RGB24, dst_width, dst_height, 1);
    buffer = (uint8_t *) av_malloc(bytes * sizeof(uint8_t));
    if (!buffer) {
        ret = -1;
        av_log(NULL, AV_LOG_ERROR, "%s av_image_get_buffer_size failed\n", __func__);
        goto fail1;
    }

    dst_frame->format = AV_PIX_FMT_RGB24;
    dst_frame->width = dst_width;
    dst_frame->height = dst_height;

    ret = av_image_fill_arrays(dst_frame->data,
            dst_frame->linesize,
            buffer,
            AV_PIX_FMT_RGB24,
            dst_width,
            dst_height,
            1);

    if (ret < 0) {
        ret = -1;
        av_log(NULL, AV_LOG_ERROR, "%s av_image_fill_arrays failed\n", __func__);
        goto fail2;
    }

    ret = sws_scale(img_info->frame_img_convert_ctx,
            (const uint8_t * const *) src_frame->data,
            src_frame->linesize,
            0,
            src_frame->height,
            dst_frame->data,
            dst_frame->linesize);

    if (ret <= 0) {
        ret = -1;
        av_log(NULL, AV_LOG_ERROR, "%s sws_scale failed\n", __func__);
        goto fail2;
    }

    ret = avcodec_encode_video2(img_info->frame_img_codec_ctx, &avpkt, dst_frame, &got_packet);

    if (ret >= 0 && got_packet > 0) {
        strcpy(file_path, img_info->img_path);
        strcat(file_path, "/");
        sprintf(file_name, "%" PRId64 "", src_frame_pts);
        strcat(file_name, ".png");
        strcat(file_path, file_name);

        fd = open(file_path, O_RDWR | O_TRUNC | O_CREAT, 0600);
        if (fd < 0) {
            ret = -1;
            av_log(NULL, AV_LOG_ERROR, "%s open path = %s failed %s\n", __func__, file_path, strerror(errno));
            goto fail2;
        }
        write(fd, avpkt.data, avpkt.size);
        close(fd);

        img_info->count--;

        file_name_length = (int)strlen(file_name) + 1;

        if (img_info->count <= 0)
            ffp_notify_msg4(ffp, FFP_MSG_GET_IMG_STATE, (int) src_frame_pts, 1, file_name, file_name_length);
        else
            ffp_notify_msg4(ffp, FFP_MSG_GET_IMG_STATE, (int) src_frame_pts, 0, file_name, file_name_length);

        ret = 0;
    }

fail2:
    av_free(buffer);
fail1:
    av_frame_free(&dst_frame);
fail0:
    av_packet_unref(&avpkt);

    return ret;
}

size_t ffplay_parse_ass_subtitle(const char *ass, char *output)
{
    char *tok = NULL;
    tok = strchr(ass, ':'); if (tok) tok += 1; // skip event
    tok = strchr(tok, ','); if (tok) tok += 1; // skip layer
    tok = strchr(tok, ','); if (tok) tok += 1; // skip start_time
    tok = strchr(tok, ','); if (tok) tok += 1; // skip end_time
    tok = strchr(tok, ','); if (tok) tok += 1; // skip style
    tok = strchr(tok, ','); if (tok) tok += 1; // skip name
    tok = strchr(tok, ','); if (tok) tok += 1; // skip margin_l
    tok = strchr(tok, ','); if (tok) tok += 1; // skip margin_r
    tok = strchr(tok, ','); if (tok) tok += 1; // skip margin_v
    tok = strchr(tok, ','); if (tok) tok += 1; // skip effect
    if (tok) {
        char *text = tok;
        size_t idx = 0;
        do {
            char *found = strstr(text, "\\N");
            if (found) {
                size_t n = found - text;
                memcpy(output+idx, text, n);
                output[idx + n] = '\n';
                idx = n + 1;
                text = found + 2;
            }
            else {
                size_t left_text_len = strlen(text);
                memcpy(output+idx, text, left_text_len);
                if (output[idx + left_text_len - 1] == '\n')
                    output[idx + left_text_len - 1] = '\0';
                else
                    output[idx + left_text_len] = '\0';
                break;
            }
        } while(1);
        return strlen(output) + 1;
    }
    return 0;
}


/* allocate a picture (needs to do that in main thread to avoid
   potential locking problems */
void ffplay_alloc_picture(FFPlayer *ffp, int frame_format)
{
    VideoState *is = ffp->is;
    Frame *vp;
#ifdef FFP_MERGE
    int sdl_format;
#endif

    vp = &is->pictq.queue[is->pictq.windex];

    ffplay_free_picture(vp);

#ifdef FFP_MERGE
    video_open(is, vp);
#endif

    SDL_VoutSetOverlayFormat(ffp->vout, ffp->overlay_format, ffp->vout_type);
    vp->bmp = SDL_Vout_CreateOverlay(vp->width, vp->height,
            frame_format,
            ffp->vout);
#ifdef FFP_MERGE
    if (vp->format == AV_PIX_FMT_YUV420P)
        sdl_format = SDL_PIXELFORMAT_YV12;
    else
        sdl_format = SDL_PIXELFORMAT_ARGB8888;

    int eret = (realloc_texture(&vp->bmp, sdl_format, vp->width, vp->height, SDL_BLENDMODE_NONE, 0) < 0) ? 1 : 0;
#else
    /* RV16, RV32 contains only one plane */
    int eret = (!vp->bmp || (!vp->bmp->is_private && vp->bmp->pitches[0] < vp->width));
#endif
    if (eret) {
        /* SDL allocates a buffer smaller than requested if the video
         * overlay hardware is unable to support the requested size. */
        av_log(NULL, AV_LOG_FATAL,
                "Error: the video system does not support an image\n"
                "size of %dx%d pixels. Try using -lowres or -vf \"scale=w:h\"\n"
                "to reduce the image size.\n", vp->width, vp->height );
        ffplay_free_picture(vp);
    }

    SDL_LockMutex(is->pictq.mutex);
    vp->allocated = 1;
    SDL_CondSignal(is->pictq.cond);
    SDL_UnlockMutex(is->pictq.mutex);
}

int ffplay_video_refresh_thread(void *arg)
{
    FFPlayer *ffp = arg;
    VideoState *is = ffp->is;
    double remaining_time = 0.0;
    while (!is->abort_request) {
        if (remaining_time > 0.0)
            av_usleep((uint)(uint64_t)(remaining_time * 1000000.0));
        remaining_time = REFRESH_RATE;
        if (ffp->cover_after_prepared && !ffp->first_video_frame_rendered) {
            is->force_refresh = true;
        }
#if ANDROID
        if (is->paused) {
            SDL_Delay(1000/24);
            is->force_refresh = true;
        }
#endif
        if (is->show_mode != SHOW_MODE_NONE && (!is->paused || is->force_refresh))
            ffplay_refresh_video(ffp, &remaining_time);
    }
    if (ffp->vout)
        SDL_VoutFreeContext(ffp->vout);
    return 0;
}



/* global interfaces */

static bool g_ffmpeg_global_inited = false;

inline static int log_level_av_to_ijk(int av_level)
{
    int ijk_level = IJK_LOG_VERBOSE;
    if      (av_level <= AV_LOG_PANIC)      ijk_level = IJK_LOG_FATAL;
    else if (av_level <= AV_LOG_FATAL)      ijk_level = IJK_LOG_FATAL;
    else if (av_level <= AV_LOG_ERROR)      ijk_level = IJK_LOG_ERROR;
    else if (av_level <= AV_LOG_WARNING)    ijk_level = IJK_LOG_WARN;
    else if (av_level <= AV_LOG_INFO)       ijk_level = IJK_LOG_INFO;
    // AV_LOG_VERBOSE means detailed info
    else if (av_level <= AV_LOG_VERBOSE)    ijk_level = IJK_LOG_INFO;
    else if (av_level <= AV_LOG_DEBUG)      ijk_level = IJK_LOG_DEBUG;
    else if (av_level <= AV_LOG_TRACE)      ijk_level = IJK_LOG_VERBOSE;
    else                                    ijk_level = IJK_LOG_VERBOSE;
    return ijk_level;
}

inline static int log_level_ijk_to_av(int ijk_level)
{
    int av_level = IJK_LOG_VERBOSE;
    if      (ijk_level >= IJK_LOG_SILENT)   av_level = AV_LOG_QUIET;
    else if (ijk_level >= IJK_LOG_FATAL)    av_level = AV_LOG_FATAL;
    else if (ijk_level >= IJK_LOG_ERROR)    av_level = AV_LOG_ERROR;
    else if (ijk_level >= IJK_LOG_WARN)     av_level = AV_LOG_WARNING;
    else if (ijk_level >= IJK_LOG_INFO)     av_level = AV_LOG_INFO;
    // AV_LOG_VERBOSE means detailed info
    else if (ijk_level >= IJK_LOG_DEBUG)    av_level = AV_LOG_DEBUG;
    else if (ijk_level >= IJK_LOG_VERBOSE)  av_level = AV_LOG_TRACE;
    else if (ijk_level >= IJK_LOG_DEFAULT)  av_level = AV_LOG_TRACE;
    else if (ijk_level >= IJK_LOG_UNKNOWN)  av_level = AV_LOG_TRACE;
    else                                    av_level = AV_LOG_TRACE;
    return av_level;
}

static void ffp_log_callback_brief(void *ptr, int level, const char *fmt, va_list vl)
{
    if (level > av_log_get_level())
        return;

    int ffplv av_unused = log_level_av_to_ijk(level);
    VLOG(ffplv, IJK_LOG_TAG, fmt, vl);
}

static void ffp_log_callback_report(void *ptr, int level, const char *fmt, va_list vl)
{
    if (level > av_log_get_level())
        return;

    int ffplv av_unused = log_level_av_to_ijk(level);

    va_list vl2;
    char line[1024];
    static int print_prefix = 1;

    va_copy(vl2, vl);
    // av_log_default_callback(ptr, level, fmt, vl);
    av_log_format_line(ptr, level, fmt, vl2, line, sizeof(line), &print_prefix);
    va_end(vl2);

    ALOG(ffplv, IJK_LOG_TAG, "%s", line);
}

int ijkav_register_all(void);
void ffp_global_init()
{
    if (g_ffmpeg_global_inited)
        return;

    ALOGD("ijkmediaplayer version : %s\n", ijkmp_version());
    /* register all codecs, demux and protocols */
    avcodec_register_all();
#if CONFIG_AVDEVICE
    avdevice_register_all();
#endif
#if CONFIG_AVFILTER
    avfilter_register_all();
#endif
    av_register_all();

    ijkav_register_all();

    avformat_network_init();

    //av_lockmgr_register(lockmgr);
    av_log_set_callback(ffp_log_callback_brief);

    av_init_packet(ffplay_flush_pkt());
    ffplay_flush_pkt()->data = (uint8_t *)ffplay_flush_pkt();

    g_ffmpeg_global_inited = true;
}

void ffp_global_uninit()
{
    if (!g_ffmpeg_global_inited)
        return;

    //av_lockmgr_register(NULL);

    // FFP_MERGE: uninit_opts

    avformat_network_deinit();

    g_ffmpeg_global_inited = false;
}

void ffp_global_set_log_report(int use_report)
{
    if (use_report) {
        av_log_set_callback(ffp_log_callback_report);
    } else {
        av_log_set_callback(ffp_log_callback_brief);
    }
}

void ffp_global_set_log_level(int log_level)
{
    int av_level = log_level_ijk_to_av(log_level);
    ijk_log_set_level(log_level);
    av_log_set_level(av_level);
}

static ijk_inject_callback s_inject_callback;
int inject_callback(void *opaque, int type, void *data, size_t data_size)
{
    if (s_inject_callback)
        return s_inject_callback(opaque, type, data, data_size);
    return 0;
}

void ffp_global_set_inject_callback(ijk_inject_callback cb)
{
    s_inject_callback = cb;
}

void ffp_io_stat_register(void (*cb)(const char *url, int type, int bytes))
{
    // avijk_io_stat_register(cb);
}

void ffp_io_stat_complete_register(void (*cb)(const char *url,
            int64_t read_bytes, int64_t total_size,
            int64_t elpased_time, int64_t total_duration))
{
    // avijk_io_stat_complete_register(cb);
}


/* ffplayer context */

static const char *ffp_context_to_name(void *ptr)
{
    return "FFPlayer";
}

static void *ffp_context_child_next(void *obj, void *prev)
{
    return NULL;
}

static const AVClass *ffp_context_child_class_next(const AVClass *prev)
{
    return NULL;
}

const AVClass ffp_context_class = {
    .class_name       = "FFPlayer",
    .item_name        = ffp_context_to_name,
    .option           = ffp_context_options,
    .version          = LIBAVUTIL_VERSION_INT,
    .child_next       = ffp_context_child_next,
    .child_class_next = ffp_context_child_class_next,
};

static const char *ijk_version_info()
{
    return IJKPLAYER_VERSION;
}

FFPlayer *ffp_create()
{
    av_log(NULL, AV_LOG_INFO, "av_version_info: %s\n", av_version_info());
    av_log(NULL, AV_LOG_INFO, "ijk_version_info: %s\n", ijk_version_info());

    FFPlayer* ffp = (FFPlayer*) av_mallocz(sizeof(FFPlayer));
    if (!ffp)
        return NULL;

    msg_queue_init(&ffp->msg_queue);
    ffp->af_mutex = SDL_CreateMutex();
    ffp->vf_mutex = SDL_CreateMutex();

    ffp_reset_internal(ffp);
    ffp->av_class = &ffp_context_class;
    ffp->meta = ijkmeta_create();

    av_opt_set_defaults(ffp);

    return ffp;
}

void ffp_reset(FFPlayer *ffp)
{
    if (!ffp)
        return;

    ffp->start_time = AV_NOPTS_VALUE;
    ffp->duration = AV_NOPTS_VALUE;
    ffp->error = 0;
    ffp->loop = 1;
    ffp->first_audio_frame_rendered = 0;
    ffp->first_video_frame_rendered = 0;
    av_freep(&ffp->input_filename);

    memset(ffp->wanted_stream_spec, 0, sizeof(ffp->wanted_stream_spec));

    av_freep(&ffp->video_codec_info);
    av_freep(&ffp->audio_codec_info);
    av_freep(&ffp->subtitle_codec_info);

    ijkmeta_reset(ffp->meta);

    SDL_SpeedSamplerReset(&ffp->vfps_sampler);
    SDL_SpeedSamplerReset(&ffp->vdps_sampler);

    ffp_reset_statistic(&ffp->stat);
    ffp_reset_demux_cache_control(&ffp->dcc);
}

void ffp_destroy(FFPlayer *ffp)
{
    if (!ffp)
        return;

    if (ffp->is) {
        av_log(NULL, AV_LOG_WARNING, "%s: force stream_close()", __func__);
        ffplay_stream_close(ffp);
        ffp->is = NULL;
    }

    SDL_VoutFreeP(&ffp->vout);
    SDL_AoutFreeP(&ffp->aout);
    ffpipenode_free_p(&ffp->node_vdec);
    ffpipeline_free_p(&ffp->pipeline);
    ijkmeta_destroy_p(&ffp->meta);
    ffp_reset_internal(ffp);

    SDL_DestroyMutexP(&ffp->af_mutex);
    SDL_DestroyMutexP(&ffp->vf_mutex);

    msg_queue_destroy(&ffp->msg_queue);

    av_free(ffp);
}

void ffp_destroy_p(FFPlayer **pffp)
{
    if (!pffp)
        return;

    ffp_destroy(*pffp);
    *pffp = NULL;
}

static AVDictionary **ffp_get_opt_dict(FFPlayer *ffp, int opt_category)
{
    assert(ffp);

    switch (opt_category) {
        case FFP_OPT_CATEGORY_FORMAT:   return &ffp->format_opts;
        case FFP_OPT_CATEGORY_CODEC:    return &ffp->codec_opts;
        case FFP_OPT_CATEGORY_SWS:      return &ffp->sws_dict;
        case FFP_OPT_CATEGORY_PLAYER:   return &ffp->player_opts;
        case FFP_OPT_CATEGORY_SWR:      return &ffp->swr_opts;
        default:
            av_log(ffp, AV_LOG_ERROR, "unknown option category %d\n", opt_category);
            return NULL;
    }
}

static int app_func_event(AVApplicationContext *h, int message ,void *data, size_t size)
{
    if (!h || !h->opaque || !data)
        return 0;

    FFPlayer *ffp = (FFPlayer *)h->opaque;
    if (!ffp->inject_opaque)
        return 0;
    if (message == AVAPP_EVENT_IO_TRAFFIC && sizeof(AVAppIOTraffic) == size) {
        AVAppIOTraffic *event = (AVAppIOTraffic *)(intptr_t)data;
        if (event->bytes > 0) {
            ffp->stat.byte_count += event->bytes;
            SDL_SpeedSampler2Add(&ffp->stat.tcp_read_sampler, event->bytes);
        }
    } else if (message == AVAPP_EVENT_ASYNC_STATISTIC && sizeof(AVAppAsyncStatistic) == size) {
        AVAppAsyncStatistic *statistic =  (AVAppAsyncStatistic *) (intptr_t)data;
        ffp->stat.buf_backwards = statistic->buf_backwards;
        ffp->stat.buf_forwards = statistic->buf_forwards;
        ffp->stat.buf_capacity = statistic->buf_capacity;
    }
    return inject_callback(ffp->inject_opaque, message , data, size);
}

static int ijkio_app_func_event(IjkIOApplicationContext *h, int message ,void *data, size_t size)
{
    if (!h || !h->opaque || !data)
        return 0;

    FFPlayer *ffp = (FFPlayer *)h->opaque;
    if (!ffp->ijkio_inject_opaque)
        return 0;

    if (message == IJKIOAPP_EVENT_CACHE_STATISTIC && sizeof(IjkIOAppCacheStatistic) == size) {
        IjkIOAppCacheStatistic *statistic =  (IjkIOAppCacheStatistic *) (intptr_t)data;
        ffp->stat.cache_physical_pos      = statistic->cache_physical_pos;
        ffp->stat.cache_file_forwards     = statistic->cache_file_forwards;
        ffp->stat.cache_file_pos          = statistic->cache_file_pos;
        ffp->stat.cache_count_bytes       = statistic->cache_count_bytes;
        ffp->stat.logical_file_size       = statistic->logical_file_size;
    }

    return 0;
}

void ffp_set_frame_at_time(FFPlayer *ffp, const char *path, int64_t start_time, int64_t end_time, int num, int definition) {
    if (!ffp->get_img_info) {
        ffp->get_img_info = av_mallocz(sizeof(GetImgInfo));
        if (!ffp->get_img_info) {
            ffp_notify_msg3(ffp, FFP_MSG_GET_IMG_STATE, 0, -1);
            return;
        }
    }

    if (start_time >= 0 && num > 0 && end_time >= 0 && end_time >= start_time) {
        ffp->get_img_info->img_path   = av_strdup(path);
        ffp->get_img_info->start_time = start_time;
        ffp->get_img_info->end_time   = end_time;
        ffp->get_img_info->num        = num;
        ffp->get_img_info->count      = num;
        if (definition== HD_IMAGE) {
            ffp->get_img_info->width  = 640;
            ffp->get_img_info->height = 360;
        } else if (definition == SD_IMAGE) {
            ffp->get_img_info->width  = 320;
            ffp->get_img_info->height = 180;
        } else {
            ffp->get_img_info->width  = 160;
            ffp->get_img_info->height = 90;
        }
    } else {
        ffp->get_img_info->count = 0;
        ffp_notify_msg3(ffp, FFP_MSG_GET_IMG_STATE, 0, -1);
    }
}

void *ffp_set_ijkio_inject_opaque(FFPlayer *ffp, void *opaque)
{
    if (!ffp)
        return NULL;
    void *prev_weak_thiz = ffp->ijkio_inject_opaque;
    ffp->ijkio_inject_opaque = opaque;

    ijkio_manager_destroyp(&ffp->ijkio_manager_ctx);
    ijkio_manager_create(&ffp->ijkio_manager_ctx, ffp);
    ijkio_manager_set_callback(ffp->ijkio_manager_ctx, ijkio_app_func_event);
    ffp_set_option_int(ffp, FFP_OPT_CATEGORY_FORMAT, "ijkiomanager", (int64_t)(intptr_t)ffp->ijkio_manager_ctx);

    return prev_weak_thiz;
}

void *ffp_set_inject_opaque(FFPlayer *ffp, void *opaque)
{
    if (!ffp)
        return NULL;
    void *prev_weak_thiz = ffp->inject_opaque;
    ffp->inject_opaque = opaque;

    av_application_closep(&ffp->app_ctx);
    av_application_open(&ffp->app_ctx, ffp);
    ffp_set_option_int(ffp, FFP_OPT_CATEGORY_FORMAT, "ijkapplication", (int64_t)(intptr_t)ffp->app_ctx);

    ffp->app_ctx->func_on_app_event = app_func_event;
    return prev_weak_thiz;
}

void ffp_set_option(FFPlayer *ffp, int opt_category, const char *name, const char *value)
{
    if (!ffp)
        return;

    AVDictionary **dict = ffp_get_opt_dict(ffp, opt_category);
    av_dict_set(dict, name, value, 0);
    // av_opt_set(ffp, name, value, 0);
}

void ffp_set_option_int(FFPlayer *ffp, int opt_category, const char *name, int64_t value)
{
    if (!ffp)
        return;

    AVDictionary **dict = ffp_get_opt_dict(ffp, opt_category);
    av_dict_set_int(dict, name, value, 0);
    // av_opt_set_int(ffp, name, value, 0);
}

void ffp_set_overlay_format(FFPlayer *ffp, int chroma_fourcc)
{
    switch (chroma_fourcc) {
        case SDL_FCC__GLES2:
        case SDL_FCC_I420:
        case SDL_FCC_YV12:
        case SDL_FCC_RV16:
        case SDL_FCC_RV24:
        case SDL_FCC_RV32:
            ffp->overlay_format = chroma_fourcc;
            break;
#ifdef __APPLE__
        case SDL_FCC_I444P10LE:
            ffp->overlay_format = chroma_fourcc;
            break;
#endif
        default:
            av_log(ffp, AV_LOG_ERROR, "%s: unknown chroma fourcc: %d\n", __func__, chroma_fourcc);
            break;
    }
}

int ffp_get_video_codec_info(FFPlayer *ffp, char **codec_info)
{
    if (!codec_info)
        return -1;

    // FIXME: not thread-safe
    if (ffp->video_codec_info) {
        *codec_info = strdup(ffp->video_codec_info);
    } else {
        *codec_info = NULL;
    }
    return 0;
}

int ffp_get_audio_codec_info(FFPlayer *ffp, char **codec_info)
{
    if (!codec_info)
        return -1;

    // FIXME: not thread-safe
    if (ffp->audio_codec_info) {
        *codec_info = strdup(ffp->audio_codec_info);
    } else {
        *codec_info = NULL;
    }
    return 0;
}

static void ffp_show_dict(FFPlayer *ffp, const char *tag, AVDictionary *dict)
{
    AVDictionaryEntry *t = NULL;

    while ((t = av_dict_get(dict, "", t, AV_DICT_IGNORE_SUFFIX))) {
        av_log(ffp, AV_LOG_INFO, "%-*s: %-*s = %s\n", 12, tag, 28, t->key, t->value);
    }
}

#define FFP_VERSION_MODULE_NAME_LENGTH 13
static void ffp_show_version_str(FFPlayer *ffp, const char *module, const char *version)
{
    av_log(ffp, AV_LOG_INFO, "%-*s: %s\n", FFP_VERSION_MODULE_NAME_LENGTH, module, version);
}

static void ffp_show_version_int(FFPlayer *ffp, const char *module, unsigned version)
{
    av_log(ffp, AV_LOG_INFO, "%-*s: %u.%u.%u\n",
            FFP_VERSION_MODULE_NAME_LENGTH, module,
            (unsigned int)IJKVERSION_GET_MAJOR(version),
            (unsigned int)IJKVERSION_GET_MINOR(version),
            (unsigned int)IJKVERSION_GET_MICRO(version));
}

int ffp_prepare_async_l(FFPlayer *ffp, const char *file_name)
{
    assert(ffp);
    assert(!ffp->is);
    assert(file_name);

    if (av_stristart(file_name, "rtmp", NULL) ||
        av_stristart(file_name, "rtsp", NULL)) {
        // There is total different meaning for 'timeout' option in rtmp
        av_log(ffp, AV_LOG_WARNING, "remove 'timeout' option for rtmp.\n");
        av_dict_set(&ffp->format_opts, "timeout", NULL, 0);
    }

    /* there is a length limit in avformat */
    if (strlen(file_name) + 1 > 1024) {
        av_log(ffp, AV_LOG_ERROR, "%s too long url\n", __func__);
        if (avio_find_protocol_name("ijklongurl:")) {
            av_dict_set(&ffp->format_opts, "ijklongurl-url", file_name, 0);
            file_name = "ijklongurl:";
        }
    }

    av_log(NULL, AV_LOG_INFO, "===== versions =====\n");
    ffp_show_version_str(ffp, "ijkplayer",      ijk_version_info());
    ffp_show_version_str(ffp, "FFmpeg",         av_version_info());
    ffp_show_version_int(ffp, "libavutil",      avutil_version());
    ffp_show_version_int(ffp, "libavcodec",     avcodec_version());
    ffp_show_version_int(ffp, "libavformat",    avformat_version());
    ffp_show_version_int(ffp, "libswscale",     swscale_version());
    ffp_show_version_int(ffp, "libswresample",  swresample_version());
    av_log(NULL, AV_LOG_INFO, "===== options =====\n");
    ffp_show_dict(ffp, "player-opts", ffp->player_opts);
    ffp_show_dict(ffp, "format-opts", ffp->format_opts);
    ffp_show_dict(ffp, "codec-opts ", ffp->codec_opts);
    ffp_show_dict(ffp, "sws-opts   ", ffp->sws_dict);
    ffp_show_dict(ffp, "swr-opts   ", ffp->swr_opts);
    av_log(NULL, AV_LOG_INFO, "===================\n");

    av_opt_set_dict(ffp, &ffp->player_opts);
    if (!ffp->aout) {
        ffp->aout = ffpipeline_open_audio_output(ffp->pipeline, ffp);
        if (!ffp->aout)
            return -1;
    }

#if CONFIG_AVFILTER
    if (ffp->vfilter0) {
        GROW_ARRAY(ffp->vfilters_list, ffp->nb_vfilters);
        ffp->vfilters_list[ffp->nb_vfilters - 1] = ffp->vfilter0;
    }
#endif

    VideoState *is = ffplay_stream_open(ffp, file_name, NULL);
    if (!is) {
        av_log(NULL, AV_LOG_WARNING, "ffp_prepare_async_l: stream_open failed OOM");
        return EIJK_OUT_OF_MEMORY;
    }

    ffp->is = is;
    ffp->input_filename = av_strdup(file_name);
    return 0;
}

int ffp_start_from_l(FFPlayer *ffp, long msec)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (!is)
        return EIJK_NULL_IS_PTR;

    ffp->auto_resume = 1;
    ffp_toggle_buffering(ffp, 1);
    ffp_seek_to_l(ffp, msec);
    return 0;
}

int ffp_start_l(FFPlayer *ffp)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (!is)
        return EIJK_NULL_IS_PTR;

    ffplay_toggle_pause(ffp, 0);
    return 0;
}

int ffp_pause_l(FFPlayer *ffp)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (!is)
        return EIJK_NULL_IS_PTR;

    ffplay_toggle_pause(ffp, 1);
    return 0;
}

int ffp_is_paused_l(FFPlayer *ffp)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (!is)
        return 1;

    return is->paused;
}

int ffp_stop_l(FFPlayer *ffp)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (is) {
        is->abort_request = 1;
        ffplay_toggle_pause(ffp, 1);
    }

    if (ffp->enable_accurate_seek && is && is->accurate_seek_mutex
            && is->audio_accurate_seek_cond && is->video_accurate_seek_cond) {
        SDL_LockMutex(is->accurate_seek_mutex);
        is->audio_accurate_seek_req = 0;
        is->video_accurate_seek_req = 0;
        SDL_CondSignal(is->audio_accurate_seek_cond);
        SDL_CondSignal(is->video_accurate_seek_cond);
        SDL_UnlockMutex(is->accurate_seek_mutex);
    }
    return 0;
}

int ffp_wait_stop_l(FFPlayer *ffp)
{
    assert(ffp);

    if (ffp->is) {
        ffp_stop_l(ffp);
        ffplay_stream_close(ffp);
        ffp->is = NULL;
    }
    return 0;
}

/*
 * pixels must be alloced using av_alloc
 */
static void ffp_get_snap_shot(void *opaque, uint8_t* pixels, int width, int height)
{
    FFPlayer *ffp = opaque;
    ffp_notify_msg5(ffp, FFP_MSG_VIDEO_SNAP_SHOT, width, height, pixels,
            (size_t)width * height * 4, msg_obj_free_l);
}

void ffp_take_snapshot(FFPlayer *ffp)
{
    assert(ffp);
    int ret = SDL_Vout_TakeSnapShot(ffp->vout, ffp, ffp_get_snap_shot);
    if (ret < 0) {
        ffp_notify_msg2(ffp, FFP_MSG_ERROR, -FFP_MSG_VIDEO_SNAP_SHOT);
        ALOGE("ffp take snap_shot error: %d", ret);
    }
}

int ffp_seek_to_l(FFPlayer *ffp, long msec)
{
    assert(ffp);
    VideoState *is = ffp->is;
    int64_t start_time = 0;
    int64_t seek_pos = milliseconds_to_fftime(msec);
    int64_t duration = milliseconds_to_fftime(ffp_get_duration_l(ffp));

    if (!is)
        return EIJK_NULL_IS_PTR;

    if (duration > 0 && seek_pos >= duration && ffp->enable_accurate_seek) {
        ffplay_toggle_pause(ffp, 1);
        ffp_notify_msg1(ffp, FFP_MSG_COMPLETED);
        return 0;
    }

    start_time = is->ic->start_time;
    if (start_time > 0 && start_time != AV_NOPTS_VALUE)
        seek_pos += start_time;

    // FIXME: 9 seek by bytes
    // FIXME: 9 seek out of range
    // FIXME: 9 seekable
    av_log(ffp, AV_LOG_DEBUG, "stream_seek %"PRId64"(%d) + %"PRId64", \n", seek_pos, (int)msec, start_time);
    ffplay_stream_seek(ffp, seek_pos, 0, 0);
    return 0;
}

long ffp_get_current_position_l(FFPlayer *ffp)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (!is || !is->ic)
        return 0;

    int64_t start_time = is->ic->start_time;
    int64_t start_diff = 0;
    if (start_time > 0 && start_time != AV_NOPTS_VALUE)
        start_diff = fftime_to_milliseconds(start_time);

    int64_t pos = 0;
    double pos_clock = ffplay_get_master_clock(is);
    if (isnan(pos_clock)) {
        pos = fftime_to_milliseconds(is->seek_pos);
    } else {
        pos = pos_clock * 1000;
    }

    // If using REAL time and not ajusted, then return the real pos as calculated from the stream
    // the use case for this is primarily when using a custom non-seekable data source that starts
    // with a buffer that is NOT the start of the stream.  We want the get_current_position to
    // return the time in the stream, and not the player's internal clock.
    if (ffp->no_time_adjust) {
        return (long)pos;
    }

    if (pos < 0 || pos < start_diff)
        return 0;

    int64_t adjust_pos = pos - start_diff;
    return (long)adjust_pos;
}

long ffp_get_duration_l(FFPlayer *ffp)
{
    assert(ffp);
    VideoState *is = ffp->is;
    if (!is || !is->ic)
        return 0;

    int64_t duration = fftime_to_milliseconds(is->ic->duration);
    if (duration < 0)
        return 0;

    return (long)duration;
}

long ffp_get_playable_duration_l(FFPlayer *ffp)
{
    assert(ffp);
    if (!ffp)
        return 0;

    return (long)ffp->playable_duration_ms;
}

void ffp_set_loop(FFPlayer *ffp, int loop)
{
    assert(ffp);
    if (!ffp)
        return;
    ffp->loop = loop;
}

int ffp_get_loop(FFPlayer *ffp)
{
    assert(ffp);
    if (!ffp)
        return 1;
    return ffp->loop;
}

int ffp_packet_queue_init(PacketQueue *q)
{
    return ffplay_packet_queue_init(q);
}

void ffp_packet_queue_destroy(PacketQueue *q)
{
    ffplay_packet_queue_destroy(q);
}

void ffp_packet_queue_abort(PacketQueue *q)
{
    ffplay_packet_queue_abort(q);
}

void ffp_packet_queue_start(PacketQueue *q)
{
    ffplay_packet_queue_start(q);
}

void ffp_packet_queue_flush(PacketQueue *q)
{
    ffplay_packet_queue_flush(q);
}

int ffp_packet_queue_get(PacketQueue *q, AVPacket *pkt, int block, int *serial)
{
    return ffplay_packet_queue_get(q, pkt, block, serial);
}

int ffp_packet_queue_get_or_buffering(FFPlayer *ffp, PacketQueue *q, AVPacket *pkt, int *serial, int *finished)
{
    return ffplay_packet_queue_get_or_buffering(ffp, q, pkt, serial, finished);
}

int ffp_packet_queue_put(PacketQueue *q, AVPacket *pkt)
{
    return ffplay_packet_queue_put(q, pkt);
}

bool ffp_is_flush_packet(AVPacket *pkt)
{
    if (!pkt)
        return false;

    return pkt->data == ffplay_flush_pkt()->data;
}

Frame *ffp_frame_queue_peek_writable(FrameQueue *f)
{
    return ffplay_frame_queue_peek_writable(f);
}

void ffp_frame_queue_push(FrameQueue *f)
{
    ffplay_frame_queue_push(f);
}

int ffp_queue_picture(FFPlayer *ffp, AVFrame *src_frame, double pts, double duration, int64_t pos, int serial)
{
    return ffplay_queue_picture(ffp, src_frame, pts, duration, pos, serial);
}

int ffp_get_master_sync_type(VideoState *is)
{
    return ffplay_get_master_sync_type(is);
}

double ffp_get_master_clock(VideoState *is)
{
    return ffplay_get_master_clock(is);
}

void ffp_toggle_buffering_l(FFPlayer *ffp, int buffering_on)
{
    if (!ffp->packet_buffering)
        return;

    VideoState *is = ffp->is;
    if (buffering_on && !is->buffering_on) {
        av_log(ffp, AV_LOG_DEBUG, "ffp_toggle_buffering_l: start\n");
        is->buffering_on = 1;
        ffplay_stream_update_pause_l(ffp);
        if (is->seek_req) {
            is->seek_buffering = 1;
            ffp_notify_msg2(ffp, FFP_MSG_BUFFERING_START, 1);
        } else {
            ffp_notify_msg2(ffp, FFP_MSG_BUFFERING_START, 0);
        }
    } else if (!buffering_on && is->buffering_on){
        av_log(ffp, AV_LOG_DEBUG, "ffp_toggle_buffering_l: end\n");
        is->buffering_on = 0;
        ffplay_stream_update_pause_l(ffp);
        if (is->seek_buffering) {
            is->seek_buffering = 0;
            ffp_notify_msg2(ffp, FFP_MSG_BUFFERING_END, 1);
        } else {
            ffp_notify_msg2(ffp, FFP_MSG_BUFFERING_END, 0);
        }
    }
}

void ffp_toggle_buffering(FFPlayer *ffp, int start_buffering)
{
    SDL_LockMutex(ffp->is->play_mutex);
    ffp_toggle_buffering_l(ffp, start_buffering);
    SDL_UnlockMutex(ffp->is->play_mutex);
}

void ffp_track_statistic_l(FFPlayer *ffp, AVStream *st, PacketQueue *q, FFTrackCacheStatistic *cache)
{
    assert(cache);

    if (q) {
        cache->bytes   = q->size;
        cache->packets = q->nb_packets;
    }

    if (q && st && st->time_base.den > 0 && st->time_base.num > 0) {
        cache->duration = q->duration * av_q2d(st->time_base) * 1000;
    }
}

void ffp_audio_statistic_l(FFPlayer *ffp)
{
    VideoState *is = ffp->is;
    ffp_track_statistic_l(ffp, is->audio_st, &is->audioq, &ffp->stat.audio_cache);
}

void ffp_video_statistic_l(FFPlayer *ffp)
{
    VideoState *is = ffp->is;
    ffp_track_statistic_l(ffp, is->video_st, &is->videoq, &ffp->stat.video_cache);
}

void ffp_statistic_l(FFPlayer *ffp)
{
    ffp_audio_statistic_l(ffp);
    ffp_video_statistic_l(ffp);
}

void ffp_check_buffering_l(FFPlayer *ffp)
{
    VideoState *is            = ffp->is;
    int hwm_in_ms             = ffp->dcc.current_high_water_mark_in_ms; // use fast water mark for first loading
    int buf_size_percent      = -1;
    int buf_time_percent      = -1;
    int hwm_in_bytes          = ffp->dcc.high_water_mark_in_bytes;
    int need_start_buffering  = 0;
    int audio_time_base_valid = 0;
    int video_time_base_valid = 0;
    int64_t buf_time_position = -1;

    if(is->audio_st)
        audio_time_base_valid = is->audio_st->time_base.den > 0 && is->audio_st->time_base.num > 0;
    if(is->video_st)
        video_time_base_valid = is->video_st->time_base.den > 0 && is->video_st->time_base.num > 0;

    if (hwm_in_ms > 0) {
        int     cached_duration_in_ms = -1;
        int64_t audio_cached_duration = -1;
        int64_t video_cached_duration = -1;

        if (is->audio_st && audio_time_base_valid) {
            audio_cached_duration = ffp->stat.audio_cache.duration;
#ifdef FFP_SHOW_DEMUX_CACHE
            int audio_cached_percent = (int)av_rescale(audio_cached_duration, 1005, hwm_in_ms * 10);
            av_log(ffp, AV_LOG_DEBUG, "audio cache=%%%d milli:(%d/%d) bytes:(%d/%d) packet:(%d/%d)\n", audio_cached_percent,
                    (int)audio_cached_duration, hwm_in_ms,
                    is->audioq.size, hwm_in_bytes,
                    is->audioq.nb_packets, MIN_FRAMES);
#endif
        }

        if (is->video_st && video_time_base_valid) {
            video_cached_duration = ffp->stat.video_cache.duration;
#ifdef FFP_SHOW_DEMUX_CACHE
            int video_cached_percent = (int)av_rescale(video_cached_duration, 1005, hwm_in_ms * 10);
            av_log(ffp, AV_LOG_DEBUG, "video cache=%%%d milli:(%d/%d) bytes:(%d/%d) packet:(%d/%d)\n", video_cached_percent,
                    (int)video_cached_duration, hwm_in_ms,
                    is->videoq.size, hwm_in_bytes,
                    is->videoq.nb_packets, MIN_FRAMES);
#endif
        }

        if (video_cached_duration > 0 && audio_cached_duration > 0) {
            cached_duration_in_ms = (int)IJKMIN(video_cached_duration, audio_cached_duration);
        } else if (video_cached_duration > 0) {
            cached_duration_in_ms = (int)video_cached_duration;
        } else if (audio_cached_duration > 0) {
            cached_duration_in_ms = (int)audio_cached_duration;
        }

        if (cached_duration_in_ms >= 0) {
            buf_time_position = ffp_get_current_position_l(ffp) + cached_duration_in_ms;
            ffp->playable_duration_ms = buf_time_position;

            buf_time_percent = (int)av_rescale(cached_duration_in_ms, 1005, hwm_in_ms * 10);
#ifdef FFP_SHOW_DEMUX_CACHE
            av_log(ffp, AV_LOG_DEBUG, "time cache=%%%d (%d/%d)\n", buf_time_percent, cached_duration_in_ms, hwm_in_ms);
#endif
#ifdef FFP_NOTIFY_BUF_TIME
            ffp_notify_msg3(ffp, FFP_MSG_BUFFERING_TIME_UPDATE, cached_duration_in_ms, hwm_in_ms);
#endif
        }
    }

    int cached_size = is->audioq.size + is->videoq.size;
    if (hwm_in_bytes > 0) {
        buf_size_percent = (int)av_rescale(cached_size, 1005, hwm_in_bytes * 10);
#ifdef FFP_SHOW_DEMUX_CACHE
        av_log(ffp, AV_LOG_DEBUG, "size cache=%%%d (%d/%d)\n", buf_size_percent, cached_size, hwm_in_bytes);
#endif
#ifdef FFP_NOTIFY_BUF_BYTES
        ffp_notify_msg3(ffp, FFP_MSG_BUFFERING_BYTES_UPDATE, cached_size, hwm_in_bytes);
#endif
    }

    int buf_percent = -1;
    if (buf_time_percent >= 0) {
        // alwas depend on cache duration if valid
        if (buf_time_percent >= 100)
            need_start_buffering = 1;
        buf_percent = buf_time_percent;
    } else {
        if (buf_size_percent >= 100)
            need_start_buffering = 1;
        buf_percent = buf_size_percent;
    }

    if (buf_time_percent >= 0 && buf_size_percent >= 0) {
        buf_percent = FFMIN(buf_time_percent, buf_size_percent);
    }
    if (buf_percent) {
#ifdef FFP_SHOW_BUF_POS
        av_log(ffp, AV_LOG_DEBUG, "buf pos=%"PRId64", %%%d\n", buf_time_position, buf_percent);
#endif
        ffp_notify_msg3(ffp, FFP_MSG_BUFFERING_UPDATE, (int)buf_time_position, buf_percent);
    }

    if (need_start_buffering) {
        if (hwm_in_ms < ffp->dcc.next_high_water_mark_in_ms) {
            hwm_in_ms = ffp->dcc.next_high_water_mark_in_ms;
        } else {
            hwm_in_ms *= 2;
        }

        if (hwm_in_ms > ffp->dcc.last_high_water_mark_in_ms)
            hwm_in_ms = ffp->dcc.last_high_water_mark_in_ms;

        ffp->dcc.current_high_water_mark_in_ms = hwm_in_ms;

        if (is->buffer_indicator_queue && is->buffer_indicator_queue->nb_packets > 0) {
            if (   (is->audioq.nb_packets >= MIN_MIN_FRAMES || is->audio_stream < 0 || is->audioq.abort_request)
                    && (is->videoq.nb_packets >= MIN_MIN_FRAMES || is->video_stream < 0 || is->videoq.abort_request)) {
                if (buf_percent < 100)
                    ffp_notify_msg3(ffp, FFP_MSG_BUFFERING_UPDATE, (int)buf_time_position, 100);
                ffp_toggle_buffering(ffp, 0);
            }
        }
    }
}

int ffp_video_thread(FFPlayer *ffp)
{
    return ffplay_video_thread(ffp);
}

void ffp_set_video_codec_info(FFPlayer *ffp, const char *module, const char *codec)
{
    av_freep(&ffp->video_codec_info);
    ffp->video_codec_info = av_asprintf("%s, %s", module ? module : "", codec ? codec : "");
    av_log(ffp, AV_LOG_INFO, "VideoCodec: %s\n", ffp->video_codec_info);
}

void ffp_set_audio_codec_info(FFPlayer *ffp, const char *module, const char *codec)
{
    av_freep(&ffp->audio_codec_info);
    ffp->audio_codec_info = av_asprintf("%s, %s", module ? module : "", codec ? codec : "");
    av_log(ffp, AV_LOG_INFO, "AudioCodec: %s\n", ffp->audio_codec_info);
}

void ffp_set_subtitle_codec_info(FFPlayer *ffp, const char *module, const char *codec)
{
    av_freep(&ffp->subtitle_codec_info);
    ffp->subtitle_codec_info = av_asprintf("%s, %s", module ? module : "", codec ? codec : "");
    av_log(ffp, AV_LOG_INFO, "SubtitleCodec: %s\n", ffp->subtitle_codec_info);
}

void ffp_set_playback_rate(FFPlayer *ffp, float rate)
{
    if (!ffp)
        return;

    av_log(ffp, AV_LOG_INFO, "Playback rate: %f\n", rate);
    ffp->pf_playback_rate = rate;
    ffp->pf_playback_rate_changed = 1;
}

void ffp_set_playback_volume(FFPlayer *ffp, float volume)
{
    if (!ffp)
        return;
    ffp->pf_playback_volume = volume;
    ffp->pf_playback_volume_changed = 1;
}

int ffp_get_video_rotate_degrees(FFPlayer *ffp)
{
    VideoState *is = ffp->is;
    if (!is)
        return 0;

    int theta  = abs((int)((int64_t)round(fabs(get_rotation(is->video_st))) % 360));
    switch (theta) {
        case 0:
        case 90:
        case 180:
        case 270:
            break;
        case 360:
            theta = 0;
            break;
        default:
            ALOGW("Unknown rotate degress: %d\n", theta);
            theta = 0;
            break;
    }

    return theta;
}

int ffp_set_stream_selected(FFPlayer *ffp, int stream, int selected)
{
    VideoState        *is = ffp->is;
    AVFormatContext   *ic = NULL;
    AVCodecParameters *codecpar = NULL;
    if (!is)
        return -1;
    ic = is->ic;
    if (!ic)
        return -1;

    if (stream < 0 || stream >= ic->nb_streams) {
        av_log(ffp, AV_LOG_ERROR, "invalid stream index %d >= stream number (%d)\n", stream, ic->nb_streams);
        return -1;
    }

    codecpar = ic->streams[stream]->codecpar;

    if (selected) {
        switch (codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:
                if (stream != is->video_stream && is->video_stream >= 0)
                    ffplay_stream_component_close(ffp, is->video_stream);
                break;
            case AVMEDIA_TYPE_AUDIO:
                if (stream != is->audio_stream && is->audio_stream >= 0)
                    ffplay_stream_component_close(ffp, is->audio_stream);
                break;
            case AVMEDIA_TYPE_SUBTITLE:
                if (stream != is->subtitle_stream && is->subtitle_stream >= 0)
                    ffplay_stream_component_close(ffp, is->subtitle_stream);
                break;
            default:
                av_log(ffp, AV_LOG_ERROR, "select invalid stream %d of video type %d\n", stream, codecpar->codec_type);
                return -1;
        }
        return ffplay_stream_component_open(ffp, stream);
    } else {
        switch (codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:
                if (stream == is->video_stream)
                    ffplay_stream_component_close(ffp, is->video_stream);
                break;
            case AVMEDIA_TYPE_AUDIO:
                if (stream == is->audio_stream)
                    ffplay_stream_component_close(ffp, is->audio_stream);
                break;
            case AVMEDIA_TYPE_SUBTITLE:
                if (stream == is->subtitle_stream)
                    ffplay_stream_component_close(ffp, is->subtitle_stream);
                break;
            default:
                av_log(ffp, AV_LOG_ERROR, "select invalid stream %d of audio type %d\n", stream, codecpar->codec_type);
                return -1;
        }
        return 0;
    }
}

float ffp_get_property_float(FFPlayer *ffp, int id, float default_value)
{
    switch (id) {
        case FFP_PROP_FLOAT_VIDEO_DECODE_FRAMES_PER_SECOND:
            return ffp ? ffp->stat.vdps : default_value;
        case FFP_PROP_FLOAT_VIDEO_OUTPUT_FRAMES_PER_SECOND:
            return ffp ? ffp->stat.vfps : default_value;
        case FFP_PROP_FLOAT_PLAYBACK_RATE:
            return ffp ? ffp->pf_playback_rate : default_value;
        case FFP_PROP_FLOAT_AVDELAY:
            return ffp ? ffp->stat.avdelay : default_value;
        case FFP_PROP_FLOAT_AVDIFF:
            return ffp ? ffp->stat.avdiff : default_value;
        case FFP_PROP_FLOAT_PLAYBACK_VOLUME:
            return ffp ? ffp->pf_playback_volume : default_value;
        case FFP_PROP_FLOAT_DROP_FRAME_RATE:
            return ffp ? ffp->stat.drop_frame_rate : default_value;
        default:
            return default_value;
    }
}

void ffp_set_property_float(FFPlayer *ffp, int id, float value)
{
    switch (id) {
        case FFP_PROP_FLOAT_PLAYBACK_RATE:
            ffp_set_playback_rate(ffp, value);
            break;
        case FFP_PROP_FLOAT_PLAYBACK_VOLUME:
            ffp_set_playback_volume(ffp, value);
            break;
        default:
            return;
    }
}

int64_t ffp_get_property_int64(FFPlayer *ffp, int id, int64_t default_value)
{
    switch (id) {
        case FFP_PROP_INT64_SELECTED_VIDEO_STREAM:
            if (!ffp || !ffp->is)
                return default_value;
            return ffp->is->video_stream;
        case FFP_PROP_INT64_SELECTED_AUDIO_STREAM:
            if (!ffp || !ffp->is)
                return default_value;
            return ffp->is->audio_stream;
        case FFP_PROP_INT64_SELECTED_TIMEDTEXT_STREAM:
            if (!ffp || !ffp->is)
                return default_value;
            return ffp->is->subtitle_stream;
        case FFP_PROP_INT64_VIDEO_DECODER:
            if (!ffp)
                return default_value;
            return ffp->stat.vdec_type;
        case FFP_PROP_INT64_AUDIO_DECODER:
            return FFP_PROPV_DECODER_AVCODEC;

        case FFP_PROP_INT64_VIDEO_CACHED_DURATION:
            if (!ffp)
                return default_value;
            return ffp->stat.video_cache.duration;
        case FFP_PROP_INT64_AUDIO_CACHED_DURATION:
            if (!ffp)
                return default_value;
            return ffp->stat.audio_cache.duration;
        case FFP_PROP_INT64_VIDEO_CACHED_BYTES:
            if (!ffp)
                return default_value;
            return ffp->stat.video_cache.bytes;
        case FFP_PROP_INT64_AUDIO_CACHED_BYTES:
            if (!ffp)
                return default_value;
            return ffp->stat.audio_cache.bytes;
        case FFP_PROP_INT64_VIDEO_CACHED_PACKETS:
            if (!ffp)
                return default_value;
            return ffp->stat.video_cache.packets;
        case FFP_PROP_INT64_AUDIO_CACHED_PACKETS:
            if (!ffp)
                return default_value;
            return ffp->stat.audio_cache.packets;
        case FFP_PROP_INT64_BIT_RATE:
            return ffp ? ffp->stat.bit_rate : default_value;
        case FFP_PROP_INT64_TCP_SPEED:
            return ffp ? SDL_SpeedSampler2GetSpeed(&ffp->stat.tcp_read_sampler) : default_value;
        case FFP_PROP_INT64_ASYNC_STATISTIC_BUF_BACKWARDS:
            if (!ffp)
                return default_value;
            return ffp->stat.buf_backwards;
        case FFP_PROP_INT64_ASYNC_STATISTIC_BUF_FORWARDS:
            if (!ffp)
                return default_value;
            return ffp->stat.buf_forwards;
        case FFP_PROP_INT64_ASYNC_STATISTIC_BUF_CAPACITY:
            if (!ffp)
                return default_value;
            return ffp->stat.buf_capacity;
        case FFP_PROP_INT64_LATEST_SEEK_LOAD_DURATION:
            return ffp ? ffp->stat.latest_seek_load_duration : default_value;
        case FFP_PROP_INT64_TRAFFIC_STATISTIC_BYTE_COUNT:
            return ffp ? ffp->stat.byte_count : default_value;
        case FFP_PROP_INT64_CACHE_STATISTIC_PHYSICAL_POS:
            if (!ffp)
                return default_value;
            return ffp->stat.cache_physical_pos;
        case FFP_PROP_INT64_CACHE_STATISTIC_FILE_FORWARDS:
            if (!ffp)
                return default_value;
            return ffp->stat.cache_file_forwards;
        case FFP_PROP_INT64_CACHE_STATISTIC_FILE_POS:
            if (!ffp)
                return default_value;
            return ffp->stat.cache_file_pos;
        case FFP_PROP_INT64_CACHE_STATISTIC_COUNT_BYTES:
            if (!ffp)
                return default_value;
            return ffp->stat.cache_count_bytes;
        case FFP_PROP_INT64_LOGICAL_FILE_SIZE:
            if (!ffp)
                return default_value;
            return ffp->stat.logical_file_size;
        case FFP_PROP_INT64_AMC_GLES_OES_VOUT:
            if (!ffp)
                return default_value;
            return ffp->vout_type & SDL_VOUT_AMC_OES_EGL;
        default:
            return default_value;
    }
}

void ffp_set_property_int64(FFPlayer *ffp, int id, int64_t value)
{
    switch (id) {
        // case FFP_PROP_INT64_SELECTED_VIDEO_STREAM:
        // case FFP_PROP_INT64_SELECTED_AUDIO_STREAM:
        case FFP_PROP_INT64_SHARE_CACHE_DATA:
            if (ffp) {
                if (value) {
                    ijkio_manager_will_share_cache_map(ffp->ijkio_manager_ctx);
                } else {
                    ijkio_manager_did_share_cache_map(ffp->ijkio_manager_ctx);
                }
            }
            break;
        case FFP_PROP_INT64_IMMEDIATE_RECONNECT:
            if (ffp) {
                ijkio_manager_immediate_reconnect(ffp->ijkio_manager_ctx);
            }
            break;
        case FFP_PROP_INT64_AMC_GLES_OES_VOUT:
            if (ffp && value) {
                ffp->vout_type |= SDL_VOUT_AMC_OES_EGL;
            }
            break;
        default:
            break;
    }
}

//开始录制函数:file_name是保存路径
int ffp_start_record(FFPlayer *ffp, const char *file_name)
{
    assert(ffp);

    VideoState *is = ffp->is;
    avcodec_register_all();
    ffp->m_ofmt_ctx = NULL;
    ffp->m_ofmt = NULL;
    ffp->is_record = 0;
    ffp->record_error = 0;

    if (!file_name || !strlen(file_name)) { // 没有路径
        av_log(ffp, AV_LOG_ERROR, "filename is invalid\n");
        goto end;
    }

    if (!is || !is->ic|| is->paused || is->abort_request) { // 没有上下文，或者上下文已经停止
        av_log(ffp, AV_LOG_ERROR, "is,is->ic,is->paused is invalid\n");
        goto end;
    }

    if (ffp->is_record) { // 已经在录制
        av_log(ffp, AV_LOG_ERROR, "recording has started\n");
        goto end;
    }

    AVOutputFormat *oformat = av_guess_format(NULL, file_name, NULL);
    // 初始化一个用于输出的AVFormatContext结构体
    avformat_alloc_output_context2(&ffp->m_ofmt_ctx, oformat, NULL, file_name);
    av_log(NULL, AV_LOG_INFO, "===== 初始化一个用于输出的AVFormatContext结构体 =====\n");
    if (!ffp->m_ofmt_ctx) {
        av_log(ffp, AV_LOG_ERROR, "Could not create output context filename is %s\n", file_name);
        goto end;
    }
    ffp->m_ofmt = ffp->m_ofmt_ctx->oformat;

    for (int i = 0; i < is->ic->nb_streams; i++) {
        // 对照输入流创建输出流通道
        AVStream *out_stream;
        AVStream *in_stream = is->ic->streams[i];
        AVCodecParameters *in_codecpar = in_stream->codecpar;
        if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
                in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
                in_codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            continue;
        }

        out_stream = avformat_new_stream(ffp->m_ofmt_ctx, NULL);

        if (!out_stream) {
            av_log(ffp, AV_LOG_ERROR, "Failed allocating output stream\n");
            goto end;
        }

        // 将输入视频/音频的参数拷贝至输出视频/音频的AVCodecContext结构体
        av_log(NULL, AV_LOG_INFO, "===== 将输入视频/音频的参数拷贝至输出视频/音频的AVCodecContext结构体 =====\n");
        if (avcodec_parameters_copy(out_stream->codecpar, in_codecpar) < 0) {
            av_log(ffp, AV_LOG_ERROR, "Failed to copy codec parameters\n");
            av_log(NULL, AV_LOG_INFO, "===== 将输入视频/音频的参数拷贝至输出视频/音频的AVCodecContext结构体，拷贝失败 =====\n");
            goto end;
        }
        out_stream->codecpar->codec_tag = 0;
        //视频流中经常缺少重要参数，会导致写文件头失败，特此在这里处理
        if(out_stream->codecpar->width<=0){
            out_stream->codecpar->width=1920;
        }
        if(out_stream->codecpar->height<=0){
            out_stream->codecpar->height=1080;
        }
        if (!out_stream->codecpar->block_align)
            out_stream->codecpar->block_align = out_stream->codecpar->channels *
                av_get_bits_per_sample(out_stream->codecpar->codec_id) >> 3;
        if(out_stream->codecpar->sample_rate<=0)
            out_stream->codecpar->sample_rate = 44100;
        int ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Failed to copy context from input to output stream codec context, error:%d", ret);
            goto end;
        }
        // TODO:
        if (ffp->m_ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
            //out_stream->codecpar->codec_type = AVMEDIA_TYPE_VIDEO;
        }
    }

    av_dump_format(ffp->m_ofmt_ctx, 0, file_name, 1);

    // 打开输出文件
    if (!(ffp->m_ofmt->flags & AVFMT_NOFILE)) {
        if (avio_open(&ffp->m_ofmt_ctx->pb, file_name, AVIO_FLAG_WRITE) < 0) {
            av_log(ffp, AV_LOG_ERROR, "Could not open output file '%s'", file_name);
            goto end;
        }
    }

    // 写视频文件头
    av_log(NULL, AV_LOG_INFO, "===== 写视频文件头 =====\n");
    int state = avformat_write_header(ffp->m_ofmt_ctx, NULL);
    av_log(NULL, AV_LOG_INFO, "===== 写视频文件头 =====返回值:%d\n",state);
    if (state < 0) {
        av_log(NULL, AV_LOG_INFO, "===== 写视频文件头失败 =====\n");
        av_log(ffp, AV_LOG_ERROR, "Error occurred when opening output file\n");
        goto end;
    }
    ffp->is_first = 0;
    ffp->is_record = 1;
    ffp->record_error = 0;
    av_log(NULL, AV_LOG_INFO, "===== 文件录制开启成功 =====\n");
    pthread_mutex_init(&ffp->record_mutex, NULL);

    return 0;
end:
    ffp->record_error = 1;
    return -1;
}

//停止录播
int ffp_stop_record(FFPlayer *ffp)
{
    pthread_mutex_lock(&ffp->record_mutex);
    assert(ffp);
    av_log(NULL, AV_LOG_INFO, "===== 文件录制结束流程 =====\n");
    if (ffp->is_record) {
        ffp->is_record = 0;

        if (ffp->m_ofmt_ctx != NULL) {
            av_log(NULL, AV_LOG_INFO, "===== 开始写文件尾部 =====\n");
            int errorCode = av_write_trailer(ffp->m_ofmt_ctx);
            av_log(NULL, AV_LOG_INFO, "===== 写文件尾部返回：%d =====\n",errorCode);
            if (ffp->m_ofmt_ctx && !(ffp->m_ofmt->flags & AVFMT_NOFILE)) {
                av_log(NULL, AV_LOG_INFO, "===== 开始关闭文件 =====\n");
                avio_closep(&ffp->m_ofmt_ctx->pb);
                avio_close(ffp->m_ofmt_ctx->pb);
            }
            avformat_free_context(ffp->m_ofmt_ctx);
            ffp->m_ofmt_ctx = NULL;
            ffp->is_first = 0;
            av_log(NULL, AV_LOG_INFO, "===== 文件录制结束成功 =====\n");
        }

        av_log(ffp, AV_LOG_DEBUG, "stopRecord ok\n");
    } else {
        av_log(ffp, AV_LOG_ERROR, "don't need stopRecord\n");
    }
    pthread_mutex_unlock(&ffp->record_mutex);
    pthread_mutex_destroy(&ffp->record_mutex);
    return 0;
}


//保存文件
int ffp_record_file(FFPlayer *ffp, AVPacket *packet)
{
    pthread_mutex_lock(&ffp->record_mutex);
    assert(ffp);
    VideoState *is = ffp->is;
    int ret = 0;
    AVStream *in_stream;
    AVStream *out_stream;

    if (ffp->is_record) {
        if (packet == NULL) {
            ffp->record_error = 1;
            av_log(ffp, AV_LOG_ERROR, "packet == NULL");
            pthread_mutex_unlock(&ffp->record_mutex);
            return -1;
        }

        AVPacket *pkt = (AVPacket *)av_malloc(sizeof(AVPacket)); // 与看直播的 AVPacket分开，不然卡屏
        av_new_packet(pkt, 0);
        //av_packet_alloc();
        //av_packet_from_data(pkt,packet->data,packet->size);
        if(packet!=NULL && packet->size>0 && packet->data!=NULL){
            if (0 == av_packet_ref(pkt, packet)) {
                av_log(ffp, AV_LOG_INFO, "ffp->start_pts:%"PRId64"",ffp->start_pts);
                av_log(ffp, AV_LOG_INFO, "ffp->start_dts:%"PRId64"",ffp->start_dts);

                av_log(ffp, AV_LOG_INFO, "ffp->is_first:%d",ffp->is_first);
                if (!ffp->is_first) { // 录制的第一帧，时间从0开始
                    if(pkt->flags==AV_PKT_FLAG_KEY){
                        //取到I帧开始写录制数据
                        ffp->is_first = 1;
                        ffp->start_pts = pkt->pts;
                        ffp->start_dts = pkt->dts;
                        pkt->pts = 0;
                        pkt->dts = 0;
                    }else{
                        ffp->is_first = 0;
                        ffp->start_pts = pkt->pts;
                        ffp->start_dts = pkt->dts;
                        pkt->pts = 0;
                        pkt->dts = 0;
                        av_packet_unref(pkt);
                        pthread_mutex_unlock(&ffp->record_mutex);
                        return 0;
                    }

                } else { // 之后的每一帧都要减去，点击开始录制时的值，这样的时间才是正确的
                    pkt->pts = llabs(pkt->pts - ffp->start_pts);
                    pkt->dts = llabs(pkt->dts - ffp->start_dts);
                }

                if(pkt->pts<pkt->dts)
                    pkt->dts = pkt->pts;
                if(pkt->dts<pkt->pts)
                    pkt->pts = pkt->dts;
                in_stream  = is->ic->streams[pkt->stream_index];
                out_stream = ffp->m_ofmt_ctx->streams[pkt->stream_index];

                // 转换PTS/DTS
                pkt->pts = av_rescale_q_rnd(pkt->pts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
                pkt->dts = av_rescale_q_rnd(pkt->dts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
                pkt->duration = av_rescale_q(pkt->duration, in_stream->time_base, out_stream->time_base);

                pkt->pos = -1;


                av_log(ffp, AV_LOG_INFO, "inner pkt->pts:%"PRId64"\n",pkt->pts);
                av_log(ffp, AV_LOG_INFO, "inner pkt->dts:%"PRId64"\n",pkt->dts);
                av_log(ffp, AV_LOG_INFO, "inner pkt->duration:%"PRId64"\n",pkt->duration);


                av_log(ffp, AV_LOG_INFO, "av_interleaved_write_frame\n");
                // 写入一个AVPacket到输出文件
                if ((ret = av_interleaved_write_frame(ffp->m_ofmt_ctx, pkt)) < 0) {
                    av_log(ffp, AV_LOG_ERROR, "Error muxing packet\n");
                }
                av_packet_unref(pkt);
                pthread_mutex_unlock(&ffp->record_mutex);
            } else {
                av_log(ffp, AV_LOG_ERROR, "av_packet_ref == NULL");
            }
        }

    }
    pthread_mutex_unlock(&ffp->record_mutex);
    return ret;
}

IjkMediaMeta *ffp_get_meta_l(FFPlayer *ffp)
{
    if (!ffp)
        return NULL;

    return ffp->meta;
}

