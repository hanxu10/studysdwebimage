//
//  UIView+XXWebCache.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_UIKIT || XXSD_MAC

#import "XXSDWebImageManager.h"
#import "XXSDWebImageTransition.h"

/**
   一个Dispatch group来维护setImageBlock和completionBlock。 该key只能在内部使用，将来可能会更改。（dispatch_group_t）
  */
FOUNDATION_EXPORT NSString * const XXSDWebImageInternalSetImageGroupKey;

/**
   一个SDWebImageManager实例，用于控制在UIImageView + WebCache类别中使用的图像下载和缓存过程。 如果未提供，则使用共享管理器（SDWebImageManager）
  */
FOUNDATION_EXPORT NSString *const XXSDWebImageExternalCustomManagerKey;

/**
   该值指定由于未调用progressBlock而无法确定图像进度单位计数。
  */
FOUNDATION_EXPORT const int64_t XXSDWebImageProgressUnitCountUnknown;

typedef void(^XXSDSetImageBlock)(UIImage *image, NSData *imageData);

@interface UIView (XXWebCache)

/**
   *获取当前图片的网址。
  *
   * @note请注意，由于类别的限制，如果直接使用setImage：则此属性可能会不同步。
  */
- (NSURL *)xxsd_imageURL;

/**
 *与视图关联的当前图像加载进度。单位数量是收到的大小和下载的期望大小。

 *新的图像加载开始后（从当前队列改变），`totalUnitCount`和`completedUnitCount`将被重置为0。如果progressBlock没有被调用，但是图像加载成功以标记进度完成（从主队列改变），则它们将被设置为“SDWebImageProgressUnitCountUnknown”。
 * @note您可以使用Key-Value Observing查看进度，但您应该注意，进度更改是在下载期间从后台队列中进行的（与progressBlock相同）。如果您想使用KVO并更新UI，请确保在主队列中分派。建议使用KVOController等KVO库，因为它更安全，易于使用。
 * @note如果值为零，getter将创建一个进度实例。您还可以设置自定义进度实例，并在图像加载期间更新它
 * @note请注意，由于类别的限制，如果直接更新进度，此属性可能会不同步。
 */
@property (nonatomic, strong) NSProgress *xxsd_imageProgress;

/**
 *用一个`url`和一个可选的占位符图像设置imageView`图像`。
 *
 *下载是异步的并且缓存。
 *
 * @param url 图片的网址。
 * @param placeholder 最初设置的图像，直到图像请求结束。
 * @param options 下载图像时使用的选项。请参阅SDWebImageOptions以了解可能的值。
 * @param operationKey 用作操作键的字符串。如果为零，将使用类名
 * @param setImageBlock 用于自定义设置图像代码的块
 * @param progressBlock 在图像下载时调用的块
 *        @note进度块在后台队列上执行
 * @param completedBlock 操作完成时调用的块。该块没有返回值，并将请求的UIImage作为第一个参数。如果出现错误，图像参数为零，第二个参数可能包含NSError。第三个参数是布尔值，指示图像是从本地缓存还是从网络中检索。
 第四个参数是原始图片网址。
 */
- (void)xxsd_internalSetImageWithURL:(NSURL *)url
                    placeholderImage:(UIImage *)image
                             options:(XXSDWebImageOptions)options
                        operationKey:(NSString *)operationKey
                       setImageBlock:(XXSDSetImageBlock)setImageBlock
                            progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                           completed:(XXSDExternalCompletionBlock)completedBlock;

/**
  *用一个`url`和一个可选的占位符图像设置imageView`图像`。
  *
  *下载是异步的并且缓存。
  *
  * @param url 图片的网址。
  * @param placeholder 最初设置的图像，直到图像请求结束。
  * @param options 下载图像时使用的选项。请参阅SDWebImageOptions以了解可能的值。
  * @param operationKey 用作操作键的字符串。如果为零，将使用类名
  * @param setImageBlock 用于自定义设置图像代码的块
  * @param progressBlock 在图像下载时调用的块
  *        @note进度块在后台队列上执行
  * @param completedBlock 操作完成时调用的块。该块没有返回值，并将请求的UIImage作为第一个参数。如果出现错误，图像参数为零，第二个参数可能包含NSError。第三个参数是布尔值，指示图像是从本地缓存还是从网络中检索。
 第四个参数是原始图片网址。
  * @param context 具有额外信息的上下文来执行指定更改或进程。
  */
- (void)xxsd_internalSetImageWithURL:(NSURL *)url
                  placeholderImage:(UIImage *)placeholder
                           options:(XXSDWebImageOptions)options
                      operationKey:(NSString *)operationKey
                     setImageBlock:(XXSDSetImageBlock)setImageBlock
                          progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                         completed:(XXSDExternalCompletionBlock)completedBlock
                           context:(NSDictionary<NSString *, id> *)context;

/**
  *取消当前的图片加载
  */
- (void)xxsd_cancelCurrentImageLoad;

#pragma mark - Image Transition

/**
   图像加载完成时的图像转换。 请参阅`SDWebImageTransition`。
   如果你指定nil，不做转换。 默认为nil。
  */
@property (nonatomic, strong) XXSDWebImageTransition *xxsd_imageTransition;

#if XXSD_UIKIT
#pragma mark - Activity indicator

/**
  *显示活动UIActivityIndicatorView
  */
- (void)xxsd_setShowActivityIndicatorView:(BOOL)show;

/**
  *设置所需的UIActivityIndicatorViewStyle
  *
  * @param style UIActivityIndicatorView的样式
  */
- (void)xxsd_setIndicatorStyle:(UIActivityIndicatorViewStyle)style;

- (BOOL)xxsd_showActivityIndicatorView;
- (void)xxsd_addActivityIndicator;
- (void)xxsd_removeActivityIndicator;

#endif

@end

#endif

