// RavenJSONUtilities.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "RavenJSONUtilities.h"

NSMutableDictionary * cleanDictionary(NSDictionary * inDictionary);


NSMutableArray * cleanArray(NSArray * inArray){
	
	NSMutableArray * tmpArray = [NSMutableArray array];
	for (id tmpValue in inArray) {
		
		if([tmpValue isKindOfClass:[NSDate class]]){
			[tmpArray addObject:@([(NSDate*)tmpValue timeIntervalSince1970])];
		}else if([tmpValue isKindOfClass:[NSDictionary class]]){
			[tmpArray addObject:cleanDictionary(tmpValue)];
		}else if([tmpValue isKindOfClass:[NSArray class]]){
			[tmpArray addObject:cleanArray(tmpValue)];
		}
	}
	return tmpArray;
}


NSMutableDictionary * cleanDictionary(NSDictionary * inDictionary){
	
	NSMutableDictionary * tmpDictionary = [NSMutableDictionary dictionary];
	NSArray * tmpKeysArray = [inDictionary allKeys];
	for (NSString * tmpKey in tmpKeysArray) {
		id tmpValue = inDictionary[tmpKey];
		//DLog(@"%@", tmpKey);
		if([tmpValue isKindOfClass:[NSDate class]]){
			[tmpDictionary setObject:@([(NSDate*)tmpValue timeIntervalSince1970]) forKey:tmpKey];
		}else if([tmpValue isKindOfClass:[NSData class]]){
		//	[tmpDictionary setObject:@([(NSDate*)tmpValue timeIntervalSince1970]) forKey:tmpKey];
		}else if([tmpValue isKindOfClass:[NSDictionary class]]){
			[tmpDictionary setObject:cleanDictionary(tmpValue) forKey:tmpKey];
		}else if([tmpValue isKindOfClass:[NSArray class]]){
			[tmpDictionary setObject:cleanArray(tmpValue) forKey:tmpKey];
		}else{
			[tmpDictionary setObject:tmpValue forKey:tmpKey];
		}
	}
	return tmpDictionary;
}


NSData * JSONEncode(id object, NSError **error) {
    __unsafe_unretained NSData *data = nil;
    
    SEL _JSONKitSelector = NSSelectorFromString(@"JSONDataWithOptions:error:"); 
    SEL _YAJLSelector = NSSelectorFromString(@"yajl_JSONString");
    
    id _SBJsonWriterClass = NSClassFromString(@"SBJsonWriter");
    SEL _SBJsonWriterSelector = NSSelectorFromString(@"dataWithObject:");
    
    id _NXJsonSerializerClass = NSClassFromString(@"NXJsonSerializer");
    SEL _NXJsonSerializerSelector = NSSelectorFromString(@"serialize:");

    id _NSJSONSerializationClass = NSClassFromString(@"NSJSONSerialization");
    SEL _NSJSONSerializationSelector = NSSelectorFromString(@"dataWithJSONObject:options:error:");
    
    if (_JSONKitSelector && [object respondsToSelector:_JSONKitSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:_JSONKitSelector]];
        invocation.target = object;
        invocation.selector = _JSONKitSelector;
        
        NSUInteger serializeOptionFlags = 0;
        [invocation setArgument:&serializeOptionFlags atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        
        [invocation invoke];
        [invocation getReturnValue:&data];
    } else if (_SBJsonWriterClass && [_SBJsonWriterClass instancesRespondToSelector:_SBJsonWriterSelector]) {
        id writer = [[_SBJsonWriterClass alloc] init];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[writer methodSignatureForSelector:_SBJsonWriterSelector]];
        invocation.target = writer;
        invocation.selector = _SBJsonWriterSelector;
        
        [invocation setArgument:&object atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        
        [invocation invoke];
        [invocation getReturnValue:&data];
    } else if (_YAJLSelector && [object respondsToSelector:_YAJLSelector]) {
        @try {
            __unsafe_unretained NSString *JSONString = nil;
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:_YAJLSelector]];
            invocation.target = object;
            invocation.selector = _YAJLSelector;
            
            [invocation invoke];
            [invocation getReturnValue:&JSONString];
            
            data = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
        }
        @catch (NSException *exception) {
            *error = [[NSError alloc] initWithDomain:NSStringFromClass([exception class]) code:0 userInfo:[exception userInfo]];
        }
    } else if (_NXJsonSerializerClass && [_NXJsonSerializerClass respondsToSelector:_NXJsonSerializerSelector]) {
        __unsafe_unretained NSString *JSONString = nil;
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NXJsonSerializerClass methodSignatureForSelector:_NXJsonSerializerSelector]];
        invocation.target = _NXJsonSerializerClass;
        invocation.selector = _NXJsonSerializerSelector;
        
        [invocation setArgument:&object atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        
        [invocation invoke];
        [invocation getReturnValue:&JSONString];
        data = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    } else if (_NSJSONSerializationClass && [_NSJSONSerializationClass respondsToSelector:_NSJSONSerializationSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NSJSONSerializationClass methodSignatureForSelector:_NSJSONSerializationSelector]];
        invocation.target = _NSJSONSerializationClass;
        invocation.selector = _NSJSONSerializationSelector;

		NSMutableDictionary * tmpDictionary =  cleanDictionary(object);

        [invocation setArgument:&tmpDictionary atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        NSUInteger writeOptions = 0;
        [invocation setArgument:&writeOptions atIndex:3];
        if (error != NULL) {
            [invocation setArgument:&error atIndex:4];
        }
		
		@try {
			[invocation invoke];
			[invocation getReturnValue:&data];


		}@catch (NSException *exception) {
			NSLog(@"%@", exception);
			*error = [[NSError alloc] initWithDomain:NSStringFromClass([exception class]) code:0 userInfo:[exception userInfo]];
		}
		
    } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Please either target a platform that supports NSJSONSerialization or add one of the following libraries to your project: JSONKit, SBJSON, or YAJL", nil) forKey:NSLocalizedRecoverySuggestionErrorKey];
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:NSLocalizedString(@"No JSON generation functionality available", nil) userInfo:userInfo] raise];
    }

    return data;
}

