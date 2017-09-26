//
//  ezregex.h
//  
//
//  Created by Tail Red on 2/06/15.
//  Copyright 2015 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//


#import <Foundation/Foundation.h>

//
// This class is used to simplify regex
//
@interface ezregex : NSObject
-(BOOL)checkMatch:(NSString *)string pattern:(NSString *)pattern;
-(NSString *)searchreplace:(NSString *)string pattern:(NSString *)pattern;
-(NSString *)findMatch:(NSString *)string pattern:(NSString *)pattern rangeatindex:(int)ri;
-(NSArray *)findMatches:(NSString *)string pattern:(NSString *)pattern;
@end
