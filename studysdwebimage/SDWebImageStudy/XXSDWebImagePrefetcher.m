//
//  XXSDWebImagePrefetcher.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImagePrefetcher.h"

@interface XXSDWebImagePrefetcher ()

@property (nonatomic, strong) XXSDWebImageManager *manager;
@property (atomic, strong) NSArray<NSURL *> *prefetchURLS;//可以从不同的队列访问
@property (nonatomic, assign) NSUInteger requestedCount;
@property (nonatomic, assign) NSUInteger skippedCount;
@property (nonatomic, assign) NSUInteger finishedCount;
@property (nonatomic, assign) NSTimeInterval startedTime;
@property (nonatomic, copy) XXSDWebImagePrefetcherCompletionBlock completionBlock;
@property (nonatomic, copy) XXSDWebImagePrefetcherProgressBlock progressBlock;

@end


@implementation XXSDWebImagePrefetcher

+ (instancetype)sharedImagePrefetcher
{
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init
{
    return [self initWithImageManager:[XXSDWebImageManager new]];
}

- (instancetype)initWithImageManager:(XXSDWebImageManager *)manager
{
    if (self = [super init]) {
        _manager = manager;
        _options = XXSDWebImageLowPriority;
        _prefetcherQueue = dispatch_get_main_queue();
        self.maxConcurrentDownloads = 3;
    }
    return self;
}

- (void)setMaxConcurrentDownloads:(NSUInteger)maxConcurrentDownloads
{
    self.manager.imageDownloader.maxConcurrentDownloads = maxConcurrentDownloads;
}

- (NSUInteger)maxConcurrentDownloads
{
    return self.manager.imageDownloader.maxConcurrentDownloads;
}

- (void)startPrefetchingAtIndex:(NSUInteger)index
{
    NSURL *currentURL;
    @synchronized (self) {
        if (index >= self.prefetchURLS.count) {
            return;
        }
        currentURL = self.prefetchURLS[index];
        self.requestedCount++;
    }
    [self.manager loadImageWithURL:currentURL options:self.options progress:nil completed:^(UIImage *image, NSData *data, NSError *error, XXSDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        if (!finished) {
            return;
        }
        self.finishedCount++;
        
        if (self.progressBlock) {
            self.progressBlock(self.finishedCount, self.prefetchURLS.count);
        }
        if (!image) {
            self.skippedCount++;
        }
        
        if ([self.delegate respondsToSelector:@selector(imagePrefetcher:didPrefetchURL:finishedCount:totalCount:)]) {
            [self.delegate imagePrefetcher:self didPrefetchURL:currentURL finishedCount:self.finishedCount totalCount:self.prefetchURLS.count];
        }
        if (self.prefetchURLS.count > self.requestedCount) {
            dispatch_async(self.prefetcherQueue, ^{
                [self startPrefetchingAtIndex:self.requestedCount];
            });
        } else if (self.finishedCount == self.requestedCount) {
            [self reportStatus];
            if (self.completionBlock) {
                self.completionBlock(self.finishedCount, self.skippedCount);
                self.completionBlock = nil;
            }
            self.progressBlock = nil;
        }
    }];
}

- (void)reportStatus
{
    NSInteger total = self.prefetchURLS.count;
    if ([self.delegate respondsToSelector:@selector(imagePrefetcher:didFinishWithTotalCount:skippedCount:)]) {
        [self.delegate imagePrefetcher:self didFinishWithTotalCount:total - self.skippedCount skippedCount:self.skippedCount];
    }
}

- (void)prefetchURLs:(NSArray<NSURL *> *)urls
{
    [self prefetchURLs:urls progress:nil completed:nil];
}

- (void)prefetchURLs:(NSArray<NSURL *> *)urls
            progress:(XXSDWebImagePrefetcherProgressBlock)progressBlock
           completed:(XXSDWebImagePrefetcherCompletionBlock)completionBlock
{
    [self cancelPrefetching];
    self.startedTime = CFAbsoluteTimeGetCurrent();
    self.prefetchURLS = urls;
    self.completionBlock = completionBlock;
    self.progressBlock = progressBlock;
    
    if (urls.count == 0) {
        if (completionBlock) {
            completionBlock(0,0);
        }
    } else {
        NSUInteger listCount = self.prefetchURLS.count;
        for (NSUInteger i = 0; i < self.maxConcurrentDownloads && self.requestedCount < listCount; i++) {
            [self startPrefetchingAtIndex:i];
        }
    }
}

- (void)cancelPrefetching
{
    @synchronized (self) {
        self.prefetchURLS = nil;
        self.skippedCount = 0;
        self.requestedCount = 0;
        self.finishedCount = 0;
    }
    [self.manager cancelAll];
}

@end











