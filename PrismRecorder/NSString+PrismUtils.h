//
//  NSString+PrismUtils.h
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PrismUtils)
- (BOOL)isBlank;
- (BOOL)contains:(NSString *)string;
- (NSArray *)splitOnChar:(char)ch;
- (NSString *)substringFrom:(NSInteger)from to:(NSInteger)to;
- (NSString *)stringByStrippingWhitespace;
- (NSString *)getElapsedTimeSince:(NSDate*)date;
- (NSString *)stripURL;
- (NSString*)stripHTMLtag:(NSString*)selector;
@end
