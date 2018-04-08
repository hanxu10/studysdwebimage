//
//  XXSDWebImageCompat.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/3/30.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"
#import "UIImage+XXMultiFormat.h"

NSString *const XXSDWebImageErrorDomain = @"XXSDWebImageErrorDomain";

inline UIImage *XXSDScaledImageForKey(NSString *key, UIImage *image)
{
    if (!image) {
        return nil;
    }
    
#if XXSD_MAC
    return image;
#elif XXSD_UIKIT || XXSD_WATCH
    if (image.images.count) {
        NSMutableArray<UIImage *> *scaledImages = [NSMutableArray array];
        
        for (UIImage *tempImage in image.images) {
            [scaledImages addObject:XXSDScaledImageForKey(key, tempImage)];
        }
        
        UIImage *animatedImage = [UIImage animatedImageWithImages:scaledImages duration:image.duration];
        if (animatedImage) {
            animatedImage.xxsd_imageLoopCount = image.xxsd_imageLoopCount;
        }
        return animatedImage;
    } else {
#if XXSD_WATCH
        if ([[WKInterfaceDevice currentDevice] respondsToSelector:@selector(screenScale)]) {
#elif XXSD_UIKIT
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
#endif
            CGFloat scale = 1;
            if (key.length >= 8) {
                NSRange range = [key rangeOfString:@"@2x."];
                if (range.location != NSNotFound) {
                    scale = 2.0;
                }
                
                range = [key rangeOfString:@"@3x."];
                if (range.location != NSNotFound) {
                    scale = 3.0;
                }
            }
            
            UIImage *scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
            image = scaledImage;
        }
        return image;
    }
#endif
}
