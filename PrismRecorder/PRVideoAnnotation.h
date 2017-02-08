//
//  PRVideoAnnotation.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <UIKit/UIKit.h>
@import AVFoundation;

@protocol PRVideoAnnotationDelegate<NSObject>
- (void)handleTap;
@end

@interface PRVideoAnnotation : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, weak) id <PRVideoAnnotationDelegate> tapDelegate;
@property (nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic) BOOL enabled;

- (void)updateUIWithRecordingState:(BOOL)recordingState;
- (void)setProgress:(CGFloat)newProgress;
- (void)initialScaleDone;

@end
