//
//  PRAPIClient.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRAPIClient.h"
#import "PRConstants.h"

typedef void (^SendRequestCompletionBlock)(NSURLResponse* response, NSData* data, NSError* connectionError);

NSString *const _PRLiveURLString = @"https://blink.am";
NSString *const _PRTestingURLString = @"https://stage.blink.am";

@interface PRAPIClient()

@property (nonatomic, strong) NSString *apiToken;

@end

@implementation PRAPIClient


- (void)getAccountDetails:(NSString *)token completion:(PRClientCompletionBlock)completion {
    BLog();
    self.apiToken = token;
    NSURL *url = [self setupRequestURLWithPath:@"/api/account/" isAPICall:NO];
    NSMutableURLRequest *req = [self requestSetup:url andType:@"GET"];
    
    [self sendRequest:req completion:^(NSURLResponse *response, NSData *rdata, NSError *error) {
        if ([self handleCompletionForRequest:response andData:rdata error:error]) {
            if (completion)
                completion([self handleCompletionForRequest:response andData:rdata error:error], rdata, error);
        }
    }];
}


#pragma mark - Private

- (void)sendRequest:(NSURLRequest *)request completion:(SendRequestCompletionBlock)completion{
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionTask *task = [session dataTaskWithRequest:request  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // handle response
        if (completion) {
            completion(response, data, error);
            return;
        }
    }];
    [task resume];
}


-(BOOL)handleCompletionForRequest:(NSURLResponse *)response andData:(NSData*)data error:(NSError*)error {
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    NSInteger code = [httpResponse statusCode];
    
    
    if (error) {
        BLog(@"RQ code %li and eror %@", (long)code, error.localizedDescription);
    }
    
    if (error || code >= 400) {
        BLog(@"RQ code %li and eror %@", (long)code, error.localizedDescription);
        return NO;
    }
    
    
    return YES;
}

- (NSMutableURLRequest*) requestSetup:(NSURL*)url andType:(NSString*)type {
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:type];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"json" forHTTPHeaderField:@"Data-Type"];
    
    NSString *auth = [NSString stringWithFormat:@"Token %@", self.apiToken];
    [req setValue:auth forHTTPHeaderField:@"Authorization"];
    
    [req setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    req.timeoutInterval = 35.0;
    // BLog(@"user token %@ for username %@", [PRUser currentUser].token, [PRUser currentUser].username );
    
    return req;
}

- (NSString *)percentEscapeString:(NSString *)string
{
    NSCharacterSet * queryKVSet = [NSCharacterSet characterSetWithCharactersInString:@":/?@!$&'()*+,;="].invertedSet;
    
    NSString * result = [string stringByAddingPercentEncodingWithAllowedCharacters:queryKVSet];
    
    return [result stringByReplacingOccurrencesOfString:@" " withString:@"+"];
}


- (NSURL *)setupRequestURLWithPath:(NSString*)path isAPICall:(BOOL)isAPI {
    
    NSString *finalPath = self.baseURL;
    if (isAPI) {
        finalPath = [finalPath stringByAppendingString:@"/api/v1"];
    }
    finalPath = [finalPath stringByAppendingString:path];
    finalPath = [finalPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    //  BLog(@"final path %@", finalPath);
    return [NSURL URLWithString:finalPath];
}

- (NSString*)baseURL {
    NSString *baseURL = self.isDebugEnabled ?_PRTestingURLString : _PRLiveURLString;
    return baseURL;
}


-(BOOL)isDebugEnabled {
    #ifdef DEBUG
        return true;
    #endif
}


@end
