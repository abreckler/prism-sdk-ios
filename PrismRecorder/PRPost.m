//
//  PRPost.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRPost.h"
#import "PRConstants.h"
#import "NSString+PrismUtils.h"

@interface PRPost()
@property (nonatomic, copy) NSString *post_id;
@property (nonatomic, copy) NSString *post_uuid;
@property (nonatomic, copy) NSURL *post_image;
@property (nonatomic, copy) NSURL *post_thumbnail;
@property (nonatomic, copy) NSURL *post_image_source;
@property (nonatomic, copy) NSURL *post_video;
@property (nonatomic, copy) NSString *post_description;
@property (nonatomic, copy) NSString *post_author;
@property (nonatomic, copy) NSString *like_count;
@property (nonatomic, copy) NSString *comment_count;
@property (nonatomic, copy) NSDate *creation_date;
@property (nonatomic, copy) NSString *post_url;
@property (nonatomic, copy) NSString *image_filename;
@property (nonatomic) PRAssetType contentType;
@property (nonatomic) BOOL didUpvote;
@property (nonatomic) BOOL isPrivate;
@property (nonatomic) BOOL isProcessed;
@property (nonatomic) BOOL isPublished;
@end

@implementation PRPost

+ (instancetype)initWithData:(NSDictionary *)data {
    //   BLog(@"%@", data);
    PRPost *currentPost = [PRPost new];
    
    currentPost.post_uuid = data[@"uuid"];
    currentPost.post_id = data[@"id"];
    currentPost.post_description = ![data[@"description"] isKindOfClass:[NSNull class]] ? data[@"description"] : @"";
    currentPost.post_author = ![data[@"author"][@"username"] isKindOfClass:[NSNull class]] ?  data[@"author"][@"username"] : @"";
    currentPost.like_count = ![data[@"postlike"] isKindOfClass:[NSNull class]] ?  [data[@"postlike"] stringValue] : @"" ;
    currentPost.comment_count = ![data[@"comment_count"] isKindOfClass:[NSNull class]] ? [data[@"comment_count"] stringValue] : @"";
    currentPost.image_filename = ![data[@"image_filename"] isKindOfClass:[NSNull class]] ? data[@"image_filename"] : @"";
    currentPost.post_url = ![data[@"report_link"] isKindOfClass:[NSNull class]] ? data[@"report_link"] : @"";

    
    currentPost.isPrivate = ![data[@"is_private"] isKindOfClass:[NSNull class]] ? [data[@"is_private"] boolValue] : false;
    currentPost.isPublished = ![data[@"is_published"] isKindOfClass:[NSNull class]] ? [data[@"is_published"] boolValue] : false;
    
    NSString *rawImage = data[@"image"];
    if (![rawImage isKindOfClass:[NSNull class] ] && rawImage.length > 0) {
        NSString *selector = @"img src";
        if ([rawImage containsString:selector])
            currentPost.post_image = [NSURL URLWithString:[rawImage stripHTMLtag:selector]];
        else
            currentPost.post_image = [NSURL URLWithString:rawImage];
        
    }
    
    if (![data[@"image_thumbnail"] isKindOfClass:[NSNull class]] && data[@"image_thumbnail"]) {
        currentPost.post_thumbnail = [NSURL URLWithString:data[@"image_thumbnail"]];
    } else {
        currentPost.post_thumbnail = currentPost.post_image;
    }
    
    NSString *rawImageSource = data[@"image_source"];
    if (![rawImageSource isKindOfClass:[NSNull class] ] && rawImageSource.length > 0) {
        NSString *selector = @"img src";
        if ([rawImageSource containsString:selector])
            currentPost.post_image_source = [NSURL URLWithString:[rawImageSource stripHTMLtag:selector]];
        else
            currentPost.post_image_source = [NSURL URLWithString:rawImageSource];
    }
    
    NSString *videoString = ![data[@"video"] isKindOfClass:NSNull.class]? data[@"video"] : @"";
    currentPost.post_video = !videoString.isBlank? [NSURL URLWithString:videoString] : nil;
    
    NSDateFormatter *_dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSz"];
    currentPost.creation_date = ![data[@"created_at"] isKindOfClass:[NSNull class]] ? [_dateFormatter dateFromString:data[@"created_at"]] : [NSDate date];
    
    
    int contentType = ![data[@"content_type"] isKindOfClass:[NSNull class]] ? [data[@"content_type"] intValue] : 0;
    if (contentType == 1 && currentPost.hasVideo) {
        contentType = 2;
    }
    
    if (contentType == 0) {
        contentType = 1;
    }
    
    currentPost.contentType = (PRAssetType) contentType;
    
    return currentPost;
}


