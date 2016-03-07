//
//  MonitorHDAccountSetting.m
//  bither-ios
//
//  Copyright 2014 http://Bither.net
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Created by songchenwen on 15/7/16.
//

#import <Bitheri/BTAddressManager.h>
#import "MonitorHDAccountSetting.h"
#import "ScanQrCodeViewController.h"
#import "ScanQrCodeTransportViewController.h"
#import "DialogProgress.h"
#import "StringUtil.h"
#import "BTQRCodeUtil.h"
#import "PeerUtil.h"

@interface MonitorHDAccountSetting () <ScanQrCodeDelegate>
@property(weak) UIViewController *vc;
@end

static Setting *monitorSetting;

@implementation MonitorHDAccountSetting


+ (MonitorHDAccountSetting *)getMonitorHDAccountSetting {
    if (!monitorSetting) {
        monitorSetting = [[MonitorHDAccountSetting alloc] initWithName:NSLocalizedString(@"monitor_cold_hd_account", nil) icon:[UIImage imageNamed:@"scan_button_icon"]];
    }
    return monitorSetting;
}

- (instancetype)initWithName:(NSString *)name icon:(UIImage *)icon {
    self = [super initWithName:name icon:icon];
    if (self) {
        [self configureSetting];
    }
    return self;
}

- (void)configureSetting {
    [self setSelectBlock:^(UIViewController *controller) {
        self.vc = controller;
        if ([BTAddressManager instance].hasHDAccountMonitored) {
            [self showMsg:NSLocalizedString(@"monitor_cold_hd_account_limit", nil)];
            return;
        }
        ScanQrCodeViewController *scan = [[ScanQrCodeViewController alloc] initWithDelegate:self title:nil message:nil];
        [self.vc presentViewController:scan animated:YES completion:nil];
    }];
}

- (void)handleResult:(NSString *)result byReader:(ScanQrCodeViewController *)reader {
    [reader.presentingViewController dismissViewControllerAnimated:YES completion:^{
        DialogProgress *dp = [[DialogProgress alloc] initWithMessage:NSLocalizedString(@"Please wait…", nil)];
        [dp showInWindow:self.vc.view.window completion:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self processQrCodeContent:result dp:dp];
            });
        }];
    }];
}

- (void)showMsg:(NSString *)msg {
    if (self.vc && [self.vc respondsToSelector:@selector(showMsg:)]) {
        [self.vc performSelector:@selector(showMsg:) withObject:msg];
    }
}

- (void)processQrCodeContent:(NSString *)content dp:(DialogProgress *)dp {
    BOOL isXRandom = [content characterAtIndex:0] == [XRANDOM_FLAG characterAtIndex:0];
    NSData *bytes = isXRandom ? [content substringFromIndex:1].hexToData : content.hexToData;
    if(bytes.length != 65){
        [dp dismissWithCompletion:^{
            [self showMsg:NSLocalizedString(@"monitor_cold_hd_account_failed_wrong_qr_code", nil)];
        }];
        return;
    }
    BTHDAccount *account = nil;
    @try {
        account = [[BTHDAccount alloc] initWithAccountExtendedPub:bytes fromXRandom:isXRandom syncedComplete:NO andGenerationCallback:nil];
    } @catch (NSException *e) {
        if ([e isKindOfClass:[DuplicatedHDAccountException class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [dp dismissWithCompletion:^{
                    [self showMsg:NSLocalizedString(@"monitor_cold_hd_account_failed_duplicated", nil)];
                }];
            });
            return;
        }
    }
    if (!account) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [dp dismissWithCompletion:^{
                [self showMsg:NSLocalizedString(@"monitor_cold_hd_account_failed", nil)];
            }];
        });
        return;
    }
    [[PeerUtil instance] stopPeer];
    [BTAddressManager instance].hdAccountMonitored = account;
    [[PeerUtil instance] startPeer];
    dispatch_async(dispatch_get_main_queue(), ^{
        [dp dismissWithCompletion:^{
            [self showMsg:NSLocalizedString(@"monitor_cold_hd_account_success", nil)];
            if (self.vc && [self.vc respondsToSelector:@selector(reload)]) {
                [self.vc performSelector:@selector(reload)];
            }
        }];
    });
}

@end