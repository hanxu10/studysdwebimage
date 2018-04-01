//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageCoder.h"

NSString *const XXSDWebImageCoderScaleDownLargeImageKey = @"XXSDWebImageCoderScaleDownLargeImageKey";

CGColorSpaceRef XXSDCGColorSpaceGetDeviceRGB()
{
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}


BOOL XXSDCGImageRefContainsAlpha(_Nullable CGImageRef imageRef)
{
    if (!imageRef) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone || alphaInfo == kCGImageAlphaNoneSkipFirst || alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}

