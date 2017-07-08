//
//  PlexLoginPanel.m
//  DetectionKit
//
//  Created by 天々座理世 on 2017/07/07.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import "PlexLoginPanel.h"

@interface PlexLoginPanel ()

@end

@implementation PlexLoginPanel
-(id)init{
    self = [super initWithWindowNibName:@"PlexLoginPanel"];
    if(!self)
        return nil;
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
- (IBAction)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    [self.window close];
}

- (IBAction)login:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    [self.window close];
}
@end
