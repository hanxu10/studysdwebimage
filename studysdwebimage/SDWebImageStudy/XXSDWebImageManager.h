//
//  XXSDWebImageManager.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/4.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"
#import "XXSDWebImageOperation.h"
#import "XXSDWebImageDownloader.h"
#import "XXSDImageCache.h"

typedef NS_OPTIONS(NSUInteger, XXSDWebImageOptions) {
    /**
      * 默认情况下，当一个URL无法下载时，该URL会被列入黑名单，因此库不会继续尝试。
      * 此标志禁用此黑名单。
      */
    XXSDWebImageRetryFailed = 1 << 0,
    
    /**
      * 默认情况下，图像下载在UI交互过程中启动，此标志禁用此功能，
      * 例如，在UIScrollView减速时延迟下载。
      */
    XXSDWebImageLowPriority = 1 << 1,
    
    /**
      * 此标志在下载完成后禁用磁盘缓存，只缓存在内存中
      */
    XXSDWebImageCacheMemoryOnly = 1 << 2,
    
    /**
      * 此标志启用渐进式下载，图像在下载期间会逐渐显示，就像浏览器一样。
      * 默认情况下，图像仅在完全下载后才显示。
      */
    XXSDWebImageProgressiveDownload = 1 << 3,
    
    /**
     * 即使图像被缓存，也要尊重HTTP响应缓存控制，并根据需要从远程位置刷新图像。
     * 磁盘缓存将由NSURLCache而不是SDWebImage处理，导致性能下降。
     * 此选项可帮助处理在相同请求网址后面更改的图片，例如 Facebook图表api配置文件图片。
     * 如果刷新了缓存的图像，则使用缓存的图像和最终的图像再次调用完成块。
     *
     * 只有在无法通过嵌入式缓存清除参数使您的URL静态时才使用此标志。
     */
    XXSDWebImageRefreshCached = 1 << 4,
    
    /**
     * 在iOS 4+中，如果应用程序转到后台，请继续下载图像。 这是通过向系统请求后台的额外时间来完成请求来实现的。 如果后台任务到期，操作将被取消。
     */
    XXSDWebImageContinueInBackground = 1 << 5,
    
    /**
      * 通过设置NSMutableURLRequest.HTTPShouldHandleCookies = YES处理存储在NSHTTPCookieStore中的cookie;
      */
    XXSDWebImageHandleCookies = 1 << 6,
    
    /**
      * 允许不可信的SSL证书。
      * 用于测试目的。 在生产中谨慎使用。
      */
    XXSDWebImageAllowInvalidSSLCertificates = 1 << 7,
    
    /**
      * 默认情况下，图像按照它们排队的顺序加载。 这个标志将它们移动到队列的前面。
      */
    XXSDWebImageHighPriority = 1 << 8,
    
    /**
      * 默认情况下，占位符图像在加载图像时加载。 该标志将延迟加载占位符图像，直到图像加载完成。
      */
    XXSDWebImageDelayPlaceholder = 1 << 9,
    
    /**
      * 我们通常不会在动画图像上调用transformDownloadedImage委托方法，因为大多数转换代码会对其进行破坏。 使用这个标志来转换它们。
      */
    XXSDWebImageTransformAnimatedImage = 1 << 10,
    
    /**
      * 默认情况下，下载后图像被添加到imageView。 但在某些情况下，我们希望在设置图像之前进行手动处理（例如应用滤镜或添加淡入淡出动画）
      * 如果您想在成功完成时手动设置图像，请使用此标志
      */
    XXSDWebImageAvoidAutoSetImage = 1 << 11,
    
    /**
      *默认情况下，图像将根据其原始尺寸进行解码。 在iOS上，此标志会将图像缩小到与受限制的设备内存兼容的尺寸。
      *如果设置了“SDWebImageProgressiveDownload”标志，则缩小比例被抛弃。
      */
    XXSDWebImageScaleDownLargeImages = 1 << 12,
    
    /**
      * 默认情况下，当图像缓存在内存中时，我们不会查询磁盘数据。 该掩码可以强制同时查询磁盘数据。
      * 此标志建议与'SDWebImageQueryDiskSync`一起使用，以确保图像在同一个runloop中加载。
      */
    XXSDWebImageQueryDataWhenInMemory = 1 << 13,
    
    /**
      * 默认情况下，我们同步查询内存缓存，异步查询磁盘缓存。 该掩码可以强制同步查询磁盘缓存，以确保图像在同一个runloop中加载。
      * 如果禁用内存缓存或在其他一些情况下，此标志可避免在单元重用期间闪烁。
      */
    XXSDWebImageQueryDiskSync = 1 << 14,
    
    /**
      * 默认情况下，当缓存丢失时，图像从网络下载。 该标志可以防止网络下载，只从缓存中加载。
      */
    XXSDWebImageFromCacheOnly = 1 << 15,
    
    /**
      * 默认情况下，当您使用`SDWebImageTransition`在图像加载完成后进行一些视图转换时，此转换仅适用于从网络下载图像。 这个掩码也可以强制为内存和磁盘缓存应用视图转换。
      */
    XXSDWebImageForceTransition = 1 << 16
};

