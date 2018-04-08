//
//  UIImage+XXGIF.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIImage+XXGIF.h"
#import "XXSDWebImageGIFCoder.h"
#import "NSImage+XXWebCache.h"

@implementation UIImage (XXGIF)

+ (UIImage *)xxsd_animatedGIFWithData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    return [[XXSDWebImageGIFCoder sharedCoder] decodedImageWithData:data];
}

- (BOOL)xxsd_isGIF
{
    return self.images != nil;
}

@end
