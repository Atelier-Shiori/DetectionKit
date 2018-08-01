//
//  Detection.m
//  DetectionKit
//
//  Created by Tail Red on 1/31/15.
//  Copyright 2015 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import "Detection.h"
#import "Recognition.h"
#import "PlexAuth.h"
#import "StreamInfoRetrieval.h"
#import "OnigRegexp+MatchExtensions.h"
#import <AppKit/AppKit.h>
#import "PingNotifier/PingNotifier.h"
#import <CocoaOniguruma/OnigRegexp.h>
#import <CocoaOniguruma/OnigRegexpUtility.h>
#import <SAMKeychain/SAMKeychain.h>
#import <XMLReader/XMLReader.h>
#import <AFNetworking/AFNetworking.h>
#import <DetectStreamKit/DetectStreamKit.h>

@interface Detection()
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary *detectStream;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary *detectPlayer;
@property (strong) PingNotifier *kodireach;
@property (strong) PingNotifier *plexreach;
@property (strong) AFHTTPSessionManager *kodijsonrpcmanager;
@property (strong) AFHTTPSessionManager *plexmanager;
@property (strong) DetectStreamManager *detectstreammgr;
- (bool)checkifIgnored:(NSString *)filename source:(NSString *)source;
- (bool)checkifTitleIgnored:(NSString *)filename source:(NSString *)source;
- (bool)checkifDirectoryIgnored:(NSString *)filename;
- (bool)checkIgnoredKeywords:(NSArray *)types;
@end

@implementation Detection
#pragma mark Public Methods
- (id)init {
    if ([super init]) {
        _kodijsonrpcmanager = [AFHTTPSessionManager manager];
        _kodijsonrpcmanager.requestSerializer = [AFJSONRequestSerializer serializer];
        _kodijsonrpcmanager.responseSerializer = [AFJSONResponseSerializer serializer];
        _kodijsonrpcmanager.completionQueue = dispatch_queue_create("AFNetworking+Synchronous", NULL);
        _plexmanager = [AFHTTPSessionManager manager];
        _plexmanager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _plexmanager.completionQueue = dispatch_queue_create("AFNetworking+Synchronous", NULL);
        _detectstreammgr = [DetectStreamManager new];
    }
    return self;
}

- (NSDictionary *)detectmedia {
    NSDictionary *result;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enablekodiapi"]) {
        result = [self detectKodi];
        if (result) {
            return result;
        }
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableplexapi"]) {
        result = [self detectPlex];
        if (result) {
            return result;
        }
    }
    result = [self detectStreamLink];
    if (!result) {
        // Check Stream
        result = self.detectPlayer;
    }
    if (result) {
        // Return results
        return result;
    }
    else {
        // Check Streamlink
        result = self.detectStream;
    }
    if (result) {
        // Return results
        return result;
    }
    else {
        //Return an empty array
        return nil;
    }
}

- (NSDictionary *)checksstreamlinkinfo:(NSDictionary *)d {
    Detection *detector = [Detection new];
    if (![detector checkStreamlinkTitleIgnored:d]) {
        return [detector convertstreamlinkinfo:d];
    }
    return nil;
}

