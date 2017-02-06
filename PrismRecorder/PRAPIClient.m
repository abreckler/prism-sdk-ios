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

@interface PRAPIClient()<NSURLSessionTaskDelegate, NSURLSessionDelegate>

@property (nonatomic, strong) NSString *apiToken;
@property (nonatomic) NSURLSession *session;
@property (nonatomic) NSURLSessionUploadTask *sendPostTask;

@end

@implementation PRAPIClient


- (void)getAccountDetails:(NSString *)token completion:(PRClientCompletionBlock)completion {
    BLog();
    self.apiToken = token;
    NSURL *URL = [self setupRequestURLWithPath:@"/api/account/" isAPICall:NO];
    NSMutableURLRequest *request = [self requestSetup:URL andType:@"GET"];
    
    [self sendRequest:request completion:^(NSURLResponse *response, NSData *rdata, NSError *error) {
        if (completion)
            completion([self handleCompletionForRequest:response andData:rdata error:error], rdata, error);
    }];
}

- (void)publishPost:(NSDictionary*)data forAccount:(NSString *)token completion:(PRClientCompletionBlock)completion {
    BLog();
    
    [self cancelRequests];
    self.apiToken = token;
    
    
    NSMutableDictionary *postData = [[NSMutableDictionary alloc] initWithDictionary:data];
    
    if (data[@"videoPath"]) {
        NSData *videoData = [NSData  dataWithContentsOfFile:[NSURL URLWithString:data[@"videoPath"]].path];
        NSString *encodedVideo = [videoData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        NSString *formattedString =  [@"unsafe:data:video/x-m4v;base64," stringByAppendingString:encodedVideo];
        [postData addEntriesFromDictionary:@{@"video" : @[formattedString]}];
    }
    
    
    NSURL *URL = [self setupRequestURLWithPath:@"/posts/" isAPICall:YES];
    NSString *mimeType = @"data:image/jpeg;base64,";
//    NSString *encodedOriginalImage = [UIImageJPEGRepresentation(_currentPost.originalImage, 1) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
//    NSArray *originalImage=  @[[mimeType stringByAppendingString:encodedOriginalImage]];
//    [postData addEntriesFromDictionary:@{@"image_source" : originalImage}];
    NSMutableURLRequest *request = [self requestSetup:URL andType:@"POST"];
    request.URL = URL;
    
    
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:postData options:0 error:nil];
    _sendPostTask = [self.session uploadTaskWithRequest:request fromData:JSONData completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (completion)
            completion([self handleCompletionForRequest:response andData:data error:error], data, error);
        
        _sendPostTask = nil;
    }];
    
    [_sendPostTask resume];
}



#pragma mark - Private

- (void)cancelRequests {
    
    if (_sendPostTask) {
        [_sendPostTask suspend];
        _sendPostTask = nil;
    }
}


- (void)invalidateSession {
    [self.session resetWithCompletionHandler:^{}];
}


- (NSURLSession *)session
{
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSString *auth = [NSString stringWithFormat:@"Token %@", self.apiToken ];
        [configuration setHTTPAdditionalHeaders:@{@"Authorization": auth, @"Content-Type" : @"application/json"}];
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    });
    return session;
}



- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    //NSLog(@"invalid");
    //self.session = nil;
}


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
