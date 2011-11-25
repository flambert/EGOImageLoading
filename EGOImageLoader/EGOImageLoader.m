//
//  EGOImageLoader.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/15/09.
//  Copyright (c) 2009-2010 enormego
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "EGOImageLoader.h"
#import "EGOImageLoadConnection.h"
#import "EGOCache.h"

static EGOImageLoader* __imageLoader;

inline static NSString* keyForURL(NSURL* url, NSString* style) {
	if(!style) {
		return [EGOCache keyForPrefix:@"EGOImageLoader" url:url];
	} else {
		return [[EGOCache keyForPrefix:@"EGOImageLoader" url:url] stringByAppendingFormat:@"-%@", style];
	}
}

#if __EGOIL_USE_BLOCKS
	#define kNoStyle @"EGOImageLoader-nostyle"
	#define kCompletionsKey @"completions"
	#define kStylerKey @"styler"
#endif

#if __EGOIL_USE_NOTIF
    #define kStylerQueue _operationQueue
	#define kImageNotificationLoaded(key) [@"kEGOImageLoaderNotificationLoaded-" stringByAppendingString:key]
	#define kImageNotificationLoadFailed(key) [@"kEGOImageLoaderNotificationLoadFailed-" stringByAppendingString:key]
#endif

@interface EGOImageLoader ()
#if __EGOIL_USE_BLOCKS
- (void)handleCompletionsForConnection:(EGOImageLoadConnection*)connection image:(UIImage*)image error:(NSError*)error;
#endif
@end

@implementation EGOImageLoader
@synthesize currentConnections=_currentConnections;

+ (EGOImageLoader*)sharedImageLoader {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        __imageLoader = [[[self class] alloc] init];
    });
	
	return __imageLoader;
}

- (id)init {
	if((self = [super init])) {
		connectionsLock = [[NSLock alloc] init];
		currentConnections = [[NSMutableDictionary alloc] init];

        _operationQueue = dispatch_queue_create("com.enormego.EGOImageLoader",NULL);
		dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0);
		dispatch_set_target_queue(priority, _operationQueue);
	}
	
	return self;
}

- (EGOImageLoadConnection*)loadingConnectionForURL:(NSURL*)aURL {
	EGOImageLoadConnection* connection = [[self.currentConnections objectForKey:aURL] retain];
	if(!connection) return nil;
	else return [connection autorelease];
}

- (void)cleanUpConnection:(EGOImageLoadConnection*)connection {
	if(!connection.imageURL) return;
	
	connection.delegate = nil;
	
	[connectionsLock lock];
	[currentConnections removeObjectForKey:connection.imageURL];
	self.currentConnections = [[currentConnections copy] autorelease];
	[connectionsLock unlock];	
}

- (void)clearCacheForURL:(NSURL*)aURL {
	[self clearCacheForURL:aURL style:nil];
}

- (void)clearCacheForURL:(NSURL*)aURL style:(NSString*)style {
	[[EGOCache currentCache] removeCacheForKey:keyForURL(aURL, style)];
}

- (BOOL)isLoadingImageURL:(NSURL*)aURL {
	return [self loadingConnectionForURL:aURL] ? YES : NO;
}

- (void)cancelLoadForURL:(NSURL*)aURL {
	EGOImageLoadConnection* connection = [self loadingConnectionForURL:aURL];
	[NSObject cancelPreviousPerformRequestsWithTarget:connection selector:@selector(start) object:nil];
	[connection cancel];
	[self cleanUpConnection:connection];
}

- (EGOImageLoadConnection*)loadImageForURL:(NSURL*)aURL useMemoryCache:(BOOL)useMemoryCache style:(NSString *)style styler:(UIImage *(^)(UIImage *))styler {
	EGOImageLoadConnection* connection;
	
	if((connection = [self loadingConnectionForURL:aURL])) {
        connection.useMemoryCache = useMemoryCache;

		return connection;
	} else {
		connection = [[EGOImageLoadConnection alloc] initWithImageURL:aURL delegate:self];
        connection.useMemoryCache = useMemoryCache;
        connection.style = style;
        connection.styler = styler;

		[connectionsLock lock];
		[currentConnections setObject:connection forKey:aURL];
		self.currentConnections = [[currentConnections copy] autorelease];
		[connectionsLock unlock];
		[connection performSelector:@selector(start) withObject:nil afterDelay:0.01];
		[connection release];

		return connection;
	}
}

