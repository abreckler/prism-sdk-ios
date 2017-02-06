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

static NSMutableDictionary *_session;
static NSString *_status;

@interface PrismRecorder() <UIAlertViewDelegate>
@property (strong, nonatomic) NSMutableArray *uploads;
@property (strong, nonatomic) PRUser *currentUser;
@property (nonatomic) PRPost *currentPost;
@property (nonatomic) NSString *errorMessage;
@property (strong) NSDictionary *finalPostData;
@property (strong, nonatomic) PRAPIClient *apiClient;
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

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = @"Disabled";
        _currentPost = nil;
    }
    return self;
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
