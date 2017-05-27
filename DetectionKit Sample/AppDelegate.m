//
//  AppDelegate.m
//  DetectionKit Sample
//
//  Created by 桐間紗路 on 2017/05/27.
//  Copyright © 2017 Atelier Shiori. All rights reserved.
//

#import "AppDelegate.h"
#import "KodiSettings.h"
#import <DetectionKit/DetectionKit.h>

@interface AppDelegate ()
@property (strong) Detection *detect;
@property (unsafe_unretained) IBOutlet NSTextView *outputtextview;
@property (strong) KodiSettings *kodisettings;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
+ (void)initialize
{
    //Create a Dictionary
    NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
    
    // Defaults
    defaultValues[@"ignoredirectories"] = [[NSMutableArray alloc] init];
    defaultValues[@"IgnoreTitleRules"] = [[NSMutableArray alloc] init];
    defaultValues[@"enablekodiapi"] = @NO;
    defaultValues[@"kodiaddress"] = @"";
    defaultValues[@"kodiport"] = @"3005";
    //Register Dictionary
    [[NSUserDefaults standardUserDefaults]
     registerDefaults:defaultValues];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _detect = [[Detection alloc] init];
    [_detect setKodiReach:[[NSUserDefaults standardUserDefaults] boolForKey:@"enablekodiapi"]];
    if (!_kodisettings) {
        _kodisettings = [KodiSettings new];
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}
- (IBAction)detect:(id)sender {
    _outputtextview.string = [NSString stringWithFormat:@"%@", [_detect detectmedia]];
}

- (IBAction)kodisettings:(id)sender {
    [_window beginSheet:_kodisettings.window  completionHandler:^(NSModalResponse returnCode) {
        [_detect setKodiReach:NO];
        [_detect setKodiReach:YES];
    }];

}

@end
