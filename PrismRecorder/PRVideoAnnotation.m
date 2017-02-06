//
//  PRVideoAnnotation.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "PRVideoAnnotation.h"
#import "PRConstants.h"
#import "NSString+PrismUtils.h"

@interface PRVideoAnnotation()
@property (nonatomic) UILabel *recordingLabel;
@property (nonatomic) UILabel *instructionsLabel;
@property (nonatomic) NSDictionary *attributes;
@property (nonatomic) UITapGestureRecognizer *singleTapRecognizer;
@property (nonatomic) UIImageView *thumbnail;
@property (nonatomic) UIView *circlesView;
@property (nonatomic, strong) NSURL *outputFileURL;
@end

@implementation PRVideoAnnotation

CGFloat currentProgress;
CALayer *circleBorder;
UIImageView *audioBackground;
BOOL animate = true;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        _circlesView = [UIView new];
        _circlesView.frame = (CGRect){ CGPointZero, frame.size};
        [self addSubview:_circlesView];
        [self setDefaults];
    }
    return self;
}

- (void)setDefaults {
    self.layer.cornerRadius = self.frame.size.height / 2;
    self.layer.masksToBounds = YES;
    currentProgress = 0;
    [self drawBorder];
    [self setupLabel];
    _singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self addGestureRecognizer:_singleTapRecognizer];
}

- (void)setupLabel {
    _recordingLabel = [UILabel new];
    _recordingLabel.frame = (CGRect){0, 0, self.frame.size.width - 25, 20};
    _recordingLabel.textAlignment = NSTextAlignmentCenter;
    [self insertSubview:_recordingLabel aboveSubview:_circlesView];
    
    
    _instructionsLabel = [UILabel new];
    _instructionsLabel.frame = (CGRect){0, 0, self.frame.size.width, 20};
    _instructionsLabel.hidden = true;
    
    NSString *labelText = NSLocalizedString(@"tap to record", nil).uppercaseString;
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [UIColor blackColor];
    shadow.shadowOffset = CGSizeMake(0.2, 0.2);
    shadow.shadowBlurRadius = 1.25f;
    _attributes = @{NSForegroundColorAttributeName: [UIColor whiteColor],
                    NSFontAttributeName: [UIFont boldSystemFontOfSize:8.0f],
                    NSStrokeColorAttributeName:[UIColor blackColor],
                    NSStrokeWidthAttributeName: @-1,
                    NSShadowAttributeName: shadow,
                    NSParagraphStyleAttributeName:paragraphStyle
                    };
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:labelText attributes:_attributes];
    _instructionsLabel.attributedText = attributedString;
    [self insertSubview:_instructionsLabel aboveSubview:_circlesView];
    
}


- (void)layoutSubviews {
    _recordingLabel.frame = (CGRect){0, self.frame.size.height - 30, _recordingLabel.frame.size};
    _instructionsLabel.frame = (CGRect){0, CGRectGetMidY(self.bounds) + 15, _instructionsLabel.frame.size};
    [super layoutSubviews];
}


#pragma mark - Gestures

- (void)initialScaleDone
{
    [self setupPanGesture];
}

- (void)setupPanGesture {
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    panGR.delegate = self;
    [self addGestureRecognizer:panGR];
}

- (void)panned:(UIPanGestureRecognizer *)panGR
{
    if (_enabled) {
        //  BLog();
        CGPoint translation = [panGR translationInView:self.superview];
        panGR.view.center = CGPointMake(panGR.view.center.x + translation.x, panGR.view.center.y + translation.y);
        panGR.view.center = [self adjustedFrameForGesture:panGR];
        self.center = panGR.view.center;
        [panGR setTranslation:CGPointZero inView:self.superview];
    }
}

- (CGPoint)adjustedFrameForGesture:(UIGestureRecognizer*)gr {
    CGRect superBounds = self.superview.bounds;
    CGRect frame = [self.superview convertRect:self.bounds fromView:self];
    
    CGPoint grCenter = gr.view.center;
    
    if (!CGAffineTransformIsIdentity(self.transform))
        return grCenter;
    
    if (!CGRectEqualToRect(superBounds, CGRectZero)) {
        if (frame.origin.x < 0) grCenter = (CGPoint){frame.size.width / 2, grCenter.y};
        if (frame.origin.y < 0) grCenter = (CGPoint){grCenter.x, frame.size.height * 0.5};
        
    }
    
    return grCenter;
}



#pragma mark -
#pragma mark - Setters

- (void)setVideoThumbnail:(UIImage*)thumbnail {
    //   BLog();
    self.thumbnail = [UIImageView new];
    self.thumbnail.frame = (CGRect){ CGPointZero, self.frame.size};
    self.thumbnail.image = thumbnail;
    self.thumbnail.contentMode = UIViewContentModeScaleAspectFill;
    [self insertSubview:self.thumbnail aboveSubview:self.circlesView];
    
}

- (void)setProgress:(CGFloat)newProgress {
    
    currentProgress = newProgress;
    
    if (currentProgress == 0 && !_captureVideoPreviewLayer) {
        audioBackground.hidden = NO;
    }
    
    if (currentProgress >= 0) {
        [self updateLabelWithText:[self elapsedTime]];
    }
}

