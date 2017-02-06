//
//  NSString+PrismUtils.m
//  PrismRecorder
//
//  Created by Ahmed Bouchfaa on 2/6/17.
//  Copyright © 2017 prism. All rights reserved.
//

#import "NSString+PrismUtils.h"

@implementation NSString (PrismUtils)

- (BOOL)isBlank {
    if([[self stringByStrippingWhitespace] isEqualToString:@""] || [self stringByStrippingWhitespace].length == 0)
        return YES;
    return NO;
}

- (BOOL)contains:(NSString *)string {
    NSRange range = [self rangeOfString:string];
    return (range.location != NSNotFound);
}

- (NSString *)stringByStrippingWhitespace {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)stripURL {
    NSURL *url = [NSURL URLWithString:self];
    NSString *noScheme = [self stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@://",url.scheme] withString:@""];
    NSString *noWWW = [noScheme stringByReplacingOccurrencesOfString:@"www." withString:@""];
    return  noWWW;
}

- (NSString *)getElapsedTimeSince:(NSDate*) date {
    
    NSCalendar *gregorian = [[NSCalendar alloc]initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger units = NSCalendarUnitYear | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitHour | NSCalendarUnitMinute;
    
    
    NSString *elapsed = @"";
    
    //  if (date != nil) {
    NSDateComponents *components = [gregorian components:units fromDate:date toDate:[NSDate date] options:0];
    
    NSInteger years = [components year];
    NSInteger months = [components month];
    NSInteger days = [components day];
    NSInteger hours = [components hour];
    NSInteger minutes = [components minute];
    
    NSInteger time = years > 0 ? years : months > 0 ? months : days > 0 ? days : hours > 0 ? hours : minutes > 0 ? minutes : -1;
    NSString *unit = years > 0 ? @"year" : months > 0 ? @"month" : days > 0 ? @"day" : hours > 0 ? @"hour" : @"minute";
    
    elapsed = time > 1 ? [NSString stringWithFormat:@"%li %@ ago", (long)time, [unit pluralize]] : time > 0 ? [NSString stringWithFormat:@"%li %@ ago", (long)time, unit] : @"Just now";
    //}
    
    return elapsed;
}

- (NSString *)pluralize {
    return [self stringByAppendingString:@"s"];
}


- (NSArray *)splitOnChar:(char)ch {
    NSMutableArray *results = [[NSMutableArray alloc] init];
    int start = 0;
    for(int i=0; i<[self length]; i++) {
        
        BOOL isAtSplitChar = [self characterAtIndex:i] == ch;
        BOOL isAtEnd = i == [self length] - 1;
        
        if(isAtSplitChar || isAtEnd) {
            //take the substring &amp; add it to the array
            NSRange range;
            range.location = start;
            range.length = i - start + 1;
            
            if(isAtSplitChar)
                range.length -= 1;
            
            [results addObject:[self substringWithRange:range]];
            start = i + 1;
        }
        
        //handle the case where the last character was the split char.  we need an empty trailing element in the array.
        if(isAtEnd && isAtSplitChar)
            [results addObject:@""];
    }
    
    return results;
}

- (NSString *)substringFrom:(NSInteger)from to:(NSInteger)to {
    NSString *rightPart = [self substringFromIndex:from];
    return [rightPart substringToIndex:to-from];
}


- (NSString*)stripHTMLtag:(NSString*)selector {
    NSError *err;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:[NSString stringWithFormat:@"%@=\"([^\"]*)\"", selector]
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&err];
    NSTextCheckingResult *m = [regex firstMatchInString:self options:0 range:NSMakeRange(0, self.length)];
    
    if (!NSEqualRanges(m.range, NSMakeRange(NSNotFound, 0)))
        return [self substringWithRange:[m rangeAtIndex:1]];
    
    return @"";
}



@end
