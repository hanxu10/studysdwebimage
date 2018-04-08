//
//  XXSDWebImagePrefetcher.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageManager.h"

@class XXSDWebImagePrefetcher;

@protocol XXSDWebImagePrefetcherDelegate <NSObject>

@optional

/**
  * 预取图像时调用。
  *
  * @param imagePrefetcher 当前图像预取程序
  * @param imageURL 被预取的图片网址
  * @param finishedCount 已经预取的图像总数（成功或者失败）
  * @param totalCount 要预取的图像总数
  */
- (void)imagePrefetcher:(XXSDWebImagePrefetcher *)imagePrefetcher didPrefetchURL:(NSURL *)imageURL finishedCount:(NSUInteger)finishedCount totalCount:(NSUInteger)totalCount;

/**
  * 当所有图像被预取时调用。
  * @param imagePrefetcher 当前图像预取程序
  * @param totalCount 预取图像的总数（无论是否成功）
  * @param skippedCount 跳过的图像总数
  */
- (void)imagePrefetcher:(XXSDWebImagePrefetcher *)imagePrefetcher didFinishWithTotalCount:(NSUInteger)totalCount skippedCount:(NSUInteger)skippedCount;

@end

typedef void(^XXSDWebImagePrefetcherProgressBlock)(NSUInteger noOfFinishedUrls, NSUInteger noOfTotalUrls);
typedef void(^XXSDWebImagePrefetcherCompletionBlock)(NSUInteger noOfFinishedUrls, NSUInteger noOfSkippedUrls);

/**
  * 在缓存中预取一些URL以供将来使用。 图像以低优先级下载。
  */
@interface XXSDWebImagePrefetcher : NSObject

@property (nonatomic, strong, readonly) XXSDWebImageManager *manager;

/**
  * 同时预取的最大URL数量。 默认为3。
  */
@property (nonatomic, assign) NSUInteger maxConcurrentDownloads;

/**
  * 默认为SDWebImageLowPriority。
  */
@property (nonatomic, assign) XXSDWebImageOptions options;

/**
  * 预取器的队列。 默认为主队列。
  */
@property (nonatomic, strong) dispatch_queue_t prefetcherQueue;

@property (nonatomic, weak) id <XXSDWebImagePrefetcherDelegate> delegate;

+ (instancetype)sharedImagePrefetcher;

/**
  * 允许您使用任意图像管理器实例化预取器。
  */
- (instancetype)initWithImageManager:(XXSDWebImageManager *)manager NS_DESIGNATED_INITIALIZER;



/**
  * 分配URL列表让SDWebImagePrefetcher对预取进行排队，
  * 目前一次下载一个图像，
  * 并跳过失败下载的图像，然后转到列表中的下一张图像。
  * 任何以前运行的预取操作都将被取消。
  *
  * @param urls 要预取的URL列表
  */
- (void)prefetchURLs:(nullable NSArray<NSURL *> *)urls;


/**
  * 分配URL列表让SDWebImagePrefetcher对预取进行排队，
  * 目前一次下载一个图像，并跳过失败下载的图像，然后进入列表中的下一张图像。
  * 任何以前运行的预取操作都将被取消。
  *
  * @param urls 要预取的URL列表
  * @param progressBlock 块在进度更新时被调用;
  *          第一个参数是已完成（成功或未完成）请求的数量，
  *          第二个参数是最初请求预取的图像总数
  * @param completionBlock 预取完成时将调用块
  *          第一个参数是已完成（成功与否）请求的数量，
  *          第二个参数是跳过的请求数
  */
- (void)prefetchURLs:(nullable NSArray<NSURL *> *)urls
            progress:(nullable XXSDWebImagePrefetcherProgressBlock)progressBlock
           completed:(nullable XXSDWebImagePrefetcherCompletionBlock)completionBlock;

- (void)cancelPrefetching;

@end
