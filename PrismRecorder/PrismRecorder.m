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
#import "PrismUser.h"
#import "PRAPIClient.h"
#import "PRVideoAnnotation.h"
#import "NSString+PrismUtils.h"
#import "PRPhotosUtils.h"
#import "PrismPost.h"
@import ReplayKit;

NSString* const PrismUserDefaultsKey = @"io.prism.recorder.client";


@interface PrismRecorder() <RPScreenRecorderDelegate, RPPreviewViewControllerDelegate, PRVideoAnnotationDelegate>
@property (strong, nonatomic) PrismUser *currentUser;
@property (nonatomic) PrismPost *currentPost;
@property (strong, nonatomic) PRAPIClient *apiClient;
@property (nonatomic) PRPhotosUtils *library;
@property (nonatomic, weak) UIWindow *mainWindow;
@property (nonatomic) UIView *overlay;
@property (nonatomic) NSTimeInterval applicationActivatedAtTime;
@property (nonatomic, strong) PRVideoAnnotation *videoAnnotation;
@property (weak, nonatomic) RPPreviewViewController *previewViewController;
- (void)setCurrentPost:(PrismPost *)currentPost;
@end

static PrismRecorder *sharedManager = nil;

@implementation PrismRecorder


NSString* const kPRCameraPermission = @"NSCameraUsageDescription";
NSString* const kPRMicPermission = @"NSMicrophoneUsageDescription";
NSString* const kPRPhotosPermission = @"NSPhotoLibraryUsageDescription";

BOOL isShowing;
CFTimeInterval bln_startTime;

+ (instancetype)sharedManager {
    static id sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)enableWithClientId:(NSString*)clientId {
    
    NSAssert(!clientId.isBlank, @"Client ID is missing.");
    //NSAssert([[NSUUID alloc] initWithUUIDString:clientId], @"Client ID format is invalid. Double check and try again.");
    
    [[NSUserDefaults standardUserDefaults] setObject:clientId forKey:PrismUserDefaultsKey];
    
    _currentPost = nil;
    [self fetchUser];
    
    if (!self.checkForPermissionsDescriptions) {
        BLog(@"Missing permissions descriptions in Info.plist\nRecording is disabled.");
        return;
    }
    
    [self attachToWindow];
}



- (void)attachToWindow
{
    if (self.mainWindow) return;
    
    self.mainWindow = UIApplication.sharedApplication.keyWindow;
   
    if (!self.mainWindow) {
        self.mainWindow = UIApplication.sharedApplication.windows.lastObject;
    }
   
    if (!self.allSet)
        return;
    
    if (!self.currentUser)
        [self fetchUser];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (BOOL)allSet {
    
    NSAssert(self.mainWindow, @"[PrismRecorder] Main application window is missing.");
    NSAssert(self.mainWindow.rootViewController, @"[PrismRecorder] RootViewController is missing.");
    NSAssert(!self.clientKey.isBlank, @"[PrismRecorder] Client ID is missing.");
    
    return  self.mainWindow && self.mainWindow.rootViewController && self.checkForPermissionsDescriptions && self.clientKey;
}

- (BOOL)checkForPermissionsDescriptions {
    
    NSDictionary *plistDict = [NSBundle mainBundle].infoDictionary;
    NSArray *permissions = @[kPRCameraPermission, kPRMicPermission, kPRPhotosPermission];
    
    for (NSString *perm in permissions) {
        
        BOOL usageDescription = [plistDict objectForKey:perm]  != nil;
        if (!usageDescription) {
            NSString *message = [@"[PrismRecorder] missing Info.plist permission key for " stringByAppendingString:perm];
            NSAssert(!usageDescription, message);
            return false;
        }
    }
    
    return true;
}


#pragma mark - Recording

- (void)updateRecording {

    [self attachToWindow];
    
    
    //TODO: Check for currentUser
    
    if (!self.allSet) {
        return;
    }
    
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        NSDate.date.timeIntervalSince1970 - self.applicationActivatedAtTime > 1.5)
    {
        if (!self.shouldRecord) {
            return;
        }
    }
    
    [self handleTap];
}