#pragma mark Private Methods
- (NSDictionary *)detectPlayer{
    //Create an NSDictionary
    NSDictionary *result;
    // LSOF mplayer to get the media title and segment
    // Read supportedplayers.json
    NSError* error;
    NSData *supportedplayersdata = [[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"supportedplayers" ofType:@"json"] encoding:NSUTF8StringEncoding error:&error] dataUsingEncoding:NSUTF8StringEncoding];
    if (!supportedplayersdata) {
        NSLog(@"Error: Can't load supportedplayers.json, %@", error.localizedDescription);
        return result;
    }
    NSArray *player = [NSJSONSerialization JSONObjectWithData:supportedplayersdata options:0 error:&error];
    NSString *string;
    OnigRegexp    *regex;
    for (NSUInteger i = 0; i <player.count; i++) {
        NSTask *task;
        NSDictionary *theplayer = player[i];
        if (theplayer[@"applescript_command"]) {
            // Run Applescript command as specified
            task = [[NSTask alloc] init];
            task.launchPath = @"/usr/bin/osascript";
            task.arguments = @[@"-e", (NSString *)theplayer[@"applescript_command"]];
        }
        else {
            task = [[NSTask alloc] init];
            task.launchPath = @"/usr/sbin/lsof";
            task.arguments = @[@"-c", (NSString *)theplayer[@"process_name"], @"-F", @"n"];         //lsof -c '<player name>' -Fn
        }
        // Check if running
        if (theplayer[@"player_bundle_identifier"]) {
            if (![self checkIdentifier:theplayer[@"player_bundle_identifier"]]) {
                continue; // Application not running, don't check
            }
        }
        NSPipe *pipe;
        pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        
        NSFileHandle *file;
        file = pipe.fileHandleForReading;
        
        [task launch];
        
        NSData *data;
        data = [file readDataToEndOfFile];
        
        string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        if (string.length > 0) {
            if (![[OnigRegexp compile:@"/"] search:string]) {
                string = [string stringByReplacingOccurrencesOfString:@":" withString:@"/"]; // Replace colons with clashes (colon not a valid filename character)
                string = [NSString stringWithFormat:@"/%@",string];
            }
            regex = [OnigRegexp compile:@"^.+(avi|mkv|mp4|ogm|rm|rmvb|wmv|divx|mov|flv|mpg|3gp)$" options:OnigOptionIgnorecase];
            //Get the filename first
            OnigResult    *match;
            match = [regex search:string];
            NSMutableArray *filenames = [NSMutableArray new];
            for (NSString *matchedString in match.strings) {
                [filenames addObject:matchedString];
            }
            // Populate Source
            NSString *DetectedSource = theplayer[@"player_name"];
            //Check if thee file name or directory is on any ignore list
            for (NSUInteger f = 0; f < filenames.count; f++) {
                //Check every possible match
                string = filenames[f];
                BOOL onIgnoreList = [self checkifIgnored:string source:DetectedSource];
                //Make sure the file name is valid, even if player is open. Do not update video files in ignored directories
                
                if ([[regex match:string] havematches] && !onIgnoreList) {
                    NSDictionary *d = [[Recognition alloc] recognize:string];
                    BOOL invalidepisode = [self checkIgnoredKeywords:d[@"types"]];
                    if (!invalidepisode) {
                        NSString *DetectedTitle = (NSString *)d[@"title"];
                        NSString *DetectedEpisode = (NSString *)d[@"episode"];
                        NSNumber *DetectedSeason = d[@"season"];
                        NSString *DetectedGroup = (NSString *)d[@"group"];
                        if (DetectedTitle.length > 0) {
                            //Return result
                            result = @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": d[@"types"]};
                            return result;
                        }
                    }
                    else {
                        continue;
                    }
                }
                else {
                    continue;
                }
            }
        }
    }
    return result;
}

- (NSDictionary *)detectStream {
    // Perform stream detection
    @try {
        NSDictionary *d = [_detectstreammgr detectStream];
        
        if (d[@"result"]  == [NSNull null]) { // Check to see if anything is playing on stream
            return nil;
        }
        else {
            NSArray *c = d[@"result"];
            NSDictionary *result = c[0];
            if (!result[@"title"]) {
                return nil;
            }
            else if ([self checkifTitleIgnored:(NSString *)result[@"title"] source:result[@"site"]]) {
                return nil;
            }
            if ([(NSString *)result[@"type"] isEqualToString:@"manga"]) {
                return nil;
            }
            else if ([(NSString *)result[@"site"] isEqualToString:@"plex"]) {
                //Do additional pharsing
                NSDictionary *d2 = [[Recognition alloc] recognize:result[@"title"]];
                NSString *DetectedTitle = (NSString *)d2[@"title"];
                NSString *DetectedEpisode = (NSString *)d2[@"episode"];
                NSString *DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
                NSNumber *DetectedSeason = d2[@"season"];
                NSString *DetectedGroup = (NSString *)d2[@"group"];
                if (DetectedTitle.length > 0 && ![self checkifTitleIgnored:DetectedTitle source:result[@"site"]]) {
                    //Return result
                    return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": d2[@"types"]};
                }
            }
            else if (!result[@"episode"]) {
                //Episode number is missing. Do not use the stream data as a failsafe to keep the program from crashing
                return nil;
            }
            else {
                NSString *DetectedTitle = (NSString *)result[@"title"];
                NSString *DetectedEpisode = [NSString stringWithFormat:@"%@",result[@"episode"]];
                NSString *DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
                NSString *DetectedGroup = (NSString *)result[@"site"];
                NSNumber *DetectedSeason = (NSNumber *)result[@"season"];
                return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": [NSArray new]};
            }
        }
    }
    @catch (NSException *e) {
        NSLog(@"Stream Detection Failed: %@", e);
    }
    return nil;
}

