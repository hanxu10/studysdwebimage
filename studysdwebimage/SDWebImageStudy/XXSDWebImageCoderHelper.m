//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageCoderHelper.h"
#import "XXSDWebImageFrame.h"
#import "UIImage+XXMultiFormat.h"
#import "NSImage+XXWebCache.h"
#import <ImageIO/ImageIO.h>

@implementation XXSDWebImageCoderHelper {

}
+ (UIImage *_Nullable)animatedImageWithFrames:(NSArray<XXSDWebImageFrame *> *_Nullable)frames
{
    NSUInteger frameCount = frames.count;
    if (frameCount == 0) {
        return nil;
    }

    UIImage *animatedImage;
#if SD_UIKIT || SD_WATCH
    NSUInteger durations[frameCount];//装的是毫秒
    for (size_t i = 0; i < frameCount; i++) {
        durations[i] = frames[i].duration * 1000;
    }
    NSUInteger const gcd = gcdArray(frameCount, durations);
    __block NSUInteger totalDuration = 0;
    NSMutableArray<UIImage *> *animatedImages = [NSMutableArray arrayWithCapacity:frameCount];
    [frames enumerateObjectsUsingBlock:^(XXSDWebImageFrame *frame, NSUInteger idx, BOOL *stop) {
        UIImage *image = frame.image;
        NSUInteger duration = frame.duration * 1000;
        totalDuration += duration;
        NSUInteger repeatCount;
        if (gcd) {
            repeatCount = duration / gcd;
        } else {
            repeatCount = 1;
        }
        for (int i = 0; i < repeatCount; ++i) {
            [animatedImages addObject:image];
        }
    }];

    animatedImage = [UIImage animatedImageWithImages:animatedImages duration:totalDuration / 1000.0f];
#else

#endif
    return animatedImage;
}

+ (NSArray<XXSDWebImageFrame *> *)framesFromAnimatedImage:(UIImage *)animatedImage
{
    if (!animatedImage) {
        return nil;
    }

    NSMutableArray<XXSDWebImageFrame *> *frames = [NSMutableArray array];
    NSUInteger frameCount = 0;

#if XXSD_UIKIT || XXSD_WATCH
    NSArray<UIImage *> *animatedImages = animatedImage.images;
    frameCount = animatedImages.count;
    if (frameCount == 0) {
        return nil;
    }

    NSTimeInterval avgDuration = animatedImage.duration / frameCount;
    if (avgDuration == 0) {
        avgDuration = 0.1;//如果它是一个动画图像但没有持续时间，则将其设置为默认的100ms（这不具有像GIF或WebP那样的10ms限制，以允许自定义编码器提供限制）
    }

    __block NSUInteger index = 0;
    __block NSUInteger repeatCount = 1;
    __block UIImage *previousImage = animatedImages.firstObject;
    [animatedImages enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {

        if (idx == 0) {//忽略第一个
            return;
        }
        if ([image isEqual:previousImage]) {
            repeatCount++;
        } else {
            XXSDWebImageFrame *frame = [XXSDWebImageFrame frameWithImage:previousImage duration:avgDuration * repeatCount];
            [frames addObject:frame];
            repeatCount = 1;
            index++;
        }
        previousImage = image;

        if (idx == frameCount - 1) {
            XXSDWebImageFrame *frame = [XXSDWebImageFrame frameWithImage:previousImage duration:avgDuration * repeatCount];
            [frames addObject:frame];
        }
    }];
#endif
    return frames;
}

+ (UIImageOrientation)imageOrientationFromEXIFOrientation:(NSInteger)exifOrientation
{
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    switch (exifOrientation) {
        case 1:
            imageOrientation = UIImageOrientationUp;
            break;
        case 3:
            imageOrientation = UIImageOrientationDown;
            break;
        case 8:
            imageOrientation = UIImageOrientationLeft;
            break;
        case 6:
            imageOrientation = UIImageOrientationRight;
            break;
        case 2:
            imageOrientation = UIImageOrientationUpMirrored;
            break;
        case 4:
            imageOrientation = UIImageOrientationDownMirrored;
            break;
        case 5:
            imageOrientation = UIImageOrientationLeftMirrored;
            break;
        case 7:
            imageOrientation = UIImageOrientationRightMirrored;
            break;
        default:
            break;
    }
    return imageOrientation;
}

+ (NSInteger)exifOrientationFromImageOrientation:(UIImageOrientation)imageOrientation
{
    NSInteger exifOrientation = 1;
    switch (imageOrientation) {
        case UIImageOrientationUp:
            exifOrientation = 1;
            break;
        case UIImageOrientationDown:
            exifOrientation = 3;
            break;
        case UIImageOrientationLeft:
            exifOrientation = 8;
            break;
        case UIImageOrientationRight:
            exifOrientation = 6;
            break;
        case UIImageOrientationUpMirrored:
            exifOrientation = 2;
            break;
        case UIImageOrientationDownMirrored:
            exifOrientation = 4;
            break;
        case UIImageOrientationLeftMirrored:
            exifOrientation = 5;
            break;
        case UIImageOrientationRightMirrored:
            exifOrientation = 7;
            break;
        default:
            break;
    }
    return exifOrientation;

}


#pragma mark - Helper Function
#if SD_UIKIT || SD_WATCH

static NSUInteger gcd(NSUInteger a, NSUInteger b)
{
    NSUInteger c;
    while (a != 0) {
        c = a;
        a = b % a;
        b = c;
    }
    return b;
}

static NSUInteger gcdArray(size_t const count, NSUInteger const *const values)
{
    if (count == 0) {
        return 0;
    }
    NSUInteger result = values[0];
    for (size_t i = 0; i < count; i++) {
        result = gcd(values[i], result);
    }
    return result;
}
#endif

@end