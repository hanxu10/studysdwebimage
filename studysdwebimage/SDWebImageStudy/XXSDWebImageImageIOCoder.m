//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageImageIOCoder.h"
#import "XXSDWebImageCoderHelper.h"
#import "NSImage+XXWebCache.h"
#import <ImageIO/ImageIO.h>
#import "NSData+XXImageContentType.h"

#if XXSD_UIKIT || XXSD_WATCH
static const size_t kBytesPerPixel = 4;
static const size_t kBitsPerComponent = 8;

/*
  *设置标记“SDWebImageScaleDownLargeImages”时，解码图像的最大尺寸（以MB为单位）
  * iPad1和iPhone 3GS的建议值：60。
  *为iPad2和iPhone 4建议的价值：120。
  * iPhone 3G和iPod 2及更早版本设备的建议价值：30。
 */
static const CGFloat kDestImageSizeMB = 60.0f;


/*
  *定义当设置标志“SDWebImageScaleDownLargeImages”时用于解码图像的图块的最大大小（以MB为单位）
  * iPad1和iPhone 3GS的建议值：20。
  * iPad2和iPhone 4的建议价值：40。
  * iPhone 3G和iPod 2及更早版本设备的建议价值：10。
 */
static const CGFloat kSourceImageTileSizeMB = 20.0f;

static const CGFloat kBytesPerMB = 1024.0f * 1024.0f;
static const CGFloat kPixelsPerMB = kBytesPerMB / kBytesPerPixel;
static const CGFloat kDestTotalPixels = kDestImageSizeMB * kPixelsPerMB;
static const CGFloat kTileTotalPixels = kSourceImageTileSizeMB * kBytesPerMB;

// the numbers of pixels to overlap the seems where tiles meet.
static const CGFloat kDestSeemOverlap = 2.0f;

#endif

@implementation XXSDWebImageImageIOCoder
{
    size_t _width;
    size_t _height;
#if XXSD_UIKIT || XXSD_WATCH
    UIImageOrientation _orientation;
#endif
    CGImageSourceRef _imageSource;
}

- (void)dealloc
{
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
}

+ (instancetype)sharedCoder
{
    static XXSDWebImageImageIOCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[XXSDWebImageImageIOCoder alloc] init];
    });
    return coder;
}

#pragma mark - Decode

- (BOOL)canDecodeFromData:(NSData *)data
{
    switch ([NSData xxsd_imageFormatForImageData:data]) {
        case XXSDImageFormatWebP:
            return NO;
        case XXSDImageFormatHEIC:
            return [[self class] canDecodeFromHEICFormat];
        default:
            return YES;
    }
}

- (BOOL)canIncrementallyDecodeFromData:(NSData *)data
{
    switch ([NSData xxsd_imageFormatForImageData:data]) {
        case XXSDImageFormatWebP:
            //不支持WebP progressive decoding
            return NO;
        case XXSDImageFormatHEIC:
            //检查HEIC解码兼容性
            return [[self class] canDecodeFromHEICFormat];
        default:
            return YES;
    }
}

- (UIImage *)decodedImageWithData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    
    UIImage *image = [[UIImage alloc] initWithData:data];
#if XXSD_MAC
    return image;
#else
    if (!image) {
        return nil;
    }
    
    UIImageOrientation orientation = [[self class] xxsd_imageOrientationFromImageData:data];
    if (orientation != UIImageOrientationUp) {
        image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:orientation];
    }
    return image;
#endif
}

- (UIImage *)incrementallyDecodedImageWithData:(NSData *)data finished:(BOOL)finished
{
    if (!_imageSource) {
        _imageSource = CGImageSourceCreateIncremental(NULL);
    }
    UIImage *image;
    
    CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)data, finished);
    
    if (_width + _height == 0) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, NULL);
        if (properties) {
            NSInteger orientationValue = 1;
            CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
            if (val) {
                CFNumberGetValue(val, kCFNumberLongType, &_height);
            }
            val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
            if (val) {
                CFNumberGetValue(val, kCFNumberLongType, &_width);
            }
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) {
                CFNumberGetValue(val, kCFNumberNSIntegerType, &orientationValue);
            }
            CFRelease(properties);
            
            //当我们绘制到Core Graphics时，我们失去了方向信息，这意味着initWithCGIImage生成的图像有时会被错误地定位。 （与didCompleteWithError中的initWithData所生成的图像不同。）因此，请将其保存在此处并稍后传递它。