- (NSDictionary *)detectKodi {
    // Only Detect from Kodi RPC when the host is reachable.
    if (self.kodionline) {
        // Kodi/Plex Theater Detection
        NSString *address = [[NSUserDefaults standardUserDefaults] objectForKey:@"kodiaddress"];
        NSString *port = [NSString stringWithFormat:@"%@",[[NSUserDefaults standardUserDefaults] objectForKey:@"kodiport"]];
        if (address.length == 0) {
            return nil;
        }
        if (port.length == 0) {
            port = @"3005";
        }
        NSDictionary *parameters = @{@"jsonrpc": @"2.0", @"method": @"Player.GetItem", @"params": @{ @"properties": @[@"title", @"season", @"episode", @"showtitle", @"tvshowid", @"thumbnail", @"file", @"fanart", @"streamdetails"], @"playerid": @(1) }, @"id": @"VideoGetItem"};
        NSError *error;
        NSURLSessionDataTask *task;
        id responseobject = [_kodijsonrpcmanager syncPOST:[NSString stringWithFormat:@"http://%@:%@/jsonrpc", address,port] parameters:parameters task:&task error:&error];
        if (!error) {
            if (responseobject[@"result"]) {
                //Valid Result, parse title
                NSDictionary *items = responseobject[@"result"];
                NSDictionary *item = items[@"item"];
                NSString *label;
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kodiusefilename"])
                {
                    // Use filename for recognition
                    label = item[@"file"];
                }
                else {
                    // Use the label
                    label = item[@"label"];
                }
                NSDictionary *d=[[Recognition alloc] recognize:label];
                BOOL invalidepisode = [self checkIgnoredKeywords:d[@"types"]];
                if (!invalidepisode) {
                    NSString *DetectedTitle = (NSString *)d[@"title"];
                    NSString *DetectedEpisode = (NSString *)d[@"episode"];
                    NSNumber *DetectedSeason = d[@"season"];
                    NSString *DetectedGroup = d[@"group"];
                    NSString *DetectedSource = @"Kodi/Plex";
                    if (DetectedTitle.length == 0) {
                        return nil;
                    }
                    if ([self checkifTitleIgnored:DetectedTitle source:DetectedSource]) {
                        return nil;
                    }
                    else {
                        NSDictionary *output = @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": d[@"types"]};
                        return output;
                    }
                }
                else {
                    return nil;
                }
            }
            else {
                // Unexpected Output or Kodi/Plex not playing anything, return nil object
                return nil;
            }
        }
        else {
            return nil;
        }
    }
    else {
        return nil;
    }
}

- (NSDictionary *)detectStreamLink {
    NSArray *a = [self detectAndRetrieveInfo];
    if (a.count > 0) {
        NSDictionary *result = a[0];
        if (!result[@"title"] || !result[@"site"]) {
            return nil;
        }
        else if ([self checkifTitleIgnored:(NSString *)result[@"title"] source:result[@"site"]]) {
            return nil;
        }
        else if (!result[@"episode"]) {
            //Episode number is missing. Do not use the stream data as a failsafe to keep the program from crashing
            return nil;
        }
        else {
            NSString *DetectedTitle = (NSString *)result[@"title"];
            NSString *DetectedEpisode = [NSString stringWithFormat:@"%@",result[@"episode"]];
            NSString *DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
            NSString *DetectedGroup = (NSString *)result[@"site"];
            NSNumber *DetectedSeason = (NSNumber *)result[@"season"];
            return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": [NSArray new]};
        }
    }
    return nil;
}