- (void)updateWithData:(NSDictionary *)data {
    
    _post_uuid = ![data[@"uuid"] isKindOfClass:[NSNull class]] && data[@"uuid"] ? data[@"uuid"] : _post_uuid;
    _post_id = ![data[@"id"] isKindOfClass:[NSNull class]] && data[@"id"] ? data[@"id"] : _post_id;
    _post_description = ![data[@"description"] isKindOfClass:[NSNull class]] ? data[@"description"] : _post_description;
    _post_author = ![data[@"author"][@"username"] isKindOfClass:[NSNull class]] ?  data[@"author"][@"username"] : _post_author;
    _like_count = ![data[@"postlike"] isKindOfClass:[NSNull class]] ?  [data[@"postlike"] stringValue] : _like_count ;
    _comment_count = ![data[@"comment_count"] isKindOfClass:[NSNull class]] ? [data[@"comment_count"] stringValue] : _comment_count;
    _image_filename = ![data[@"image_filename"] isKindOfClass:[NSNull class]] ? data[@"image_filename"] : _image_filename;
    _post_url = ![data[@"report_link"] isKindOfClass:[NSNull class]] ? data[@"report_link"] : _post_url;
    
    
    
    _isPrivate = data[@"is_private"] ? [data[@"is_private"] boolValue] : _isPrivate;
    _isPublished = data[@"is_published"] ? [data[@"is_published"] boolValue] : _isPublished;
    
    NSString *rawImage = data[@"image"];
    
    if (![rawImage isKindOfClass:[NSNull class] ] && rawImage.length > 0) {
        
        NSError *err;
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"img src=\"([^\"]*)\""
                                      options:NSRegularExpressionCaseInsensitive
                                      error:&err];
        NSTextCheckingResult *m = [regex firstMatchInString:rawImage options:0 range:NSMakeRange(0, rawImage.length)];
        
        if (!NSEqualRanges(m.range, NSMakeRange(NSNotFound, 0))) {
            _post_image = [NSURL URLWithString:[rawImage substringWithRange:[m rangeAtIndex:1]]];
        }
    }
    
    if (![data[@"image_thumbnail"] isKindOfClass:[NSNull class]] && data[@"image_thumbnail"]) {
        _post_thumbnail = [NSURL URLWithString:data[@"image_thumbnail"]];
    }
    
    
    _post_video = ![data[@"video"] isKindOfClass:[NSNull class]]? [NSURL URLWithString:data[@"video"]] : _post_video;
    
    NSDateFormatter *_dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSz"];
    _creation_date = [_dateFormatter dateFromString:data[@"created_at"]];
    
    
    int contentType = ![data[@"content_type"] isKindOfClass:[NSNull class]] ? [data[@"content_type"] intValue] : _contentType;
    if (contentType == 0 && [self hasVideo]) {
        contentType = 2;
    }
    
    if (contentType == 0) {
        contentType = 1;
    }
    
    _contentType = (PRAssetType) contentType;
    
}


+ (instancetype)createWithAsset:(PRAsset *)asset {
    PRPost *currentPost = [PRPost new];
    currentPost.post_asset = asset;
    currentPost.image_filename = asset.phAsset.localIdentifier;
    return  currentPost;
}


#pragma mark -
#pragma mark - Getters

- (PRAssetType)contentType {
    if (self.post_asset) {
        _contentType = self.post_asset.assetType;
    }
    return _contentType;
}

- (BOOL)hasVideo {
    BOOL status = _post_video != nil;
    status = status && _post_video.absoluteString.isBlank? !_post_video.absoluteString.isBlank : status;
    if (_post_asset != nil) status = _post_asset.hasVideo;
    return status;
}

- (BOOL)isStaticImage {
    return self.contentType != PRVideos && self.contentType != PRGIFs;
}

- (NSString*)contentTypeToString {
    NSString *type;
    switch (_contentType) {
        case PRGIFs:
            type = @"image/gif";
            break;
        case PRImages:
        case PRScreenshots:
            type = @"image/jpg";
            break;
        case PRVideos:
            type = @"video/mpa";
            break;
        default:
            break;
    }
    
    return type;
}



#pragma mark -
#pragma mark - Setters

- (void)setPost_asset:(PRAsset *)post_asset {
    _post_asset = post_asset;
    _image_filename = post_asset.phAsset.localIdentifier;
}

-(void)incrementLike:(NSString *)like_count {
    self.like_count = like_count;
}

-(void)upvoted:(BOOL)did_upvote {
    self.didUpvote = did_upvote;
}

-(void)setPost_description:(NSString *)post_description {
    _post_description = post_description;
}

-(void)setPost_url:(NSString *)post_url {
    _post_url = post_url;
}

- (NSString *)description {
    return [NSString stringWithFormat: @"Post: title=%@ uuid=%@ videoPath=%@ post_video=%@ _post_video_length %li isVideo=%@ blank %i", _post_description, _post_uuid, _videoPath, _post_video, (unsigned long)_post_video.absoluteString.length, NSStringFromBool(self.hasVideo), _post_video.absoluteString.isBlank];
}

- (void)setIsProcessed:(BOOL)isProcessed {
    _isProcessed = isProcessed;
}

- (void)setImage_filename:(NSString *)image_filename {
    _image_filename = image_filename;
}

- (void)setIsPrivate:(BOOL)isPrivate {
    _isPrivate = isPrivate;
}

- (void)setIsPublished:(BOOL)isPublished {
    _isPublished = isPublished;
}


@end
