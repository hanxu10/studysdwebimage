//
//  XXSDWebImageManager.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/4.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageManager.h"
#import "NSImage+XXWebCache.h"
#import <objc/message.h>

@interface XXSDWebImageCombinedOperation:NSObject <XXSDWebImageOperation>

@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, strong) XXSDWebImageDownloadToken *downloadToken;
@property (nonatomic, strong) NSOperation *cacheOperation;
@property (nonatomic, weak) XXSDWebImageManager *manager;

@end

@interface XXSDWebImageManager ()

@property (nonatomic, strong) XXSDImageCache *imageCache;
@property (nonatomic, strong) XXSDWebImageDownloader *imageDownloader;
@property (nonatomic, strong) NSMutableSet<NSURL *> *failedURLS;
@property (nonatomic, strong) NSMutableArray<XXSDWebImageCombinedOperation *> *runningOperations;

@end

@implementation XXSDWebImageManager

+ (instancetype)sharedManager
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    XXSDImageCache *cache = [XXSDImageCache sharedImageCache];
    XXSDWebImageDownloader *downloader = [XXSDWebImageDownloader sharedDownloader];
    return [self initWithCache:cache downloader:downloader];
}

- (instancetype)initWithCache:(XXSDImageCache *)cache downloader:(XXSDWebImageDownloader *)downloader
{
    if (self = [super init]) {
        _imageCache = cache;
        _imageDownloader = downloader;
        _failedURLS = [NSMutableSet set];
        _runningOperations = [NSMutableArray array];
    }
    return self;
}

- (NSString *)cacheKeyForURL:(NSURL *)url
{
    if (!url) {
        return @"";
    }
    
    if (self.cacheKeyFilter) {
        return self.cacheKeyFilter(url);
    } else {
        return url.absoluteString;
    }
}

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image
{
    return XXSDScaledImageForKey(key, image);
}

- (void)cachedImageExistsForURL:(NSURL *)url completion:(XXSDWebImageCheckCacheCompletionBlock)completionBlock
{
    NSString *key = [self cacheKeyForURL:url];
    
    BOOL isInmemoryCache = [self.imageCache imageFromMemoryCacheForKey:key] != nil;
    
    if (isInmemoryCache) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(YES);
            }
        });
        return;
    }
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