- (NSDictionary *)detectPlex {
    NSString *username = [PlexAuth checkplexaccount];
    if (username.length > 0) {
        if (self.plexonline) {
            // Retrieve ssessions opened in Plex Media Server
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [_plexmanager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"plexidentifier"] forHTTPHeaderField:@"X-Plex-Client-Identifier"];
            [_plexmanager.requestSerializer setValue:NSBundle.mainBundle.infoDictionary[@"CFBundleName"] forHTTPHeaderField:@"X-Plex-Product"];
            [_plexmanager.requestSerializer setValue:@"X-Plex-Version" forHTTPHeaderField:NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
            NSError *error;
            NSURLSessionDataTask *task;
            id responseObject = [_plexmanager syncPOST:[NSString stringWithFormat:@"http://%@:%li/status/sessions?X-Plex-Token=%@", [defaults objectForKey:@"plexaddress"],(long)[defaults integerForKey:@"plexport"], [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account:username]] parameters:nil task:&task error:&error];
            switch (((NSHTTPURLResponse *)task.response).statusCode) {
                case 200:{
                    return [self parsePlexXML:[NSString stringWithUTF8String:[responseObject bytes]]];
                }
                default:
                    return nil;
            }
        }
        else {
            return nil;
        }
    }
    return nil;
}

- (NSDictionary *)parsePlexXML:(NSString *)xml {
    NSError *error = nil;
    NSDictionary *d = [XMLReader dictionaryForXMLString:xml options:XMLReaderOptionsProcessNamespaces error:&error];
    NSArray *sessions;
    if (d[@"MediaContainer"]) {
        sessions = d[@"MediaContainer"];
        if (![sessions isKindOfClass:[NSArray class]]) {
            // Import only contains one object, put it in an array.
            sessions = @[sessions];
        }
        NSString *currentuser = [PlexAuth checkplexaccount];
        for (NSDictionary *videoi in sessions) {
            id videoa = videoi[@"Video"];
            if (!videoa) {
                continue;
            }
            else if (![videoa isKindOfClass:[NSArray class]]) {
                videoa = @[videoa];
            }
            for (NSDictionary *video in videoa) {
                if (video[@"Player"][@"state"]) {
                    NSString *playerstate = [video[@"Player"][@"state"] isKindOfClass:[NSString class]] ? video[@"Player"][@"state"] : video[@"Player"][@"state"][0];
                    NSString *playerusername = video[@"User"][@"title"];
                    if ([playerstate isEqualToString:@"playing"] && [playerusername isEqualToString:currentuser]) {
                        NSDictionary *result;
                        if ([video[@"Media"][@"Part"] isKindOfClass:[NSArray class]]) {
                            if (((NSArray *)video[@"Media"][@"Part"]).count > 0) {
                                for (NSDictionary *v in video[@"Media"][@"Part"]) {
                                    result = [self checkmetadata:@{@"Media" : @{@"Part" : v}}];
                                    if (result) {
                                        return result;
                                    }
                                }
                            }
                        }
                        else if (video[@"Media"][@"Part"]) {
                            result = [self checkmetadata:video];
                        }
                        else {
                            result = [self checkmetadata:[self retrievemetadata:(NSString *)video[@"key"]]];
                        }
                        if (result) {
                            return result;
                        }
                    }
                }
                else {
                    continue;
                }
            }
        }
    }
    return nil;
}

- (NSDictionary *)checkmetadata:(NSDictionary *)metadata {
    NSString *filepath = metadata[@"Media"][@"Part"][@"file"] && [(NSString *)metadata[@"Media"][@"Part"][@"decision"] isEqualToString:@"directplay"] ? metadata[@"Media"][@"Part"][@"file"]  : metadata[@"title"];
    NSDictionary *recoginfo = [[Recognition alloc] recognize:filepath];
    NSString *DetectedTitle = (NSString *)recoginfo[@"title"];
    NSString *DetectedEpisode = (NSString *)recoginfo[@"episode"];
    NSString *DetectedSource = @"Plex";
    NSNumber *DetectedSeason = recoginfo[@"season"];
    NSString *DetectedGroup = (NSString *)recoginfo[@"group"];
    if (DetectedTitle.length > 0 && ![self checkifTitleIgnored:DetectedTitle source:@"Plex"]) {
        //Return result
        return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": recoginfo[@"types"]};
    }
    return nil;
}

