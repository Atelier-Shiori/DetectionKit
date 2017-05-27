//
//  Detection.h
//  MAL Updater OS X
//
//  Created by Tail Red on 1/31/15.
//  Copyright 2015 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import <Foundation/Foundation.h>

@class OnigRegexp;
@class OnigResult;
@class Reachability;

@interface Detection : NSObject
@property (getter=getKodiOnlineStatus) bool kodionline;
@property (strong) Reachability *kodireach;

- (NSDictionary *)detectmedia;
- (NSDictionary *)checksstreamlinkinfo:(NSDictionary *)d;
@end
