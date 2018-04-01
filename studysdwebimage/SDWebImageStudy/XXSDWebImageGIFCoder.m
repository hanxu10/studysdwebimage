//
//  XXSDWebImageGIFCoder.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageGIFCoder.h"
#import "NSImage+XXWebCache.h"
#import <ImageIO/ImageIO.h>
#import "NSData+XXImageContentType.h"
#import "UIImage+XXMultiFormat.h"
#import "XXSDWebImageCoderHelper.h"
#import "XXSDAnimatedImageRep.h"

@implementation XXSDWebImageGIFCoder

+ (instancetype)sharedCoder
{
    static XXSDWebImageGIFCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[XXSDWebImageGIFCoder alloc] init];
    });
    return coder;
}

#pragma mark - Decode

- (BOOL)canDecodeFromData:(NSData *)data
{
    return ([NSData xxsd_imageFormatForImageData:data] == XXSDImageFormatGIF);
}

- (UIImage *)decodedImageWithData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
    size_t count = CGImageSourceGetCount(source);
    
    UIImage *animatedImage;
    
    if (count <= 1) {
        animatedImage = [[UIImage alloc] initWithData:data];
    } else {
        NSMutableArray<XXSDWebImageFrame *> *frames = [NSMutableArray array];
        
        for (size_t i = 0; i < count; i++) {
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
            if (!imageRef) {
                continue;
            }
            
            float duration = [self xxsd_frameDurationAtIndex:i source:source];
            UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
            CGImageRelease(imageRef);
            
            XXSDWebImageFrame *frame = [XXSDWebImageFrame frameWithImage:image duration:duration];
            [frames addObject:frame];
        }
        
        NSUInteger loopCount = 1;
        NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(source, NULL);
        NSDictionary *gifProperties = [imageProperties valueForKey:(__bridge_transfer NSString *)kCGImagePropertyGIFDictionary];
        if (gifProperties) {
            NSNumber *gifLoopCount = [gifProperties valueForKey:(__bridge_transfer NSString *)kCGImagePropertyGIFLoopCount];
            if (gifLoopCount) {
                loopCount = gifLoopCount.unsignedIntegerValue;
            }
        }
        
        animatedImage = [XXSDWebImageCoderHelper animatedImageWithFrames:frames];
        animatedImage.xxsd_imageLoopCount = loopCount;
    }
    
    CFRelease(source);
    
    return animatedImage;
}

- (float)xxsd_frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source
{
    float frameDuration = 0.1f;
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, NULL);
    if (!cfFrameProperties) {
        return frameDuration;
    }
    
    NSDictionary *frameProperties = (__bridge NSDictionary *)(cfFrameProperties);
    NSDictionary *gifProperties = frameProperties[(NSString *)kCGImagePropertyGIFDictionary];
    
    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    if (delayTimeUnclampedProp) {
        frameDuration = delayTimeUnclampedProp.floatValue;
    } else {
        NSNumber *delayTimeProp = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
        if (delayTimeProp) {
            frameDuration = delayTimeProp.floatValue;
        }
    }
    
    //许多令人讨厌的广告指定了持续时间为0，以尽可能快地使图像闪烁。
    //我们遵循Firefox的行为，并对指定持续时间<= 10 ms的任何帧使用100 ms的持续时间。 参见<rdar：// problem / 7689300>和<http://webkit.org/b36082>
    // 了解更多信息。
    if (frameDuration < 0.011f) {
        frameDuration = 0.1f;
    }
    
    CFRelease(cfFrameProperties);
    return frameDuration;
}

- (UIImage *)decompressedImageWithImage:(UIImage *)image
                                   data:(NSData *__autoreleasing  _Nullable *)data
                                options:(NSDictionary<NSString *,NSObject *> *)optionsDict
{
    // GIF 不解码
    return image;
}

#pragma mark - Encode

- (BOOL)canEncodeToFormat:(XXSDImageFormat)format
{
    return (format == XXSDImageFormatGIF);
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(XXSDImageFormat)format
{
    if (!image) {
        return nil;
    }
    
    if (format != XXSDImageFormatGIF) {
        return nil;
    }
    
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData xxsd_UTTypeFromSDImageFormat:XXSDImageFormatGIF];
    NSArray<XXSDWebImageFrame *> *frames = [XXSDWebImageCoderHelper framesFromAnimatedImage:image];
    
    //创建一个图像destination。 GIF不支持EXIF图像方向
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, frames.count, NULL);
    if (!imageDestination) {
        return nil;
    }
    if (frames.count == 0) {
        //用于静态单个GIF图像
        CGImageDestinationAddImage(imageDestination, image.CGImage, nil);
    } else {
        //用于动画GIF图像
        NSUInteger loopCount = image.xxsd_imageLoopCount;
        NSDictionary *gifProperties = @{
                                        (__bridge_transfer NSString *)kCGImagePropertyGIFDictionary : @{
                                                (__bridge_transfer NSString *)kCGImagePropertyGIFLoopCount : @(loopCount)
                                                }
                                        };
        CGImageDestinationSetProperties(imageDestination, (__bridge CFDictionaryRef)gifProperties);
        
        for (size_t i = 0; i < frames.count; i++) {
            XXSDWebImageFrame *frame = frames[i];
            float frameDuration = frame.duration;
            CGImageRef frameImageRef = frame.image.CGImage;
            NSDictionary *frameProperties = @{
                                              (__bridge_transfer NSString *)kCGImagePropertyGIFDictionary : @{
                                                      (__bridge_transfer NSString *)kCGImagePropertyGIFDelayTime : @(frameDuration),
                                                      }
                                              };
            CGImageDestinationAddImage(imageDestination, frameImageRef, (__bridge CFDictionaryRef)frameProperties);
        }
    }
    
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        imageData = nil;
    }
    
    CFRelease(imageDestination);
    
    return [imageData copy];
}

@end
