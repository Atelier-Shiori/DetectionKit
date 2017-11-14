//
//  PingNotifier.m
//  DetectionKit
//
//  Created by 桐間紗路 on 2017/09/26.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import "PingNotifier.h"
#import <MSWeakTimer_macOS/MSWeakTimer.h>

@interface PingNotifier ()
@property (strong) MSWeakTimer *pingtimer;
@property (strong) MSWeakTimer *pingstoptimer;
@property (strong) dispatch_queue_t privatequeue;
@property (strong) dispatch_queue_t stopqueue;
@property bool blockran;
@end

@implementation PingNotifier
- (id)initWithHost:(NSString *)hostname {
    if (self = [super init]) {
     _privatequeue = dispatch_queue_create("moe.ateliershiori.detectionkit", DISPATCH_QUEUE_CONCURRENT);
        _stopqueue = dispatch_queue_create("moe.ateliershiori.detectionkit", DISPATCH_QUEUE_CONCURRENT);
        _pingclient = [GBPing new];
        _pingclient.host = hostname;
        _pingclient.timeout = 1.0;
        _pingclient.pingPeriod = 1;
        _pingclient.delegate = self;
    }
    return self;
}

- (void)changeHostName:(NSString *)hostname; {
    if (_isActive) {
        NSLog(@"Ping is active, ignoring...");
    }
    else {
        _pingclient.host = hostname;
    }
}

- (void)setupPing {
    [_pingclient setupWithBlock:^(BOOL success, NSError *error) {
        if (success) {
            _isSetUp = true;
            _blockran = false;
            @try {
                [_pingclient startPinging];
            }
            @catch (NSException *e) {
                NSLog(@"Ping failed to start: %@" , e);
                [self setOnline:false];
            }
            _pingstoptimer = [MSWeakTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(stopPingTimer) userInfo:nil repeats:NO dispatchQueue:_stopqueue];
        }
    }];
}

- (void)startPing {
    _pingtimer = [MSWeakTimer scheduledTimerWithTimeInterval:300
                                                      target:self
                                                    selector:@selector(fireTimer)
                                                    userInfo:nil
                                                     repeats:YES
                                               dispatchQueue:_privatequeue];
    _isActive = true;
    [_pingtimer fire];
}

- (void)stopPing {
    [_pingtimer invalidate];
    _isActive = false;
    if (_pingclient.isPinging) {
        [_pingclient stop];
    }
}


- (void)fireTimer {
    [self setupPing];
    [_pingclient startPinging];
    
}

- (void)stopPingTimer {
    [_pingclient stop];
}
     
- (void)setOnline:(bool)online {
    _isOnline = online;
    if (_isOnline) {
        if (_onlineblock && !_blockran) {
            _onlineblock();
            _blockran = true;
        }
    }
    else {
        if (_offlineblock && !_blockran) {
            _offlineblock();
            _blockran = true;
        }
    }
}

#pragma mark GBPing Delegate Methods
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary {
    [self setOnline:true];
}

-(void)ping:(GBPing *)pinger didReceiveUnexpectedReplyWithSummary:(GBPingSummary *)summary {
}

-(void)ping:(GBPing *)pinger didSendPingWithSummary:(GBPingSummary *)summary {
}

-(void)ping:(GBPing *)pinger didTimeoutWithSummary:(GBPingSummary *)summary {
    [self setOnline:false];
}

-(void)ping:(GBPing *)pinger didFailWithError:(NSError *)error {
    [self setOnline:false];
}

-(void)ping:(GBPing *)pinger didFailToSendPingWithSummary:(GBPingSummary *)summary error:(NSError *)error {
    [self setOnline:false];
}

@end
