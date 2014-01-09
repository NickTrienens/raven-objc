//
//  RavenClient.h
//  Raven
//
//  Created by Kevin Renskers on 25-05-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RavenCaptureMessage( s, ... ) [[RavenClient sharedClient] captureMessage:[NSString stringWithFormat:(s), ##__VA_ARGS__] level:kRavenLogLevelDebugWarning method:__FUNCTION__ file:__FILE__ line:__LINE__]

#define RavenCaptureMessageWithLevel(inLevel, s,  ... ) [[RavenClient sharedClient] captureMessage:[NSString stringWithFormat:(s), ##__VA_ARGS__] level:inLevel method:__FUNCTION__ file:__FILE__ line:__LINE__]

#ifdef DEBUG
	#define RavenCaptureDebugMessageWithLevel(inLevel, s,  ... ) [[RavenClient sharedClient] captureMessage:[NSString stringWithFormat:(s), ##__VA_ARGS__] level:inLevel method:__FUNCTION__ file:__FILE__ line:__LINE__]
#else
	#define RavenCaptureDebugMessageWithLevel(inLevel, s,  ... )
#endif

#define RavenCreateDictinaryWithMessage( s, inParams ) [[RavenClient sharedClient] createDictionaryWithMessage:s params:inParams level:kRavenLogLevelDebugWarning method:__FUNCTION__ file:__FILE__ line:__LINE__]



#ifndef kRavenCachedEventsDirectory
	#define  kRavenCachedEventsDirectory @"RavenEvents"
#endif

typedef enum {
    kRavenLogLevelDebug,
    kRavenLogLevelDebugInfo,
    kRavenLogLevelDebugWarning,
    kRavenLogLevelDebugError,
    kRavenLogLevelDebugFatal
} RavenLogLevel;

/*
 
"sentry.interfaces.Exception"
 
 
sentry.interfaces.Message
 message
 params
 
 
sentry.interfaces.Query
 message
 level
 
sentry.interfaces.Http
 method
 url
 query_string
 data
 cookies
 headers
 env
 
sentry.interfaces.User
 id
 data == dictionary
 */



@interface RavenClient : NSObject

@property(strong) NSMutableArray * backlog;
@property(strong) NSTimer * backlogRequestTrigger;

// Singleton and initializers
+ (RavenClient *)clientWithDSN:(NSString *)DSN;
+ (RavenClient *)sharedClient;

- (id)initWithDSN:(NSString *)DSN;

// Messages
- (void)captureMessage:(NSString *)message;
- (void)captureMessage:(NSString *)message level:(RavenLogLevel)level;
- (void)captureMessage:(NSString *)message level:(RavenLogLevel)level method:(const char *)method file:(const char *)file line:(NSInteger)line;


-(NSMutableDictionary*)createDictionaryWithMessage:(NSString *)message params:(NSArray*)params level:(RavenLogLevel)level method:(const char *)method file:(const char *)file line:(NSInteger)line;
-(NSMutableDictionary*)addRequestReportingToDictionary:(NSMutableDictionary*)inDictionary responseObject:(NSHTTPURLResponse*)response request:(NSURLRequest*)request;
-(NSMutableDictionary*)addQueryReportingToDictionary:(NSMutableDictionary*)inDictionary queryMessage:(NSString*)inMessage level:(NSString*)inLevel;
-(NSMutableDictionary*)addUserReportingToDictionary:(NSMutableDictionary*)inDictionary userId:(NSString*)inId userData:(NSDictionary*)inUserData;

- (void)sendDictionary:(NSDictionary *)dict;


// Exceptions
- (void)captureException:(NSException *)exception;
- (void)captureException:(NSException *)exception sendNow:(BOOL)sendNow;
- (void)setupExceptionHandler;

@end
