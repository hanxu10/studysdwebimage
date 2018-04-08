//
//  XXSDWebImageDownloader.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/3.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCompat.h"
#import "XXSDWebImageOperation.h"

typedef NS_OPTIONS(NSUInteger, XXSDWebImageDownloaderOptions) {
    /**
     * 将下载的队列优先级和任务优先级设置为低。
     */
    XXSDWebImageDownloaderLowPriority = 1 << 0,
    
    /**
     * 此标志启用渐进式下载，图像在下载期间会逐渐显示就像浏览器所做的一样。
     */
    XXSDWebImageDownloaderProgressiveDownload = 1 << 1,
    
    /**
     * 默认情况下，请求阻止使用NSURLCache。 有了这个标志，NSURLCache
     * 与默认策略一起使用。
     */
    XXSDWebImageDownloaderUseNSURLCache = 1 << 2,
    
    /**
     * 如果图像是从NSURLCache读取的，则调用具有 image / imageData为nil的完成块
     * （与'SDWebImageDownloaderUseNSURLCache`结合使用）。
     */
    XXSDWebImageDownloaderIgnoreCachedResponse = 1 << 3,
    
    /**
     * 在iOS 4+中，如果应用程序转到后台，请继续下载图像。 这是通过向系统请求后台的额外时间来完成请求来实现的。 如果后台任务到期，操作将被取消。
     */
    XXSDWebImageDownloaderContinueInBackground = 1 << 4,
    
    /**
     * 通过设置NSMutableURLRequest.HTTPShouldHandleCookies = YES处理存储在NSHTTPCookieStore中的cookie;
     */
    XXSDWebImageDownloaderHandleCookies = 1 << 5,
    
    /**
     * 启用以允许不可信的SSL证书。 用于测试目的。 在生产中谨慎使用。
     */
    XXSDWebImageDownloaderAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * 将下载放在高队列优先级和任务优先级中。
     */
    XXSDWebImageDownloaderHightPriority = 1 << 7,
    
    /**
     * 缩小图像
     */
    XXSDWebImageDownloaderScaleDownLargeImages = 1 << 8,
};

typedef NS_ENUM(NSUInteger, XXSDWebImageDownloaderExecutionOrder) {
    /**
     * 默认值。 所有下载操作将以队列样式（先进先出）执行。
     */
    XXSDWebImageDownloaderFIFOExecutionOrder,
    
    /**
     * 所有下载操作将以堆栈样式执行（后进先出）。
     */
    XXSDWebImageDownloaderLIFOExecutionOrder,
};

FOUNDATION_EXPORT NSString *const XXSDWebImageDownloadStartNotification;
FOUNDATION_EXPORT NSString *const XXSDWebImageDownloadStopNotification;

typedef void(^XXSDWebImageDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL);

typedef void(^XXSDWebImageDownloaderCompletionBlock)(UIImage *image, NSData *data, NSError *error, BOOL finished);

typedef NSDictionary<NSString *, NSString *> XXSDHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString *, NSString *> XXSDHTTPHeadersMutableDictionary;

typedef XXSDHTTPHeadersDictionary *(^XXSDWebImageDownloaderHeadersFilterBlock)(NSURL *url, XXSDHTTPHeadersDictionary *headers);

@interface XXSDWebImageDownloadToken : NSObject <XXSDWebImageOperation>

/**
   下载的URL。 这应该是只读的，你不应该修改
  */
@property (nonatomic, strong) NSURL *url;

/**
   取自'addHandlersForProgress：completed`的取消令牌。 这应该是只读的，你不应该修改
   @note 使用` - [XXSDWebImageDownloadToken cancel]`来取消令牌
  */
@property (nonatomic, strong) id downloadOperationCancelToken;

@end


/**
  * 异步下载器，专用于图片加载并进行了优化。
  */
@interface XXSDWebImageDownloader : NSObject

/**
  * 解压下载并缓存的图像可以提高性能，但会消耗大量内存。
  * 默认为YES。 如果由于内存消耗过多而导致崩溃，请将其设置为NO。
  */
@property (nonatomic, assign) BOOL shouldDecompressImages;

/**
  * 最大并发下载数量
  */
@property (nonatomic, assign) NSInteger maxConcurrentDownloads;

/**
  * 显示当前仍需下载的下载量
  */
@property (nonatomic, assign) NSUInteger currentDownloadCount;

/**
  * 下载操作的超时值（以秒为单位）。 默认值：15.0。
  */
@property (nonatomic, assign) NSTimeInterval downloadTimeout;

/**
  * 由内部NSURLSession使用的配置。
  * 直接改变这个对象不起作用。
  *
  * @请参阅createNewSessionWithConfiguration：
  */