- (NSString*)elapsedTime {
    int  minutes, seconds;
    NSString *elapsedTime = @"";
    
    seconds = currentProgress;
    
    if (currentProgress > 60) {
        minutes = currentProgress / 60;
        seconds -= minutes * 60;
        elapsedTime = [NSString stringWithFormat:@"%02d", minutes];
    }
    
    elapsedTime = [elapsedTime stringByAppendingString:[NSString stringWithFormat:@"'%02d", seconds]];
    
    return  elapsedTime;
}


- (void)updateUIWithRecordingState:(BOOL)recordingState {
    // BLog(@"recording %@", NSStringFromBool(recordingState));
    
    _captureVideoPreviewLayer.hidden = !recordingState;
    
    if (!_captureVideoPreviewLayer) {
        audioBackground.hidden = !recordingState;
    }
    
    
    self.recordingLabel.hidden = !recordingState;
    self.instructionsLabel.hidden = self.instructionsLabel.hidden ? self.instructionsLabel.hidden : recordingState;
    
    if (animate) {
        CGAffineTransform start = recordingState? CGAffineTransformScale(CGAffineTransformIdentity, 0.001, 0.001) : CGAffineTransformIdentity;
        CGAffineTransform end = recordingState? CGAffineTransformIdentity:  CGAffineTransformScale(CGAffineTransformIdentity, 0.001, 0.001);
        circleBorder.hidden = !recordingState;
        self.transform = start;
        
        [UIView animateWithDuration:0.3/1.5 delay:0.0f usingSpringWithDamping:.8f initialSpringVelocity:1.f options:0 animations:^{
            self.transform = end;
        } completion:^(BOOL finished) {
            self.transform = CGAffineTransformIdentity;
        }];
    }
    
    [self layoutSubviews];
}

- (void)updateLabelWithText:(NSString*)text {
    NSString *labelText = text.uppercaseString;
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentRight;
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [UIColor blackColor];
    shadow.shadowOffset = CGSizeMake(0.2, 0.2);
    shadow.shadowBlurRadius = 1.25f;
    NSDictionary *attr = @{NSForegroundColorAttributeName: [UIColor whiteColor],
                           NSFontAttributeName: [UIFont boldSystemFontOfSize:14.0f],
                           NSStrokeColorAttributeName:[UIColor blackColor],
                           NSStrokeWidthAttributeName: @-1,
                           NSShadowAttributeName: shadow,
                           NSParagraphStyleAttributeName:paragraphStyle
                           };
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:labelText attributes:attr];
    _recordingLabel.attributedText = attributedString;
}

- (void)handleSingleTap:(UIGestureRecognizer *)recognizer {
    BLog();
    if (self.hasRecording) {
        self.thumbnail.hidden = true;
        return;
    }
    if (self.tapDelegate) {
        [self.tapDelegate handleTap];
    }
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    _recordingLabel.hidden =  _recordingLabel.hidden ?  _recordingLabel.hidden : !enabled;
    _singleTapRecognizer.enabled = enabled;
}

- (void)didFinishPlaying {
    self.thumbnail.hidden = false;
}

- (void)prepareForCapture {
    self.recordingLabel.hidden = YES;
}



#pragma mark -
#pragma mark - Circles

- (void)drawBorder {
    
    currentProgress = 0;
    // Get the root layer
    CALayer *layer = self.layer;
    
    CGRect circleFrame = CGRectMake(0, 0, self.bounds.size.width-.5f, self.bounds.size.height-.5f);
    
    circleBorder = [CALayer layer];
    circleBorder.backgroundColor = [UIColor clearColor].CGColor;
    circleBorder.borderWidth = 3;
    circleBorder.borderColor = [UIColor whiteColor].CGColor;
    circleBorder.hidden = true;
    circleBorder.bounds = circleFrame;
    circleBorder.anchorPoint = CGPointMake(0.5, 0.5);
    circleBorder.position = (CGPoint){CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds)};
    circleBorder.cornerRadius = self.frame.size.width/2;
    
    circleBorder.shadowColor = [UIColor blackColor].CGColor;
    circleBorder.shadowOpacity = 0.8;
    circleBorder.shadowRadius = 0.5;
    circleBorder.shadowOffset = CGSizeMake(0.0f, 0.0f);
    [layer insertSublayer:circleBorder above:_circlesView.layer];
    
    
    audioBackground = [[UIImageView alloc] initWithFrame:circleFrame];
    audioBackground.image = [UIImage imageNamed:@"blink_audio"];
    audioBackground.contentMode = UIViewContentModeCenter;
    audioBackground.hidden = true;
    audioBackground.backgroundColor = [UIColor whiteColor];
    audioBackground.layer.cornerRadius = audioBackground.frame.size.height / 2;
    [_circlesView.layer insertSublayer:audioBackground.layer atIndex:0];
}


#pragma mark -
#pragma mark - AVSession

- (void)setCaptureVideoPreviewLayer:(AVCaptureVideoPreviewLayer *)captureVideoPreviewLayer
{
    //    BLog();
    _captureVideoPreviewLayer = captureVideoPreviewLayer;
    _captureVideoPreviewLayer.frame = self.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _captureVideoPreviewLayer.hidden = false;
    [_circlesView.layer insertSublayer:_captureVideoPreviewLayer atIndex:0];
    
}


- (BOOL)hasRecording {
    if (!self.outputFileURL) {
        return NO;
    }
    return !self.outputFileURL.absoluteString.isBlank;
}


@end
