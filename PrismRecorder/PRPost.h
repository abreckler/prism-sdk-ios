//
//  PRPost.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PRAsset.h"


@interface PRPost : NSObject

@property (nonatomic, copy, readonly) NSString *post_id;
@property (nonatomic, copy, readonly) NSString *post_uuid;
@property (nonatomic, copy, readonly) NSURL *post_image;
@property (nonatomic, copy, readonly) NSURL *post_thumbnail;
@property (nonatomic, copy, readonly) NSURL *post_image_source;
@property (nonatomic, copy, readonly) NSURL *post_video;
@property (nonatomic, copy, readonly) NSString *post_description;
@property (nonatomic, copy, readonly) NSString *post_author;
@property (nonatomic, copy, readonly) NSString *like_count;
@property (nonatomic, copy, readonly) NSString *comment_count;
@property (nonatomic, copy, readonly) NSDate *creation_date;
@property (nonatomic, copy, readonly) NSString *image_filename;
@property (nonatomic, copy, readonly) NSString *post_url;
@property (nonatomic, readonly) PRAssetType contentType;
@property (nonatomic, readonly) BOOL isPrivate;
@property (nonatomic, readonly) BOOL isProcessed;
@property (nonatomic, readonly) BOOL isPublished;
@property (nonatomic, copy) PRAsset *post_asset;
@property (nonatomic) UIImage *finalImage;
@property (nonatomic) NSData *finalData;
@property (nonatomic) UIImage *originalImage;
@property (nonatomic) NSString *videoPath;

+ (instancetype)initWithData:(NSDictionary *)data;
+ (instancetype)createWithAsset:(PRAsset *)asset;


//Setters
- (void)updateWithData:(NSDictionary *)data;
- (void)setIsPrivate:(BOOL)isPrivate;
- (void)setIsProcessed:(BOOL)isProcessed;
- (void)setIsPublished:(BOOL)isPublished;

//Getters
- (BOOL)hasVideo;
- (BOOL)isStaticImage;
- (NSString*)contentTypeToString;

@end
