//
//  PrismRecorder.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


FOUNDATION_EXPORT double PrismRecorderVersionNumber;
FOUNDATION_EXPORT const unsigned char PrismRecorderVersionString[];

typedef void (^SendPostCompletionBlock)(BOOL success);

@interface PrismRecorder : NSObject

@property (nonatomic, readonly, nullable) NSString *errorMessage;

//engine
+ (instancetype _Nonnull )sharedManager;
- (void)enableWithClientId:(NSString*_Nonnull)clientId;
- (void)updateRecording;
- (void)setRecordingPath:(NSString *_Nullable)recordingPath;
+ (NSBundle*_Nonnull)bundle;

@end
