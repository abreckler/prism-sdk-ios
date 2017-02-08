//
//  UIWindow+Prism.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/8/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <objc/runtime.h>
#import "UIWindow+Prism.h"
#import "PrismRecorder.h"

@implementation UIWindow (Prism)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(motionEnded:withEvent:);
        SEL swizzledSelector = @selector(prismRecorder_motionEnded:withEvent:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        // When swizzling a class method, use the following:
        // Class class = object_getClass((id)self);
        // ...
        // Method originalMethod = class_getClassMethod(class, originalSelector);
        // Method swizzledMethod = class_getClassMethod(class, swizzledSelector);
        
        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}


- (void)prismRecorder_motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [super motionEnded:motion withEvent:event];
    
    if (event.subtype == UIEventSubtypeMotionShake)
    {
        [[PrismRecorder sharedManager] handleShakeMotion];
    }
}




@end
