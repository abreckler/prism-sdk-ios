//
//  PRAssetsProtocol.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

@import UIKit;

@class PRAsset;

@protocol PRAssetsProtocolDelegate
@optional
-(void)reload;
@end


@protocol PRAssetsProtocol <NSObject>
@property (weak, nonatomic) id<PRAssetsProtocolDelegate> assetsDataSourceDelegate;
@property (nonatomic, readonly) NSUInteger assetsCount;

- (PRAsset *)assetAtIndex:(NSUInteger)assetIndex;
- (NSUInteger)indexOfAsset:(PRAsset*)asset;
- (BOOL)containsAsset:(PRAsset *)asset;
- (PRAsset *)objectAtIndexedSubscript:(NSUInteger)assetIndex;
@end
