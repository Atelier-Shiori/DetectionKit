//
//  StreamInfoRetrieval.m
//  streamlinkdetect
//
//  Created by 天々座理世 on 2017/03/21.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import "StreamInfoRetrieval.h"
#import "ezregex.h"
#import "NSString+HTML.h"

@implementation StreamInfoRetrieval
NSString *const supportedSites = @"(crunchyroll|daisuki|animelab|funimation)";
+(NSDictionary *)retrieveStreamInfo:(NSString*) URL{
    NSString * site = [self checkURL:URL];
    if (site.length > 0) {
        // Retrieves information about stream
        // Send a synchronous request
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
        // Do not use Cookies
        [request setHTTPShouldHandleCookies:true];
        // Set Timeout
        [request setTimeoutInterval:15];
        // Set User Agent
        [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_4) AppleWebKit/600.7.12 (KHTML, like Gecko) Version/8.0.7 Safari/600.7.12" forHTTPHeaderField:@"User-Agent"];
        NSLock * lock = [NSLock new]; // NSMutableArray is not Thread Safe, lock before performing operation
        // Based on http://demianturner.com/2016/08/synchronous-nsurlsession-in-obj-c/
        __block NSHTTPURLResponse *urlresponse = nil;
        __block NSData *data = nil;
        __block NSError * error2 = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *taskData, NSURLResponse *rresponse, NSError *eerror) {
            data = taskData;
            urlresponse = (NSHTTPURLResponse *)rresponse;
            error2 = eerror;
            dispatch_semaphore_signal(semaphore);
        }];
        [dataTask resume];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        // Parse data
        if (urlresponse.statusCode == 200) {
            NSString * dom = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString * title = [StreamInfoRetrieval getPageTitle:dom];
            NSString * browser = @"streamlink";
            if (title && dom && site) {
                return @{ @"title":title, @"DOM":dom, @"url":URL, @"browser":browser, @"site":site};
            }
        }
    }
    return nil;
}
+(NSString *)getPageTitle:(NSString *)dom{
    // Parses title from DOM
    ezregex * regex = [ezregex new];
    NSString * title = [regex findMatch:dom pattern:@"<title>(.*?)<\\/title>" rangeatindex:0];
    title = [regex searchreplace:title pattern:@"(<title>|<\\/title>)"];
    //Unexcape HTML Characters
    title = [title kv_decodeHTMLCharacterEntities];
    return title;
}
+(NSString *)checkURL:(NSString *)url{
    NSString * site = [[[ezregex alloc] init] findMatch:url pattern:supportedSites rangeatindex:0];
    if ([site isEqualToString:@"32400"]) {
        //Plex local port, return plex
        return @"plex";
    }
    return site;
}
@end