- (NSDictionary *)retrievemetadata:(NSString *)key {
    NSString *username = [PlexAuth checkplexaccount];
    // Retrieve Token
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [_plexmanager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"plexidentifier"] forHTTPHeaderField:@"X-Plex-Client-Identifier"];
    [_plexmanager.requestSerializer setValue:NSBundle.mainBundle.infoDictionary[@"CFBundleName"] forHTTPHeaderField:@"X-Plex-Product"];
    [_plexmanager.requestSerializer setValue:@"X-Plex-Version" forHTTPHeaderField:NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
    NSError *error;
    NSURLSessionDataTask *task;
    id responseObject = [_plexmanager syncPOST:[NSString stringWithFormat:@"http://%@:%li/status/sessions?X-Plex-Token=%@", [defaults objectForKey:@"plexaddress"],(long)[defaults integerForKey:@"plexport"], [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account:username]] parameters:nil task:&task error:&error];
    switch (((NSHTTPURLResponse *)task.response).statusCode) {
        case 200:{
            NSError *error = nil;
            NSDictionary *d = [XMLReader dictionaryForXMLString:[NSString stringWithUTF8String:[responseObject bytes]] options:XMLReaderOptionsProcessNamespaces error:&error];
            if ([d[@"MediaContainer"][@"Video"] isKindOfClass:[NSDictionary class]]){
                return d[@"MediaContainer"][@"Video"];
            }
            
        }
        default:
            return nil;
    }

}

#pragma mark Helpers

- (NSDictionary *)convertstreamlinkinfo:(NSDictionary *)result {
    NSString *DetectedTitle = (NSString *)result[@"title"];
    NSString *DetectedEpisode = [NSString stringWithFormat:@"%@",result[@"episode"]];
    NSString *DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
    NSString *DetectedGroup = (NSString *)result[@"site"];
    NSNumber *DetectedSeason = (NSNumber *)result[@"season"];
    return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": [NSArray new]};
}

- (bool)checkStreamlinkTitleIgnored:(NSDictionary *)d {
    return [self checkifIgnored:d[@"title"] source:d[@"site"]];
}

- (bool)checkifIgnored:(NSString *)filename source:(NSString *)source {
    if ([self checkifTitleIgnored:filename source:source] || [self checkifDirectoryIgnored:filename]) {
        return true;
    }
    return false;
}

