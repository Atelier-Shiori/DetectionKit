//
//  ezregex.h
//  
//
//  Created by Tail Red on 2/06/15.
//  Copyright 2015 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//


#import "ezregex.h"

@implementation ezregex

-(BOOL)checkMatch:(NSString *)string pattern:(NSString *)pattern {
    NSError *errRegex = NULL;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:pattern
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&errRegex];
    NSRange  searchrange = NSMakeRange(0, [string length]);
    NSRange matchRange = [regex rangeOfFirstMatchInString:string options:NSMatchingReportProgress range:searchrange];
    if (matchRange.location != NSNotFound) {
        return true;
    }
    else {
        return false;
    }
}
-(NSString *)searchreplace:(NSString *)string pattern:(NSString *)pattern {
    NSError *errRegex = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&errRegex];
    NSString * newString = [regex stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:@""];
    return newString;
}
-(NSString *)findMatch:(NSString *)string pattern:(NSString *)pattern rangeatindex:(int)ri {
    NSError *errRegex = NULL;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:pattern
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&errRegex];
    NSRange  searchrange = NSMakeRange(0, [string length]);
    NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range: searchrange];
    NSRange matchRange = [regex rangeOfFirstMatchInString:string options:NSMatchingReportProgress range:searchrange];
    if (matchRange.location != NSNotFound) {
        return [string substringWithRange:[match rangeAtIndex:ri]];
    }
    return @"";
}
-(NSArray *)findMatches:(NSString *)string pattern:(NSString *)pattern {
    NSError *errRegex = NULL;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:pattern
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&errRegex];
    NSRange  searchrange = NSMakeRange(0, [string length]);
    NSArray * a = [regex matchesInString:string options:kNilOptions range:searchrange];
    NSMutableArray * results = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult * result in a ) {
        [results addObject:[string substringWithRange:[result rangeAtIndex:0]]];
    }
    return results;
}
@end
