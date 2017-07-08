//
//  PlexAuth.m
//  DetectionKit
//
//  Created by 天々座理世 on 2017/07/07.
//  Copyright © 2017年 Atelier Shiori. All rights reserved.
//

#import "PlexAuth.h"
#import <SAMKeychain/SAMKeychain.h>
#import <EasyNSURLConnection/EasyNSURLConnectionClass.h>

@implementation PlexAuth
+ (bool)peformplexlogin:(NSString *)username withPassword:(NSString *)password {
    // Retrieve Token
    EasyNSURLConnection * request = [[EasyNSURLConnection alloc] initWithURL:[NSURL URLWithString:@"https://plex.tv/users/sign_in.xml"]];
    request.headers = @{@"X-Plex-Client-Identifier":[[NSUserDefaults standardUserDefaults] objectForKey:@"plexidentifier"],@"X-Plex-Product":NSBundle.mainBundle.infoDictionary[@"CFBundleName"],@"X-Plex-Version":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]};
    [request addFormData:username forKey:@"user[login]"];
    [request addFormData:password forKey:@"user[password]"];
    [request startFormRequest];
    NSLog(@"%@",[request getResponseDataString]);
    switch (request.getStatusCode) {
        case 200:
        case 201:{
            NSString *token = [self extractXMLElement:@"authentication-token" withXML:[request getResponseDataString]];
            // Store Token
            [SAMKeychain setPassword:token forService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account:username];
            return true;
        }
        default:
            return false;
    }
}

+ (bool)removeplexaccount {
    NSString *username = [self checkplexaccount];
    if (username.length > 0) {
        return [SAMKeychain deletePasswordForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account:[self checkplexaccount]];
    }
    return false;
}

+ (NSString *)checkplexaccount{
    // This method checks for any accounts that Hachidori can use
    NSArray * accounts = [SAMKeychain accountsForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]]];
    if (accounts > 0) {
        //retrieve first valid account
        for (NSDictionary * account in accounts) {
            return (NSString *)account[@"acct"];
        }
    }
    return @"";
}

+ (NSString *)extractXMLElement:(NSString *)tagname withXML:(NSString *)xml {
    NSScanner *scanner = [NSScanner scannerWithString:xml];
    NSString *text;
    while (![scanner isAtEnd]){
        [scanner scanUpToString:[NSString stringWithFormat:@"<%@>", tagname] intoString:NULL];
        [scanner scanString:[NSString stringWithFormat:@"<%@>", tagname] intoString:NULL];
        [scanner scanUpToString:[NSString stringWithFormat:@"</%@>", tagname] intoString:&text];
    }
    return text;
}

@end