- (void)setupPreview
{
    
    RPScreenRecorder *sharedRecorder = RPScreenRecorder.sharedRecorder;
    CGRect videoFrame = (CGRect){20, self.mainWindow.bounds.size.height - 120, 100, 100};
    _videoAnnotation = [[PRVideoAnnotation alloc] initWithFrame:videoFrame];
    _videoAnnotation.backgroundColor = [UIColor clearColor];
    _videoAnnotation.frame = videoFrame;
    _videoAnnotation.tapDelegate = self;
    [_videoAnnotation initialScaleDone];
    _videoAnnotation.userInteractionEnabled = false;
    [self.mainWindow addSubview:_videoAnnotation];
    
    if (sharedRecorder.isCameraEnabled) {
        for (CALayer *layer  in sharedRecorder.cameraPreviewView.layer.sublayers) {
            if (layer.class == AVCaptureVideoPreviewLayer.class) {
                _videoAnnotation.captureVideoPreviewLayer = (AVCaptureVideoPreviewLayer*) layer;
                _videoAnnotation.captureVideoPreviewLayer.hidden = NO;
            }
        }
    }
}


#pragma mark - VideoAnnotationDelegate

- (void)handleTap
{
    if(self.isRecording) {
        [self stopRecording];
    } else if (!_videoAnnotation) {
        [self setupPreview];
        [self startRecording];
    }
}


- (void)startRecording
{
    BLog();
    RPScreenRecorder *sharedRecorder = RPScreenRecorder.sharedRecorder;
    
    if (sharedRecorder.isRecording || isShowing)
        return;
    
    
    if (!self.shouldRecord)
        return;
    
    if (![self recordingPermission:YES]) {
        BLog(@"permissions needed");
        return;
    }
    
    sharedRecorder.delegate = self;
    
    __block BOOL cameraEnabled = false;
    
    VoidBlock recordingFunction = ^{
        isShowing = false;
        //error or user didn't allow the recording
        if (!sharedRecorder.isRecording)
            return;
        
        
        _videoAnnotation.userInteractionEnabled = sharedRecorder.isRecording;
        [_videoAnnotation.captureVideoPreviewLayer removeFromSuperlayer];
        _videoAnnotation.captureVideoPreviewLayer = nil;
        
        if ([sharedRecorder respondsToSelector:@selector(isCameraEnabled)]) {
            if (sharedRecorder.isCameraEnabled && cameraEnabled) {
                for (CALayer *layer  in sharedRecorder.cameraPreviewView.layer.sublayers) {
                    if (layer.class == AVCaptureVideoPreviewLayer.class) {
                        _videoAnnotation.captureVideoPreviewLayer = (AVCaptureVideoPreviewLayer*) layer;
                    }
                }
            } else {
                [_videoAnnotation.captureVideoPreviewLayer removeFromSuperlayer];
                _videoAnnotation.captureVideoPreviewLayer = nil;
            }
        }
        
        [_videoAnnotation updateUIWithRecordingState:sharedRecorder.recording];
        
        [_videoAnnotation setProgress:0];
        bln_startTime = CACurrentMediaTime();
        [self performSelector:@selector(updateProgress) withObject:nil afterDelay:1.0];
    };
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Start Recording"
                                          message:@"Enable screen recording with:"
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    
    UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Record screen, camera & mic", nil) style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action)
                                   {
                                       if ([sharedRecorder respondsToSelector:@selector(isCameraEnabled)]) {
                                           [sharedRecorder setCameraEnabled:YES];
                                       }
                                       
                                       cameraEnabled = true;
                                       [sharedRecorder setMicrophoneEnabled:YES];
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [sharedRecorder startRecordingWithHandler:^(NSError *error) {
                                               if (error) {
                                                   BLog(@"error: %@", error.localizedDescription);
                                               }
                                               recordingFunction();
                                           }];
                                       });
                                       
                                       
                                   }];
    
    UIAlertAction *micAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Record screen & microphone", nil) style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action)
                                {
                                    [sharedRecorder setMicrophoneEnabled:true];
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [sharedRecorder startRecordingWithMicrophoneEnabled:true handler:^(NSError *error) {
                                            if (error) {
                                                BLog(@"error: %@", error.localizedDescription);
                                            }
                                            recordingFunction();
                                        }];
                                    });
                                    
                                }];
    
    UIAlertAction *screenAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Record screen only", nil) style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action)
                                   {
                                       [sharedRecorder setMicrophoneEnabled:false];
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [sharedRecorder startRecordingWithMicrophoneEnabled:false handler:^(NSError *error) {
                                               if (error) {
                                                   BLog(@"error: %@", error.localizedDescription);
                                               }
                                               recordingFunction();
                                           }];
                                       });
                                       
                                   }];
    
    
    UIAlertAction *noAction = [UIAlertAction  actionWithTitle:NSLocalizedString(@"Cancel",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                               {
                                   isShowing = false;
                               }];
    
    [alertController addAction:cameraAction];
    [alertController addAction:micAction];
    [alertController addAction:screenAction];
    [alertController addAction:noAction];
    isShowing = true;
    [self.currentViewController presentViewController:alertController animated:YES completion:nil];
    
}

