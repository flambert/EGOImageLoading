//
//  EGOImageLoader.h
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

#import <Foundation/Foundation.h>
#import "EGOImageLoaderCommon.h"

@protocol EGOImageLoaderObserver;
@interface EGOImageLoader : NSObject/*<NSURLConnectionDelegate>*/ {
@private
	NSLock* connectionsLock;
	NSDictionary* _currentConnections;
    NSMutableDictionary* currentConnections;
    dispatch_queue_t _operationQueue;
}

+ (EGOImageLoader*)sharedImageLoader;

- (BOOL)isLoadingImageURL:(NSURL*)aURL;
- (void)cancelLoadForURL:(NSURL*)aURL;

#if __EGOIL_USE_NOTIF
- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer;
- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache;
- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer style:(NSString*)style styler:(StylerBlock)styler;
- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache style:(NSString*)style styler:(StylerBlock)styler;
- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer;
- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache;
- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer style:(NSString*)style styler:(StylerBlock)styler;
- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer useMemoryCache:(BOOL)useMemoryCache style:(NSString*)style styler:(StylerBlock)styler;

- (void)removeObserver:(id<EGOImageLoaderObserver>)observer;
- (void)removeObserver:(id<EGOImageLoaderObserver>)observer forURL:(NSURL*)aURL;
- (void)removeObserver:(id<EGOImageLoaderObserver>)observer forURL:(NSURL*)aURL style:(NSString*)style;
#endif

#if __EGOIL_USE_BLOCKS
- (void)loadImageForURL:(NSURL*)aURL completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion;
- (void)loadImageForURL:(NSURL*)aURL useMemoryCache:(BOOL)useMemoryCache completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion;
- (void)loadImageForURL:(NSURL*)aURL style:(NSString*)style styler:(StylerBlock)styler completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion;
- (void)loadImageForURL:(NSURL*)aURL useMemoryCache:(BOOL)useMemoryCache style:(NSString*)style styler:(StylerBlock)styler completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion;
#endif

- (BOOL)hasLoadedImageURL:(NSURL*)aURL;
- (BOOL)hasLoadedImageURL:(NSURL*)aURL style:(NSString*)style;

- (void)clearCacheForURL:(NSURL*)aURL;
- (void)clearCacheForURL:(NSURL*)aURL style:(NSString*)style;

@property(nonatomic,retain) NSDictionary* currentConnections;
@end

@protocol EGOImageLoaderObserver<NSObject>
@optional
- (void)imageLoaderDidLoad:(NSNotification*)notification; // Object will be EGOImageLoader, userInfo will contain imageURL and image
- (void)imageLoaderDidFailToLoad:(NSNotification*)notification; // Object will be EGOImageLoader, userInfo will contain error
@end
