//
//  OnigRegexp+MatchExtensions.m
//  DetectionKit
//
//  Created by 桐間紗路 on 2017/09/25.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import "OnigRegexp+MatchExtensions.h"

@implementation OnigResult (MatchExtensions)
- (bool)havematches {
    return self.count > 0;
}
@end

