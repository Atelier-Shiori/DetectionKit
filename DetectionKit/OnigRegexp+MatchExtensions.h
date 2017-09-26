//
//  OnigRegexp+MatchExtensions.h
//  DetectionKit
//
//  Created by 桐間紗路 on 2017/09/25.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import <CocoaOniguruma/OnigRegexp.h>

@interface OnigResult (MatchExtensions)
/**
Gives a bool if there is matches or not.
 @return bool The state if there is matches for a given regular expression.
 */
- (bool)havematches;
@end

