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
#import "MediaStreamParse.h"
#import "OnigRegexp+MatchExtensions.h"
#import <AppKit/AppKit.h>
#import <EasyNSURLConnection/EasyNSURLConnectionClass.h>
#import <Reachability/Reachability.h>
#import <CocoaOniguruma/OnigRegexp.h>
#import <CocoaOniguruma/OnigRegexpUtility.h>
#import <SAMKeychain/SAMKeychain.h>
#import <XMLReader/XMLReader.h>

@interface Detection()
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary *detectStream;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary *detectPlayer;
@property (strong) Reachability *kodireach;
@property (strong) Reachability *plexreach;
- (bool)checkifIgnored:(NSString *)filename source:(NSString *)source;
- (bool)checkifTitleIgnored:(NSString *)filename source:(NSString *)source;
- (bool)checkifDirectoryIgnored:(NSString *)filename;
- (bool)checkIgnoredKeywords:(NSArray *)types;
@end

@implementation Detection
#pragma mark Public Methods
- (NSDictionary *)detectmedia {
    NSDictionary * result;
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
    result = [self detectPlayer];
    if (!result) {
        // Check Stream
        result = [self detectStream];
    }
    if (result) {
        // Return results
        return result;
    }
    else {
        // Check Streamlink
        result = [self detectStreamLink];
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
    Detection * detector = [Detection new];
    if (![detector checkStreamlinkTitleIgnored:d]) {
        return [detector convertstreamlinkinfo:d];
    }
    return nil;
}

#pragma mark Private Methods

- (NSDictionary *)detectPlayer{
    //Create an NSDictionary
    NSDictionary * result;
    // LSOF mplayer to get the media title and segment
    // Read supportedplayers.json
    NSError* error;
    NSData *supportedplayersdata = [[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"supportedplayers" ofType:@"json"] encoding:NSUTF8StringEncoding error:nil] dataUsingEncoding:NSUTF8StringEncoding];

    NSArray *player = [NSJSONSerialization JSONObjectWithData:supportedplayersdata options:kNilOptions error:&error];
    NSString *string;
    OnigRegexp    *regex;
    for (int i = 0; i <player.count; i++) {
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
            task.arguments = @[@"-c", (NSString *)theplayer[@"process_name"], @"-F", @"n"]; 		//lsof -c '<player name>' -Fn
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
            NSMutableArray * filenames = [NSMutableArray new];
            for (NSString * matchedString in match.strings) {
                [filenames addObject:matchedString];
            }
            // Populate Source
            NSString * DetectedSource = theplayer[@"player_name"];
            //Check if thee file name or directory is on any ignore list
            for (long i = filenames.count-1;i >= 0;i--) {
                //Check every possible match
                string = filenames[i];
                BOOL onIgnoreList = [self checkifIgnored:string source:DetectedSource];
                //Make sure the file name is valid, even if player is open. Do not update video files in ignored directories
                
                if ([[regex match:string] havematches] && !onIgnoreList) {
                    NSDictionary *d = [[Recognition alloc] recognize:string];
                    BOOL invalidepisode = [self checkIgnoredKeywords:d[@"types"]];
                    if (!invalidepisode) {
                        NSString * DetectedTitle = (NSString *)d[@"title"];
                        NSString * DetectedEpisode = (NSString *)d[@"episode"];
                        NSNumber * DetectedSeason = d[@"season"];
                        NSString * DetectedGroup = (NSString *)d[@"group"];
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
    // Create Dictionary
    NSDictionary * d;
    //Set detectream Task and Run it
    NSTask *task;
    task = [[NSTask alloc] init];
    NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
    task.launchPath = [myBundle pathForResource:@"detectstream" ofType:@""];
    
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    // Reads Output
    NSFileHandle *file;
    file = pipe.fileHandleForReading;
    
    // Launch Task
    [task launch];
    [task waitUntilExit];
    // Parse Data from JSON and return dictionary
    NSData *data;
    data = [file readDataToEndOfFile];
    
    
    NSError* error;
    //Check if detectstream successfully exited. If not, ignore detection to prevent the program from crashing
    if (task.terminationStatus != 0) {
        NSLog(@"detectstream crashed, ignoring stream detection");
        return nil;
    }
    
    d = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    if (d[@"result"]  == [NSNull null]) { // Check to see if anything is playing on stream
        return nil;
    }
    else {
        NSArray * c = d[@"result"];
        NSDictionary * result = c[0];
        if (!result[@"title"]) {
            return nil;
        }
        else if ([self checkifTitleIgnored:(NSString *)result[@"title"] source:result[@"site"]]) {
            return nil;
        }
        else if ([(NSString *)result[@"site"] isEqualToString:@"plex"]) {
            //Do additional pharsing
            NSDictionary *d2 = [[Recognition alloc] recognize:result[@"title"]];
            NSString * DetectedTitle = (NSString *)d2[@"title"];
            NSString * DetectedEpisode = (NSString *)d2[@"episode"];
            NSString * DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
            NSNumber * DetectedSeason = d2[@"season"];
            NSString * DetectedGroup = (NSString *)d2[@"group"];
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
            NSString * DetectedTitle = (NSString *)result[@"title"];
            NSString * DetectedEpisode = [NSString stringWithFormat:@"%@",result[@"episode"]];
            NSString * DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
            NSString * DetectedGroup = (NSString *)result[@"site"];
            NSNumber * DetectedSeason = (NSNumber *)result[@"season"];
            return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": [NSArray new]};
        }
    }
    return nil;
}

- (NSDictionary *)detectKodi {
    // Only Detect from Kodi RPC when the host is reachable.
    if ([self getKodiOnlineStatus]) {
        // Kodi/Plex Theater Detection
        NSString * address = [[NSUserDefaults standardUserDefaults] objectForKey:@"kodiaddress"];
        NSString * port = [NSString stringWithFormat:@"%@",[[NSUserDefaults standardUserDefaults] objectForKey:@"kodiport"]];
        if (address.length == 0) {
            return nil;
        }
        if (port.length == 0) {
            port = @"3005";
        }
        EasyNSURLConnection * request = [[EasyNSURLConnection alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%@/jsonrpc", address,port]]];
        [request startJSONRequest:@"{\"jsonrpc\": \"2.0\", \"method\": \"Player.GetItem\", \"params\": { \"properties\": [\"title\", \"season\", \"episode\", \"showtitle\", \"tvshowid\", \"thumbnail\", \"file\", \"fanart\", \"streamdetails\"], \"playerid\": 1 }, \"id\": \"VideoGetItem\"}" type:EasyNSURLConnectionJsonType];
        if (request.getStatusCode == 200) {
            NSDictionary * result;
            NSError * error = nil;
            result = [NSJSONSerialization JSONObjectWithData:[request getResponseData] options:kNilOptions error:&error];
            if (result[@"result"]) {
                //Valid Result, parse title
                NSDictionary * items = result[@"result"];
                NSDictionary * item = items[@"item"];
                NSString * label;
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kodiusefilename"])
                {
                    // Use filename for recognition
                    label = item[@"file"];
                }
                else {
                    // Use the label
                    label = item[@"label"];
                }
                NSDictionary * d=[[Recognition alloc] recognize:label];
                BOOL invalidepisode = [self checkIgnoredKeywords:d[@"types"]];
                if (!invalidepisode) {
                    NSString * DetectedTitle = (NSString *)d[@"title"];
                    NSString * DetectedEpisode = (NSString *)d[@"episode"];
                    NSNumber * DetectedSeason = d[@"season"];
                    NSString * DetectedGroup = d[@"group"];
                    NSString * DetectedSource = @"Kodi/Plex";
                    if ([self checkifTitleIgnored:(NSString *)DetectedTitle source:DetectedSource]) {
                        return nil;
                    }
                    else {
                        NSDictionary * output = @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": d[@"types"]};
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
    NSArray * a = [self detectAndRetrieveInfo];
    if (a.count > 0) {
        NSDictionary * result = a[0];
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
            NSString * DetectedTitle = (NSString *)result[@"title"];
            NSString * DetectedEpisode = [NSString stringWithFormat:@"%@",result[@"episode"]];
            NSString * DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
            NSString * DetectedGroup = (NSString *)result[@"site"];
            NSNumber * DetectedSeason = (NSNumber *)result[@"season"];
            return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": [NSArray new]};
        }
    }
    return nil;
}

- (NSDictionary *)detectPlex {
    NSString *username = [PlexAuth checkplexaccount];
    if (username.length > 0) {
        if ([self getPlexOnlineStatus]) {
            // Retrieve ssessions opened in Plex Media Server
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            EasyNSURLConnection * request = [[EasyNSURLConnection alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%li/status/sessions?X-Plex-Token=%@", [defaults objectForKey:@"plexaddress"],(long)[defaults integerForKey:@"plexport"], [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account:username] ]]];
            request.headers = @{@"X-Plex-Client-Identifier":[defaults objectForKey:@"plexidentifier"],@"X-Plex-Product":NSBundle.mainBundle.infoDictionary[@"CFBundleName"],@"X-Plex-Version":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]};
            [request startFormRequest];
            switch (request.getStatusCode) {
                case 200:{
                    return [self parsePlexXML:request.getResponseDataString];
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
            sessions = [NSArray arrayWithObject:sessions];
        }
        NSString *currentuser = [PlexAuth checkplexaccount];
        for (NSDictionary *videoi in sessions) {
            NSDictionary *video = videoi[@"Video"];
            NSString *playerstate = video[@"Player"][@"state"];
            NSString *playerusername = video[@"User"][@"title"];
            if ([playerstate isEqualToString:@"playing"] && [playerusername isEqualToString:currentuser]) {
                NSDictionary *metadata = [self retrievemetadata:(NSString *)video[@"key"]];
                NSString *filepath = metadata[@"Media"][@"Part"][@"file"];
                NSDictionary *recoginfo = [[Recognition alloc] recognize:filepath];
                NSString * DetectedTitle = (NSString *)recoginfo[@"title"];
                NSString * DetectedEpisode = (NSString *)recoginfo[@"episode"];
                NSString * DetectedSource = @"Plex";
                NSNumber * DetectedSeason = recoginfo[@"season"];
                NSString * DetectedGroup = (NSString *)recoginfo[@"group"];
                if (DetectedTitle.length > 0 && ![self checkifTitleIgnored:DetectedTitle source:@"Plex"]) {
                    //Return result
                    return @{@"detectedtitle": DetectedTitle, @"detectedepisode": DetectedEpisode, @"detectedseason": DetectedSeason, @"detectedsource": DetectedSource, @"group": DetectedGroup, @"types": recoginfo[@"types"]};
                }
            }
            else {
                continue;
            }
        }
    }
    return nil;
}

- (NSDictionary *)retrievemetadata:(NSString *)key {
    NSString *username = [PlexAuth checkplexaccount];
    // Retrieve Token
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    EasyNSURLConnection * request = [[EasyNSURLConnection alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%li/status/sessions?X-Plex-Token=%@", [defaults objectForKey:@"plexaddress"],(long)[defaults integerForKey:@"plexport"], [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account:username] ]]];
    request.headers = @{@"X-Plex-Client-Identifier":[defaults objectForKey:@"plexidentifier"],@"X-Plex-Product":NSBundle.mainBundle.infoDictionary[@"CFBundleName"],@"X-Plex-Version":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]};
    [request startFormRequest];
    switch (request.getStatusCode) {
        case 200:{
            NSError *error = nil;
            NSDictionary *d = [XMLReader dictionaryForXMLString:request.getResponseDataString options:XMLReaderOptionsProcessNamespaces error:&error];
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
    NSString * DetectedTitle = (NSString *)result[@"title"];
    NSString * DetectedEpisode = [NSString stringWithFormat:@"%@",result[@"episode"]];
    NSString * DetectedSource = [NSString stringWithFormat:@"%@ in %@", [result[@"site"] capitalizedString], result[@"browser"]];
    NSString * DetectedGroup = (NSString *)result[@"site"];
    NSNumber * DetectedSeason = (NSNumber *)result[@"season"];
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
    NSArray * ignoredfilenames = [[[NSUserDefaults standardUserDefaults] objectForKey:@"IgnoreTitleRules"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(rulesource == %@) OR (rulesource ==[c] %@)" , @"All Sources", source]];
    NSLog(@"Debug: %@", filename);
    if (ignoredfilenames.count > 0) {
        for (NSDictionary * d in ignoredfilenames) {
            NSString * rule = [NSString stringWithFormat:@"%@", d[@"rule"]];
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
    NSArray * ignoredirectories = [[NSUserDefaults standardUserDefaults] objectForKey:@"ignoreddirectories"];
    if (ignoredirectories.count > 0) {
        for (NSDictionary * d in ignoredirectories) {
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
    for (NSString * type in types) {
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
        NSString *pattern = @"(https?:\\/\\/(?:www\\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\\.[^\\s]{2,}|www\\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\\.[^\\s]{2,}|https?:\\/\\/(?:www\\.|(?!www))[a-zA-Z0-9]\\.[^\\s]{2,}|www\\.[a-zA-Z0-9]\\.[^\\s]{2,})";
        regex = [OnigRegexp compile:pattern];
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
        _kodireach = [Reachability reachabilityWithHostname:(NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"kodiaddress"]];
        // Set up blocks
        _kodireach.reachableBlock = ^(Reachability*reach)
        {
            _kodionline = true;
            NSLog(@"Kodi host is online.");
        };
        _kodireach.unreachableBlock = ^(Reachability*reach)
        {
            _kodionline = false;
            NSLog(@"Kodi host is offline.");
        };
        // Start notifier
        [_kodireach startNotifier];
    }
    else {
        [_kodireach stopNotifier];
        _kodireach = nil;
    }
}
- (void)setKodiReachAddress:(NSString *)url{
    [_kodireach stopNotifier];
    _kodireach = [Reachability reachabilityWithHostname:url];
    // Set up blocks
    // Set the blocks
    _kodireach.reachableBlock = ^(Reachability*reach)
    {
        NSLog(@"Plex Media Server host is online.");
        _kodionline = true;
    };
    _kodireach.unreachableBlock = ^(Reachability*reach)
    {
        NSLog(@"Plex Media Server host is offline.");
        _kodionline = false;
    };
    // Start notifier
    [_kodireach startNotifier];
}

#pragma mark Plex Media Server Helper Methods
- (void)setPlexReach:(BOOL)enable {
    if (enable == 1) {
        //Create Reachability Object
        _plexreach = [Reachability reachabilityWithHostname:(NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"plexaddress"]];
        // Set up blocks
        _plexreach.reachableBlock = ^(Reachability*reach)
        {
            _plexonline = true;
        };
        _plexreach.unreachableBlock = ^(Reachability*reach)
        {
            _plexonline = false;
        };
        // Start notifier
        [_plexreach startNotifier];
    }
    else {
        [_plexreach stopNotifier];
        _plexreach = nil;
    }
}
- (void)setPlexReachAddress:(NSString *)url{
    [_plexreach stopNotifier];
    _plexreach = [Reachability reachabilityWithHostname:url];
    // Set up blocks
    // Set the blocks
    _plexreach.reachableBlock = ^(Reachability*reach)
    {
        _plexonline = true;
    };
    _plexreach.unreachableBlock = ^(Reachability*reach)
    {
        _plexonline = false;
    };
    // Start notifier
    [_plexreach startNotifier];
}

#pragma mark Utility Methods
- (BOOL)checkIdentifier:(NSString*)identifier {
    NSWorkspace * ws = [NSWorkspace sharedWorkspace];
    NSArray *runningApps = [ws runningApplications];
    NSRunningApplication *a;
    for (a in runningApps) {
        if ([[a bundleIdentifier] isEqualToString:identifier]) {
            return true;
        }
    }
    return false;
}

@end
