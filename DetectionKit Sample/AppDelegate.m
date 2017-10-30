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
#import "PlexLoginPanel.h"
#import "PingNotifier/PingNotifier.h"

@interface AppDelegate ()
@property (strong) Detection *detect;
@property (unsafe_unretained) IBOutlet NSTextView *outputtextview;
@property (strong) KodiSettings *kodisettings;
@property (weak) IBOutlet NSWindow *window;
@property (strong) PlexLoginPanel *plexlogin;
@property (weak) IBOutlet NSButton *plexloginbut;
@property (weak) IBOutlet NSButton *plexlogoutbut;
@property (strong) PingNotifier* pingclient;
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
    defaultValues[@"plexaddress"] = @"";
    defaultValues[@"plexport"] = @"32400";
    defaultValues[@"plexidentifier"] = @"EXAMPLE_IDENTIFER";
    //Register Dictionary
    [[NSUserDefaults standardUserDefaults]
     registerDefaults:defaultValues];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _detect = [[Detection alloc] init];
    [_detect setKodiReach:[[NSUserDefaults standardUserDefaults] boolForKey:@"enablekodiapi"]];
    [_detect setPlexReach:[[NSUserDefaults standardUserDefaults] boolForKey:@"enableplexapi"]];
    if (!_kodisettings) {
        _kodisettings = [KodiSettings new];
    }
    if (!_plexlogin) {
        _plexlogin = [PlexLoginPanel new];
    }
    if ([PlexAuth checkplexaccount].length > 0) {
        _plexlogoutbut.hidden = NO;
        _plexloginbut.hidden = YES;
    }
    else {
        _plexloginbut.hidden = NO;
        _plexlogoutbut.hidden = YES;
    }
    // Test Ping
    _pingclient = [[PingNotifier alloc] initWithHost:@"169.254.77.43"];
    [_pingclient setOnlineblock:^(void) {
        NSLog(@"Host is online");
    }];
    [_pingclient setOfflineblock:^(void) {
        NSLog(@"Host is offline");
    }];
    [_pingclient startPing];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}
- (IBAction)detect:(id)sender {
    _outputtextview.string = [NSString stringWithFormat:@"%@", [_detect detectmedia]];
}

- (IBAction)kodisettings:(id)sender {
    [_window beginSheet:_kodisettings.window  completionHandler:^(NSModalResponse returnCode) {
        [_detect setKodiReach:[[NSUserDefaults standardUserDefaults] boolForKey:@"enablekodiapi"]];
        [_detect setPlexReach:[[NSUserDefaults standardUserDefaults] boolForKey:@"enableplexapi"]];
    }];

}
- (IBAction)login:(id)sender {
    [_window beginSheet:_plexlogin.window  completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK) {
            if ([PlexAuth performplexlogin:_plexlogin.username.stringValue withPassword:_plexlogin.password.stringValue]) {
                _plexloginbut.hidden = YES;
                _plexlogoutbut.hidden = NO;
            }
        }
    }];
}
- (IBAction)logout:(id)sender {
    [PlexAuth removeplexaccount];
    _plexloginbut.hidden = NO;
    _plexlogoutbut.hidden = YES;
}

@end
