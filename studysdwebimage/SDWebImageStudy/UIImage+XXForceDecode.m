//
//  UIImage+XXForceDecode.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIImage+XXForceDecode.h"
#import "XXSDWebImageCodersManager.h"

@implementation UIImage (XXForceDecode)

+ (UIImage *)xx_decodedImageWithImage:(UIImage *)image
{
    if (!image) {
        return nil;
    }
    NSData *tempData;
    return [[XXSDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&tempData options:@{XXSDWebImageCoderScaleDownLargeImageKey : @(NO)}];
}

+ (UIImage *)xx_decodedAndScaledDownImageWithImage:(UIImage *)image
{
    if (!image) {
        return nil;
    }
    NSData *tempData;
    return [[XXSDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&tempData options:@{XXSDWebImageCoderScaleDownLargeImageKey : @(YES)}];
}

@end
