#import "AppVolumeManager.h"

NSString *const AppVolumePreferencesDomain = @"com.mayday.appvolume";
NSString *const AppVolumeChangedDarwinNotification = @"com.mayday.appvolume.changed";

static NSString *const AVVolumeKeyPrefix = @"vol.";
static NSString *const AVEnabledKey = @"enabled";

static NSString *AVCurrentBundleIdentifier(void) {
    static NSString *identifier = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifier = [NSBundle mainBundle].bundleIdentifier ?: @"";
    });
    return identifier;
}

static NSString *AVVolumeKey(NSString *bundleIdentifier) {
    return [AVVolumeKeyPrefix stringByAppendingString:bundleIdentifier ?: @""];
}

static void AVSynchronizePreferences(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)AppVolumePreferencesDomain);
}

static id AVCopyPreferenceValue(NSString *key) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)AppVolumePreferencesDomain);
    if (!value) {
        return nil;
    }
    return (__bridge_transfer id)value;
}

static BOOL AVReadBool(NSString *key, BOOL fallback) {
    id value = AVCopyPreferenceValue(key);
    if (!value) {
        return fallback;
    }
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return fallback;
}

static float AVReadFloat(NSString *key, float fallback) {
    id value = AVCopyPreferenceValue(key);
    if (!value || ![value respondsToSelector:@selector(floatValue)]) {
        return fallback;
    }
    return [value floatValue];
}

static float AVClampVolume(float volume) {
    if (volume < 0.0f) {
        return 0.0f;
    }
    if (volume > 1.0f) {
        return 1.0f;
    }
    return volume;
}

@implementation AppVolumeManager {
    BOOL _enabled;
    float _scale;
    NSString *_bundleIdentifier;
}

+ (instancetype)sharedManager {
    static AppVolumeManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AppVolumeManager alloc] init];
        [manager reload];
    });
    return manager;
}

- (void)reload {
    AVSynchronizePreferences();

    NSString *bundleIdentifier = AVCurrentBundleIdentifier();
    BOOL enabled = AVReadBool(AVEnabledKey, YES);
    float volume = AVClampVolume(AVReadFloat(AVVolumeKey(bundleIdentifier), 1.0f));

    _bundleIdentifier = bundleIdentifier;
    _enabled = enabled;
    _scale = enabled ? volume : 1.0f;
}

+ (BOOL)isEnabled {
    AVSynchronizePreferences();
    return AVReadBool(AVEnabledKey, YES);
}

+ (void)setEnabled:(BOOL)enabled {
    CFPreferencesSetAppValue((__bridge CFStringRef)AVEnabledKey,
                             (__bridge CFPropertyListRef)@(enabled),
                             (__bridge CFStringRef)AppVolumePreferencesDomain);
    AVSynchronizePreferences();
    [self notifyChanged];
}

+ (float)volumeForBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return 1.0f;
    }
    return AVClampVolume(AVReadFloat(AVVolumeKey(bundleIdentifier), 1.0f));
}

+ (void)setVolume:(float)volume forBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return;
    }
    CFPreferencesSetAppValue((__bridge CFStringRef)AVVolumeKey(bundleIdentifier),
                             (__bridge CFPropertyListRef)@(AVClampVolume(volume)),
                             (__bridge CFStringRef)AppVolumePreferencesDomain);
    AVSynchronizePreferences();
    [self notifyChanged];
}

+ (void)resetAllVolumes {
    CFStringRef domain = (__bridge CFStringRef)AppVolumePreferencesDomain;
    CFDictionaryRef allValues = CFPreferencesCopyMultiple(NULL, domain,
                                                          kCFPreferencesCurrentUser,
                                                          kCFPreferencesAnyHost);
    if (allValues) {
        for (NSString *key in (__bridge NSDictionary *)allValues) {
            if ([key hasPrefix:AVVolumeKeyPrefix]) {
                CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, domain);
            }
        }
        CFRelease(allValues);
    }
    AVSynchronizePreferences();
    [self notifyChanged];
}

+ (void)notifyChanged {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                          (__bridge CFStringRef)AppVolumeChangedDarwinNotification,
                                          NULL, NULL, true);
}

@end