@property (nonatomic, strong, readonly) NSURLSessionConfiguration *sessionConfiguration;

/**
  * 更改下载操作执行顺序。 默认值是`SDWebImageDownloaderFIFOExecutionOrder`。
  */
@property (nonatomic, assign) XXSDWebImageDownloaderExecutionOrder executionOrder;

+ (instancetype)sharedDownloader;

/**
  * 为请求操作设置的默认的URL凭证。
  */
@property (nonatomic, strong) NSURLCredential *urlCredential;

/**
 * 设置用户名
 */
@property (nonatomic, strong) NSString *username;

/**
 * 设置密码
 */
@property (nonatomic, strong) NSString *password;

/**
  * 设置过滤器来选择下载图片HTTP请求的标题。
  *
  * 将为每个下载图像请求调用此块，返回的NSDictionary将用作相应HTTP请求中的headers。
  */
@property (nonatomic, copy) XXSDWebImageDownloaderHeadersFilterBlock headersFilter;

/**
  * 使用指定的会话配置创建下载器的实例。
  * @note`timeoutIntervalForRequest`将被覆盖。
  * @返回下载类的新实例
  */
- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/**
  * 为每个下载HTTP请求附加一个HTTP标头。
  *
  * @参数值标题字段的值。 使用`nil`值来删除标题。
  * @参数字段要设置的标题字段的名称。
  */
- (void)setValue:(NSString *)value forHTTPHeaderField:(nonnull NSString *)field;

/**
  * 返回指定的HTTP头字段的值。
  *
  * @return 与HTTP头字段关联的值，如果没有相应的header字段，则返回“nil”。
  */
- (NSString *)valueForHTTPHeaderField:(NSString *)field;

/**
  *将SDWebImageDownloaderOperation的子类设置为每次SDWebImage构造请求操作以下载图像时使用的默认“NSOperation”。
  *
  * @param operationClass SDWebImageDownloaderOperation的子类。 传递`nil`将恢复为`SDWebImageDownloaderOperation`。
  */
- (void)setOperationClass:(Class)operationClass;


/**
 * 使用给定的URL创建一个SDWebImageDownloader异步下载器实例
 *
 * 当图像完成下载或发生错误时，会通知代表。
 *
 * @请参阅SDWebImageDownloaderDelegate
 *
 * @参数URL要下载的图像的URL
 * @参数选项用于此下载的选项
 * @param progressBlock 在图像下载时重复调用的块
 * @note 进度块在后台队列上执行
 * @param completedBlock 完成下载后调用的块。如果下载成功，则设置图像参数，如果有错误，则将错误参数设置为错误。如果不使用SDWebImageDownloaderProgressiveDownload，则最后一个参数始终为YES。使用SDWebImageDownloaderProgressiveDownload选项，该块将在部分图像对象和完成参数设置为NO之前重复调用，最后一次将完整图像和完成参数设置为YES。如果发生错误，完成的参数始终为YES。

 * @return 返回一个令牌，可以在该令牌上调用-cancel方法来取消该操作
 */
- (XXSDWebImageDownloadToken *)downloadImageWithURL:(NSURL *)url
                                            options:(XXSDWebImageDownloaderOptions)options
                                           progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                                          completed:(XXSDWebImageDownloaderCompletionBlock)completedBlock;

/**
  * 取消之前使用-downloadImageWithURL:options:progress:completed:排队的下载
  *
  * @param token 从-downloadImageWithURL：options：progress：completed得到的令牌.
  */
- (void)cancel:(XXSDWebImageDownloadToken *)token;

/**
  * 设置下载队列暂停状态
  */
- (void)setSuspended:(BOOL)suspended;

/**
  * 取消队列中的所有下载操作
  */
- (void)cancelAllDownloads;

/**
  * 强制SDWebImageDownloader创建并使用用给定配置初始化的新NSURLSession。
  * @note队列中的所有现有下载操作将被取消。
  * @note`timeoutIntervalForRequest`将被覆盖。
  *
  * @param sessionConfiguration 用于新NSURLSession的配置
  */
- (void)createNewSessionWithConfiguration:(NSURLSessionConfiguration *)sessionConfiguration;

/**
  * 使managed session无效，可选择是否取消未决操作。
  * @note 如果您使用自定义下载程序而不是共享下载程序，则当您不使用它时，您需要调用此方法来避免内存泄漏
  * @param cancelPendingOperations 是否取消未决操作。
  * @note 在共享下载器上调用此方法不起作用。
  */
- (void)invalidateSessionAndCancel:(BOOL)cancelPendingOperations;

@end
