//
//  PRPhotosUtils.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRPhotosUtils.h"
#import "PrismRecorder.h"
#import "PrismAsset.h"
#import "PRConstants.h"

@interface PRPhotosUtils() <PHPhotoLibraryChangeObserver>
@property (nonatomic) id <PRAssetsProtocol> assetsDataSource;
@property (strong) PHFetchResult *assetsFetchResults;
@property (strong) PHCachingImageManager *imageManager;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic) PrismAssetType assetsType;
@end


static NSString * const ReplaceIdentifier = @"io.prism.recorder";

@implementation PRPhotosUtils

- (instancetype)init {
    self = [super init];
    
    if ([self photosPermission] ) {
        self.imageManager = [[PHCachingImageManager alloc] init];
        [self initLibrary];
    }

    return self;
}


- (void)initLibrary {
    BLog();
    _assetsType = PRAllAssets;
    
    self.assetsFetchResults =  [PHAsset fetchAssetsWithOptions:[self assetsFetchOptions]];
    
    NSMutableArray *assetsResult = [[NSMutableArray alloc] init];
    [_assetsFetchResults enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx2, BOOL *stop2) {
        [assetsResult addObject:[[PrismAsset alloc] initWithPHAsset:asset]];
    }];
    
    self.assetsDataSource = [[PRAssetsDataSource alloc] initWithAssets:assetsResult];
    
}

- (void)registerChangeObserver {
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)unregisterChangeObserver {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

#pragma mark - Photos library

- (void)requestLibraryAccessHandler:(PRPhotoLibraryAccessHandler)handler {
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        //     NSLog(@"requestLibraryAccessHandler");
        [self executeInMainThread:^{
            if (handler) handler([self permissionStatusFromPH:status]);
        }];
    }];
    
}

- (void)getImagesWithBlock:(PRPhotoLibraryGetImagesBlock)success {
    
    [self.queue addOperationWithBlock:^{
        
        PRPhotoLibraryPermissionStatus status = [self permissionStatus];
        
        if (status == PRPhotoLibraryPermissionStatusGranted) {
            
            NSMutableArray *assetsResult = [[NSMutableArray alloc] init];
            
            self.assetsFetchResults =  [PHAsset fetchAssetsWithOptions:[self assetsFetchOptions]];
            
            [_assetsFetchResults enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx2, BOOL *stop2) {
                
                BOOL valid = _assetsType != PRGIFs && _assetsType != PRImages;
                if (!valid) {
                    NSString *fileName = [asset valueForKey:@"filename"];
                    NSString * fileExtension = fileName.pathExtension;
                    valid = [fileExtension.lowercaseString isEqualToString:@"gif"];
                    valid = _assetsType == PRImages ? !valid : valid; //remove gifs from images
                }
                
                
                if (valid) {
                    [assetsResult addObject:[[PrismAsset alloc] initWithPHAsset:asset]];
                }
                
                
            }];
            
            self.assetsDataSource = [[PRAssetsDataSource alloc] initWithAssets:assetsResult];
            
            [self executeInMainThread:^{
                if (success) success(assetsResult);
            }];
            
        }
        else {
            
            [self executeInMainThread:^{
                if (success) success(nil);
            }];
        }
        
    }];
}

- (void)getLatestAssetForType:(PrismAssetType)type andBlock:(PRPhotoLibraryGetLatestAssetBlock)completion {
    
    [self.queue addOperationWithBlock:^{
        
        PRPhotoLibraryPermissionStatus status = [self permissionStatus];
        
        if (status == PRPhotoLibraryPermissionStatusGranted) {
            _assetsType = type;
            PHFetchOptions *options = [self assetsFetchOptions];
//            options.fetchLimit = 1;
            self.assetsFetchResults =  [PHAsset fetchAssetsWithOptions:options];
//            BLog(@"%li", (unsigned long)self.assetsFetchResults.count);
            PHAsset *latest = self.assetsFetchResults.firstObject;
            
            if (!latest.hidden) {
                [self executeInMainThread:^{
                    if (completion) completion([[PrismAsset alloc] initWithPHAsset:latest]);
                }];
            }
        }
        else {
            [self executeInMainThread:^{
                if (completion) completion(nil);
            }];
        }
        
    }];
}

- (NSInteger)getImagesCount {
    return _assetsFetchResults.count;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    // Call might come on any background queue. Re-dispatch to the main queue to handle it.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (_assetsFetchResults.count == 0) {
            _assetsType = PRVideos;
            self.assetsFetchResults = [PHAsset fetchAssetsWithOptions:[self assetsFetchOptions]];
        }
        
        PHFetchResultChangeDetails *libraryChanges = [changeInstance changeDetailsForFetchResult:self.assetsFetchResults];
        //        NSLog(@"collection changes %@", screenshotChanges);
        //        NSLog(@"fetch count %i", self.screenshotsFetchResults.count);
        
        
        if ( libraryChanges.hasIncrementalChanges) {
            
            [self getLatestAssetForType:_assetsType andBlock:^(PrismAsset *prismAsset) {
                
                if (prismAsset) {
                    // get the new fetch result
                    self.assetsFetchResults = [libraryChanges fetchResultAfterChanges];
                    
                    [prismAsset getAssetVideo:^(AVAsset *avasset) {
                        AVURLAsset *urlasset = (AVURLAsset*)avasset;
                        [[PrismRecorder sharedManager] setRecordingPath:urlasset.URL.absoluteString];
                    }];
                    
                }
            }];
            
        }
        
    });
}





#pragma mark - Getters

- (NSOperationQueue *)queue {
    if (!_queue) {
        _queue = [[NSOperationQueue alloc] init];
    }
    return _queue;
}


- (PHFetchOptions *) assetsFetchOptions {
    
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    switch (_assetsType) {
        case PRVideos:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
            break;
        case PRImages:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d && pixelWidth != %f && pixelHeight != %f", PHAssetMediaTypeImage, screenSize.width * screenScale, screenSize.height * screenScale];
            break;
        case PRScreenshots:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d && pixelWidth == %f && pixelHeight == %f", PHAssetMediaTypeImage, screenSize.width * screenScale, screenSize.height * screenScale];
            break;
        case PRGIFs:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
            break;
        default:
            break;
    }
    
    return options;
}

- (PHFetchOptions *) screenshotsFetchOptions {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d && pixelWidth == %f && pixelHeight == %f", PHAssetMediaTypeImage, screenSize.width * screenScale, screenSize.height * screenScale];
    return options;
}



#pragma mark - Helpers

- (void)resetCachedAssets
{
    PRPhotoLibraryPermissionStatus status = [self permissionStatus];
    
    if (status == PRPhotoLibraryPermissionStatusGranted) {
        [self.imageManager stopCachingImagesForAllAssets];
    }
}

- (BOOL)photosPermission {
    return [PHPhotoLibrary authorizationStatus] == 3;
}

- (PRPhotoLibraryPermissionStatus)permissionStatus {
    return [self permissionStatusFromPH:    [PHPhotoLibrary authorizationStatus]  ];
}

- (PRPhotoLibraryPermissionStatus)permissionStatusFromPH:(PHAuthorizationStatus)status {
    if (status == PHAuthorizationStatusAuthorized) return PRPhotoLibraryPermissionStatusGranted;
    else if (status == PHAuthorizationStatusNotDetermined) return PRPhotoLibraryPermissionStatusPending;
    else return PRPhotoLibraryPermissionStatusDenied;
}

- (void)executeInMainThread:(VoidBlock)block {
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}


- (void)dealloc
{
  // [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

@end
