#import "AVSliderCell.h"
#import "../AppVolumeManager.h"
#import <Preferences/PSSpecifier.h>
#include <math.h>

@implementation AVSliderCell {
    UILabel *_nameLabel;
    UILabel *_percentLabel;
    UISlider *_slider;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:15.0];
        _nameLabel.textColor = [UIColor labelColor];

        _percentLabel = [[UILabel alloc] init];
        _percentLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightMedium];
        _percentLabel.textAlignment = NSTextAlignmentRight;

        _slider = [[UISlider alloc] init];
        _slider.minimumValue = 0.0f;
        _slider.maximumValue = 1.0f;
        _slider.continuous = YES;
        [_slider addTarget:self action:@selector(sliderValueChanged:)
         forControlEvents:UIControlEventValueChanged];
        [_slider addTarget:self action:@selector(sliderCommit:)
         forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

        [self.contentView addSubview:_nameLabel];
        [self.contentView addSubview:_percentLabel];
        [self.contentView addSubview:_slider];

        [self refreshCellContentsWithSpecifier:specifier];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];

    self.textLabel.hidden = YES;
    self.detailTextLabel.hidden = YES;

    NSString *bundleIdentifier = [specifier propertyForKey:@"bundleID"];
    float volume = [AppVolumeManager volumeForBundleIdentifier:bundleIdentifier];

    _nameLabel.text = [specifier propertyForKey:@"appName"];
    _slider.value = volume;
    [self updatePercentLabel:volume];
}

- (void)updatePercentLabel:(float)volume {
    _percentLabel.text = [NSString stringWithFormat:@"%d%%", (int)lroundf(volume * 100.0f)];
    _percentLabel.textColor = volume >= 0.999f ? [UIColor secondaryLabelColor] : [UIColor systemBlueColor];
}

- (void)sliderValueChanged:(UISlider *)slider {
    [self updatePercentLabel:slider.value];
}

- (void)sliderCommit:(UISlider *)slider {
    [self updatePercentLabel:slider.value];
    NSString *bundleIdentifier = [self.specifier propertyForKey:@"bundleID"];
    [AppVolumeManager setVolume:slider.value forBundleIdentifier:bundleIdentifier];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.contentView.bounds.size.width;
    CGFloat height = self.contentView.bounds.size.height;

    _nameLabel.frame = CGRectMake(16.0, 7.0, width - 100.0, 20.0);
    _percentLabel.frame = CGRectMake(width - 72.0, 7.0, 56.0, 20.0);
    _slider.frame = CGRectMake(16.0, height - 36.0, width - 32.0, 28.0);
}

@end