- (void)stopRecording
{
    BLog();
    RPScreenRecorder *sharedRecorder = RPScreenRecorder.sharedRecorder;
    
    if (!sharedRecorder.isRecording)
        return;
    
    [sharedRecorder stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *error) {
        _videoAnnotation.userInteractionEnabled = sharedRecorder.isRecording;
        [_videoAnnotation updateUIWithRecordingState:sharedRecorder.recording];
        if (error) {
            BLog(@"error: %@", error.localizedDescription);
        }
        
        if (previewViewController) {
            self.previewViewController = previewViewController;
            self.previewViewController.previewControllerDelegate = self;
            self.previewViewController.modalPresentationStyle = UIModalPresentationFullScreen;
            [self.currentViewController presentViewController:self.previewViewController animated:YES completion:nil];
            [self.library registerChangeObserver];
            return;
        }
         isShowing = false;
    }];
    
}

- (void)updateProgress
{
   // BLog();
    if (!RPScreenRecorder.sharedRecorder.isRecording)
        return;
    CFTimeInterval elapsedTime = CACurrentMediaTime() - bln_startTime;
    [_videoAnnotation setProgress:elapsedTime];
   
    [self performSelector:@selector(updateProgress) withObject:nil afterDelay:1.0];
}

- (void)discardRecording {
    RPScreenRecorder *sharedRecorder = RPScreenRecorder.sharedRecorder;
    if (RPScreenRecorder.sharedRecorder.isRecording) {
        [sharedRecorder stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *error) {
            [RPScreenRecorder.sharedRecorder discardRecordingWithHandler:^{
                _videoAnnotation.enabled = sharedRecorder.recording;
                [_videoAnnotation updateUIWithRecordingState:sharedRecorder.recording];
                _videoAnnotation.backgroundColor = [UIColor clearColor];
                 isShowing = false;
            }];
        }];
    }
}


#pragma mark - RPScreenRecorderDelegate

- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithError:(NSError *)error previewViewController:(nullable RPPreviewViewController *)previewViewController
{
    // handle error which caused unexpected stop of recording
    BLog();
    _videoAnnotation.backgroundColor = [UIColor clearColor];
    if (previewViewController) {
        self.previewViewController = previewViewController;
    }
    
   
}

- (void)screenRecorderDidChangeAvailability:(RPScreenRecorder *)screenRecorder
{
    // handle screen recorder availability changes
//    BLog(@"availability %@", NSStringFromBool(screenRecorder.available));
}

#pragma mark - RPPreviewViewControllerDelegate

- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController
{
    BLog();
    isShowing = false;
    [previewController dismissViewControllerAnimated:YES completion:nil];
}


- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet<NSString *> *)activityTypes {

    if (![activityTypes containsObject:UIActivityTypeSaveToCameraRoll]) {
       
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Discard recording?"
                                              message:@"You didn't save your recording.\nThere is no undo and you will have to start over."
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Discard", nil)
                                    style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action)
                                    {
                                        [previewController dismissViewControllerAnimated:YES completion:nil];
                                        [self.library unregisterChangeObserver];
                                    }];
        [alertController addAction:yesAction];
        
        UIAlertAction *noAction = [UIAlertAction  actionWithTitle:NSLocalizedString(@"Cancel",nil) style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:noAction];
        
        [self.previewViewController presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma mark - Permissions

- (BOOL)recordingPermission:(BOOL)triggerRequest
{
    // Check video authorization status. Video access is required and audio access is optional.
    // If audio access is denied, audio is not recorded during movie recording.
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusAuthorized: //we're good
            return true;
            break;
        case AVAuthorizationStatusNotDetermined:
        {
            // The user has not yet been presented with the option to grant video access.
            if (triggerRequest) {
                [self requestPermission];
            }
            break;
        }
            
        case AVAuthorizationStatusDenied:
            [self permissionCallback:@"Camera permission needed"];
            break;
        default:
            break;
    }
    
    return false;
}