typedef void(^XXSDExternalCompletionBlock)(UIImage *image, NSError *error, XXSDImageCacheType cacheType, NSURL *imageURL);

typedef void(^XXSDInteranalCompletionBlock)(UIImage *image, NSData *data, NSError *error, XXSDImageCacheType cacheType, BOOL finished, NSURL *imageURL);

typedef NSString *(^XXSDWebImageCacheKeyFilterBlock)(NSURL *url);

typedef NSData *(^XXSDWebImageCacheSerializerBlock)(UIImage *image, NSData *data, NSURL *imageURL);

@class XXSDWebImageManager;

@protocol XXSDWebImageManagerDelegate <NSObject>

@optional
/**
  * 控制在缓存中找不到图像时应下载哪个图像。
  *
  * @param imageManager 当前的“SDWebImageManager”
  * @param imageURL 要下载的图像的网址
  *
  * @return返回NO以阻止在缓存未命中时下载图像。 如果不实施，暗示是。
  */
- (BOOL)imageManager:(XXSDWebImageManager *)imageManager shouldDownloadImageForURL:(NSURL *)imageURL;

/**
  * 控制复杂的逻辑，在发生下载错误时标记为失败的URL。
  * 如果委托实现此方法，则不会使用内置方式根据错误代码将URL标记为失败;
   @param imageManager 当前的`SDWebImageManager`
   @param imageURL 图像的网址
   @param error url的下载错误
   @return 是否阻止这个网址。 返回YES将此URL标记为失败。
  */
- (BOOL)imageManager:(XXSDWebImageManager *)imageManager shouldBlockFailedURL:(NSURL *)imageURL withError:(NSError *)error;

/**
  * 允许在下载之后，在将图像缓存在磁盘和内存上之前，立即转换图像，
  * 注意：从全局队列中调用此方法是为了不阻塞主线程。
  *
  * @param imageManager 当前的“SDWebImageManager”
  * @param image 要转换的图像
  * @param imageURL 要转换的图像的网址
  *
  * @return 转换后的图像对象。
  */
- (UIImage *)imageManager:(XXSDWebImageManager *)imageManager transformDownloadedImage:(UIImage *)image withURL:(NSURL *)imageURL;

@end


/**
 * The SDWebImageManager is the class behind the UIImageView+WebCache category and likes.
 * It ties the asynchronous downloader (SDWebImageDownloader) with the image cache store (SDImageCache).
 * You can use this class directly to benefit from web image downloading with caching in another context than
 * a UIView.
 *
 * Here is a simple example of how to use SDWebImageManager:
 *
 * @code
 
 SDWebImageManager *manager = [SDWebImageManager sharedManager];
 [manager loadImageWithURL:imageURL
                   options:0
                  progress:nil
                 completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                    if (image) {
                       // do something with image
                    }
                  }];
 
 * @endcode
 */

@interface XXSDWebImageManager : NSObject

@property (nonatomic, weak) id<XXSDWebImageManagerDelegate> delegate;

@property (nonatomic, strong, readonly) XXSDImageCache *imageCache;

@property (nonatomic, strong, readonly) XXSDWebImageDownloader *imageDownloader;

/**
  * 缓存过滤器是每次SDWebImageManager需要将URL转换为缓存键时使用的块。 这可以用来删除图片网址的动态部分。
  *
  * 以下示例在应用程序委托中设置一个筛选器，该筛选器将从URL中删除任何查询字符串，然后将其用作缓存键：
  * @code
 SDWebImageManager.sharedManager.cacheKeyFilter = ^（NSURL * _Nullable url）{
      url = [[NSURL alloc] initWithScheme：url.scheme host：url.host path：url.path];
      return [url absoluteString];
 };
 
  * @endcode
  */
