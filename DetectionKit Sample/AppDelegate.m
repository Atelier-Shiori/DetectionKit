//
//  AppDelegate.m
//  DetectionKit Sample
//
//  Created by 桐間紗路 on 2017/05/27.
//  Copyright © 2017 Atelier Shiori. All rights reserved.
//

#import "AppDelegate.h"
#import <DetectionKit/DetectionKit.h>

@interface AppDelegate ()
@property (strong) Detection *detect;
@property (unsafe_unretained) IBOutlet NSTextView *outputtextview;

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _detect = [Detection new];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}
- (IBAction)detect:(id)sender {
    _outputtextview.string = [NSString stringWithFormat:@"%@", [_detect detectmedia]];
}


@end
