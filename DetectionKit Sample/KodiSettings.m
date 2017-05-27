//
//  KodiSettings.m
//  DetectionKit
//
//  Created by 桐間紗路 on 2017/05/27.
//  Copyright © 2017 Atelier Shiori. All rights reserved.
//

#import "KodiSettings.h"

@interface KodiSettings ()

@end

@implementation KodiSettings
-(id)init{
    self = [super initWithWindowNibName:@"KodiSettings"];
    if(!self)
        return nil;
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)close:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    [self.window close];
}

@end