#if __EGOIL_USE_NOTIF
- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer {
    [self loadImageForURL:aURL observer:observer useMemoryCache:YES style:nil styler:NULL];
}

- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache {
    [self loadImageForURL:aURL observer:observer useMemoryCache:useMemoryCache style:nil styler:NULL];
}

- (void)loadImageForURL:(NSURL *)aURL observer:(id<EGOImageLoaderObserver>)observer style:(NSString *)style styler:(UIImage *(^)(UIImage *))styler {
    [self loadImageForURL:aURL observer:observer useMemoryCache:YES style:style styler:styler];
}

- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache style:(NSString *)style styler:(UIImage *(^)(UIImage *))styler {
	if(!aURL) return;

    NSString* key = keyForURL(aURL,style);
	if([observer respondsToSelector:@selector(imageLoaderDidLoad:)])
		[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(imageLoaderDidLoad:) name:kImageNotificationLoaded(key) object:self];
	if([observer respondsToSelector:@selector(imageLoaderDidFailToLoad:)])
		[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(imageLoaderDidFailToLoad:) name:kImageNotificationLoadFailed(key) object:self];

	[self loadImageForURL:aURL useMemoryCache:useMemoryCache style:style styler:styler];
}

- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer {
    return [self imageForURL:aURL shouldLoadWithObserver:observer useMemoryCache:YES style:nil styler:NULL];
}

- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache {
    return [self imageForURL:aURL shouldLoadWithObserver:observer useMemoryCache:useMemoryCache style:nil styler:NULL];
}

- (UIImage*)imageForURL:(NSURL *)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer style:(NSString *)style styler:(UIImage *(^)(UIImage *))styler {
    return [self imageForURL:aURL shouldLoadWithObserver:observer useMemoryCache:YES style:style styler:styler];
}

- (UIImage*)imageForURL:(NSURL *)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache style:(NSString *)style styler:(UIImage *(^)(UIImage *))styler {
	if(!aURL) return nil;

    // Check if it is in memory (styled or not)
    NSString* key = keyForURL(aURL,style);
    if (useMemoryCache) {
        if([[EGOCache currentCache] hasCacheForKey:key checkOnlyMemory:YES]) {
            // It is, return it
            return [[EGOCache currentCache] imageForKey:key useMemoryCache:useMemoryCache];
        }
    }

    // Check if it is on disk (styled or not)
    if([[EGOCache currentCache] hasCacheForKey:key]){
        // It is, load it in background and send notification
        if([observer respondsToSelector:@selector(imageLoaderDidLoad:)])
            [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(imageLoaderDidLoad:) name:kImageNotificationLoaded(key) object:self];

        __block EGOImageLoader* object = self;
        dispatch_async(kStylerQueue, ^{
            UIImage* anImage = [[EGOCache currentCache] imageForKey:key useMemoryCache:useMemoryCache];
            NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoaded(key)
                                                                         object:object
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:anImage,@"image",aURL,@"imageURL",nil]];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        });
        return nil;
    }

    // Check if it is cached, but unstyled
    NSString* keyNoStyle = keyForURL(aURL,nil);
    if(style && styler && [[EGOCache currentCache] hasCacheForKey:keyNoStyle]) {
        // It is, load it, style it, cache it and send notification
        if([observer respondsToSelector:@selector(imageLoaderDidLoad:)])
            [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(imageLoaderDidLoad:) name:kImageNotificationLoaded(key) object:self];

        __block EGOImageLoader* object = self;
        dispatch_async(kStylerQueue, ^{
            UIImage* anImage = [[EGOCache currentCache] imageForKey:keyNoStyle useMemoryCache:useMemoryCache];
            UIImage* styledImage = styler(anImage);
            if (styledImage) {
                [[EGOCache currentCache] setImage:styledImage forKey:key withTimeoutInterval:604800 useMemoryCache:useMemoryCache];
                if (styledImage != anImage) {
                    [[EGOCache currentCache] removeMemoryCacheForKey:keyNoStyle];
                }
            }
            NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoaded(key)
                                                                         object:object
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:styledImage,@"image",aURL,@"imageURL",nil]];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        });
        return nil;
    }

    // It is not in cache, load it from URL
    [self loadImageForURL:aURL observer:observer useMemoryCache:useMemoryCache style:style styler:styler];
    return nil;
}

