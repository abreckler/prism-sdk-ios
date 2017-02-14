//
//  PRPhotosUtils.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//
#import <Foundation/Foundation.h>
@import Photos;
#import "PRAssetsDataSource.h"
@class PrismAsset;

typedef void (^VoidBlock)();
typedef enum {
    PRPhotoLibraryPermissionStatusDenied = 0,
    PRPhotoLibraryPermissionStatusPending,
    PRPhotoLibraryPermissionStatusRestricted,
    PRPhotoLibraryPermissionStatusGranted
} PRPhotoLibraryPermissionStatus;


typedef NS_ENUM(NSInteger, PrismAssetType)  {
    PRAllAssets,
    PRScreenshots,
    PRVideos,
    PRImages,
    PRGIFs,
    PRWebRecording
};


typedef void (^PRPhotoLibraryAccessHandler)(PRPhotoLibraryPermissionStatus status);
typedef void (^PRPhotoLibraryGetImagesBlock)(NSArray *assets);
typedef void (^PRPhotoLibraryGetLatestAssetBlock)(PrismAsset *asset);
typedef void (^PRPhotoLibraryCompletionBlock)(BOOL success);
typedef void (^PRPhotoLibraryCreationBlock)(BOOL success, PrismAsset *asset, NSError *error);
typedef void (^PRPhotoLibraryAlbumCreationBlock)(BOOL success, PHAssetCollection *assetCollection, NSError *error);

@interface PRPhotosUtils : NSObject

// Permissions
- (PRPhotoLibraryPermissionStatus)permissionStatus;
- (void)requestLibraryAccessHandler:(PRPhotoLibraryAccessHandler)handler;
- (BOOL)photosPermission;

//Library
- (void)initLibrary;
- (void)registerChangeObserver;
- (void)unregisterChangeObserver;
- (void)getImagesWithBlock:(PRPhotoLibraryGetImagesBlock)success;
- (void)getLatestAssetForType:(PrismAssetType)type andBlock:(PRPhotoLibraryGetLatestAssetBlock)completion;


- (NSOperationQueue *)queue;

@end
