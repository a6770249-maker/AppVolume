#import <substrate.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AppVolumeManager.h"

// 记录 App 原本请求的音量，配置变更时据此重新套用系数，避免系数被重复相乘。
static NSString *const AVOriginalVolumeKey = @"com.mayday.appvolume.originalVolume";

// 弱引用表：配置变更时对仍然存活的播放器重新应用音量，做到即时生效。
static NSHashTable *AVTrackedPlayers = nil;

static inline float AVScaledVolume(float volume) {
    return volume * AppVolumeManager.sharedManager.scale;
}

static void AVTrackPlayerWithVolume(id player, float volume) {
    @synchronized ([AppVolumeManager class]) {
        if (!AVTrackedPlayers) {
            AVTrackedPlayers = [NSHashTable weakObjectsHashTable];
        }
        [AVTrackedPlayers addObject:player];
    }
    objc_setAssociatedObject(player, (__bridge const void *)AVOriginalVolumeKey,
                             @(volume), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL AVHasTrackedVolume(id player) {
    return objc_getAssociatedObject(player, (__bridge const void *)AVOriginalVolumeKey) != nil;
}

// 有些 App 从不主动设置音量（默认 1.0），在 play 时补一次，让系数也能生效。
static void AVApplyDefaultVolumeIfNeeded(id player) {
    if (!AVHasTrackedVolume(player) && [player respondsToSelector:@selector(setVolume:)]) {
        [player setVolume:1.0f];
    }
}

static void AVReapplyTrackedPlayers(void) {
    NSArray *players = nil;
    @synchronized ([AppVolumeManager class]) {
        players = AVTrackedPlayers.allObjects;
    }

    Class playerClass = objc_getClass("AVPlayer");
    Class audioPlayerClass = objc_getClass("AVAudioPlayer");

    for (id player in players) {
        NSNumber *requestedVolume = objc_getAssociatedObject(player, (__bridge const void *)AVOriginalVolumeKey);
        if (!requestedVolume) {
            continue;
        }
        // 只对 AVPlayer / AVAudioPlayer 重新应用，避免对未挂载到 AVAudioEngine 的节点设置音量。
        BOOL safeToReapply = (playerClass && [player isKindOfClass:playerClass]) ||
                             (audioPlayerClass && [player isKindOfClass:audioPlayerClass]);
        if (safeToReapply && [player respondsToSelector:@selector(setVolume:)]) {
            [player setVolume:requestedVolume.floatValue];
        }
    }
}

static void AVPreferencesDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                   const void *object, CFDictionaryRef userInfo) {
    [[AppVolumeManager sharedManager] reload];
    dispatch_async(dispatch_get_main_queue(), ^{
        AVReapplyTrackedPlayers();
    });
}

%ctor {
    [[AppVolumeManager sharedManager] reload];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    AVPreferencesDidChange,
                                    (__bridge CFStringRef)AppVolumeChangedDarwinNotification,
                                    NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

%hook AVPlayer

- (void)setVolume:(float)volume {
    AVTrackPlayerWithVolume(self, volume);
    %orig(AVScaledVolume(volume));
}

- (void)play {
    AVApplyDefaultVolumeIfNeeded(self);
    %orig;
}

%end

%hook AVAudioPlayer

- (void)setVolume:(float)volume {
    AVTrackPlayerWithVolume(self, volume);
    %orig(AVScaledVolume(volume));
}

- (BOOL)play {
    AVApplyDefaultVolumeIfNeeded(self);
    return %orig;
}

%end

%hook AVAudioPlayerNode

- (void)setVolume:(float)volume {
    AVTrackPlayerWithVolume(self, volume);
    %orig(AVScaledVolume(volume));
}

%end

%hook AVAudioMixerNode

- (void)setVolume:(float)volume {
    AVTrackPlayerWithVolume(self, volume);
    %orig(AVScaledVolume(volume));
}

%end

// 直接用 AudioQueue 播放的 App（部分游戏、老式播放器）走这里。
%hookf(OSStatus, AudioQueueSetParameter, AudioQueueRef queue,
       AudioQueueParameterID parameterID, AudioQueueParameterValue value) {
    if (parameterID == kAudioQueueParam_Volume) {
        value = (AudioQueueParameterValue)AVScaledVolume((float)value);
    }
    return %orig;
}
