//
//  RavenClient.m
//  Raven
//
//  Created by Kevin Renskers on 25-05-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "RavenClient.h"
#import "RavenClient_Private.h"
#import "RavenConfig.h"
#import "RavenJSONUtilities.h"

NSString *const kRavenLogLevelArray[] = {
    @"debug",
    @"info",
    @"warning",
    @"error",
    @"fatal"
};

NSString *const userDefaultsKey = @"nl.mixedCase.RavenClient.Exceptions";

static RavenClient *sharedClient = nil;

@implementation RavenClient

void exceptionHandler(NSException *exception) {
	[[RavenClient sharedClient] captureException:exception sendNow:NO];
}

#pragma mark - Setters and getters

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setTimeZone:timeZone];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    }

    return _dateFormatter;
}

#pragma mark - Singleton and initializers

+ (RavenClient *)clientWithDSN:(NSString *)DSN {
    RavenClient *client = [[self alloc] initWithDSN:DSN];
    return client;
}

+ (RavenClient *)sharedClient {
    return sharedClient;
}

- (id)initWithDSN:(NSString *)DSN {
    self = [super init];
    if (self) {
        self.config = [[RavenConfig alloc] init];
        
        // Parse DSN
        if (![self.config setDSN:DSN]) {
            NSLog(@"Invalid DSN %@!", DSN);
            return nil;
        }

        // Save singleton
        if (sharedClient == nil) {
            sharedClient = self;
        }
		
		self.backlog = (NSMutableArray*)[self readObjectFromFile:[self pathForCachedEventWithID:@"backlog.xml"]];
		if(self.backlog == nil){
			self.backlog = [NSMutableArray array];
		}else{
			[self sendBackloggedEvent];
		}
		
    }

    return self;
}

#pragma mark - Messages

- (void)captureMessage:(NSString *)message {
    [self captureMessage:message level:kRavenLogLevelDebugInfo];
}

- (void)captureMessage:(NSString *)message level:(RavenLogLevel)level {
    [self captureMessage:message level:level method:nil file:nil line:0];
}

- (void)captureMessage:(NSString *)message level:(RavenLogLevel)level method:(const char *)method file:(const char *)file line:(NSInteger)line {
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          [self generateUUID], @"event_id",
                          self.config.projectId, @"project",
                          [self.dateFormatter stringFromDate:[NSDate date]], @"timestamp",
                          message, @"message",
                          kRavenLogLevelArray[level], @"level",
                          @"objc", @"platform",
                          nil];

    
    if (file) {
        [data setObject:[[NSString stringWithUTF8String:file] lastPathComponent] forKey:@"culprit"];
    }

    if (method && file && line) {
        NSDictionary *frame = [NSDictionary dictionaryWithObjectsAndKeys:
                               [[NSString stringWithUTF8String:file] lastPathComponent], @"filename", 
                               [NSString stringWithUTF8String:method], @"function", 
                               [NSNumber numberWithInt:line], @"lineno", 
                               nil];

        NSDictionary *stacktrace = [NSDictionary dictionaryWithObjectsAndKeys:
                      [NSArray arrayWithObject:frame], @"frames", 
                      nil];

        [data setObject:stacktrace forKey:@"sentry.interfaces.Stacktrace"];
    }

    [self sendDictionary:data];
}

#pragma mark - Exceptions

- (void)captureException:(NSException *)exception {
    [self captureException:exception sendNow:YES];
}