- (void)removeObserver:(id<EGOImageLoaderObserver>)observer {
	[[NSNotificationCenter defaultCenter] removeObserver:observer name:nil object:self];
}

- (void)removeObserver:(id<EGOImageLoaderObserver>)observer forURL:(NSURL*)aURL {
    [self removeObserver:observer forURL:aURL style:nil];
}

- (void)removeObserver:(id<EGOImageLoaderObserver>)observer forURL:(NSURL*)aURL style:(NSString*)style {
    NSString* key = keyForURL(aURL,style);
	[[NSNotificationCenter defaultCenter] removeObserver:observer name:kImageNotificationLoaded(key) object:self];
	[[NSNotificationCenter defaultCenter] removeObserver:observer name:kImageNotificationLoadFailed(key) object:self];
}
#endif

#if __EGOIL_USE_BLOCKS
- (void)loadImageForURL:(NSURL*)aURL completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion {
    [self loadImageForURL:aURL useMemoryCache:YES style:nil styler:NULL completion:completion];
}

- (void)loadImageForURL:(NSURL*)aURL useMemoryCache:(BOOL)useMemoryCache completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion {
    [self loadImageForURL:aURL useMemoryCache:useMemoryCache style:nil styler:NULL completion:completion];
}

- (void)loadImageForURL:(NSURL*)aURL style:(NSString*)style styler:(UIImage* (^)(UIImage* image))styler completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion {
    [self loadImageForURL:aURL useMemoryCache:YES style:style styler:styler completion:completion];
}

- (void)loadImageForURL:(NSURL*)aURL useMemoryCache:(BOOL)useMemoryCache style:(NSString*)style styler:(UIImage* (^)(UIImage* image))styler completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion {
    NSString* key = keyForURL(aURL,style);
	UIImage* anImage = [[EGOCache currentCache] imageForKey:key];

	if(anImage) {
		completion(anImage, aURL, nil);
	} else if(!anImage && styler && style && (anImage = [[EGOCache currentCache] imageForKey:keyForURL(aURL,nil)])) {
        dispatch_queue_t calling_queue = dispatch_get_current_queue();
		dispatch_async(kStylerQueue, ^{
			UIImage* styledImage = styler(anImage);
            if (styledImage) {
                [[EGOCache currentCache] setImage:styledImage forKey:key withTimeoutInterval:604800 useMemoryCache:useMemoryCache];
                if (styledImage != anImage) {
                    [[EGOCache currentCache] removeMemoryCacheForKey:keyForURL(aURL,nil)];
                }
            }
			dispatch_async(calling_queue, ^{
				completion(styledImage, aURL, nil);
			});
		});
	} else {
		EGOImageLoadConnection* connection = [self loadImageForURL:aURL useMemoryCache:useMemoryCache style:style styler:styler];
		void (^completionCopy)(UIImage* image, NSURL* imageURL, NSError* error) = [completion copy];
		
		NSString* handlerKey = style ? style : kNoStyle;
		NSMutableDictionary* handler = [connection.handlers objectForKey:handlerKey];
		
		if(!handler) {
			handler = [[NSMutableDictionary alloc] initWithCapacity:2];
			[connection.handlers setObject:handler forKey:handlerKey];

			[handler setObject:[NSMutableArray arrayWithCapacity:1] forKey:kCompletionsKey];
			if(styler) {
				UIImage* (^stylerCopy)(UIImage* image) = [styler copy];
				[handler setObject:stylerCopy forKey:kStylerKey];
				[stylerCopy release];
			}
			
			[handler release];
		}
		
		[[handler objectForKey:kCompletionsKey] addObject:completionCopy];
		[completionCopy release];
	}
}
#endif

- (BOOL)hasLoadedImageURL:(NSURL*)aURL {
    return [self hasLoadedImageURL:aURL style:nil];
}

- (BOOL)hasLoadedImageURL:(NSURL*)aURL style:(NSString*)style {
	return [[EGOCache currentCache] hasCacheForKey:keyForURL(aURL,style)];
}

#pragma mark -
#pragma mark URL Connection delegate methods

