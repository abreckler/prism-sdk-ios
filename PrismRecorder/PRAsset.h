//
//  PRAsset.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

@import Foundation;
@import Photos;
#import "PRPhotosUtils.h"
@class VideoAnnotation;

typedef void (^PRAssetGetImage)(UIImage *image);
typedef void (^PRAssetGetImageData)(NSData *imageData);
typedef void (^PRAssetGetAssetURL)(NSString *assetURL);
typedef void (^PRAssetGetVideoAsset)(AVAsset *avasset);
typedef void (^PRAssetGetPlayer)(AVPlayerItem *player);

@interface PRAsset : NSObject

@property (nonatomic, strong, readonly) PHAsset *phAsset;
@property (nonatomic, strong) UIColor *cropColor;
@property (nonatomic, strong) UIColor *drawColor;
@property (nonatomic) CGFloat cropAlpha;
@property (nonatomic) CGFloat drawAlpha;
@property (nonatomic, strong) NSDictionary *textAttributes;
@property (nonatomic) CLLocationCoordinate2D coordinates;
@property (nonatomic, strong) NSArray *annotations;
@property (nonatomic) CGRect croppedRect;
@property (nonatomic) PRAssetType assetType;
@property (nonatomic) PRAssetType originalAssetType;
@property (nonatomic, readonly) VideoAnnotation *videoAnnotation;
@property BOOL isCropped;
@property BOOL shouldDelete;

- (id)initWithPHAsset:(PHAsset*)asset;
- (id)initWithImageData:(NSData*)imageData andType:(PRAssetType)assetType;
- (id)initWithFile:(NSURL*)file andType:(PRAssetType)assetType;
- (void)setCachedAVAsset:(AVAsset *)cachedAVAsset;

- (void)getThumbnail:(PRAssetGetImage)result size:(CGSize)size;
- (void)getOriginalImageData:(PRAssetGetImageData)result;
- (void)getAssetURL:(PRAssetGetAssetURL)completion;
- (void)getAssetVideo:(PRAssetGetVideoAsset)completion;
- (void)getPlayerForVideo:(PRAssetGetPlayer)completion;
- (NSDate*)creationDate;
- (BOOL)hasVideo;

@end
