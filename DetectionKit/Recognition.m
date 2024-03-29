//
//  Recognition.m
//  DetectionKit
//
//  Created by 高町なのは on 2014/11/16.
//  Copyright 2014 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import "Recognition.h"
#import <CocoaOniguruma/OnigRegexp.h>
#import <CocoaOniguruma/OnigRegexpUtility.h>
#import <anitomy-osx/anitomy-objc-wrapper.h>

@implementation Recognition

-(NSDictionary*)recognize:(NSString *)string {
    OnigRegexp    *regex;
    NSString *DetectedTitle;
    NSString *DetectedEpisode;
    NSString *DetectedGroup;
    
    int DetectedSeason;
    //Get Filename
    regex = [OnigRegexp compile:@"^.+/" options:OnigOptionIgnorecase];
    string = [string replaceByRegexp:regex with:@""];
    regex = [OnigRegexp compile:@"^.+\\\\" options:OnigOptionIgnorecase];//for Plex
    string = [string replaceByRegexp:regex with:@""];
    NSDictionary *d = [[anitomy_bridge new] tokenize:string];
    DetectedTitle = d[@"title"];
    DetectedEpisode = d[@"episode"];
    DetectedGroup = d[@"group"];
    if (DetectedGroup.length == 0) {
        DetectedGroup = @"Unknown";
    }
    NSArray *DetectedTypes = [Recognition populateAnimeTypes:d[@"type"]];
    
    //Season Checking
    NSString *tmpseason;
    NSString *tmptitle = [NSString stringWithFormat:@"%@ %@", DetectedTitle, d[@"season"]];
    OnigResult *smatch;
    regex = [OnigRegexp compile:@"((S|s|Season )\\d+|\\d+(st|nd|rd|th) Season|\\d+)" options:OnigOptionIgnorecase];
    smatch = [regex search:tmptitle];
    if (smatch.count > 0 ) {
        tmpseason = [smatch stringAt:0];
        regex = [OnigRegexp compile:@"(S|s|Season |(st|nd|rd|th) Season)" options:OnigOptionIgnorecase];
        tmpseason = [tmpseason replaceByRegexp:regex with:@""];
        regex = [OnigRegexp compile:@"\\w\\d+\\w" options:OnigOptionIgnorecase];
        smatch = [regex search:tmptitle];
        // Check if season is actually a season number and not a number in a title
        if (smatch.count == 0 ) {
            DetectedSeason = tmpseason.intValue;
            DetectedTitle = [DetectedTitle replaceByRegexp:[OnigRegexp compile:@"((S|s|Season )\\d+|\\d+(st|nd|rd|th) Season|\\d+)" options:OnigOptionIgnorecase] with:@""];
        }
        else {
            DetectedSeason = 1;
        }
    }
    else {
        DetectedSeason = 1;
    }
    
    // remove tildes
    DetectedTitle = [DetectedTitle stringByReplacingOccurrencesOfString:@"~" withString:@""];
    
    // Trim Whitespace
    DetectedTitle = [DetectedTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    DetectedEpisode = [DetectedEpisode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return @{@"title": DetectedTitle, @"episode": DetectedEpisode, @"season": @(DetectedSeason), @"group": DetectedGroup, @"types":DetectedTypes};
    
}

+(NSArray*)populateAnimeTypes:(NSArray *)types{
    NSMutableArray *ftypes = [NSMutableArray new];
    for (NSString * type in types ) {
        if ([type caseInsensitiveCompare:@"Genkijouban"] == NSOrderedSame) {
            [ftypes addObject:@"Movie"];
        }
        else if ([type caseInsensitiveCompare:@"OAD"] == NSOrderedSame) {
            [ftypes addObject:@"OVA"];
        }
        else if ([type caseInsensitiveCompare:@"OAV"] == NSOrderedSame) {
            [ftypes addObject:@"OVA"];
        }
        else if ([type caseInsensitiveCompare:@"Specials"] == NSOrderedSame) {
            [ftypes addObject:@"Special"];
        }
        else {
            [ftypes addObject:type];
        }
    }
    return ftypes;
}


@end
