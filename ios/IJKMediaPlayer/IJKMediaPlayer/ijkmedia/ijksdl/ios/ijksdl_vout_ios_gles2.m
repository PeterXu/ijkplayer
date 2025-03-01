/*
 * ijksdl_vout_ios_gles2.c
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

#import "ijksdl_vout_ios_gles2.h"

#include <assert.h>
#include "ijksdl/ijksdl_vout.h"
#include "ijksdl/ijksdl_vout_internal.h"
#include "ijksdl/ffmpeg/ijksdl_vout_overlay_ffmpeg.h"
#include "ijksdl_vout_overlay_videotoolbox.h"
#import "IJKSDLGLView.h"
#import "IJKSDLFboGLView.h"

typedef struct SDL_VoutSurface_Opaque {
    SDL_Vout *vout;
} SDL_VoutSurface_Opaque;

struct SDL_Vout_Opaque {
    id<IJKSDLGLViewProtocol> gl_viewp;
#if TARGET_OS_IPHONE
    IJKSDLGLView *gl_view;
    IJKSDLFboGLView *fbo_viewl;
#endif
    BOOL response_display_pixels;
    BOOL third_part;
    int no_glview_warning;
};

static SDL_VoutOverlay *vout_create_overlay_l(int width, int height, int frame_format, SDL_Vout *vout)
{
    switch (frame_format) {
        case IJK_AV_PIX_FMT__VIDEO_TOOLBOX:
            return SDL_VoutVideoToolBox_CreateOverlay(width, height, vout);
        default:
            return SDL_VoutFFmpeg_CreateOverlay(width, height, frame_format, vout);
    }
}

static SDL_VoutOverlay *vout_create_overlay(int width, int height, int frame_format, SDL_Vout *vout)
{
    SDL_LockMutex(vout->mutex);
    SDL_VoutOverlay *overlay = vout_create_overlay_l(width, height, frame_format, vout);
    SDL_UnlockMutex(vout->mutex);
    return overlay;
}

static void vout_free_l(SDL_Vout *vout)
{
    if (!vout)
        return;

    SDL_Vout_Opaque *opaque = vout->opaque;
    if (opaque) {
        if (opaque->gl_viewp) {
            // TODO: post to MainThread?
            [opaque->gl_viewp release];
            opaque->gl_viewp = nil;
        }
#if TARGET_OS_IPHONE
        opaque->gl_view = nil;
#endif
    }

    SDL_Vout_FreeInternal(vout);
}

static int vout_display_overlay_l(SDL_Vout *vout, SDL_VoutOverlay *overlay)
{
    SDL_Vout_Opaque *opaque = vout->opaque;
    id<IJKSDLGLViewProtocol> gl_viewp = opaque->gl_viewp;

    if (!gl_viewp) {
        if (opaque->no_glview_warning < 10) {
            opaque->no_glview_warning ++;
            ALOGE("vout_display_overlay_l: NULL gl_view\n");
        }
        return -1;
    }

    if (!overlay) {
        ALOGE("vout_display_overlay_l: NULL overlay\n");
        return -1;
    }

    if (overlay->w <= 0 || overlay->h <= 0) {
        ALOGE("vout_display_overlay_l: invalid overlay dimensions(%d, %d)\n", overlay->w, overlay->h);
        return -1;
    }

    if (opaque->third_part) {
        IJKOverlay ijk_overlay;
        memset(&ijk_overlay, 0, sizeof(IJKOverlay));
        ijk_overlay.w = overlay->w;
        ijk_overlay.h = overlay->h;
        ijk_overlay.format = overlay->format;
        ijk_overlay.planes = overlay->planes;
        ijk_overlay.pitches = overlay->pitches;
        ijk_overlay.pixels = overlay->pixels;
        ijk_overlay.sar_num = overlay->sar_num;
        ijk_overlay.sar_den = overlay->sar_den;
#ifdef __APPLE__
        if (ijk_overlay.format == SDL_FCC__VTB) {
            ijk_overlay.pixel_buffer = SDL_VoutOverlayVideoToolBox_GetCVPixelBufferRef(overlay);
        }
#endif
        if (opaque->response_display_pixels) {
             [gl_viewp display_pixels:&ijk_overlay];
        }
    }
#if TARGET_OS_IPHONE
    if (!opaque->third_part) {
        if (opaque->gl_view){
            [opaque->gl_view display:overlay];
        } else if (opaque->fbo_viewl) {
            [opaque->fbo_viewl display:overlay];
        }
    }
#endif
    return 0;
}

static int vout_display_overlay(SDL_Vout *vout, SDL_VoutOverlay *overlay)
{
    @autoreleasepool {
        SDL_LockMutex(vout->mutex);
        int retval = vout_display_overlay_l(vout, overlay);
        SDL_UnlockMutex(vout->mutex);
        return retval;
    }
}

SDL_Vout *SDL_VoutIos_CreateForGLES2()
{
    SDL_Vout *vout = SDL_Vout_CreateInternal(sizeof(SDL_Vout_Opaque));
    if (!vout)
        return NULL;

    SDL_Vout_Opaque *opaque = vout->opaque;
    opaque->gl_viewp = nil;
    opaque->third_part = NO;
    opaque->response_display_pixels = NO;
    opaque->no_glview_warning = 0;

    vout->create_overlay = vout_create_overlay;
    vout->free_l = vout_free_l;
    vout->display_overlay = vout_display_overlay;

    return vout;
}

static void SDL_VoutIos_SetGLView_l(SDL_Vout *vout, id<IJKSDLGLViewProtocol> view)
{
    SDL_Vout_Opaque *opaque = vout->opaque;

    if (opaque->gl_viewp == view)
        return;

    if (opaque->gl_viewp) {
        [opaque->gl_viewp release];
        opaque->gl_viewp = nil;
    }
    opaque->no_glview_warning = 0;
    if (view) {
        opaque->gl_viewp = [view retain];
        opaque->third_part = view.isThirdGLView;
        if ([opaque->gl_viewp respondsToSelector:@selector(display_pixels:)])
            opaque->response_display_pixels = YES;
#if TARGET_OS_IPHONE
        if ([opaque->gl_viewp isKindOfClass:[IJKSDLGLView class] ]){
            opaque->gl_view = (IJKSDLGLView *)opaque->gl_viewp;
        } else if ([opaque->gl_viewp isKindOfClass:[IJKSDLFboGLView class] ]) {
            opaque->fbo_viewl = (IJKSDLFboGLView *)opaque->gl_viewp;
        }
#endif
    }
}

void SDL_VoutIos_SetGLView(SDL_Vout *vout, id<IJKSDLGLViewProtocol> view)
{
    SDL_LockMutex(vout->mutex);
    SDL_VoutIos_SetGLView_l(vout, view);
    SDL_UnlockMutex(vout->mutex);
}
