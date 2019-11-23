//
//  JDInternalAdsViewController.m
//  Midiflow Monitor
//
//  Created by Johannes Dörr on 18.01.17.
//  Copyright © 2017 Johannes Dörr. All rights reserved.
//

#import "JDInternalAdsViewController.h"
#import <BlocksKit/NSArray+BlocksKit.h>
#import <BlocksKit/UIAlertView+BlocksKit.h>
#import <JDSetFrame/UIView+JDSetFrame.h>

static NSTimeInterval timeIntervalNextApp = 18;
static NSTimeInterval timeIntervalNextAppAfterShownApp = 6;
static NSTimeInterval timeIntervalShowAdsAgain = 60 * 10;


@interface JDInternalAdsViewController ()
{
    NSArray *apps;
    NSMutableSet *shownApps;
    UIView *appContainer;
    UIImageView *iconImageView;
    UILabel *titleLabel;
    UILabel *subtitleLabel;
    UILabel *buyLabel;
    UIButton *button;
    UIButton *hideButton;
    NSTimer *timer;
    NSTimeInterval timerInterval;
}
    
@property (nonatomic, strong) NSDictionary *currentApp;
@property (nonatomic, assign) BOOL visible;
    
@end


@implementation JDInternalAdsViewController

- (id)initWithApps:(NSArray *)theApps
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        apps = theApps;
        shownApps = [NSMutableSet set];
        appContainer = [[UIView alloc] init];
        _visible = FALSE;
        _allowVisible = TRUE;
        _foregroundColor = [UIColor whiteColor];
        NSString *urlString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MFAppWebsite"];
        _websiteURL = [NSURL URLWithString:urlString];
        
        iconImageView = [[UIImageView alloc] init];
        iconImageView.userInteractionEnabled = FALSE;
        iconImageView.clipsToBounds = TRUE;
        [appContainer addSubview:iconImageView];
        
        titleLabel = [[UILabel alloc] init];
        titleLabel.adjustsFontSizeToFitWidth = TRUE;
        titleLabel.font = [UIFont systemFontOfSize:22];
        [appContainer addSubview:titleLabel];
        
        subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.font = [UIFont systemFontOfSize:12];
        subtitleLabel.numberOfLines = 0;
        [appContainer addSubview:subtitleLabel];
        
        buyLabel = [[UILabel alloc] init];
        buyLabel.text = @"Buy now";
        buyLabel.font = [UIFont systemFontOfSize:15];
        buyLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
        buyLabel.textAlignment = NSTextAlignmentCenter;
        buyLabel.layer.cornerRadius = 5;
        buyLabel.clipsToBounds = TRUE;
        [appContainer addSubview:buyLabel];
        
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [button addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        
        hideButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [hideButton addTarget:self action:@selector(hideButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];

}

- (void)setForegroundColor:(UIColor *)foregroundColor
{
    _foregroundColor = foregroundColor;
    titleLabel.textColor = foregroundColor;
    subtitleLabel.textColor = foregroundColor;
    buyLabel.textColor = foregroundColor;

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"×"];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineHeightMultiple = 0.88;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, 1)];
    [attributedString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:30 weight:0.1] range:NSMakeRange(0, 1)];
    [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:1 alpha:0.4] range:NSMakeRange(0, 1)];
    [hideButton setAttributedTitle:attributedString forState:UIControlStateNormal];
    
    NSMutableAttributedString *attributedStringHighlighted = [attributedString mutableCopy];
    [attributedStringHighlighted addAttribute:NSForegroundColorAttributeName value:foregroundColor range:NSMakeRange(0, 1)];
    [hideButton setAttributedTitle:attributedStringHighlighted forState:UIControlStateHighlighted];
}

- (void)setCurrentApp:(NSDictionary *)currentApp
{
    _currentApp = currentApp;
    if (currentApp != nil) {
        titleLabel.text = currentApp[@"title"];
        subtitleLabel.text = currentApp[@"subtitle"];
        iconImageView.image = currentApp[@"image"];
        [shownApps addObject:currentApp];
        [self.view setNeedsLayout];
    }
}

- (NSArray *)notInstalledApps
{
    UIApplication *application = [UIApplication sharedApplication];
    return [apps bk_select:^BOOL(NSDictionary *app) {
#ifdef DEBUG
        return TRUE;
#endif
        NSURL *url = [NSURL URLWithString:[app[@"urlScheme"] stringByAppendingString:@"://"]];
        return ![application canOpenURL:url];
    }];
}

