#import "AVRootListController.h"
#import "../AppVolumeManager.h"
#import <Preferences/PSSpecifier.h>

@implementation AVRootListController {
    NSArray<NSDictionary *> *_installedApplications;
}

#pragma mark - Specifiers

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.title.length == 0) {
        self.title = @"单 App 音量";
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];

        PSSpecifier *switchGroup = [PSSpecifier groupSpecifierWithName:@"总开关"];
        [switchGroup setProperty:@"关闭后所有 App 都按系统音量播放。"
                         forKey:@"footerText"];
        [specifiers addObject:switchGroup];

        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"启用单 App 音量"
                                                             target:self
                                                                set:@selector(setEnabledValue:specifier:)
                                                                get:@selector(enabledValue:)
                                                             detail:nil
                                                               cell:PSSwitchCell
                                                               edit:nil];
        [specifiers addObject:toggle];

        PSSpecifier *resetGroup = [PSSpecifier groupSpecifierWithName:@""];
        [specifiers addObject:resetGroup];

        PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:@"重置全部为 100%"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:nil
                                                              cell:PSButtonCell
                                                              edit:nil];
        reset->action = @selector(resetAllVolumes);
        [specifiers addObject:reset];

        PSSpecifier *appsGroup = [PSSpecifier groupSpecifierWithName:@"已安装的 App"];
        [appsGroup setProperty:@"拖动滑块设置该 App 的音量上限，100% 表示不限制。松手后立即生效。"
                        forKey:@"footerText"];
        [specifiers addObject:appsGroup];

        if (self.installedApplications.count == 0) {
            PSSpecifier *emptyNotice = [PSSpecifier groupSpecifierWithName:@"未读取到 App 列表"];
            [emptyNotice setProperty:@"请确认设备已越狱并安装 PreferenceLoader，然后重启设置 App 再试。"
                              forKey:@"footerText"];
            [specifiers addObject:emptyNotice];
        }

        for (NSDictionary *application in self.installedApplications) {
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:application[@"name"]
                                                              target:nil
                                                                 set:nil
                                                                 get:nil
                                                              detail:nil
                                                                cell:PSLinkCell
                                                                edit:nil];
            [row setProperty:@"AVSliderCell" forKey:@"cellClass"];
            [row setProperty:application[@"bundleID"] forKey:@"bundleID"];
            [row setProperty:application[@"name"] forKey:@"appName"];
            [row setProperty:@64 forKey:@"height"];
            [specifiers addObject:row];
        }

        _specifiers = specifiers;
    }
    return _specifiers;
}

#pragma mark - 总开关

- (id)enabledValue:(PSSpecifier *)specifier {
    return @([AppVolumeManager isEnabled]);
}

- (void)setEnabledValue:(id)value specifier:(PSSpecifier *)specifier {
    [AppVolumeManager setEnabled:[value boolValue]];
}

#pragma mark - 重置

- (void)resetAllVolumes {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置全部音量"
                                                                   message:@"所有 App 都会恢复为 100% 音量。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"重置"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [AppVolumeManager resetAllVolumes];
        [weakSelf reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - App 列表

- (NSArray<NSDictionary *> *)installedApplications {
    if (!_installedApplications) {
        _installedApplications = [self loadInstalledApplications];
    }
    return _installedApplications;
}

- (NSArray<NSDictionary *> *)loadInstalledApplications {
    NSMutableArray<NSDictionary *> *applications = [NSMutableArray array];

    Class workspaceClass = objc_getClass("LSApplicationWorkspace");
    if (!workspaceClass) {
        return applications;
    }

    id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
    if (![workspace respondsToSelector:@selector(allApplications)]) {
        return applications;
    }

    for (id proxy in [workspace allApplications]) {
        if (![proxy respondsToSelector:@selector(bundleIdentifier)]) {
            continue;
        }

        NSString *bundleIdentifier = [proxy bundleIdentifier];
        if (bundleIdentifier.length == 0) {
            continue;
        }

        if ([proxy respondsToSelector:@selector(isPlaceholder)] && [proxy isPlaceholder]) {
            continue;
        }
        if ([proxy respondsToSelector:@selector(isHidden)] && [proxy isHidden]) {
            continue;
        }
        if ([proxy respondsToSelector:@selector(isRestricted)] && [proxy isRestricted]) {
            continue;
        }

        // 只保留用户安装的 App 和系统可见 App，过滤掉内部组件。
        if ([proxy respondsToSelector:@selector(applicationType)]) {
            NSString *type = [proxy applicationType];
            if (![type isEqualToString:@"User"] && ![type isEqualToString:@"System"]) {
                continue;
            }
        }

        NSString *name = nil;
        if ([proxy respondsToSelector:@selector(localizedName)]) {
            name = [proxy localizedName];
        }
        if (name.length == 0) {
            name = bundleIdentifier;
        }

        [applications addObject:@{ @"bundleID": bundleIdentifier, @"name": name }];
    }

    [applications sortUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        return [lhs[@"name"] localizedStandardCompare:rhs[@"name"]];
    }];

    return applications;
}

@end