id JSONDecode(NSData *data, NSError **error) {    
    __unsafe_unretained id JSON = nil;
    
    SEL _JSONKitSelector = NSSelectorFromString(@"objectFromJSONDataWithParseOptions:error:"); 
    SEL _YAJLSelector = NSSelectorFromString(@"yajl_JSONWithOptions:error:");
    
    id _SBJSONParserClass = NSClassFromString(@"SBJsonParser");
    SEL _SBJSONParserSelector = NSSelectorFromString(@"objectWithData:");

    id _NSJSONSerializationClass = NSClassFromString(@"NSJSONSerialization");
    SEL _NSJSONSerializationSelector = NSSelectorFromString(@"JSONObjectWithData:options:error:");
    
    id _NXJsonParserClass = NSClassFromString(@"NXJsonParser");
    SEL _NXJsonParserSelector = NSSelectorFromString(@"parseData:error:ignoreNulls:");

    if (_JSONKitSelector && [data respondsToSelector:_JSONKitSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[data methodSignatureForSelector:_JSONKitSelector]];
        invocation.target = data;
        invocation.selector = _JSONKitSelector;
        
        NSUInteger parseOptionFlags = 0;
        [invocation setArgument:&parseOptionFlags atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        
        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_SBJSONParserClass && [_SBJSONParserClass instancesRespondToSelector:_SBJSONParserSelector]) {
        id parser = [[_SBJSONParserClass alloc] init];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[parser methodSignatureForSelector:_SBJSONParserSelector]];
        invocation.target = parser;
        invocation.selector = _SBJSONParserSelector;
        
        [invocation setArgument:&data atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation

        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_YAJLSelector && [data respondsToSelector:_YAJLSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[data methodSignatureForSelector:_YAJLSelector]];
        invocation.target = data;
        invocation.selector = _YAJLSelector;
        
        NSUInteger yajlParserOptions = 0;
        [invocation setArgument:&yajlParserOptions atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        
        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_NXJsonParserClass && [_NXJsonParserClass respondsToSelector:_NXJsonParserSelector]) {
        NSNumber *nullOption = [NSNumber numberWithBool:YES];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NXJsonParserClass methodSignatureForSelector:_NXJsonParserSelector]];
        invocation.target = _NXJsonParserClass;
        invocation.selector = _NXJsonParserSelector;
        
        [invocation setArgument:&data atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        [invocation setArgument:&nullOption atIndex:4];
        
        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_NSJSONSerializationClass && [_NSJSONSerializationClass respondsToSelector:_NSJSONSerializationSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NSJSONSerializationClass methodSignatureForSelector:_NSJSONSerializationSelector]];
        invocation.target = _NSJSONSerializationClass;
        invocation.selector = _NSJSONSerializationSelector;

        [invocation setArgument:&data atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        NSUInteger readOptions = 0;
        [invocation setArgument:&readOptions atIndex:3];
        if (error != NULL) {
            [invocation setArgument:&error atIndex:4];
        }

        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Please either target a platform that supports NSJSONSerialization or add one of the following libraries to your project: JSONKit, SBJSON, or YAJL", nil) forKey:NSLocalizedRecoverySuggestionErrorKey];
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:NSLocalizedString(@"No JSON parsing functionality available", nil) userInfo:userInfo] raise];
    }
        
    return JSON;
}
