//
//  PRAsset.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PrismAsset.h"
#import "PRPhotosUtils.h"
#import "PRConstants.h"

@interface PrismAsset ()

@property (nonatomic, strong) UIImage *cachedThumbnail;
@property (nonatomic, strong) NSData *cachedData;
@property (nonatomic, strong) AVAsset *cachedAVAsset;
@property (nonatomic, strong) PHAsset *phAsset;
@property (nonatomic) PRPhotosUtils *library;

@end

@implementation PrismAsset


- (id)initWithPHAsset:(PHAsset *)asset {
    self = [super init];
    if (self) {
        self.phAsset = asset;
        switch (asset.mediaType) {
            case PHAssetMediaTypeImage:
            {
                self.assetType = PRImages;
                if ((asset.pixelWidth == screenSize.width * screenScale) && (asset.pixelHeight == screenSize.height * screenScale)) {
                    self.assetType = PRScreenshots;
                }
                
                NSString *fileName = [asset valueForKey:@"filename"];
                NSString * fileExtension = fileName.pathExtension;
                if([fileExtension.lowercaseString isEqualToString:@"gif"]) {
                    self.assetType = PRGIFs;
                }
                
            }
                break;
            case PHAssetMediaTypeVideo:
                self.assetType = PRVideos;
                break;
            default:
                self.assetType = PRAllAssets;
                break;
        }
    }
    return self;
}

- (id)initWithFile:(NSURL*)file andType:(PrismAssetType)assetType {
    self = [super init];
    if (self) {
        self.cachedThumbnail = [UIImage imageWithContentsOfFile:file.path];
        self.cachedData = [NSData dataWithContentsOfFile:file.path];
        self.assetType = assetType;
    }
    return self;
}

- (id)initWithImageData:(NSData*)imageData andType:(PrismAssetType)assetType {
    self = [super init];
    if (self) {
        self.cachedThumbnail = [UIImage imageWithData:imageData];
        self.cachedData = imageData;
        self.assetType = assetType;
    }
    return self;
}

- (void)getThumbnail:(PRAssetGetImage)result size:(CGSize)size {
    
    VoidBlock returnBlock = ^{
        if (result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                result(self.cachedThumbnail);
            });
        }
    };
    
    
    if (self.cachedThumbnail == nil) {
        
        [self.library.queue addOperationWithBlock:^{
            
            PHImageManager *manager = [PHImageManager defaultManager];
            [manager requestImageForAsset:self.phAsset targetSize:size contentMode:PHImageContentModeAspectFill options:[self PHResizeOptions] resultHandler:^(UIImage *image, NSDictionary *info) {
                self.cachedThumbnail = image;
                //                    BLog(@"info %@", info);
                returnBlock();
            }];
        }];
        
    }
    else {
        returnBlock();
    }
    
}

- (void)getAssetURL:(PRAssetGetAssetURL)completion {
    
    [self.library.queue addOperationWithBlock:^{
        [[PHImageManager defaultManager] requestImageDataForAsset:self.phAsset options:nil resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            //         NSLog(@"dict %@", info);
            NSURL *assetURL = info[@"PHImageFileURLKey"];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(assetURL.absoluteString);
            });
        }];
    }];
}

- (void)getAssetVideo:(PRAssetGetVideoAsset)completion {
    
    VoidBlock returnBlock = ^{
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(self.cachedAVAsset);
            });
        }
    };
    
    if (self.cachedAVAsset == nil) {
        
        [self.library.queue addOperationWithBlock:^{
            [[PHImageManager defaultManager] requestAVAssetForVideo:self.phAsset options:[self videoRequestOptions] resultHandler:^(AVAsset * avasset, AVAudioMix * audioMix, NSDictionary * info) {
                //            NSLog(@"dict %@", info);
                //            NSLog(@"localID %@", self.phAsset.localIdentifier);
                self.cachedAVAsset = avasset;
                returnBlock();
            }];
        }];
    } else {
        returnBlock();
    }
    
}



- (void)getPlayerForVideo:(PRAssetGetPlayer)completion {
    
    [self.library.queue addOperationWithBlock:^{
        [[PHImageManager defaultManager] requestPlayerItemForVideo:self.phAsset options:nil resultHandler:^(AVPlayerItem *playerItem, NSDictionary *info) {
            //        NSLog(@"dict %@", info);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(playerItem);
            });
        }];
    }];
    
}



- (void)getOriginalImageData:(PRAssetGetImageData)result {
    
    VoidBlock returnBlock = ^{
        if (result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                result(self.cachedData);
            });
        }
    };
    
    if (self.cachedData == nil) {
        [self.library.queue addOperationWithBlock:^{
            [[PHImageManager defaultManager] requestImageDataForAsset:self.phAsset options:[self PHResizeOptions] resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                self.cachedData = imageData;
                returnBlock();
            }];
        }];
    } else {
        returnBlock();
    }
}

- (BOOL)hasVideo {
    return self.assetType == PRVideos;
}

- (void)setCachedAVAsset:(AVAsset *)cachedAVAsset {
    _cachedAVAsset = cachedAVAsset;
}


- (PRPhotosUtils*)library {
    if (!_library) {
         _library = [[PRPhotosUtils alloc] init];
    }
    return  _library;
}

#pragma mark - MetaData

- (NSDate*)creationDate {
    
    return self.phAsset.creationDate;
}

#pragma mark - PHOptions resize

- (PHImageRequestOptions*)PHResizeOptions {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    [options setDeliveryMode:PHImageRequestOptionsDeliveryModeHighQualityFormat];
    // [options setResizeMode:PHImageRequestOptionsResizeModeExact];
    options.networkAccessAllowed = YES;
    return options;
}



- (PHVideoRequestOptions*)videoRequestOptions {
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    options.version = PHVideoRequestOptionsVersionCurrent;
    options.networkAccessAllowed = YES;
    return options;
}


@end