- (NSDictionary *)getNextApp
{
    NSArray *appsToAdvertise = [self notInstalledApps];
    appsToAdvertise = [appsToAdvertise bk_reject:^BOOL(NSDictionary *app) {
        return [shownApps containsObject:app];
    }];
    if (appsToAdvertise.count == 0) {
        return nil;
    }
    int r = arc4random_uniform(appsToAdvertise.count);
    return appsToAdvertise[r];
}

- (void)showNextAppIfAllowed
{
    [self cancelScheduleNextAppAfterDelay];
    if (self.allowVisible) {
        NSDictionary *nextApp = [self getNextApp];
        if (nextApp != nil) {
            if (self.visible) {
                [UIView transitionWithView:self.view.superview duration:0.3 options:UIViewAnimationOptionTransitionFlipFromTop animations:^{
                    self.currentApp = nextApp;
                } completion:nil];
            }
            else {
                self.currentApp = nextApp;
                self.visible = TRUE;
            }
            // Switch to next app after a time
            [self scheduleNextAppAfterDelay:timeIntervalNextApp];
            return;
        }
        else {
            self.currentApp = nil;
        }
    }
    self.visible = FALSE;
}

- (void)setVisible:(BOOL)visible
{
    BOOL changed = _visible != visible;
    _visible = visible;
    if (changed) {
        [self.delegate internalAdsViewController:self changedToVisible:visible];
        if (!visible) {
            [self cancelScheduleNextAppAfterDelay];
        }
    }
}

- (void)setAllowVisible:(BOOL)allowVisible
{
    BOOL changed = _allowVisible != allowVisible;
    _allowVisible = allowVisible;
    if (changed && self.viewLoaded) {
        [self performSelector:@selector(allowVisibeChanged) withObject:nil afterDelay:0];
    }
}

- (void)allowVisibeChanged
{
    if (self.allowVisible) {
        if (self.currentApp == nil) {
            [self showNextAppIfAllowed];
        }
        else {
            self.visible = TRUE;
            // Switch to next app after a time
            [self scheduleNextAppAfterDelay:timeIntervalNextApp];
        }
    }
    else {
        self.visible = FALSE;
    }
}

- (void)timerFired:(NSTimer *)timer2
{
    timer = nil;
    [self showNextAppIfAllowed];
}

- (void)scheduleNextAppAfterDelay:(NSTimeInterval)delay
{
    [self cancelScheduleNextAppAfterDelay];
    timer = [NSTimer scheduledTimerWithTimeInterval:delay
                                     target:self
                                   selector:@selector(timerFired:)
                                   userInfo:nil
                                    repeats:FALSE];
    timerInterval = delay;
}

