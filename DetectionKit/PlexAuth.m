//
//  PlexAuth.m
//  DetectionKit
//
//  Created by 天々座理世 on 2017/07/07.
//  Copyright © 2017年 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import "PlexAuth.h"
#import <SAMKeychain/SAMKeychain.h>
#import <EasyNSURLConnection/EasyNSURLConnectionClass.h>
#import <XMLReader/XMLReader.h>

@implementation PlexAuth
+ (bool)performplexlogin:(NSString *)username withPassword:(NSString *)password {
    // Retrieve Token
    EasyNSURLConnection *request = [[EasyNSURLConnection alloc] initWithURL:[NSURL URLWithString:@"https://plex.tv/users/sign_in.xml"]];
    request.headers = (NSMutableDictionary *)@{@"X-Plex-Client-Identifier":[[NSUserDefaults standardUserDefaults] objectForKey:@"plexidentifier"],@"X-Plex-Product":NSBundle.mainBundle.infoDictionary[@"CFBundleName"],@"X-Plex-Version":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]};
    [request addFormData:username forKey:@"user[login]"];
    [request addFormData:password forKey:@"user[password]"];
    [request startFormRequest];
    switch (request.getStatusCode) {
        case 200:
        case 201:{
            NSError *error = nil;
            NSDictionary *d = [XMLReader dictionaryForXMLString:request.getResponseDataString options:XMLReaderOptionsProcessNamespaces error:&error];
            if (!error){
                NSString *token = d[@"user"][@"authToken"];
                // Store Token
                [SAMKeychain setPassword:token forService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account: d[@"user"][@"username"][0]];
            return true;
            }
            else {
                return false;
            }
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
    NSArray *accounts = [SAMKeychain accountsForService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]]];
    if (accounts.count > 0) {
        //retrieve first valid account
        for (NSDictionary *account in accounts) {
            return (NSString *)account[@"acct"];
        }
    }
    return @"";
}
@end
