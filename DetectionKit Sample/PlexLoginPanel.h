//
//  PlexLoginPanel.h
//  DetectionKit
//
//  Created by 天々座理世 on 2017/07/07.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlexLoginPanel : NSWindowController
@property (strong) IBOutlet NSTextField *username;
@property (strong) IBOutlet NSSecureTextField *password;

@end
