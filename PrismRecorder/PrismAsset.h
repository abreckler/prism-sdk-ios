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

typedef void (^PRAssetGetImage)(UIImage *image);
typedef void (^PRAssetGetImageData)(NSData *imageData);
typedef void (^PRAssetGetAssetURL)(NSString *assetURL);
typedef void (^PRAssetGetVideoAsset)(AVAsset *avasset);
typedef void (^PRAssetGetPlayer)(AVPlayerItem *player);

@interface PrismAsset : NSObject

@property (nonatomic, strong, readonly) PHAsset *phAsset;
@property (nonatomic, strong) NSDictionary *textAttributes;
@property (nonatomic) PrismAssetType assetType;
@property BOOL shouldDelete;

- (id)initWithPHAsset:(PHAsset*)asset;
- (id)initWithImageData:(NSData*)imageData andType:(PrismAssetType)assetType;
- (id)initWithFile:(NSURL*)file andType:(PrismAssetType)assetType;
- (void)setCachedAVAsset:(AVAsset *)cachedAVAsset;

- (void)getThumbnail:(PRAssetGetImage)result size:(CGSize)size;
- (void)getOriginalImageData:(PRAssetGetImageData)result;
- (void)getAssetURL:(PRAssetGetAssetURL)completion;
- (void)getAssetVideo:(PRAssetGetVideoAsset)completion;
- (void)getPlayerForVideo:(PRAssetGetPlayer)completion;
- (NSDate*)creationDate;
- (BOOL)hasVideo;

@end
