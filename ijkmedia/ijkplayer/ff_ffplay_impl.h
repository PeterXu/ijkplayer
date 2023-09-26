//
//  Header.h
//  IJKMediaPlayer
//
//  Created by Peter on 2023/9/13.
//  Copyright © 2023 bilibili. All rights reserved.
//

#ifndef FFPLAY__FF_FFPLAY_IMPL_H
#define FFPLAY__FF_FFPLAY_IMPL_H

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

#include "ff_ffinc.h"

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

VideoState *ffplay_stream_open(FFPlayer *ffp, const char *filename, AVInputFormat *iformat);
void ffplay_stream_close(FFPlayer *ffp);
void ffplay_stream_seek(FFPlayer *ffp, int64_t pos, int64_t rel, int seek_by_bytes);
void ffplay_toggle_pause(FFPlayer *ffp, int pause_on);
void ffplay_stream_update_pause_l(FFPlayer *ffp);
int ffplay_stream_component_open(FFPlayer *ffp, int stream_index);
void ffplay_stream_component_close(FFPlayer *ffp, int stream_index);


#endif /* FFPLAY__FF_FFPLAY_IMPL_H */
