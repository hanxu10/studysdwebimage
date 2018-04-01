//
//  NSData+XXImageContentType.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/3/30.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCompat.h"

typedef NS_ENUM(NSInteger, XXSDImageFormat) {
    XXSDImageFormatUndefined = -1,
    XXSDImageFormatJPEG = 0,
    XXSDImageFormatPNG,
    XXSDImageFormatGIF,
    XXSDImageFormatTIFF,
    XXSDImageFormatWebP,
    XXSDImageFormatHEIC,
};


@interface NSData (XXImageContentType)

+ (XXSDImageFormat)xxsd_imageFormatForImageData:(nullable NSData *)data;

+ (nonnull CFStringRef)xxsd_UTTypeFromSDImageFormat:(XXSDImageFormat)format;

@end