#if XXSD_UIKIT || XXSD_WATCH
            _orientation = [XXSDWebImageCoderHelper imageOrientationFromEXIFOrientation:orientationValue];
#endif
        }
    }
    
    if (_width + _height > 0) {
        //创建image
        CGImageRef partialImageRef = CGImageSourceCreateImageAtIndex(_imageSource, 0, NULL);
#if XXSD_UIKIT || XXSD_WATCH
        //针对iOS变形图像的解决方法
        if (partialImageRef) {
            const size_t partialHeight = CGImageGetHeight(partialImageRef);
            CGColorSpaceRef colorSpace = XXSDCGColorSpaceGetDeviceRGB();
            CGContextRef bmContext = CGBitmapContextCreate(NULL, _width, _height, 8, 0, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
            if (bmContext) {
                CGContextDrawImage(bmContext, CGRectMake(0, 0, _width, _height), partialImageRef);
                CGImageRelease(partialImageRef);
                partialImageRef = CGBitmapContextCreateImage(bmContext);
                CGContextRelease(bmContext);
            } else {
                CGImageRelease(partialImageRef);
                partialImageRef = nil;
            }
        }
#endif
        if (partialImageRef) {
#if XXSD_UIKIT || XXSD_WATCH
            image = [[UIImage alloc] initWithCGImage:partialImageRef scale:1 orientation:_orientation];
#elif XXSD_MAC
            image = [[UIImage alloc] initWithCGImage:partialImageRef size:NSZeroSize];
#endif
            CGImageRelease(partialImageRef);
        }
    }
    
    if (finished) {
        if (_imageSource) {
            CFRelease(_imageSource);
            _imageSource = NULL;
        }
    }
    return image;
}

- (UIImage *)decompressedImageWithImage:(UIImage *)image
                                   data:(NSData *__autoreleasing  _Nullable *)data
                                options:(NSDictionary<NSString *,NSObject *> *)optionsDict
{
#if XXSD_MAC
    return image;
#endif
#if XXSD_UIKIT || XXSD_WATCH
    BOOL shouldScaleDown = NO;
    if (optionsDict != nil) {
        NSNumber *scaleDownLargeImagesOption = nil;
        if ([optionsDict[XXSDWebImageCoderScaleDownLargeImageKey] isKindOfClass:[NSNumber class]]) {
            scaleDownLargeImagesOption = (NSNumber *)optionsDict[XXSDWebImageCoderScaleDownLargeImageKey];
        }
        if (scaleDownLargeImagesOption) {
            shouldScaleDown = [scaleDownLargeImagesOption boolValue];
        }
    }
    if (!shouldScaleDown) {
        return [self xxsd_decompressedImageWithImage:image];
    } else {
        UIImage *scaledDownImage = [self xxsd_decompressedAndScaledDownImageWithImage:image];
        if (scaledDownImage && !CGSizeEqualToSize(scaledDownImage.size, image.size)) {
            XXSDImageFormat format = [NSData xxsd_imageFormatForImageData:*data];
            NSData *imageData = [self encodedDataWithImage:scaledDownImage format:format];
            if (imageData) {
                *data = imageData;
            }
        }
        return scaledDownImage;
    }
#endif
}

#if SD_UIKIT || SD_WATCH

