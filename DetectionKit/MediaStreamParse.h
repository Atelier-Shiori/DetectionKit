//
//  MediaStreamParse.h
//  
//
//  Created by 高町なのは on 2015/02/09.
//  Copyright (c) 2015年 Chikorita157's Anime Blog. All rights reserved.
//
//  This class parses the title if it's playing an episode.
//  It will find title, episode and season information.


#import <Foundation/Foundation.h>

@interface MediaStreamParse : NSObject
+(NSArray *)parse:(NSArray *)pages;
@end
