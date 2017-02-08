//
//  PRUser.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PrismUser.h"


@interface PrismUser()

@property (nonatomic, copy) NSString *user_id;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *firstname;
@property (nonatomic, copy) NSString *lastname;
@property (nonatomic, copy) NSString *gravatar_url;
@property (nonatomic, copy) NSString *phone_number;
@property (nonatomic) BOOL has_gravatar;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *org_name;
@property (nonatomic, copy) NSString *token;
@end

@implementation PrismUser

- (instancetype)init {
    self = [super init];
    
    if (self) { }
    
    return self;
}

- (NSString*)username {
    return !_username? @"blink" : _username;
}

#pragma mark - private

- (void)configureWithData:(NSDictionary *)data {
    
//    NSArray *team = @[@"adam", @"ahmed", @"laptop_mini", @"alexisp", @"demo", @"hmd"];
    
    _user_id = [NSString stringWithFormat:@"%@", data[@"id"]];
    _email = data[@"email"];
    _username = data[@"username"];
    _firstname = data[@"first_name"];
    _lastname = data[@"last_name"];
    _gravatar_url = data[@"gravatar_url"];
    _has_gravatar = [data[@"has_gravatar"] boolValue];
    _title = data[@"title"];
    _org_name = data[@"org_name"];
    _phone_number = ![data[@"phone_number"] isKindOfClass:[NSNull class]] ? [[data[@"phone_number"] componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]] componentsJoinedByString:@""] : @"";
    
    if (data[@"token"] && ![data[@"token"] isKindOfClass:[NSNull class]]) {
        _token = data[@"token"];
    }
}

- (BOOL)hasToken {
    return _token.length > 0;
}

@end