- (void)diskImageExistsForURL:(NSURL *)url completion:(XXSDWebImageCheckCacheCompletionBlock)completionBlock
{
    NSString *key = [self cacheKeyForURL:url];
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

- (id <XXSDWebImageOperation>)loadImageWithURL:(NSURL *)url
                                       options:(XXSDWebImageOptions)options
                                      progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                                     completed:(XXSDInteranalCompletionBlock)completionBlock
{
    NSAssert(completionBlock != nil, @"如果您的意思是预取图像，请使用 - [SDWebImagePrefetcher prefetchURLs]");
    
    //很常见的错误是使用NSString对象而不是NSURL发送URL。 出于某种奇怪的原因，Xcode不会为这种类型的不匹配发出任何警告。 在这里，我们通过允许URL作为NSString传递来保证这个错误。
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    //防止应用程序在参数类型错误（如发送NSNull而不是NSURL）时崩溃
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    XXSDWebImageCombinedOperation *operation = [[XXSDWebImageCombinedOperation alloc] init];
    operation.manager = self;
    
    BOOL isFailedURL = NO;
    if (url) {
        @synchronized (self.failedURLS) {
            isFailedURL = [self.failedURLS containsObject:url];
        }
    }
    
    if (url.absoluteString.length == 0 || (!(options & XXSDWebImageRetryFailed) && isFailedURL)) {
        [self callCompletionBlockForOperation:operation completion:completionBlock error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] url:url];
        return operation;
    }
    
    @synchronized(self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    
    NSString *key = [self cacheKeyForURL:url];
    
    XXSDImageCacheOptions cacheOptions = 0;
    if (options & XXSDWebImageQueryDataWhenInMemory) {
        cacheOptions |= XXSDImageCacheQueryDataWhenInMemory;
    }
    if (options & XXSDWebImageQueryDiskSync) {
        cacheOptions |= XXSDImageCacheQueryDiskSync;
    }
    
    __weak XXSDWebImageCombinedOperation *weakOperation = operation;
    operation.cacheOperation = [self.imageCache queryCacheOperationForKey:key options:cacheOptions done:^(UIImage *cachedImage, NSData *cachedData, XXSDImageCacheType cacheType) {
        __strong __typeof(weakOperation) strongOperation = weakOperation;
        if (!strongOperation || strongOperation.isCancelled) {
            [self safelyRemoveOperationFromRunning:strongOperation];
            return;
        }
        
        //检查是否需要从网络下载图片
        BOOL shouldDownload = (!(options & XXSDWebImageFromCacheOnly)) /*不仅仅只取缓存*/
        && (!cachedImage || options & XXSDWebImageRefreshCached)/*（没有取到缓存image）或者（设置了refreshcache）*/
        && (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url]);
        if (shouldDownload) {
            if (cachedImage && options & XXSDWebImageRefreshCached) {
                //如果在缓存中找到图像但提供了SDWebImageRefreshCached，则通知缓存的图像
                //并尝试重新下载它以便让NSURLCache从服务器刷新它。
                [self callCompletionBlockForOperation:strongOperation completion:completionBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            }
            
            // download if no image or requested to refresh anyway, and download allowed by delegate
            XXSDWebImageDownloaderOptions downloaderOptions = 0;
            if (options & XXSDWebImageLowPriority) {
                downloaderOptions |= XXSDWebImageDownloaderLowPriority;
            }
            if (options & XXSDWebImageProgressiveDownload) {
                downloaderOptions |= XXSDWebImageDownloaderProgressiveDownload;
            }
            if (options & XXSDWebImageRefreshCached) {
                downloaderOptions |= XXSDWebImageDownloaderUseNSURLCache;
            }
            if (options & XXSDWebImageContinueInBackground) {
                downloaderOptions |= XXSDWebImageDownloaderContinueInBackground;
            }
            if (options & XXSDWebImageHandleCookies) {
                downloaderOptions |= XXSDWebImageDownloaderHandleCookies;
            }
            if (options & XXSDWebImageAllowInvalidSSLCertificates) {
                downloaderOptions |= XXSDWebImageDownloaderAllowInvalidSSLCertificates;
            }
            if (options & XXSDWebImageHighPriority) {
                downloaderOptions |= XXSDWebImageDownloaderHightPriority;
            }
            if (options & XXSDWebImageScaleDownLargeImages) {
                downloaderOptions |= XXSDWebImageDownloaderScaleDownLargeImages;
            }
            
            if (cachedImage && options & XXSDWebImageRefreshCached) {
                //如果图像已经被缓存但强制刷新，强制把progressive关闭
                downloaderOptions &= ~XXSDWebImageDownloaderProgressiveDownload;
                //如果图像缓存但强制刷新，则忽略从NSURLCache读取的图像
                downloaderOptions |= XXSDWebImageDownloaderIgnoreCachedResponse;
            }
            
            // `SDWebImageCombinedOperation` -> `SDWebImageDownloadToken` -> `downloadOperationCancelToken`, which is a `SDCallbacksDictionary` and retain the completed block below, so we need weak-strong again to avoid retain cycle
            __weak typeof(strongOperation) weakSubOperation = strongOperation;
            strongOperation.downloadToken = [self.imageDownloader downloadImageWithURL:url options:downloaderOptions progress:progressBlock completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
                __strong typeof(weakSubOperation) strongSubOperation = weakSubOperation;
                if (!strongSubOperation || strongSubOperation.isCancelled) {
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                } else if (error) {
                    [self callCompletionBlockForOperation:strongSubOperation completion:completionBlock error:error url:url];
                    BOOL shouldBlockFailedURL;
                    // Check whether we should block failed url
                    if ([self.delegate respondsToSelector:@selector(imageManager:shouldBlockFailedURL:withError:)]) {
                        shouldBlockFailedURL = [self.delegate imageManager:self shouldBlockFailedURL:url withError:error];
                    } else {
                        shouldBlockFailedURL = (   error.code != NSURLErrorNotConnectedToInternet
                                                && error.code != NSURLErrorCancelled
                                                && error.code != NSURLErrorTimedOut
                                                && error.code != NSURLErrorInternationalRoamingOff/*当连接需要在漫游时激活数据上下文时返回，但国际漫游已禁用。*/
                                                && error.code != NSURLErrorDataNotAllowed/*当蜂窝网络不允许连接时返回。*/
                                                && error.code != NSURLErrorCannotFindHost/*当无法解析URL的主机名时返回。*/
                                                && error.code != NSURLErrorCannotConnectToHost/*当尝试连接到主机失败时返回。
                                                                                               当主机名解析时，但主机已关闭或可能不接受某个端口上的连接,可能会发生这种情况。*/
                                                && error.code != NSURLErrorNetworkConnectionLost/*当客户端或服务器连接在正在进行的加载过程中被切断时返回。*/);
                    }
                    
                    if (shouldBlockFailedURL) {
                        @synchronized (self.failedURLS) {
                            [self.failedURLS addObject:url];
                        }
                    }
                } else {
                    if (options & XXSDWebImageRetryFailed) {
                        @synchronized(self.failedURLS) {
                            [self.failedURLS removeObject:url];
                        }
                    }
                    
                    BOOL cacheOnDisk = !(options & XXSDWebImageCacheMemoryOnly);
                    
                    //我们使用共享管理器在SDWebImageDownloader中完成了缩放过程，这用于自定义管理器并避免了额外的缩放。
                    if (self != [XXSDWebImageManager sharedManager] && self.cacheKeyFilter && downloadedImage) {
                        downloadedImage = [self scaledImageForKey:key image:downloadedImage];
                    }
                    
                    if (options & XXSDWebImageRefreshCached && cachedImage && !downloadedImage) {
                        //图像刷新命中NSURLCache缓存，不要调用完成块
                    } else if (downloadedImage && (!downloadedImage.images || (options & XXSDWebImageTransformAnimatedImage)) && [self.delegate respondsToSelector:@selector(imageManager:transformDownloadedImage:withURL:)]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];
                            
                            if (transformedImage && finished) {
                                BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
                                NSData *cacheData;
                                //如果图像被转换，则传递nil，所以我们可以重新计算图像中的数据
                                if (self.cacheSerializer) {
                                    cacheData = self.cacheSerializer(transformedImage, (imageWasTransformed ? nil : downloadedData), url);
                                } else {
                                    cacheData = (imageWasTransformed ? nil : downloadedData);
                                }
                                [self.imageCache storeImage:transformedImage imageData:cacheData forKey:key toDisk:cacheOnDisk completion:nil];
                            }
                            
                            [self callCompletionBlockForOperation:strongSubOperation completion:completionBlock image:transformedImage data:downloadedData error:nil cacheType:XXSDImageCacheTypeNone finished:finished url:url];
                        });
                    } else {
                        if (downloadedImage && finished) {
                            if (self.cacheSerializer) {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                    NSData *cacheData = self.cacheSerializer(downloadedImage, downloadedData, url);
                                    [self.imageCache storeImage:downloadedImage imageData:cacheData forKey:key toDisk:cacheOnDisk completion:nil];
                                });
                            } else {
                                [self.imageCache storeImage:downloadedImage imageData:downloadedData forKey:key toDisk:cacheOnDisk completion:nil];
                            }
                        }
                        [self callCompletionBlockForOperation:strongSubOperation completion:completionBlock image:downloadedImage data:downloadedData error:nil cacheType:XXSDImageCacheTypeNone finished:finished url:url];
                    }
                }
                
                if (finished) {
                    [self safelyRemoveOperationFromRunning:strongSubOperation];
                }
            }];
        } else if (cachedImage) {
            [self callCompletionBlockForOperation:strongOperation completion:completionBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            [self safelyRemoveOperationFromRunning:strongOperation];
        } else {
            // Image not in cache and download disallowed by delegate
            [self callCompletionBlockForOperation:strongOperation completion:completionBlock image:nil data:nil error:nil cacheType:XXSDImageCacheTypeNone finished:YES url:url];
            [self safelyRemoveOperationFromRunning:strongOperation];
        }
    }];
    
    return operation;
}

- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url
{
    if (image && url) {
        NSString *key = [self cacheKeyForURL:url];
        [self.imageCache storeImage:image forKey:key toDisk:YES completion:nil];
    }
}

- (void)cancelAll
{
    @synchronized (self.runningOperations) {
        NSArray<XXSDWebImageCombinedOperation *> *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning
{
    BOOL isRunning = NO;
    @synchronized(self.runningOperations) {
        isRunning = self.runningOperations.count > 0;
    }
    return isRunning;
}

- (void)safelyRemoveOperationFromRunning:(XXSDWebImageCombinedOperation *)operation
{
    @synchronized (self.runningOperations) {
        if (operation) {
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(XXSDWebImageCombinedOperation *)operation
                             completion:(XXSDInteranalCompletionBlock)completionBlock
                                  error:(NSError *)error url:(NSURL *)url
{
    [self callCompletionBlockForOperation:operation completion:completionBlock image:nil data:nil error:error cacheType:XXSDImageCacheTypeNone finished:YES url:url];
}

- (void)callCompletionBlockForOperation:(XXSDWebImageCombinedOperation *)operation
                             completion:(XXSDInteranalCompletionBlock)completionBlock
                                  image:(UIImage *)image
                                   data:(NSData *)data
                                  error:(NSError *)error
                              cacheType:(XXSDImageCacheType)cacheType
                               finished:(BOOL)finished
                                    url:(NSURL *)url
{
    dispatch_main_async_safe(^{
        if (operation && !operation.isCancelled && completionBlock) {
            completionBlock(image, data, error, cacheType, finished, url);
        }
    });
}
@end

@implementation XXSDWebImageCombinedOperation

- (void)cancel
{
    @synchronized (self) {
        self.cancelled = YES;
        if (self.cacheOperation) {
            [self.cacheOperation cancel];
            self.cacheOperation = nil;
        }
        if (self.downloadToken) {
            [self.manager.imageDownloader cancel:self.downloadToken];
        }
        [self.manager safelyRemoveOperationFromRunning:self];
    }
}

@end




















