//
//  PrismRecorder.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
// In this header, you should import all the public headers of your framework using statements like #import <PrismRecorder/PublicHeader.h>
#import <PRPhotosUtils.h>
#import "PRPost.h"

//! Project version number for PrismRecorder.
FOUNDATION_EXPORT double PrismRecorderVersionNumber;

//! Project version string for PrismRecorder.
FOUNDATION_EXPORT const unsigned char PrismRecorderVersionString[];


#define PRISM_VERSION @"1.0.0"



typedef void (^SendPostCompletionBlock)(BOOL success);

@interface PrismRecorder : NSObject

@property (nonatomic, readonly) PRPost *currentPost;
@property (nonatomic, readonly) NSString *errorMessage;

//engine
+ (instancetype)sharedManager;
- (void)sendPost:(NSDictionary*)postData completion:(SendPostCompletionBlock)completion;
- (void)setCurrentPost:(PRPost *)currentPost;
- (void)handleShakeMotion;

@end
