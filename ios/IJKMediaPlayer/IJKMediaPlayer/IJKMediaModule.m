/*
 * IJKMediaModule.m
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

#import "IJKMediaModule.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@implementation IJKMediaModule

@synthesize appIdleTimerDisabled         = _appIdleTimerDisabled;
@synthesize mediaModuleIdleTimerDisabled = _mediaModuleIdleTimerDisabled;

+ (IJKMediaModule *)sharedModule
{
    static IJKMediaModule *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[IJKMediaModule alloc] init];
    });
    return obj;
}

- (void)setAppIdleTimerDisabled:(BOOL) idleTimerDisabled
{
    _appIdleTimerDisabled = idleTimerDisabled;
    [self updateIdleTimer];
}

- (BOOL)isAppIdleTimerDisabled
{
    return _appIdleTimerDisabled;
}

- (void)setMediaModuleIdleTimerDisabled:(BOOL) idleTimerDisabled
{
    _mediaModuleIdleTimerDisabled = idleTimerDisabled;
    [self updateIdleTimer];
}

- (BOOL)isMediaModuleIdleTimerDisabled
{
    return _mediaModuleIdleTimerDisabled;
}

- (void)updateIdleTimer
{
#if TARGET_OS_IPHONE
    if (self.appIdleTimerDisabled || self.mediaModuleIdleTimerDisabled) {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
#endif
}

@end
