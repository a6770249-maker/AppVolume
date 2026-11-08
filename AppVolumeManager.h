#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const AppVolumePreferencesDomain;
FOUNDATION_EXPORT NSString *const AppVolumeChangedDarwinNotification;

/// 负责读写下发的配置。tweak 与设置面板各自编译一份。
@interface AppVolumeManager : NSObject

/// 总开关（默认 YES）。
@property (nonatomic, assign, readonly) BOOL enabled;

/// 当前进程应当乘上的音量系数，1.0 表示不处理。
@property (nonatomic, assign, readonly) float scale;

+ (instancetype)sharedManager;

+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;

/// 单个 App 的音量（0.0 ~ 1.0），未配置时返回 1.0。
+ (float)volumeForBundleIdentifier:(NSString *)bundleIdentifier;
+ (void)setVolume:(float)volume forBundleIdentifier:(NSString *)bundleIdentifier;

+ (void)resetAllVolumes;

/// 广播配置变更，让所有已注入的进程刷新并重新应用音量。
+ (void)notifyChanged;

/// 重新读取配置（会同时刷新当前进程的 scale）。
- (void)reload;

@end