- (UIImage *)xxsd_decompressedImageWithImage:(UIImage *)image
{
    if (![[self class] shouldDecodeImage:image]) {
        return image;
    }
    
    //自动释放位图上下文和所有变量以帮助系统在存在内存警告时释放内存。
    //在iOS7上，不要忘记调用[[SDImageCache sharedImageCache] clearMemory];
    @autoreleasepool {
        CGImageRef imageRef = image.CGImage;
        CGColorSpaceRef colorspaceRef = [[self class] colorSpaceForImageRef:imageRef];
        
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        
        //CGBitmapContextCreate不支持kCGImageAlphaNone。
        //由于此处的原始图像没有alpha信息，因此请使用kCGImageAlphaNoneSkipLast创建不带alpha信息的位图图形上下文。
        CGContextRef context = CGBitmapContextCreate(NULL, width, height, kBitsPerComponent, 0, colorspaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast);
        
        if (context == NULL) {
            return image;
        }
        
        //将图像绘制到上下文中并获取没有alpha的新位图图像
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGImageRef imageRefWithoutAlpha = CGBitmapContextCreateImage(context);
        UIImage *imageWithoutAlpha = [[UIImage alloc] initWithCGImage:imageRefWithoutAlpha scale:image.scale orientation:image.imageOrientation];
        CGContextRelease(context);
        CGImageRelease(imageRefWithoutAlpha);
        
        return imageWithoutAlpha;
    }
}

- (UIImage *)xxsd_decompressedAndScaledDownImageWithImage:(UIImage *)image
{
    if (![[self class] shouldDecodeImage: image]) {
        return image;
    }
    
    if (![[self class] shouldScaleDownImage:image]) {
        return [self xxsd_decompressedImageWithImage:image];
    }
    
    CGContextRef destContext;
    
    @autoreleasepool {
        CGImageRef sourceImageRef = image.CGImage;
        
        CGSize sourceResolution = CGSizeZero;
        sourceResolution.width = CGImageGetWidth(sourceImageRef);
        sourceResolution.height = CGImageGetHeight(sourceImageRef);
        float sourceTotalPixels = sourceResolution.width * sourceResolution.height;
        //确定应用于输入图像的比例比率，以产生定义大小的输出图像。 请参阅kDestImageSizeMB，以及它与destTotalPixels的关系。
        float imageScale = kDestTotalPixels / sourceTotalPixels;
        CGSize destResolution = CGSizeZero;
        destResolution.width = (int)(sourceResolution.width * imageScale);
        destResolution.height = (int)(sourceResolution.height * imageScale);
        
        //当前色彩空间
        CGColorSpaceRef colorspaceRef = [[self class] colorSpaceForImageRef:sourceImageRef];
        
        //CGBitmapContextCreate不支持kCGImageAlphaNone。
        //由于此处的原始图像没有alpha信息，因此请使用kCGImageAlphaNoneSkipLast创建不带alpha信息的位图图形上下文。
        destContext = CGBitmapContextCreate(NULL, destResolution.width, destResolution.height, kBitsPerComponent, 0, colorspaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast);
        
        if (destContext == NULL) {
            return image;
        }
        CGContextSetInterpolationQuality(destContext, kCGInterpolationHigh);
        
        //定义用于从输入图像到输出图像的增量色块的矩形的大小。 由于iOS从磁盘获取图像数据的方式，我们使用与源图像宽度相等的源图像宽度。 即使当前图形上下文在该频带内被裁剪为子目录，iOS也必须从全磁带“全带宽”解码磁盘上的图像。 因此，我们通过将我们的图块大小修改为输入图像的整个宽度，充分利用解码操作产生的所有像素数据。
        CGRect sourceTile = CGRectZero;
        sourceTile.size.width = sourceResolution.width;
        //源tile的高度是动态的。 由于我们以MB为单位指定了源tile的大小， 因此对于给定的输入图片宽度，可以算出要多少行像素
        sourceTile.size.height = (int)(kTileTotalPixels / sourceTile.size.width);
        sourceTile.origin.x = 0.0f;
        //输出tile和输入tile有着相同的属性，但是缩放到图像比例
        CGRect destTile;
        destTile.size.width = destResolution.width;
        destTile.size.height = sourceTile.size.height * imageScale;
        destTile.origin.x = 0.0f;
        // The source seem overlap is proportionate to the destination seem overlap.
        // this is the amount of pixels to overlap each tile as we assemble the ouput image.
        float sourceSeemOverlap = (int)(kDestSeemOverlap / destResolution.height * sourceResolution.height);
        CGImageRef sourceTileImageRef;
        //计算组装输出图像 所需的读/写操作次数。
        int iterations = (int)(sourceResolution.height / sourceTile.size.height);
        //如果tile高度不均匀划分图像高度，则添加另一个迭代来计算其余像素。
        int remainder = (int)sourceResolution.height % (int)sourceTile.size.height;
        if (remainder) {
            iterations++;
        }
        // Add seem overlaps to the tiles, but save the original tile height for y coordinate calculations.
        float sourceTileHeightMinusOverlap = sourceTile.size.height;
        sourceTile.size.height += sourceSeemOverlap;
        destTile.size.height += kDestSeemOverlap;
        for (int y = 0; y < iterations; ++y) {
            @autoreleasepool {
                sourceTile.origin.y = y * sourceTileHeightMinusOverlap + sourceSeemOverlap;
                destTile.origin.y = destResolution.height - ((y+1) * sourceTileHeightMinusOverlap * imageScale + kDestSeemOverlap);
                sourceTileImageRef = CGImageCreateWithImageInRect(sourceImageRef, sourceTile);
                if (y == iterations - 1 && remainder) {
                    float dify = destTile.size.height;
                    destTile.size.height = CGImageGetHeight(sourceTileImageRef) * imageScale;
                    dify -= destTile.size.height;
                    destTile.origin.y += dify;
                }
                CGContextDrawImage(destContext, destTile, sourceTileImageRef);
                CGImageRelease(sourceTileImageRef);
            }
        }
        CGImageRef destImageRef = CGBitmapContextCreateImage(destContext);
        CGContextRelease(destContext);
        if (destImageRef == NULL) {
            return image;
        }
        
        UIImage *destImage = [[UIImage alloc] initWithCGImage:destImageRef scale:image.scale orientation:image.imageOrientation];
        CGImageRelease(destImageRef);
        if (destImage == nil) {
            return image;
        }
        return destImage;
    }
}