- (void)requestPermission
{
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted )
     {
         
         if (granted) {
             
             //checking Audio permission
             if ([AVAudioSession sharedInstance].recordPermission == AVAudioSessionRecordPermissionUndetermined) {
                 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backFromPermission) name:UIApplicationDidBecomeActiveNotification object:nil];
             }
             
             [self startRecording];
         }
     }];
}


- (void)permissionCallback:(NSString*)message
{
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:message
                                          message:@"Blink needs camera and microphone permissions to enable video reactions\nPlease enable both in Settings"
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *yesAction = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"Take me to Settings", nil)
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action)
                                {
                                    [self openSystemSettings];
                                }];
    
    
    UIAlertAction *noAction = [UIAlertAction  actionWithTitle:NSLocalizedString(@"Later",nil) style:UIAlertActionStyleDestructive handler:nil];
    
    [alertController addAction:yesAction];
    [alertController addAction:noAction];
    
    [self.currentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)backFromPermission
{
    BLog();
    if ([AVAudioSession sharedInstance].recordPermission == AVAudioSessionRecordPermissionUndetermined) {
        //        NSLog(@"undetermined");
    }
    if ([AVAudioSession sharedInstance].recordPermission == AVAudioSessionRecordPermissionDenied) {
        //        NSLog(@"Denied");
    }
    if ([AVAudioSession sharedInstance].recordPermission == AVAudioSessionRecordPermissionGranted) {
        //        NSLog(@"Granted");
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    if ([AVAudioSession sharedInstance].recordPermission == AVAudioSessionRecordPermissionDenied) {
        NSString *message = @"Microphone permission denied";
        [self permissionCallback:message];
    }
}


- (BOOL)shouldRecord {
    BOOL shoudlRecord = true;
    if ([self.currentViewController isKindOfClass:UINavigationController.class]) {
        UINavigationController *navController = (UINavigationController*)self.currentViewController;
        if ([navController.visibleViewController isKindOfClass:RPPreviewViewController.class]) {
//            BLog(@"visibleViewController class %@", navController.visibleViewController.class);
            shoudlRecord = false;
        }
    }
    return shoudlRecord;
}



#pragma mark - Post

- (void)setRecordingPath:(NSString *)recordingPath {
    NSString *dummyImg = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNkYPhfz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC";
    NSDictionary *post = @{@"username" : self.currentUser.username,
                           @"image" : dummyImg,
                           @"videoPath": recordingPath,
                           @"description" : @"",
                           @"report_link" : @"",
                           @"content_type" : @2,
                           @"is_published": @1
                           };
    [self.library unregisterChangeObserver];
    [self sendPost:post completion:^(BOOL success) {
        
    }];

}

- (void)sendPost:(NSDictionary*)postData completion:(SendPostCompletionBlock)completion {
    BLog();
    
    
    UIView *overlay = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.overlay = overlay;
    UIView *loadingView = [self loadingView:@"Just a sec..."];
    UIButton *cancelBtn = [UIButton new];
    cancelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [cancelBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelBtn setTitle:[NSLocalizedString(@"Cancel", nil) uppercaseString] forState:UIControlStateNormal];
    cancelBtn.frame = (CGRect) (CGRect){0, loadingView.frame.size.height - 60, loadingView.frame.size.width, 60};
    [cancelBtn addTarget:self action:@selector(cancelRequests) forControlEvents:UIControlEventTouchUpInside];
    [self.overlay addSubview:loadingView];
    [self.overlay addSubview:cancelBtn];
    [self.mainWindow addSubview:self.overlay];
    
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
        } else {
            NSString *respString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            BLog(@"failed with error %@ and response %@",error.localizedDescription, respString);
        }
        
        [self clearWindow];
    }];
   
}


- (void)setCurrentPost:(PrismPost *)currentPost {
    _currentPost = currentPost;
}

- (void)fetchUser {
    _currentUser = [PrismUser new];
    _apiClient = [PRAPIClient new];
    [_apiClient getAccountDetails:self.clientKey completion:^(BOOL status, NSData *data, NSError *error) {
        if (status) {
            NSDictionary *accountDetails = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [_currentUser configureWithData:accountDetails];
        } else {
            NSString *respString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            BLog(@"failed with error %@ and response %@",error.localizedDescription, respString);
            //TODO: Inform host of failure
        }
    }];
}

#pragma mark - App State

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


#pragma mark - Helpers

