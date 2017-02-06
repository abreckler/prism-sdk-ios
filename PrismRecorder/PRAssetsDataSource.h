//
//  PRAssetsDataSource.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PRAssetsProtocol.h"

@interface PRAssetsDataSource : NSObject<PRAssetsProtocol>
@property (weak, nonatomic) id<PRAssetsProtocolDelegate> assetsDataSourceDelegate;
- (instancetype)initWithAssets:(NSArray *)assets;
@end
