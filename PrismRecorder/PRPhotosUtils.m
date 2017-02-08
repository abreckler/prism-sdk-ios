//
//  PRPhotosUtils.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRPhotosUtils.h"
#import "PrismAsset.h"
#import "PRConstants.h"

@interface PRPhotosUtils() // <PHPhotoLibraryChangeObserver>
@property (strong) PHFetchResult *assetsFetchResults;
@property (strong) PHFetchResult *screenshotsFetchResults;
@property (strong) PHCachingImageManager *imageManager;
@property (nonatomic, strong) NSOperationQueue *queue;
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
    
    _assetsType = PRScreenshots;
    
    self.assetsFetchResults =  [PHAsset fetchAssetsWithOptions:[self assetsFetchOptions]];
    self.screenshotsFetchResults = [PHAsset fetchAssetsWithOptions:[self screenshotsFetchOptions]];
    
    NSMutableArray *assetsResult = [[NSMutableArray alloc] init];
    [_assetsFetchResults enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx2, BOOL *stop2) {
        [assetsResult addObject:[[PrismAsset alloc] initWithPHAsset:asset]];
    }];
    
    self.assetsDataSource = [[PRAssetsDataSource alloc] initWithAssets:assetsResult];
    
//    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    
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

- (void)getLatestAssetWithBlock:(PRPhotoLibraryGetLatestAssetBlock)completion {
    
    [self.queue addOperationWithBlock:^{
        
        PRPhotoLibraryPermissionStatus status = [self permissionStatus];
        
        if (status == PRPhotoLibraryPermissionStatusGranted) {
            
            self.screenshotsFetchResults =  [PHAsset fetchAssetsWithOptions:[self screenshotsFetchOptions]];
            
            PHAsset *latest = _screenshotsFetchResults.firstObject;
            
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

- (void)getLatestScreenshotWithBlock:(PRPhotoLibraryGetLatestAssetBlock)completion {
    
    [self.queue addOperationWithBlock:^{
        
        PRPhotoLibraryPermissionStatus status = [self permissionStatus];
        
        if (status == PRPhotoLibraryPermissionStatusGranted) {
            
            self.screenshotsFetchResults =  [PHAsset fetchAssetsWithOptions:[self screenshotsFetchOptions]];
            
            PHAsset *latest = _assetsFetchResults.firstObject;
            
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



- (void)deleteAssetWithIdentifier:(NSString*)localId completion:(PRPhotoLibraryCompletionBlock)completion {
    PHFetchResult *fetchAsset = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest deleteAssets:fetchAsset];
    } completionHandler:^(BOOL success, NSError *error) {
        if (completion)
            completion(success);
    }];
}



- (NSInteger)getImagesCount {
    //  NSLog(@"screenshots count %li", (unsigned long)_assetsFetchResults.count);
    return _assetsFetchResults.count;
}


#pragma mark-
#pragma mark - Save to Library

- (void)saveImageToLibrary:(UIImage *)image completion:(PRPhotoLibraryCreationBlock)completion {
    
    __block PHObjectPlaceholder *placeholder;
    
    [self blinkAlbum:^(BOOL success, PHAssetCollection *blinkCollection, NSError *error) {
        
        if (success) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetCollectionChangeRequest *changeRequest;
                if ( [PHAssetResourceCreationOptions class] ) { //check if iOS9 and up
                    PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAssetFromImage:image];
                    placeholder = creationRequest.placeholderForCreatedAsset;
                } else {
                    PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                    placeholder = assetChangeRequest.placeholderForCreatedAsset;
                    
                }
                PHFetchResult *blinkAssets = [PHAsset fetchAssetsInAssetCollection:blinkCollection options:nil];
                changeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:blinkCollection assets:blinkAssets];
                [changeRequest addAssets:@[placeholder]];
                
            } completionHandler:^(BOOL success, NSError *error) {
                PrismAsset *savedAsset;
                if ( !success )
                    NSLog( @"Could not save Image to photo library: %@", error );
                else {
                    PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[placeholder.localIdentifier] options:nil];
                    savedAsset = [[PrismAsset alloc] initWithPHAsset:assetResult.firstObject];
                }
                if (completion)
                    completion(success, savedAsset, error);
            }];
        }
        else if (completion)
            completion(success, nil, error);
    }];
}

