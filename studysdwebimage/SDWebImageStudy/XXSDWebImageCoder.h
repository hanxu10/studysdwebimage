//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCompat.h"
#import "NSData+XXImageContentType.h"



//是否缩减大图，在解码过程中
FOUNDATION_EXPORT NSString *_Nonnull const XXSDWebImageCoderScaleDownLargeImageKey;

//设备相关的RGB色彩空间
CG_EXTERN CGColorSpaceRef _Nonnull XXSDCGColorSpaceGetDeviceRGB(void);

//检查CGImageRef是否包含alpha通道
CG_EXTERN BOOL XXSDCGImageRefContainsAlpha(_Nullable CGImageRef imageRef);


//图片编码协议，提供自定义的图片编码/解码
@protocol XXSDWebImageCoder <NSObject>

@required

#pragma mark - Decoding

//如果这个coder可以解码data，返回YES.否则，这个data应该被传给另一个coder
- (BOOL)canDecodeFromData:(nullable NSData *)data;

//解码image data为image
- (nullable UIImage *)decodedImageWithData:(nullable NSData *)data;

/*
 * 用原始图像和图像数据解压缩图像。
  @param image 要解压缩的原始图像
  @param data  指向原始图像数据的指针。 指针本身是非空的，但图像数据可以为空。 如果需要，这些数据将设置为缓存。 如果您不需要同时修改数据，请忽略此参数。
  @param optionsDict  包含任何解压缩选项的字典。 通过{SDWebImageCoderScaleDownLargeImagesKey：@（YES）}缩小大图像
  @return解压缩的图像
*/
- (nullable UIImage *)decompressedImageWithImage:(nullable UIImage *)image
                                            data:(NSData * _Nullable *_Nonnull)data
                                         options:(nullable NSDictionary<NSString *, NSObject *> *)optionsDict;

#pragma mark - Encoding

//返回YES，如果coder可以编码图片。否则，把image传给另一个coder
- (BOOL)canEncodeToFormat:(XXSDImageFormat)format;

//把image编码成 image data
- (nullable NSData *)encodedDataWithImage:(nullable UIImage *)image format:(XXSDImageFormat)format;

@end

@protocol XXSDWebImageProgressiveCoder <XXSDWebImageCoder>

@required

//如果此编码器可以增量解码某些数据，则返回YES。 否则，它应该被传递给另一个编码器。
- (BOOL)canIncrementallyDecodeFromData:(nullable NSData *)data;

/*增量式将图像数据解码为图像。
  @param data     到目前为止已经下载了的图像数据
  @param finished 是否下载完成
  @warning    因为增量解码需要保持解码的上下文，我们将为每个下载操作分配一个具有相同类的新实例以避免冲突
  @return     从数据解码得到的图像
 */
- (nullable UIImage *)incrementallyDecodedImageWithData:(nullable NSData *)data finished:(BOOL)finished;

@end
