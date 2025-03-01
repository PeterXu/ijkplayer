/*
 * IJKSDLGLView.h
 *
 * Copyright (c) 2013 Bilibili
 * Copyright (c) 2013 Zhang Rui <bbcallen@gmail.com>
 *
 * based on https://github.com/kolyvan/kxmovie
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

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "IJKSDLGLViewProtocol.h"

#include "ijksdl/ijksdl_vout.h"

typedef NS_ENUM(NSInteger, IJKSDLGLViewApplicationState) {
    IJKSDLGLViewApplicationUnknownState = 0,
    IJKSDLGLViewApplicationForegroundState = 1,
    IJKSDLGLViewApplicationBackgroundState = 2
};

#if TARGET_OS_IPHONE
@interface IJKSDLGLView : UIView <IJKSDLGLViewProtocol>
#else
@interface IJKSDLGLView : NSView <IJKSDLGLViewProtocol>
#endif

- (id) initWithFrame:(CGRect)frame;
- (void) display: (SDL_VoutOverlay *) overlay;

#if TARGET_OS_IPHONE
- (UIImage*) snapshot;
#else
- (NSImage*) snapshot;
#endif

- (void)setShouldLockWhileBeingMovedToWindow:(BOOL)shouldLockWhiteBeingMovedToWindow __attribute__((deprecated("unused")));

@end