- (void)saveFileToLibrary:(NSURL *)fileURL completion:(PRPhotoLibraryCreationBlock)completion {
    __block PHObjectPlaceholder *placeholder;
    __block PHFetchResult *blinkAssets;
    
    dispatch_block_t cleanup = ^{
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    };
    
    [self blinkAlbum:^(BOOL success, PHAssetCollection *blinkCollection, NSError *error) {
        
        if (success) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                if ( [PHAssetResourceCreationOptions class] ) { //iOS 9 storage saving
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                    [creationRequest addResourceWithType:PHAssetResourceTypePhoto fileURL:fileURL options:options];
                    placeholder = creationRequest.placeholderForCreatedAsset;
                }
                else {
                    PHAssetChangeRequest *assetChangeRequest= [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];
                    placeholder = assetChangeRequest.placeholderForCreatedAsset;
                }
                
                
                blinkAssets = [PHAsset fetchAssetsInAssetCollection:blinkCollection options:nil];
                PHAssetCollectionChangeRequest *changeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:blinkCollection assets:blinkAssets];
                [changeRequest addAssets:@[placeholder]];
            } completionHandler:^( BOOL success, NSError *error ) {
                PrismAsset *savedAsset;
                if ( !success ) {
                    NSLog( @"Could not save file to photo library: %@", error );
                } else {
                    PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[placeholder.localIdentifier] options:nil];
                    savedAsset = [[PrismAsset alloc] initWithPHAsset:assetResult.firstObject];
                }
                if (completion)
                    completion(success, savedAsset, error);
                
                cleanup();
            }];
            
        } else {
            if (completion)
                completion(success, nil, error);
        }
    }];
}

- (void)saveVideoToLibrary:(NSURL *)videoURL completion:(PRPhotoLibraryCreationBlock)completion {
    
    __block PHObjectPlaceholder *placeholder;
    __block PHFetchResult *blinkAssets;
    
    dispatch_block_t cleanup = ^{
        [[NSFileManager defaultManager] removeItemAtURL:videoURL error:nil];
    };
    
    [self blinkAlbum:^(BOOL success, PHAssetCollection *blinkCollection, NSError *error) {
        
        if (success) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                
                if ( [PHAssetResourceCreationOptions class] ) { //iOS 9 storage saving
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                    [creationRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:videoURL options:options];
                    placeholder = creationRequest.placeholderForCreatedAsset;
                }
                else {
                    PHAssetChangeRequest *assetChangeRequest= [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
                    placeholder = assetChangeRequest.placeholderForCreatedAsset;
                }
                
                
                blinkAssets = [PHAsset fetchAssetsInAssetCollection:blinkCollection options:nil];
                PHAssetCollectionChangeRequest *changeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:blinkCollection assets:blinkAssets];
                [changeRequest addAssets:@[placeholder]];
            } completionHandler:^( BOOL success, NSError *error ) {
                PrismAsset *savedAsset;
                if ( !success ) {
                    NSLog( @"Could not save video to photo library: %@", error );
                } else {
                    PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[placeholder.localIdentifier] options:nil];
                    savedAsset = [[PrismAsset alloc] initWithPHAsset:assetResult.firstObject];
                }
                if (completion)
                    completion(success, savedAsset, error);
                
                cleanup();
            }];
            
        } else {
            NSLog( @"failed to get album error: %@", error );
            if (completion)
                completion(success, nil, error);
        }
    }];
}