#pragma mark - Encode

- (BOOL)canEncodeToFormat:(XXSDImageFormat)format
{
    switch (format) {
        case XXSDImageFormatWebP:
            return NO;
        case XXSDImageFormatHEIC:
            return [[self class] canEncodeToHEICFormat];
        default:
            return YES;
    }
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(XXSDImageFormat)format
{
    if (!image) {
        return nil;
    }
    
    if (format == XXSDImageFormatUndefined) {
        BOOL hasAlpha = XXSDCGImageRefContainsAlpha(image.CGImage);
        if (hasAlpha) {
            format = XXSDImageFormatPNG;
        } else {
            format = XXSDImageFormatJPEG;
        }
    }
    
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData xxsd_UTTypeFromSDImageFormat:format];
    
    //创建image destination
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, 1, NULL);
    if (!imageDestination) {
        return nil;
    }
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
#if XXSD_UIKIT || XXSD_WATCH
    NSInteger exifOrientation = [XXSDWebImageCoderHelper exifOrientationFromImageOrientation:image.imageOrientation];
    //__bridge           比较常用，不改变所有权
    //__bridge_transfer   非oc -> oc   对象的管理权交给ARC
    //__bridge_retained     oc -> 非oc  剥夺ARC的管理权，后续需要开发者使用CFRelease或者相关方法手动来释放对象
    [properties setValue:@(exifOrientation) forKey:(__bridge_transfer NSString *)kCGImagePropertyOrientation];
#endif
    //把你的image加到destiantion
    CGImageDestinationAddImage(imageDestination, image.CGImage, (__bridge CFDictionaryRef)properties);
    
    //
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        imageData = nil;
    }
    
    CFRelease(imageDestination);
   
    return [imageData copy];
}

#endif

#pragma mark - Helper