- (void)captureException:(NSException *)exception sendNow:(BOOL)sendNow {
    NSString *message = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 [self generateUUID], @"event_id",
                                 self.config.projectId, @"project",
                                 [self.dateFormatter stringFromDate:[NSDate date]], @"timestamp",
                                 message, @"message",
                                 kRavenLogLevelArray[kRavenLogLevelDebugFatal], @"level",
                                 @"objc", @"platform",
                                 nil];

    NSDictionary *exceptionDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   exception.name, @"type",
                                   exception.reason, @"value",
                                   nil];

    NSDictionary *extraDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [exception callStackSymbols], @"CallStack",
                                   nil];

    [data setObject:exceptionDict forKey:@"sentry.interfaces.Exception"];
    [data setObject:extraDict forKey:@"extra"];

    if (!sendNow) {
        // We can't send this exception to Sentry now, e.g. because the app is killed before the
        // connection can be made. So, save it into NSUserDefaults.
        NSArray *reports = [[NSUserDefaults standardUserDefaults] objectForKey:userDefaultsKey];
        if (reports != nil) {
            NSMutableArray *reportsCopy = [reports mutableCopy];
            [reportsCopy addObject:data];
            [[NSUserDefaults standardUserDefaults] setObject:reportsCopy forKey:userDefaultsKey];
        } else {
            reports = [NSArray arrayWithObject:data];
            [[NSUserDefaults standardUserDefaults] setObject:reports forKey:userDefaultsKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [self sendDictionary:data];
    }
}

- (void)setupExceptionHandler {
    NSSetUncaughtExceptionHandler(&exceptionHandler);

    // Process saved crash reports
    NSArray *reports = [[NSUserDefaults standardUserDefaults] objectForKey:userDefaultsKey];
    if (reports != nil && [reports count]) {
        for (NSDictionary *data in reports) {
            [self sendDictionary:data];
        }
        [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:userDefaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - Private methods

- (NSString *)generateUUID {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    NSString *res = [(__bridge NSString *)string stringByReplacingOccurrencesOfString:@"-" withString:@""];
    CFRelease(string);
    return res;
}

- (void)sendDictionary:(NSDictionary *)dict {
    NSError *error = nil;

    NSData *JSON = JSONEncode(dict, &error);
   

    NSTimeInterval timestamp = [NSDate timeIntervalSinceReferenceDate];
    NSString *header = [NSString stringWithFormat:@"Sentry sentry_version=2.0, sentry_client=raven-objc/0.1.0, sentry_timestamp=%f, sentry_key=%@", timestamp, self.config.publicKey];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.config.serverURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%d", [JSON length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:JSON];
    [request setValue:header forHTTPHeaderField:@"X-Sentry-Auth"];


	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		NSURLResponse * tmpResponse = nil;
		NSError * tmpError =nil;
		NSData * tmpDataResponse = [NSURLConnection sendSynchronousRequest:request returningResponse:&tmpResponse error:&tmpError];
		
		NSString * tmpStr = [[NSString alloc] initWithData:tmpDataResponse encoding:NSUTF8StringEncoding];
		NSLog(@"%@", tmpStr);
		
		if(tmpError){
			NSLog(@"Connection failed! Error - %@ %@", [tmpError localizedDescription], [[tmpError userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
			
			//write the dictionary to then disk for an attempt later.
			[self writeObject:dict toFile:[self pathForCachedEventWithID:dict[@"event_id"]]];
			@synchronized(self.backlog){
				[self.backlog addObject:dict[@"event_id"]];
				[self writeObject:self.backlog toFile:[self pathForCachedEventWithID:@"backlog.xml"]];
			}
			[self createBacklogTrigger];
		}
		
	});
	
}

-(void)createBacklogTrigger{
	if(self.backlogRequestTrigger == nil){
		self.backlogRequestTrigger = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(sendBackloggedEvent) userInfo:nil repeats:YES];
	}
}

-(void)sendBackloggedEvent{
	NSLog(@"%d", [self.backlog count]);
	NSString * tmpEventID = [self.backlog firstObject];
	if (tmpEventID == nil) {
		[self.backlogRequestTrigger invalidate];
		self.backlogRequestTrigger = nil;
		return;
	}
	[self createBacklogTrigger];
	
	//remove this event from the backlog, it will be added to the end if it failes again
	@synchronized(self.backlog){
		[self.backlog removeObject:tmpEventID];
		[self writeObject:self.backlog toFile:[self pathForCachedEventWithID:@"backlog.xml"]];
	}
	//Make sure a file exist with the full event data
	NSDictionary * tmpEventDictionary = (NSDictionary *)[self readObjectFromFile:[self pathForCachedEventWithID:tmpEventID]];
	[[NSFileManager defaultManager] removeItemAtPath:[self pathForCachedEventWithID:tmpEventID] error:nil];
	if([tmpEventDictionary isKindOfClass:[NSDictionary class]]){
		
		[self sendDictionary:tmpEventDictionary];
			
	}
	
}

#pragma mark - NSURLConnectionDelegate

-(NSObject<NSCoding>*)readObjectFromFile:(NSString *)filePath
{
    //archive object
	NSData * fileData = [NSData dataWithContentsOfFile:filePath];
	if(fileData == nil){
		return nil;
	}
	NSKeyedUnarchiver * tmpUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:fileData];
	NSObject<NSCoding>* tmpObj = [tmpUnarchiver decodeObject];
	[tmpUnarchiver finishDecoding];
	
	return tmpObj;
}



- (BOOL)writeObject:(NSObject<NSCoding>*)inObject toFile:(NSString *)filePath
{
    //archive object
	NSMutableData *xmlData = [NSMutableData data];
	NSKeyedArchiver *archive = [[NSKeyedArchiver alloc ]initForWritingWithMutableData:xmlData];
	
	[archive setOutputFormat:NSPropertyListXMLFormat_v1_0];
	[archive encodeRootObject:inObject];
	[archive finishEncoding];
	
	if(![xmlData writeToFile:filePath atomically:YES]){
		NSLog(@"Failed to write to file to filePath=%@", filePath);
		return NO;
	}
	return YES;
}


- (NSString *)pathForCachedEventWithID:(NSString *)inStr{
	
	NSString *tmpEventPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	tmpEventPath = [tmpEventPath stringByAppendingPathComponent:kRavenCachedEventsDirectory];
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken,^{
		  BOOL tmpIsDirectory = NO;
		  if (![[NSFileManager defaultManager] fileExistsAtPath:tmpEventPath isDirectory:&tmpIsDirectory])
				[[NSFileManager defaultManager]  createDirectoryAtPath:tmpEventPath withIntermediateDirectories:NO attributes:nil error:nil];
				NSURL * tmpFile = [NSURL fileURLWithPath:tmpEventPath];
				[tmpFile setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
	  });
	
	tmpEventPath = [tmpEventPath stringByAppendingPathComponent:inStr];
	return tmpEventPath;
	
}




@end