@property (nonatomic, copy) XXSDWebImageCacheKeyFilterBlock cacheKeyFilter;


/**
 * The cache serializer is a block used to convert the decoded image, the source downloaded data, to the actual data used for storing to the disk cache. If you return nil, means to generate the data from the image instance, see `SDImageCache`.
 * For example, if you are using WebP images and facing the slow decoding time issue when later retriving from disk cache again. You can try to encode the decoded image to JPEG/PNG format to disk cache instead of source downloaded data.
 * @note The `image` arg is nonnull, but when you also provide a image transformer and the image is transformed, the `data` arg may be nil, take attention to this case.
 * @note This method is called from a global queue in order to not to block the main thread.
 * @code
 SDWebImageManager.sharedManager.cacheKeyFilter = ^NSData * _Nullable(UIImage * _Nonnull image, NSData * _Nullable data, NSURL * _Nullable imageURL) {
 SDImageFormat format = [NSData sd_imageFormatForImageData:data];
 switch (format) {
 case SDImageFormatWebP:
 return image.images ? data : nil;
 default:
 return data;
 }
 };
 * @endcode
 * The default value is nil. Means we just store the source downloaded data to disk cache.
 */
@property (nonatomic, copy) XXSDWebImageCacheSerializerBlock cacheSerializer;

+ (instancetype)sharedManager;

- (instancetype)initWithCache:(XXSDImageCache *)cache downloader:(XXSDWebImageDownloader *)downloader NS_DESIGNATED_INITIALIZER;

/**
 * 如果不存在于缓存中，则下载给定URL处的图像，否则返回缓存的版本。
 *
 * @param url 图片的网址
 * @param options 用于指定用于此请求的选项的掩码
 * @param progressBlock 在图像下载时调用的块
                        @note 进度块在后台队列上执行
 * @param completedBlock 操作完成时调用的块。
 *
 * 此参数是必需的。
 *
 * 此block没有返回值，并将请求的UIImage作为第一个参数，将NSData表示作为第二个参数。
 * 如果出现错误，图像参数为nil，第三个参数可能包含NSError。
 *
 * 第四个参数是一个`SDImageCacheType`枚举，指示图像是从本地缓存还是从内存缓存或网络中检索的。
 *
 * 当使用SDWebImageProgressiveDownload选项并下载图像时，第五个参数设置为NO。 因此该块被部分图像重复调用。 当图像被完全下载时，该块被称为最后一次具有完整图像并且最后一个参数被设置为YES。
 *
 * 最后一个参数是原始图片网址 *
 *
 * @return 返回一个符合SDWebImageOperation的NSObject。应该是SDWebImageDownloaderOperation的一个实例
 */
- (id<XXSDWebImageOperation>)loadImageWithURL:(NSURL *)url options:(XXSDWebImageOptions)options progress:(XXSDWebImageDownloaderProgressBlock)progressBlock completed:(XXSDInteranalCompletionBlock)completedBlock;

/**
  * 保存图像缓存使用给定的URL
  *
  * @param image 要缓存的图像
  * @param url 图片的网址
  */
- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url;

/**
  * 取消所有当前操作
  */
- (void)cancelAll;


/**
  * 检查一个或多个正在运行的操作
  */
- (BOOL)isRunning;

/**
  * 异步检查图像是否已被缓存
  *
  * @param url 图片网址
  * @param completionBlock 在检查完成时要执行的块
  *
  * @note 完成块总是在主队列上执行
  */
- (void)cachedImageExistsForURL:(NSURL *)url completion:(XXSDWebImageCheckCacheCompletionBlock)completionBlock;

/**
 *  Async check if image has already been cached on disk only
 *
 *  @param url              image url
 *  @param completionBlock  the block to be executed when the check is finished
 *
 *  @note the completion block is always executed on the main queue
 */
- (void)diskImageExistsForURL:(NSURL *)url
                   completion:(XXSDWebImageCheckCacheCompletionBlock)completionBlock;

/**
  * 返回给定URL的缓存键
  */
- (NSString *)cacheKeyForURL:(NSURL *)url;

@end
