+ (BOOL)shouldDecodeImage:(UIImage *)image
{
    if (image == nil) {
        return NO;
    }
    
    //不解码动画
    if (image.images != nil) {
        return NO;
    }
    
    CGImageRef imageRef = image.CGImage;
    
    BOOL hasAlpha = XXSDCGImageRefContainsAlpha(imageRef);
    //不解码有alpha的图片
    if (hasAlpha) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)canDecodeFromHEICFormat
{
    static BOOL canDecode = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if TARGET_OS_SIMULATOR || XXSD_WATCH
        canDecode = NO;
#elif XXSD_MAC
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(operatingSystemVersion)]) {
            // macOS 10.13+
            canDecode = processInfo.operatingSystemVersion.minorVersion >= 13;
        } else {
            canDecode = NO;
        }
#elif XXSD_UIKIT
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(operatingSystemVersion)]) {
            //iOS 11+ && tvOS 11+
            canDecode = processInfo.operatingSystemVersion.majorVersion >= 11;
        } else {
            canDecode = NO;
        }
#endif
    });
    return canDecode;
}

+ (BOOL)canEncodeToHEICFormat
{
    static BOOL canEncode = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableData *imageData = [NSMutableData data];
        CFStringRef imageUTType = [NSData xxsd_UTTypeFromSDImageFormat:XXSDImageFormatHEIC];
        
        //创建一个图片destination
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, 1, NULL);
        if (!imageDestination) {
            canEncode = NO;
        } else {
            CFRelease(imageDestination);
            canEncode = YES;
        }
    });
    return canEncode;
}

#if XXSD_UIKIT || XXSD_WATCH
#pragma mark - EXIF orientation tag converter
+ (UIImageOrientation)xxsd_imageOrientationFromImageData:(NSData *)imageData
{
    UIImageOrientation result = UIImageOrientationUp;
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (imageSource) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
        if (properties) {
            CFTypeRef val;
            NSInteger exifOrientation;
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) {
                CFNumberGetValue(val, kCFNumberNSIntegerType, &exifOrientation);
                result = [XXSDWebImageCoderHelper imageOrientationFromEXIFOrientation:exifOrientation];
            }
            CFRelease((CFTypeRef)properties);
        } else {
            NSLog(@"没有属性");
        }
        CFRelease(imageSource);
    }
    return result;
}
#endif

#if XXSD_UIKIT || XXSD_WATCH
+ (BOOL)shouldScaleDownImage:(UIImage *)image
{
    BOOL shouldScaleDown = YES;
    
    CGImageRef sourceImageRef = image.CGImage;
    CGSize sourceResolution = CGSizeZero;
    sourceResolution.width = CGImageGetWidth(sourceImageRef);
    sourceResolution.height = CGImageGetHeight(sourceImageRef);
    float sourceTotalPixels = sourceResolution.width * sourceResolution.height;
    float imageScale = kDestTotalPixels / sourceTotalPixels;
    if (imageScale < 1) {
        shouldScaleDown = YES;
    } else {
        shouldScaleDown = NO;
    }
    return shouldScaleDown;
}

+ (CGColorSpaceRef)colorSpaceForImageRef:(CGImageRef)imageRef
{
    CGColorSpaceModel imageColorSpaceModel = CGColorSpaceGetModel(CGImageGetColorSpace(imageRef));
    CGColorSpaceRef colorspaceRef = CGImageGetColorSpace(imageRef);
    
    BOOL unsupportedColorSpace = (
                                  imageColorSpaceModel == kCGColorSpaceModelUnknown ||
                                  imageColorSpaceModel == kCGColorSpaceModelMonochrome ||
                                  imageColorSpaceModel == kCGColorSpaceModelCMYK ||
                                  imageColorSpaceModel == kCGColorSpaceModelIndexed
                                  );
    if (unsupportedColorSpace) {
        colorspaceRef = XXSDCGColorSpaceGetDeviceRGB();
    }
    return colorspaceRef;
}

#endif

@end
