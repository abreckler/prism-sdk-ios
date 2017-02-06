//
//  PrismRecorder.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PrismRecorder.h"
#import "PRConstants.h"
#import "PRUser.h"
#import "PRAPIClient.h"
#import "NSString+PrismUtils.h"
@import ReplayKit;

@interface PrismRecorder() <UIAlertViewDelegate, RPScreenRecorderDelegate, RPPreviewViewControllerDelegate>
@property (strong, nonatomic) PRUser *currentUser;
@property (nonatomic) PRPost *currentPost;
@property (nonatomic) NSString *errorMessage;
@property (strong, nonatomic) PRAPIClient *apiClient;
@property (nonatomic, weak) UIWindow *mainWindow;
@property (nonatomic) NSTimeInterval applicationActivatedAtTime;
//@property (nonatomic, strong) VideoAnnotation *videoAnnotation;
@property (weak, nonatomic) RPPreviewViewController *previewViewController;
@end

static PrismRecorder *sharedManager = nil;

@implementation PrismRecorder {
    NSMutableArray* paramList;
    BOOL publishPost;
    BOOL waitForVideo;
}


+ (instancetype)sharedManager {
    static id sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)enableWithClientId:(NSString*)clientId {
    
    NSAssert(clientId.isBlank, @"Client ID is missing.");
    NSAssert(![[NSUUID alloc] initWithUUIDString:clientId], @"Client ID format is invalid. Double check and try again.");
    
    _currentPost = nil;
    
    _apiClient = [PRAPIClient new];
    [_apiClient getAccountDetails:clientId completion:^(BOOL status, NSData *data, NSError *error) {
        if (status) {
            NSDictionary *accountDetails = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BLog(@"account %@", accountDetails);
            [_currentUser configureWithData:accountDetails];
            self.errorMessage = @"";
        } else {
            NSString *respString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            BLog(@"failed with error %@ and response %@",error.localizedDescription, respString);
        }
    }];
    
    [self attachToWindow];
    
}


- (void)attachToWindow
{
    if (self.mainWindow) return;
    
    self.mainWindow = UIApplication.sharedApplication.keyWindow;
   
    if (! self.mainWindow) {
        self.mainWindow = UIApplication.sharedApplication.windows.lastObject;
    }
    
    NSAssert(!self.mainWindow, @"[PrismRecorder] Main application window is missing.");
    
    
    if (!self.allSet) {
        NSAssert(!self.mainWindow, @"[PrismRecorder] Main application windown is missing.");
        return;
    }
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (BOOL)allSet {
    return  self.mainWindow && self.mainWindow.rootViewController;
}


- (void)sendPost:(NSDictionary*)postData completion:(SendPostCompletionBlock)completion {
    BLog();
    
    if (!postData[@"image"]) {
        if (completion)
            completion(false);
        return;
    }
    
    if(!self.currentUser.hasToken) {
        if (completion)
            completion(false);
        return;
    }
    
    
    _apiClient = [PRAPIClient new];
    [_apiClient publishPost:postData forAccount:self.currentUser.token completion:^(BOOL status, NSData *data, NSError *error) {
        
        if (status) {
            NSDictionary *createdPost = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BLog(@"published post %@", createdPost);
            [_currentPost updateWithData:createdPost];
            self.errorMessage = @"";
        } else {
            NSString *respString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            BLog(@"failed with error %@ and response %@",error.localizedDescription, respString);
#ifdef DEBUG
            self.errorMessage = [NSString stringWithFormat:@"failed with response error %@\n username %@", error.localizedDescription, self.currentUser.username];
#endif
        }
    }];
   
}


- (void)setCurrentPost:(PRPost *)currentPost {
    _currentPost = currentPost;
}



#pragma mark - private


- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if (RPScreenRecorder.sharedRecorder.isRecording) {
        [RPScreenRecorder.sharedRecorder discardRecordingWithHandler:^{
            self.previewViewController = nil;
        }];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    self.applicationActivatedAtTime = NSDate.date.timeIntervalSince1970;
}

-  (void)applicationWillResignActive:(NSNotification *)notification
{
    if (RPScreenRecorder.sharedRecorder.isRecording) {
        [RPScreenRecorder.sharedRecorder discardRecordingWithHandler:^{
            self.previewViewController = nil;
        }];
    }
}



-(BOOL)isDebugEnabled {
    //#ifdef DEBUG
    //    return true;
    //#endif
    return [[NSUserDefaults standardUserDefaults]  boolForKey:@"kDEBUGMODE"];
}

- (void)setDebugEnabled:(BOOL)status {
    [[NSUserDefaults standardUserDefaults] setBool:status forKey:@"kDEBUGMODE"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - helpers

- (void)showAlerWithTitle:(NSString*)title andMessage:(NSString*)message {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:title
                                          message:message
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *yesAction = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"Take me to Settings", nil)
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action)
                                {
                                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                                }];
    
    
    UIAlertAction *noAction = [UIAlertAction  actionWithTitle:NSLocalizedString(@"Later",nil) style:UIAlertActionStyleDestructive handler:nil];
    
    [alertController addAction:yesAction];
    [alertController addAction:noAction];
    
    [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
}


@end
