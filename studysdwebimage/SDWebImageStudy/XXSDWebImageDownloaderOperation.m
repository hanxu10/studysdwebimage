//
//  XXSDWebImageDownloaderOperation.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/3.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageDownloaderOperation.h"
#import "XXSDWebImageManager.h"
#import "NSImage+XXWebCache.h"
#import "XXSDWebImageCodersManager.h"

#define XXLOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define XXUNLOCK(lock) dispatch_semaphore_signal(lock);

// iOS 8 Foundation.framework extern这些符号，但定义在CFNetwork.framework中。 我们只是修复这个问题而不导入CFNetwork.framework
#if (__IPHONE_OS_VERSION_MIN_REQUIRED && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0)
const float NSURLSessionTaskPriorityDefault = 0.75;
const float NSURLSessionTaskPriorityLow = 0.5;
const float NSURLSessionTaskPriorityHigh = 0.25;
#endif

NSString *const XXSDWebImageDownloadStartNotification = @"XXSDWebImageDownloadStartNotification";
NSString *const XXSDWebImageDownloadReceiveResponseNotification = @"XXSDWebImageDownloadReceiveResponseNotification";
NSString *const XXSDWebImageDownloadStopNotification = @"XXSDWebImageDownloadStopNotification";
NSString *const XXSDWebImageDownloadFinishNotification = @"XXSDWebImageDownloadFinishNotification";

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";

typedef NSMutableDictionary<NSString *, id> XXSDCallbackDictionary;

@interface XXSDWebImageDownloaderOperation ()

@property (nonatomic, strong) NSMutableArray<XXSDCallbackDictionary *> *callbackBlocks;
@property (nonatomic, assign, getter=isFinished) BOOL finished;
@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, strong) NSMutableData *imageData;
@property (nonatomic, copy) NSData *cachedData;//用于`SDWebImageDownloaderIgnoreCachedResponse`

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run
// the task associated with this operation
@property (nonatomic, weak) NSURLSession *unownedSession;

// This is set if we're using not using an injected NSURLSession. We're responsible of invalidating this one
@property (strong, nonatomic) NSURLSession *ownedSession;

@property (nonatomic, strong) NSURLSessionTask *dataTask;

// a lock to keep the access to `callbackBlocks` thread-safe
@property (nonatomic, strong) dispatch_semaphore_t callbacksLock;

// the queue to do image decoding
@property (nonatomic, strong) dispatch_queue_t coderQueue;

#if XXSD_UIKIT
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskId;
#endif

@property (nonatomic, strong) id<XXSDWebImageProgressiveCoder> progressiveCoder;

@end

@implementation XXSDWebImageDownloaderOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)init
{
    return [self initWithRequest:nil inSession:nil options:0];
}

- (instancetype)initWithRequest:(NSURLRequest *)request
                      inSession:(NSURLSession *)session
                        options:(XXSDWebImageDownloaderOptions)options
{
    if (self = [super init]) {
        _request = [request copy];
        _shouldDecompressImages = YES;
        _options = options;
        _callbackBlocks = [NSMutableArray array];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        _callbacksLock = dispatch_semaphore_create(1);
        _coderQueue = dispatch_queue_create("com.xuxu.XXSDWebImageDownloaderOperationCoderQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (id)addHandlersForProgress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                   completed:(XXSDWebImageDownloaderCompletionBlock)completedBlock
{
    XXSDCallbackDictionary *callbacks = [NSMutableDictionary dictionary];
    if (progressBlock) {
        callbacks[kProgressCallbackKey] = [progressBlock copy];
    }
    if (completedBlock) {
        callbacks[kCompletedCallbackKey] = [completedBlock copy];
    }
    XXLOCK(self.callbacksLock);
    [self.callbackBlocks addObject:callbacks];
    XXUNLOCK(self.callbacksLock);
    return callbacks;
}

- (NSArray<id> *)callbacksForKey:(NSString *)key
{
    XXLOCK(self.callbacksLock);
    NSMutableArray<id> *callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
    XXUNLOCK(self.callbacksLock);
    //我们需要删除[NSNull null]，因为每个回调可能并不总是一个进度块
    [callbacks removeObjectIdenticalTo:[NSNull null]];
    return [callbacks copy];
}

- (BOOL)cancel:(id)token
{
    BOOL shouldCancel = NO;
    XXLOCK(self.callbacksLock);
    [self.callbackBlocks removeObjectIdenticalTo:token];
    if (self.callbackBlocks.count == 0) {
        shouldCancel = YES;
    }
    XXUNLOCK(self.callbacksLock);
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}

- (void)start
{
    @synchronized(self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
    
#if XXSD_UIKIT
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            __weak typeof(self) wself = self;
            UIApplication *app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong typeof(wself) sself = wself;
                
                if (sself) {
                    [sself cancel];
                    
                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
            
        }
#endif
        NSURLSession *session = self.unownedSession;
        if (!session) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
            self.ownedSession = session;
        }
        
        if (self.options & XXSDWebImageDownloaderIgnoreCachedResponse) {
            //抓取缓存的数据以供稍后检查
            NSURLCache *URLCache = session.configuration.URLCache;
            if (!URLCache) {
                URLCache = [NSURLCache sharedURLCache];
            }
            NSCachedURLResponse *cachedResponse;
            // NSURLCache's `cachedResponseForRequest:` is not thread-safe, see https://developer.apple.com/documentation/foundation/nsurlcache#2317483
            @synchronized(URLCache) {
                cachedResponse = [URLCache cachedResponseForRequest:self.request];
            }
            if (cachedResponse) {
                self.cachedData = cachedResponse.data;
            }
        }
        
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
    }
    
    if (self.dataTask) {
        if ([self.dataTask respondsToSelector:@selector(setPriority:)]) {
            if (self.options & XXSDWebImageDownloaderHightPriority) {
                self.dataTask.priority = NSURLSessionTaskPriorityHigh;
            } else if (self.options & XXSDWebImageDownloaderLowPriority) {
                self.dataTask.priority = NSURLSessionTaskPriorityLow;
            }
        }
        [self.dataTask resume];
        for (XXSDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, NSURLResponseUnknownLength, self.request.URL);
        }
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XXSDWebImageDownloadStartNotification object:weakSelf];
        });
    } else {
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey : @"task 无法初始化"}]];
        [self done];
        return;
    }