- (void)cancelScheduleNextAppAfterDelay
{
    [timer invalidate];
    timer = nil;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [timer invalidate];
    timerInterval = MAX([timer.fireDate timeIntervalSinceNow], timeIntervalNextApp);
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (timer != nil) {
        [self scheduleNextAppAfterDelay:timerInterval];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view addSubview:appContainer];
    [self.view addSubview:button];
    [self.view addSubview:hideButton];

    [self showNextAppIfAllowed];
    
    [self setForegroundColor:[UIColor whiteColor]];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [UIView performWithoutAnimation:^{
        UIEdgeInsets safeAreaInsets;
        if (@available(iOS 11.0, *)) {
            safeAreaInsets = UIEdgeInsetsMake(self.view.safeAreaInsets.top,
                                              MAX(0, self.view.safeAreaInsets.left - 14),
                                              0,
                                              MAX(0, self.view.safeAreaInsets.right - 14));
        } else {
            safeAreaInsets = UIEdgeInsetsZero;
        }
        
        CGFloat margin = 10;
        
        CGFloat maxWidth = 570;
        
        [hideButton setFrameToWidth:60];
        //    hideButton.backgroundColor = [UIColor redColor];
        [hideButton setFrameToAlignment:JDFrameAlignmentRight withInsets:safeAreaInsets];
        [hideButton setFrameToFill:JDFrameFillHeight];
        UIEdgeInsets appInsets = UIEdgeInsetsMake(margin, margin + safeAreaInsets.left, margin, hideButton.frameWidth + safeAreaInsets.right);
        
        CGFloat availableWidth = self.view.frameWidth - appInsets.left - appInsets.right;
        BOOL smallScreen = availableWidth < maxWidth;
        if (smallScreen) {
            [appContainer setFrameToFill:JDFrameFillWidth withInsets:appInsets];
        }
        else {
            [appContainer setFrameToWidth:maxWidth];
            [appContainer setFrameToAlignment:JDFrameAlignmentCenter withInsets:appInsets];
        }
        [appContainer setFrameToFill:JDFrameFillHeight withInsets:appInsets];
        
        [iconImageView setFrameToAlignment:JDFrameAlignmentLeft];
        [iconImageView setFrameToFill:JDFrameFillHeight];
        [iconImageView setFrameToWidth:iconImageView.frameHeight];
        iconImageView.layer.cornerRadius = iconImageView.frameHeight / 4.5;
        
        buyLabel.hidden = smallScreen;
        [buyLabel setFrameToWidth:100];
        [buyLabel setFrameToAlignment:JDFrameAlignmentRight];
        [buyLabel setFrameToFill:JDFrameFillHeight];
        
        UIEdgeInsets labelInsets = UIEdgeInsetsMake(0, iconImageView.frameWidth + margin, 0, (!buyLabel.hidden ? buyLabel.frameWidth + margin : 0));
        
        CGFloat labelMargin = -2;
        [titleLabel setFrameToRightOfView:iconImageView withMargin:margin];
        [titleLabel sizeToFit];
        [titleLabel setFrameToFill:JDFrameFillToRight withInsets:labelInsets];
        [subtitleLabel setFrameToBottomOfView:titleLabel withMargin:labelMargin];
        [subtitleLabel setFrameToFill:JDFrameFillToRight withInsets:labelInsets];
        [subtitleLabel setFrameToHeight:1000];
        [subtitleLabel sizeToFit];
        [subtitleLabel setFrameToFill:JDFrameFillToRight withInsets:labelInsets];
        
        CGFloat labelTop = round((appContainer.frameHeight - titleLabel.frameHeight - subtitleLabel.frameHeight - labelMargin) / 2) - 1;
        [titleLabel setFrameToTop:labelTop];
        [subtitleLabel setFrameToBottomOfView:titleLabel withMargin:labelMargin];
        
        [button setFrameToFill:JDFrameFillWidth | JDFrameFillHeight withInsets:UIEdgeInsetsMake(0, 0, 0, hideButton.frameWidth + safeAreaInsets.right)];
    }];
}

- (void)buttonDown:(id)sender
{
    [self cancelScheduleNextAppAfterDelay];
    self.view.backgroundColor = [self.foregroundColor colorWithAlphaComponent:0.1];
}

- (void)buttonUp:(id)sender
{
    self.view.backgroundColor = [UIColor clearColor];
    [self scheduleNextAppAfterDelay:timeIntervalNextApp];
}
    
- (void)buttonClicked:(id)sender
{
    [self cancelScheduleNextAppAfterDelay];
    SKStoreProductViewController *storeProductViewController = [[SKStoreProductViewController alloc] init];
    storeProductViewController.delegate = self;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    [self presentViewController:storeProductViewController animated:YES completion:^{
        [storeProductViewController loadProductWithParameters:@{
                                                                SKStoreProductParameterITunesItemIdentifier: self.currentApp[@"appleId"],
                                                                SKStoreProductParameterAffiliateToken: @"1l3vbAX",
                                                                } completionBlock:^(BOOL result, NSError *error) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = FALSE;
            if (error) {
                NSArray *buttons = self.websiteURL != nil ? @[@"Website"] : nil;
                [UIAlertView bk_showAlertViewWithTitle:@"The App Store is currently not available." message:@"" cancelButtonTitle:@"Ok" otherButtonTitles:buttons handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                    if (buttonIndex == 1) {
                        [[UIApplication sharedApplication] openURL:self.websiteURL];
                    }
                    [self dismissViewControllerAnimated:TRUE completion:nil];
                }];
            }
        }];
    }];
}

- (void)hideButtonClicked:(id)sender
{
    self.visible = FALSE;
    // Show ad again after a time
    [self scheduleNextAppAfterDelay:timeIntervalShowAdsAgain];
}


#pragma mark - SKStoreProductViewControllerDelegate
    
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    [self dismissViewControllerAnimated:TRUE completion:^{
        // Switch to next app after app has been viewed
        [self scheduleNextAppAfterDelay:timeIntervalNextAppAfterShownApp];
    }];
}
    
@end
