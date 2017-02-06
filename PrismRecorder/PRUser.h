//
//  PRUser.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PRUser : NSObject

@property (nonatomic, copy, readonly) NSString *user_id;
@property (nonatomic, copy, readonly) NSString *email;
@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, copy, readonly) NSString *firstname;
@property (nonatomic, copy, readonly) NSString *lastname;
@property (nonatomic, copy, readonly) NSString *gravatar_url;
@property (nonatomic, copy, readonly) NSString *phone_number;
@property (nonatomic, readonly) BOOL has_gravatar;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *org_name;
@property (nonatomic, copy, readonly) NSString *token;
@property (nonatomic, copy, readonly) NSString *deviceToken;

- (void)configureWithData:(NSDictionary *)data;
- (BOOL)hasToken;


@end
