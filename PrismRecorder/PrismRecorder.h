//
//  PrismRecorder.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//! Project version number for PrismRecorder.
FOUNDATION_EXPORT double PrismRecorderVersionNumber;
FOUNDATION_EXPORT const unsigned char PrismRecorderVersionString[];



typedef void (^SendPostCompletionBlock)(BOOL success);

@interface PrismRecorder : NSObject

@property (nonatomic, readonly) NSString *errorMessage;

//engine
+ (instancetype)sharedManager;
- (void)enableWithClientId:(NSString*)clientId;
- (void)updateRecording;
- (void)setRecordingPath:(NSString *)recordingPath;
+ (NSBundle*)bundle;

@end