- (void)replaceAssetInLibrary:(PrismAsset *)asset forAssetType:(PrismAssetType)assetType usingOptions:(NSDictionary*)replacementData completion:(PRPhotoLibraryCreationBlock)completion {
    
    // Only allow editing if the PHAsset supports edit operations and it is not a Live Photo.
    BLog(@"editable? %@", NSStringFromBool([asset.phAsset canPerformEditOperation:PHAssetEditOperationContent]));
    
    if ([asset.phAsset canPerformEditOperation:PHAssetEditOperationContent] && !(asset.phAsset.mediaSubtypes & PHAssetMediaSubtypePhotoLive)) {
        
        // Prepare the options to pass when requesting to edit the image.
        PHContentEditingInputRequestOptions *options = [[PHContentEditingInputRequestOptions alloc] init];
        
        [options setCanHandleAdjustmentData:^BOOL(PHAdjustmentData *adjustmentData) {
            return [adjustmentData.formatIdentifier isEqualToString:ReplaceIdentifier] && [adjustmentData.formatVersion isEqualToString:@"1.0"];
        }];
        
        
        [asset.phAsset requestContentEditingInputWithOptions:options completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
            
            
            // Create a PHAdjustmentData object that describes the change that was applied.
            PHAdjustmentData *adjustmentData = [[PHAdjustmentData alloc] initWithFormatIdentifier:ReplaceIdentifier formatVersion:@"1.0" data:[@"annotations" dataUsingEncoding:NSUTF8StringEncoding]];
            
            PHContentEditingOutput *contentEditingOutput = [[PHContentEditingOutput alloc] initWithContentEditingInput:contentEditingInput];
            contentEditingOutput.adjustmentData = adjustmentData;
            NSData *outputData;
            
            if (assetType == PRImages || assetType == PRScreenshots) {
                UIImage *image = replacementData[@"image"];
                outputData = UIImageJPEGRepresentation(image, 1);
            } else {
                outputData = [NSData dataWithContentsOfFile:replacementData[@"location"]];
            }
            
            BOOL wrote = [outputData writeToURL:contentEditingOutput.renderedContentURL options:NSDataWritingAtomic error:nil];
            BLog(@"wrote? %@", NSStringFromBool(wrote));
            if (wrote)
            {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetChangeRequest *request = [PHAssetChangeRequest changeRequestForAsset:asset.phAsset];
                    request.contentEditingOutput = contentEditingOutput;
                    
                } completionHandler:^(BOOL success, NSError *error) {
                    PrismAsset *savedAsset;
                    
                    BLog(@"saved? %@", NSStringFromBool(success));
                    
                    if (success) {
                        PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[asset.phAsset.localIdentifier] options:nil];
                        savedAsset = [[PrismAsset alloc] initWithPHAsset:assetResult.firstObject];
                    }
                    
                    if (completion)
                        completion(success, savedAsset, error);
                    
                    
                }];
            }
        }];
        
    }
}

- (void)revertAssetToOriginal:(PrismAsset *)asset completion:(PRPhotoLibraryCreationBlock)completion {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *request = [PHAssetChangeRequest changeRequestForAsset:asset.phAsset];
        [request revertAssetContentToOriginal];
    } completionHandler:^(BOOL success, NSError *error) {
        PrismAsset *savedAsset;
        
        BLog(@"reverted? %@", NSStringFromBool(success));
        
        if (success) {
            PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[asset.phAsset.localIdentifier] options:nil];
            savedAsset = [[PrismAsset alloc] initWithPHAsset:assetResult.firstObject];
        }
        
        if (completion)
            completion(success, savedAsset, error);
    }];
}

- (void)blinkAlbum:(PRPhotoLibraryAlbumCreationBlock)completion {
    __block PHAssetCollection *collection;
    __block PHObjectPlaceholder *placeholder;
    
    // Find the album
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"title = %@", @"Blink"];
    collection = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                          subtype:PHAssetCollectionSubtypeAny
                                                          options:fetchOptions].firstObject;
    // Create the album
    if (!collection)
    {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *createAlbum = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:@"Blink"];
            placeholder = [createAlbum placeholderForCreatedAssetCollection];
        } completionHandler:^(BOOL success, NSError *error) {
            
            if (!success) {
                NSLog(@"failed to create custom album %@", error.localizedDescription);
            }
            
            if (success)
            {
                PHFetchResult *collectionFetchResult = [PHAssetCollection
                                                        fetchAssetCollectionsWithLocalIdentifiers:@[placeholder.localIdentifier]
                                                        options:nil];
                collection = collectionFetchResult.firstObject;
                
            }
            
            if (completion) {
                completion (success, collection, error);
            }
        }];
        return;
    }
    
    if (completion) {
        completion (true, collection, nil);
    }
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
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO]];
    
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
