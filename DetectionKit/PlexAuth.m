//
//  PlexAuth.m
//  DetectionKit
//
//  Created by 天々座理世 on 2017/07/07.
//  Copyright © 2017年 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import "PlexAuth.h"
#import <SAMKeychain/SAMKeychain.h>
#import <XMLReader/XMLReader.h>
#import <AFNetworking/AFNetworking.h>

@implementation PlexAuth
+ (void)performplexlogin:(NSString *)username withPassword:(NSString *)password completion:(void (^)(bool success)) completionHandler {
    // Retrieve Token
    AFHTTPSessionManager *manager = [self manager];
    [manager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"plexidentifier"] forHTTPHeaderField:@"X-Plex-Client-Identifier"];
    [manager.requestSerializer setValue:NSBundle.mainBundle.infoDictionary[@"CFBundleName"] forHTTPHeaderField:@"X-Plex-Product"];
    [manager.requestSerializer setValue:@"X-Plex-Version" forHTTPHeaderField:NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
    [manager POST:@"https://plex.tv/users/sign_in.xml" parameters:@{@"user[login]" : username, @"user[password]" : password} headers:@{} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSError *error;
        NSDictionary *d = [XMLReader dictionaryForXMLString:[NSString stringWithUTF8String:[responseObject bytes]] options:XMLReaderOptionsProcessNamespaces error:&error];
        if (!error) {
            NSString *token = d[@"user"][@"authToken"];
            // Store Token
            [SAMKeychain setPassword:token forService:[NSString stringWithFormat:@"%@ - Plex", NSBundle.mainBundle.infoDictionary[@"CFBundleName"]] account: d[@"user"][@"username"][0]];
            completionHandler(true);
        }
        else {
            completionHandler(false);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        completionHandler(false);
        return;
    }];
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
+ (AFHTTPSessionManager*) manager
{
    static dispatch_once_t onceToken;
    static AFHTTPSessionManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [AFHTTPSessionManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    });
    
    return manager;
}
@end
