//
//  XXSDWebImageDownloaderOperation.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/3.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageDownloader.h"
#import "XXSDWebImageOperation.h"

FOUNDATION_EXPORT NSString * const XXSDWebImageDownloadStartNotification;
FOUNDATION_EXPORT NSString * const XXSDWebImageDownloadReceiveResponseNotification;
FOUNDATION_EXPORT NSString * const XXSDWebImageDownloadStopNotification;
FOUNDATION_EXPORT NSString * const XXSDWebImageDownloadFinishNotification;

/**
   描述一个下载器操作。 如果有人想使用自定义下载器操作，它需要从NSOperation继承，并符合此协议。
   有关这些方法的描述，请参阅“SDWebImageDownloaderOperation”
  */

@protocol XXSDWebImageDownloaderOperationInterface<NSObject>

- (instancetype)initWithRequest:(NSURLRequest *)request
                      inSession:(NSURLSession *)session
                        options:(XXSDWebImageDownloaderOptions)options;

- (id)addHandlersForProgress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                   completed:(XXSDWebImageDownloaderCompletionBlock)completedBlock;

- (BOOL)shouldDecompressImages;

- (void)setShouldDecompressImages:(BOOL)value;

- (NSURLCredential *)credential;

- (void)setCredential:(NSURLCredential *)value;

- (BOOL)cancel:(id)token;

@end

@interface XXSDWebImageDownloaderOperation : NSOperation <XXSDWebImageDownloaderOperationInterface, XXSDWebImageOperation, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

/**
  * operation的task使用的请求。
  */
@property (nonatomic, strong, readonly) NSURLRequest *request;


/**
 * operation's task
 */
@property (nonatomic, strong, readonly) NSURLSessionTask *dataTask;

@property (nonatomic, assign) BOOL shouldDecompressImages;

/**
  * 曾经被用于确定URL连接是否应查阅用于认证连接的凭证存储。
  * @deprecated 好几个版本没使用了
  */
@property (nonatomic, assign) BOOL shouldUseCredentialStorage __deprecated_msg("Property deprecated. Does nothing. Kept only for backwards compatibility");

/**
  * 在`-URLSession：task：didReceiveChallenge：completionHandler：`中用于认证挑战的凭证。
  * This will be overridden by any shared credentials that exist for the username or password of the request URL, if present.
  */
@property (nonatomic, strong) NSURLCredential *credential;

@property (nonatomic, assign, readonly) XXSDWebImageDownloaderOptions options;

/**
  * 数据的预期大小。
  */
@property (nonatomic, assign) NSInteger expectedSize;

/**
 * operation的task返回的response
 */
@property (nonatomic, strong) NSURLResponse *response;


/**
  * 初始化一个SDWebImageDownloaderOperation对象
  *
  * @请参阅SDWebImageDownloaderOperation
  *
  * @param request URL请求
  * @param session 将运行此操作的URL会话
  * @param options 下载选项
  *
  * @return 初始化的实例
  */
- (instancetype)initWithRequest:(NSURLRequest * )request
                      inSession:(NSURLSession *)session
                        options:(XXSDWebImageDownloaderOptions)options NS_DESIGNATED_INITIALIZER;


/**
 *  Adds handlers for progress and completion. Returns a tokent that can be passed to -cancel: to cancel this set of
 *  callbacks.
 *
 *  @param progressBlock  the block executed when a new chunk of data arrives.
 *                        @note the progress block is executed on a background queue
 *  @param completedBlock the block executed when the download is done.
 *                        @note the completed block is executed on the main queue for success. If errors are found, there is a chance the block will be executed on a background queue
 *
 *  @return the token to use to cancel this set of handlers
 */
- (id)addHandlersForProgress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                   completed:(XXSDWebImageDownloaderCompletionBlock)completedBlock;

/**
 *  Cancels a set of callbacks. Once all callbacks are canceled, the operation is cancelled.
 *
 *  @param token the token representing a set of callbacks to cancel
 *
 *  @return YES if the operation was stopped because this was the last token to be canceled. NO otherwise.
 */
- (BOOL)cancel:(id)token;

@end
































