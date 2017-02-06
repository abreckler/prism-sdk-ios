//
//  PRConstants.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#ifdef DEBUG
#define BLog(formatString, ...) NSLog((@"^ %s " formatString), __PRETTY_FUNCTION__, ##__VA_ARGS__);
#else
#define BLog(xx, ...)  ((void)0)
#endif

#define NSStringFromBool(b) (b ? @"YES" : @"NO")
#define UA_SHOW_VIEW_BORDERS YES
#define UA_showDebugBorderForViewColor(view) if (UA_SHOW_VIEW_BORDERS) { view.layer.borderColor = [UIColor redColor].CGColor; view.layer.borderWidth = 1.0; }
#define UA_showDebugBorderForView(view) UA_showDebugBorderForViewColor(view)

#define screenSize  [[UIScreen mainScreen] bounds].size
#define screenScale [[UIScreen mainScreen] scale]
#define AspectRatio   (roundf ((UIScreen.mainScreen.bounds.size.height / UIScreen.mainScreen.bounds.size.width) * 100) / 100.0)
#define MULTIPLIER (CGRectGetHeight(UIScreen.mainScreen.bounds) > 568 ? 0.72 : 0.65)
#define ASSET_SIZE_LIMIT 12 //in MB


#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