- (void)imageLoadConnectionDidFinishLoading:(EGOImageLoadConnection *)connection {
	UIImage* anImage = [UIImage imageWithData:connection.responseData];
	
	if(!anImage) {
		NSError* error = [NSError errorWithDomain:[connection.imageURL host] code:406 userInfo:nil];
		
#if __EGOIL_USE_NOTIF
		NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoadFailed(keyForURL(connection.imageURL,connection.style))
																	 object:self
																   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:error,@"error",connection.imageURL,@"imageURL",nil]];
		
		[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
#endif
		
#if __EGOIL_USE_BLOCKS
		[self handleCompletionsForConnection:connection image:nil error:error];
#endif
	} else {
        NSString* keyNoStyle = keyForURL(connection.imageURL,nil);
		[[EGOCache currentCache] setImage:anImage forKey:keyNoStyle withTimeoutInterval:604800 useMemoryCache:connection.useMemoryCache];
		
		[currentConnections removeObjectForKey:connection.imageURL];
		self.currentConnections = [[currentConnections copy] autorelease];
		
#if __EGOIL_USE_NOTIF
        // Check if the image must be styled
        if (connection.style && connection.styler) {
            // It does, style it and send notification
            __block EGOImageLoader* object = self;
            dispatch_async(kStylerQueue, ^{
                NSString* key = keyForURL(connection.imageURL,connection.style);
                UIImage* styledImage = connection.styler(anImage);
                if (styledImage) {
                    [[EGOCache currentCache] setImage:styledImage forKey:key withTimeoutInterval:604800 useMemoryCache:connection.useMemoryCache];
                    if (styledImage != anImage) {
                        [[EGOCache currentCache] removeMemoryCacheForKey:keyNoStyle];
                    }
                }
                NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoaded(key)
                                                                             object:object
                                                                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:styledImage,@"image",connection.imageURL,@"imageURL",nil]];
                [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
            });
        } else {
            // It does not, send notification
            NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoaded(keyNoStyle)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:anImage,@"image",connection.imageURL,@"imageURL",nil]];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
#endif
		
#if __EGOIL_USE_BLOCKS
		[self handleCompletionsForConnection:connection image:anImage error:nil];
#endif
	}

	[self cleanUpConnection:connection];
}

- (void)imageLoadConnection:(EGOImageLoadConnection *)connection didFailWithError:(NSError *)error {
	[currentConnections removeObjectForKey:connection.imageURL];
	self.currentConnections = [[currentConnections copy] autorelease];
	
#if __EGOIL_USE_NOTIF
	NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoadFailed(keyForURL(connection.imageURL,connection.style))
																 object:self
															   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:error,@"error",connection.imageURL,@"imageURL",nil]];
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
#endif
	
#if __EGOIL_USE_BLOCKS
	[self handleCompletionsForConnection:connection image:nil error:error];
#endif

	[self cleanUpConnection:connection];
}

#if __EGOIL_USE_BLOCKS
- (void)handleCompletionsForConnection:(EGOImageLoadConnection*)connection image:(UIImage*)image error:(NSError*)error {
	if([connection.handlers count] == 0) return;

	NSURL* imageURL = connection.imageURL;
	
    dispatch_queue_t calling_queue = dispatch_get_current_queue();
	void (^callCompletions)(UIImage* anImage, NSArray* completions) = ^(UIImage* anImage, NSArray* completions) {
		dispatch_async(calling_queue, ^{
			for(void (^completion)(UIImage* image, NSURL* imageURL, NSError* error) in completions) {
				completion(anImage, connection.imageURL, error);
			}
		});
	};
	
	for(NSString* styleKey in connection.handlers) {
		NSDictionary* handler = [connection.handlers objectForKey:styleKey];
		UIImage* (^styler)(UIImage* image) = [handler objectForKey:kStylerKey];
		if(!error && image && styler) {
			dispatch_async(kStylerQueue, ^{
				UIImage* anImage = styler(image);
                if (anImage) {
                    [[EGOCache currentCache] setImage:anImage forKey:keyForURL(imageURL, styleKey) withTimeoutInterval:604800 useMemoryCache:connection.useMemoryCache];
                    if (anImage != image) {
                        [[EGOCache currentCache] removeMemoryCacheForKey:keyForURL(imageURL, nil)];
                    }
                }
				callCompletions(anImage, [handler objectForKey:kCompletionsKey]);
			});
		} else {
			callCompletions(image, [handler objectForKey:kCompletionsKey]);
		}
	}
}
#endif

#pragma mark -

- (void)dealloc {
	[connectionsLock release];
	[currentConnections release];
	self.currentConnections = nil;
	dispatch_release(_operationQueue);
	[super dealloc];
}

@end