- (NSString *)clientKey {
    if (self.currentUser) {
        if (self.currentUser.token)
            return  self.currentUser.token;
    }
    //TODO: fetch user when blank
    NSString *keyDefaults = [[NSUserDefaults standardUserDefaults] stringForKey:PrismUserDefaultsKey];
    if (keyDefaults.isBlank) {
        keyDefaults = [[NSBundle mainBundle].infoDictionary objectForKey:@"prism_client_id"];
    }
    
    return keyDefaults;
}

- (PRPhotosUtils *)library {
    if (!_library) {
        _library = [PRPhotosUtils new];
    }
    return _library;
}

- (void)cancelRequests {
    [self.apiClient cancelRequests];
    [self clearWindow];
}

- (void)clearWindow {
    if (_overlay.superview) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_overlay removeFromSuperview];
            _overlay = nil;
        });
    }
}

+ (NSBundle*)bundle {
    return [NSBundle bundleForClass:self];    
}

- (UIViewController*)currentViewController
{
    UIViewController *currentViewController = self.mainWindow.rootViewController;
    while (currentViewController.presentedViewController) {
        currentViewController = currentViewController.presentedViewController;
    }
//    BLog(@"top most class %@", currentViewController.class);
    return currentViewController;
}


- (BOOL)isRecording {
    return  RPScreenRecorder.sharedRecorder.isRecording;
}

- (BOOL)isDebugEnabled {
    //#ifdef DEBUG
    //    return true;
    //#endif
    return [[NSUserDefaults standardUserDefaults]  boolForKey:@"kDEBUGMODE"];
}

- (void)setDebugEnabled:(BOOL)status {
    [[NSUserDefaults standardUserDefaults] setBool:status forKey:@"kDEBUGMODE"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (UIView *)loadingView:(NSString*)text
{
    
    UIView *loadingView = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    loadingView.alpha = 0.85f;
    loadingView.backgroundColor = [UIColor colorWithRed:0.969 green:0.973 blue:0.973 alpha:1.000];
    
    if (text.length)
    {
        [loadingView addSubview:[self makeLabelWith:text]];
    }
    
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicator.backgroundColor = [UIColor clearColor];
    activityIndicator.color = [UIColor colorWithRed:0.208 green:0.318 blue:0.471 alpha:1.000];
    CGRect activityIndicatorFrame = CGRectMake(loadingView.frame.size.width/2-activityIndicator.frame.size.width/2,
                                               loadingView.frame.size.height/2-activityIndicator.frame.size.height/2,
                                               activityIndicator.frame.size.width,
                                               activityIndicator.frame.size.height);
    if ([UIScreen mainScreen].scale == 1.f) activityIndicatorFrame = CGRectIntegral(activityIndicatorFrame);
    activityIndicator.frame = activityIndicatorFrame;
    [activityIndicator startAnimating];
    [loadingView addSubview:activityIndicator];
    
    
    return loadingView;
}

- (UILabel *)makeLabelWith:(NSString *)text {
    
    UIFont *font = [UIFont systemFontOfSize:22];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentCenter;
    
    NSAttributedString *attributedString =[[NSAttributedString alloc]
                                           initWithString:text
                                           attributes:@{
                                                        NSStrokeWidthAttributeName: @-3.0,
                                                        NSStrokeColorAttributeName:[UIColor whiteColor],
                                                        NSForegroundColorAttributeName:[UIColor blackColor],
                                                        NSFontAttributeName:font,
                                                        NSParagraphStyleAttributeName:paragraphStyle,
                                                        }
                                           ];
    
    UILabel *label = [UILabel new];
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    label.frame = CGRectMake(20, width/2 + 40, width - 40, 100);
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines  = 0;
    label.attributedText  = attributedString;
    
    return label;
    
}


- (void)showAlerWithTitle:(NSString*)title andMessage:(NSString*)message openSettings:(BOOL)settings {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:title
                                          message:message
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    
    if (settings) {
        UIAlertAction *yesAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"Take me to Settings", nil)
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction *action)
                                    {
                                        [self openSystemSettings];
                                    }];
        
        [alertController addAction:yesAction];
    }

    
    
    UIAlertAction *noAction = [UIAlertAction  actionWithTitle:NSLocalizedString(@"Ok",nil) style:UIAlertActionStyleDestructive handler:nil];
    [alertController addAction:noAction];
    
    [self.currentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)openSystemSettings {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}


@end
