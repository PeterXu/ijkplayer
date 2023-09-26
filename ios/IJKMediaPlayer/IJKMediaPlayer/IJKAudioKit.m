/*
 * IJKAudioKit.m
 *
 * Copyright (c) 2013-2014 Bilibili
 * Copyright (c) 2013-2014 Zhang Rui <bbcallen@gmail.com>
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

#import "IJKAudioKit.h"

@implementation IJKAudioKit {
    BOOL _audioSessionInitialized;
}

+ (IJKAudioKit *)sharedInstance
{
    static IJKAudioKit *sAudioKit = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sAudioKit = [[IJKAudioKit alloc] init];
    });
    return sAudioKit;
}

- (void)setupAudioSession
{
#if TARGET_OS_IPHONE
    if (!_audioSessionInitialized) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: [AVAudioSession sharedInstance]];
        _audioSessionInitialized = YES;
    }
    [self setupAudioSessionWithoutInterruptHandler];
#endif
}

- (void)setupAudioSessionWithoutInterruptHandler
{
#if TARGET_OS_IPHONE
    /* Set audio session to mediaplayback */
    NSError *error = nil;
    if (NO == [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error]) {
        NSLog(@"IJKAudioKit: AVAudioSession.setCategory() failed: %@\n", error ? [error localizedDescription] : @"nil");
        return;
    }
    [self setActive:YES];
#endif
}

- (BOOL)setActive:(BOOL)active
{
#if TARGET_OS_IPHONE
    NSError *error = nil;
    BOOL succeed = NO;
    @try {
        succeed = [[AVAudioSession sharedInstance] setActive:active error:&error];
    } @catch (NSException *exception) {
        NSLog(@"failed to inactive/active AVAudioSession\n");
        succeed = NO;
    }
    if (succeed == NO) {
        NSLog(@"IJKAudioKit: AVAudioSession.setActive(%@) failed: %@\n",
            active ? @"YES" : @"NO",
            error ? [error localizedDescription] : @"nil");
    }
    return succeed;
#endif
    return YES;
}

- (void)handleInterruption:(NSNotification *)notification
{
#if TARGET_OS_IPHONE
    int reason = [[[notification userInfo] valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    switch (reason) {
        case AVAudioSessionInterruptionTypeBegan: {
            NSLog(@"AVAudioSessionInterruptionTypeBegan\n");
            [self setActive:NO];
            break;
        }
        case AVAudioSessionInterruptionTypeEnded: {
            NSLog(@"AVAudioSessionInterruptionTypeEnded\n");
            [self setActive:YES];
            break;
        }
    }
#endif
}

@end
