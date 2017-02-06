//
//  PRAPIClient.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PRClientCompletionBlock)(BOOL success, NSData *receivedData, NSError *error);

@interface PRAPIClient : NSObject
- (void)getAccountDetails:(NSString *)token completion:(PRClientCompletionBlock)completion;
- (void)publishPost:(NSDictionary*)data forAccount:(NSString *)token completion:(PRClientCompletionBlock)completion;
@end
