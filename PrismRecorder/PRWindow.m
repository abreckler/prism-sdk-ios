//
//  PRWindow.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/8/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRWindow.h"
#import "PrismRecorder.h"

@implementation PRWindow

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [super motionEnded:motion withEvent:event];
    
    if (event.subtype == UIEventSubtypeMotionShake)
    {
        [[PrismRecorder sharedManager] handleShakeMotion];
    }
}

@end