#if XXSD_UIKIT
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
#endif
}

- (void)cancel
{
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal
{
    if (self.isFinished) {
        return;
    }
    
    if (self.dataTask) {
        [self.dataTask cancel];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XXSDWebImageDownloadStopNotification object:weakSelf];
        });
        
        if (self.isExecuting) {
            self.executing = NO;
        }
        if (!self.isFinished) {
            self.finished = YES;
        }
    }
    
    [self reset];
}

- (void)done
{
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)reset
{
    XXLOCK(self.callbacksLock);
    [self.callbackBlocks removeAllObjects];
    XXUNLOCK(self.callbacksLock);
    self.dataTask = nil;
    
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent
{
    return YES;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
    long long expected = response.expectedContentLength;
    expected = expected > 0 ? expected : 0;
    self.expectedSize = expected;
    self.response = response;
    NSInteger statusCode = [response respondsToSelector:@selector(statusCode)] ? ((NSHTTPURLResponse *)response).statusCode : 200;
    BOOL valid = statusCode < 400;
    //'304 Not Modified'是个例外。 如果没有缓存数据，它应该被视为取消.
    //当服务器响应304和URLCache命中时，URLSession当前行为将返回200状态码。 但这不是标准行为，我们只需检查一下
    if (statusCode == 304 && !self.cachedData) {
        valid = NO;
    }
    
    if (valid) {
        for (XXSDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, expected, self.request.URL);
        }
    } else {
        //状态码无效并标记为已取消.Do not call `[self.dataTask cancel]` which may mass up URLSession life cycle
        disposition = NSURLSessionResponseCancel;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XXSDWebImageDownloadReceiveResponseNotification object:weakSelf];
    });
    
    if (completionHandler) {
        completionHandler(disposition);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    if (!self.imageData) {
        self.imageData = [[NSMutableData alloc] initWithCapacity:self.expectedSize];
    }
    [self.imageData appendData:data];
    
    if ((self.options & XXSDWebImageDownloaderProgressiveDownload) && self.expectedSize > 0) {
        //获取image data
        __block NSData *imageData = [self.imageData copy];
        //获取下载的总字节
        const NSInteger totalSize = imageData.length;
        //获取完成状态
        BOOL finished = (totalSize >= self.expectedSize);
        
        if (!self.progressiveCoder) {
            //我们需要为渐进解码创建一个新实例以避免冲突
            for (id<XXSDWebImageCoder> coder in [XXSDWebImageCodersManager sharedInstance].coders) {
                if ([coder conformsToProtocol:@protocol(XXSDWebImageProgressiveCoder)] && [((id<XXSDWebImageProgressiveCoder>)coder) canIncrementallyDecodeFromData:imageData]) {
                    self.progressiveCoder = [[[coder class] alloc] init];
                    break;
                }
            }
        }
        
        //在编码器队列中逐行解码图像
        dispatch_async(self.coderQueue, ^{
            UIImage *image = [self.progressiveCoder incrementallyDecodedImageWithData:imageData finished:finished];
            if (image) {
                NSString *key = [[XXSDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
                image = [self scaledImageForKey:key image:image];
                if (self.shouldDecompressImages) {
                    image = [[XXSDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&imageData options:@{XXSDWebImageCoderScaleDownLargeImageKey: @(NO)}];
                }
                //即使`finished` = YES，我们也不会保留逐行解码图像。 因为它们用于视图渲染，但不能从下载器选项中获得全部功能。 而且一些编码器的实现可能在逐行解码和正常解码之间不一致。
                [self callCompletionBlocksWithImage:image imageData:nil error:nil finished:NO];
            }
        });
    }
    
    for (XXSDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
        progressBlock(self.imageData.length, self.expectedSize, self.request.URL);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler
{
    NSCachedURLResponse *cachedResponse = proposedResponse;
    
    if (!(self.options & XXSDWebImageDownloaderUseNSURLCache)) {
        //阻止缓存响应
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    @synchronized (self) {
        self.dataTask = nil;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XXSDWebImageDownloadStopNotification object:weakSelf];
            if (!error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:XXSDWebImageDownloadFinishNotification object:weakSelf];
            }
        });
    }
    
    //确保调用`[self done]`将操作标记为已完成
    if (error) {
        [self callCompletionBlocksWithError:error];
        [self done];
    } else {
        if ([self callbacksForKey:kCompletedCallbackKey].count > 0) {
            /**
              * 如果你指定使用`NSURLCache`，那么你得到的响应就是你需要的。
              */
            __block NSData *imageData = [self.imageData copy];
            if (imageData) {
                /**如果您指定通过`SDWebImageDownloaderIgnoreCachedResponse`使用缓存数据，那么我们应该检查缓存的数据是否等于图像数据
                */
                if (self.options & XXSDWebImageDownloaderIgnoreCachedResponse && [self.cachedData isEqualToData:imageData]) {
                    [self callCompletionBlocksWithImage:nil imageData:nil error:nil finished:YES];
                    [self done];
                } else {
                    //在coder queue进行解码
                    dispatch_async(self.coderQueue, ^{
                        UIImage *image = [[XXSDWebImageCodersManager sharedInstance] decodedImageWithData:imageData];
                        NSString *key = [[XXSDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
                        image = [self scaledImageForKey:key image:image];

                        BOOL shouldDecode = YES;
                        //不强制解码动画GIF和WebP
                        if (image.images) {
                            shouldDecode = NO;
                        } else {

                        }
                        
                        if (shouldDecode) {
                            if (self.shouldDecompressImages) {
                                BOOL shouldScaleDown = self.options & XXSDWebImageDownloaderScaleDownLargeImages;
                                image = [[XXSDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&imageData options:@{XXSDWebImageCoderScaleDownLargeImageKey: @(shouldScaleDown)}];
                            }
                        }
                        CGSize imageSize = image.size;
                        if (imageSize.width == 0 || imageSize.height == 0) {
                            [self callCompletionBlocksWithError:[NSError errorWithDomain:XXSDWebImageErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"下载的图片0像素"}]];
                        } else {
                            [self callCompletionBlocksWithImage:image imageData:imageData error:nil finished:YES];
                        }
                        [self done];
                    });
                }
            } else {
                [self callCompletionBlocksWithError:[NSError errorWithDomain:XXSDWebImageErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Image data is nil"}]];
                [self done];
            }
        } else {
            [self done];
        }
    }
}

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & XXSDWebImageDownloaderAllowInvalidSSLCertificates)) {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if (challenge.previousFailureCount == 0) {
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark - Helper methods

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image
{
    return XXSDScaledImageForKey(key, image);
}

- (BOOL)shouldContinueWhenAppEntersBackground
{
    return self.options & XXSDWebImageContinueInBackground;
}

- (void)callCompletionBlocksWithError:(NSError *)error
{
    [self callCompletionBlocksWithImage:nil imageData:nil error:error finished:YES];
}

- (void)callCompletionBlocksWithImage:(UIImage *)image
                            imageData:(NSData *)imageData
                                error:(NSError *)error
                             finished:(BOOL)finished
{
    NSArray *completionBlocks = [self callbacksForKey:kCompletedCallbackKey];
    dispatch_main_async_safe(^{
        for (XXSDWebImageDownloaderCompletionBlock completedBlock in completionBlocks) {
            completedBlock(image, imageData, error, finished);
        }
    });
}

@end































