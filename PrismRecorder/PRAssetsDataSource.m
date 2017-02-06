//
//  PRAssetsDataSource.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRAssetsDataSource.h"

@interface PRAssetsDataSource ()

@property (nonatomic, copy) NSArray *assets;

@end

@implementation PRAssetsDataSource

#pragma mark - NSObject

- (instancetype)init {
    return [self initWithAssets:nil];
}

#pragma mark - PRAssetsDataSource

- (instancetype)initWithAssets:(NSArray *)assets {
    self = [super init];
    
    if (self) {
        _assets = assets;
    }
    
    return self;
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)length {
    return [self.assets countByEnumeratingWithState:state objects:buffer count:length];
}

#pragma mark -

- (NSUInteger)assetsCount {
    return self.assets.count;
}

- (PRAsset *)assetAtIndex:(NSUInteger)assetIndex {
    if (assetIndex < self.assets.count) {
        return self.assets[assetIndex];
    }
    
    return nil;
}

- (NSUInteger)indexOfAsset:(PRAsset *)asset {
    return [self.assets indexOfObject:asset];
}

- (BOOL)containsAsset:(PRAsset *)asset {
    return [self.assets containsObject:asset];
}

- (PRAsset *)objectAtIndexedSubscript:(NSUInteger)assetIndex {
    return [self assetAtIndex:assetIndex];
}

@end

