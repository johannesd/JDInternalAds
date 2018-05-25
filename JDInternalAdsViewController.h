//
//  JDInternalAdsViewController.h
//  Midiflow Monitor
//
//  Created by Johannes Dörr on 18.01.17.
//  Copyright © 2017 Johannes Dörr. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
@class JDInternalAdsViewController;


@protocol JDInternalAdsViewControllerDelegate <NSObject>

- (void)internalAdsViewController:(JDInternalAdsViewController *)internalAdsViewController changedToVisible:(BOOL)visible;

@end


@interface JDInternalAdsViewController : UIViewController <SKStoreProductViewControllerDelegate>

- (id)initWithApps:(NSArray *)apps;

@property (nonatomic, weak) id<JDInternalAdsViewControllerDelegate> delegate;

@property (nonatomic, strong) UIColor *foregroundColor;
@property (nonatomic, assign, readonly) BOOL visible;
@property (nonatomic, assign) BOOL allowVisible;
@property (nonatomic, strong, readonly) NSDictionary *currentApp;
@property (nonatomic, strong) NSURL *websiteURL;

@end


@interface JDInternalAdsViewController ()

- (void)buttonClicked:(id)sender;
- (void)hideButtonClicked:(id)sender;

@end
