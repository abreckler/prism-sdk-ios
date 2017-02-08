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

@interface PrismRecorder() <UIAlertViewDelegate, RPScreenRecorderDelegate, RPPreviewViewControllerDelegate, PRVideoAnnotationDelegate>
@property (strong, nonatomic) PrismUser *currentUser;
@property (nonatomic) PrismPost *currentPost;
@property (nonatomic) NSString *errorMessage;
@property (strong, nonatomic) PRAPIClient *apiClient;
@property (nonatomic, weak) UIWindow *mainWindow;
@property (nonatomic) NSTimeInterval applicationActivatedAtTime;
@property (nonatomic, strong) PRVideoAnnotation *videoAnnotation;
@property (weak, nonatomic) RPPreviewViewController *previewViewController;

- (void)setCurrentPost:(PrismPost *)currentPost;
@end

static PrismRecorder *sharedManager = nil;

@implementation PrismRecorder


BOOL isShowing;
NSTimer *recordingTimer;
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

//http://stackoverflow.com/questions/10154958/ios-how-to-detect-shake-motion
//http://stackoverflow.com/questions/19131957/ios-motion-detection-motion-detection-sensitivity-levels
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


#pragma mark - Recording

- (void)handleShakeMotion {
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        NSDate.date.timeIntervalSince1970 - self.applicationActivatedAtTime > 1.5)
    {
        if (self.shouldRecord) {
            [self handleTap];
        }
    }
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
    RPScreenRecorder *sharedRecorder = RPScreenRecorder.sharedRecorder;
    if(sharedRecorder.isRecording) {
        [self stopRecording];
    } else {
        if (!_videoAnnotation) {
            [self setupPreview];
        }
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
        if (recordingTimer) {
            [recordingTimer invalidate];
            recordingTimer = nil;
        }
        bln_startTime = CACurrentMediaTime();
        recordingTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
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
    
    [recordingTimer invalidate];
    recordingTimer = nil;
    
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
        }
    }];
    
}

- (void)updateProgress
{
    
    CFTimeInterval elapsedTime = CACurrentMediaTime() - bln_startTime;
    [_videoAnnotation setProgress:elapsedTime];
}

- (void)discardRecording {
    RPScreenRecorder *sharedRecorder = RPScreenRecorder.sharedRecorder;
    if (RPScreenRecorder.sharedRecorder.isRecording) {
        [sharedRecorder stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *error) {
            [RPScreenRecorder.sharedRecorder discardRecordingWithHandler:^{
                _videoAnnotation.enabled = sharedRecorder.recording;
                [_videoAnnotation updateUIWithRecordingState:sharedRecorder.recording];
                _videoAnnotation.backgroundColor = [UIColor clearColor];
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
    BLog(@"availability %@", NSStringFromBool(screenRecorder.available));
}

#pragma mark - RPPreviewViewControllerDelegate

- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController
{
    [previewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - PBJVisionDelegate

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

//permissions
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
            BLog(@"visibleViewController class %@", navController.visibleViewController.class);
            shoudlRecord = false;
        }
    }
    return shoudlRecord;
}

- (UIViewController*)currentViewController
{
    UIViewController *currentViewController = self.mainWindow.rootViewController;
    while (currentViewController.presentedViewController) {
        currentViewController = currentViewController.presentedViewController;
    }
    BLog(@"top most class %@", currentViewController.class);
    return currentViewController;
}



#pragma mark - Post


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


- (void)setCurrentPost:(PrismPost *)currentPost {
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
                                    [self openSystemSettings];
                                }];
    
    
    UIAlertAction *noAction = [UIAlertAction  actionWithTitle:NSLocalizedString(@"Later",nil) style:UIAlertActionStyleDestructive handler:nil];
    
    [alertController addAction:yesAction];
    [alertController addAction:noAction];
    
    [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)openSystemSettings {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}


@end