- (bool)checkifTitleIgnored:(NSString *)filename source:(NSString *)source {
    // Get filename only
    filename = [filename replaceByRegexp:[OnigRegexp compile:@"^.+/" options:OnigOptionIgnorecase] with:@""];
    source = [source replaceByRegexp:[OnigRegexp compile:@"\\sin\\s\\w+" options:OnigOptionIgnorecase] with:@""];
    NSArray *ignoredfilenames = [[[NSUserDefaults standardUserDefaults] objectForKey:@"IgnoreTitleRules"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(rulesource == %@) OR (rulesource ==[c] %@)" , @"All Sources", source]];
    NSLog(@"Debug: %@", filename);
    if (ignoredfilenames.count > 0) {
        for (NSDictionary *d in ignoredfilenames) {
            NSString *rule = [NSString stringWithFormat:@"%@", d[@"rule"]];
            if ([[[OnigRegexp compile:@"%@" options:OnigOptionIgnorecase] match:filename] havematches] && rule.length !=0) { // Blank rules are infinite, thus should not be counted
                NSLog(@"Video file name is on filename ignore list.");
                return true;
            }
        }
    }
    return false;
}
- (bool)checkifDirectoryIgnored:(NSString *)filename {
    //Checks if file name or directory is on ignore list
    filename = [filename stringByReplacingOccurrencesOfString:@"n/" withString:@"/"];
    // Get only the path
    filename = [NSURL fileURLWithPath:filename].path.stringByDeletingLastPathComponent;
    if (!filename) {
        return false;
    }
    //Check ignore directories. If on ignore directory, set onIgnoreList to true.
    NSArray *ignoredirectories = [[NSUserDefaults standardUserDefaults] objectForKey:@"ignoreddirectories"];
    if (ignoredirectories.count > 0) {
        for (NSDictionary *d in ignoredirectories) {
            if ([filename isEqualToString:d[@"directory"]]) {
                NSLog(@"Video being played is in ignored directory");
                return true;
            }
        }
    }
    return false;
}
- (bool)checkIgnoredKeywords:(NSArray *)types {
    // Check for potentially invalid types
    for (NSString *type in types) {
        if ([[[OnigRegexp compile:@"(ED|Ending|NCED|NCOP|OP|Opening|Preview|PV)" options:OnigOptionIgnorecase] match:type] havematches]) {
            return true;
        }
    }
    return false;
}

- (NSArray *)detectAndRetrieveInfo{
    NSTask *task;
    task = [[NSTask alloc] init];
    task.launchPath = @"/bin/ps";
    task.arguments = @[@"-ax"];
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    NSFileHandle *file;
    file = pipe.fileHandleForReading;
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSString *pattern = @"streamlink *.* (https?:\\/\\/(?:www\\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\\.[^\\s]{2,}|www\\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\\.[^\\s]{2,}|https?:\\/\\/(?:www\\.|(?!www))[a-zA-Z0-9]\\.[^\\s]{2,}|www\\.[a-zA-Z0-9]\\.[^\\s]{2,})";
    OnigRegexp *regex = [OnigRegexp compile:pattern];
    OnigResult *matches = [regex search:string];
    if (matches.strings.count > 0) {
        string = matches.strings[0];
        NSString *urlpattern = @"(https?:\\/\\/(?:www\\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\\.[^\\s]{2,}|www\\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\\.[^\\s]{2,}|https?:\\/\\/(?:www\\.|(?!www))[a-zA-Z0-9]\\.[^\\s]{2,}|www\\.[a-zA-Z0-9]\\.[^\\s]{2,})";
        regex = [OnigRegexp compile:urlpattern];
        string = [regex search:string].strings[0];
        NSDictionary *info = [StreamInfoRetrieval retrieveStreamInfo:string];
        if (info){
            return [MediaStreamParse parse:@[info]];
        }
        return nil;
    }
    return nil;
}

#pragma mark Kodi Reachability
- (void)setKodiReach:(BOOL)enable {
    if (enable == 1) {
        //Create Reachability Object
        if (!_kodireach) {
            _kodireach = [[PingNotifier alloc] initWithHost:(NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"kodiaddress"]];
        }
        // Set up blocks
        _kodireach.onlineblock = ^(void)
        {
            _kodionline = true;
            NSLog(@"Kodi host is online.");
        };
        _kodireach.offlineblock = ^(void)
        {
            _kodionline = false;
            NSLog(@"Kodi host is offline.");
        };
        // Start notifier
        [_kodireach startPing];
    }
    else {
        [_kodireach stopPing];
        _kodireach = nil;
    }
}
- (void)setKodiReachAddress:(NSString *)url{
    [_kodireach stopPing];
    [_kodireach changeHostName:url];
    // Start notifier
    [_kodireach startPing];
}

#pragma mark Plex Media Server Helper Methods
- (void)setPlexReach:(BOOL)enable {
    if (enable == 1) {
        //Create Reachability Object
        if (!_plexreach) {
            _plexreach = [[PingNotifier alloc] initWithHost:(NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"plexaddress"]];
        }
        // Set up blocks
        _plexreach.onlineblock = ^(void)
        {
            NSLog(@"Plex Media Server is online");
            _plexonline = true;
        };
        _plexreach.offlineblock = ^(void)
        {
            NSLog(@"Plex Media Server is offline");
            _plexonline = false;
        };
        // Start notifier
        [_plexreach startPing];
    }
    else {
        [_plexreach stopPing];
        _plexreach = nil;
    }
}
- (void)setPlexReachAddress:(NSString *)url{
    [_plexreach stopPing];
    [_plexreach changeHostName:url];
    // Start notifier
    [_plexreach startPing];
}

#pragma mark Utility Methods
- (BOOL)checkIdentifier:(NSString*)identifier {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSArray *runningApps = ws.runningApplications;
    NSRunningApplication *a;
    for (a in runningApps) {
        if ([a.bundleIdentifier isEqualToString:identifier]) {
            return true;
        }
    }
    return false;
}

@end
