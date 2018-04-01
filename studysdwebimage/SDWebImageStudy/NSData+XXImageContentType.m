//
//  NSData+XXImageContentType.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/3/30.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "NSData+XXImageContentType.h"

#if XXSD_MAC
#import <CoreServices/CoreServices.h>
#else
#import <MobileCoreServices/MobileCoreServices.h>
#endif

#ifndef kSDUTTypeWebP
#define kSDUTTypeWebP ((__bridge CFStringRef)@"public.webp")
#endif
#ifndef kSDUTTypeHEIC
#define kSDUTTypeHEIC ((__bridge CFStringRef)@"public.heic")
#endif

@implementation NSData (XXImageContentType)
+ (XXSDImageFormat)xxsd_imageFormatForImageData:(nullable NSData *)data
{
    if (!data) {
        return XXSDImageFormatUndefined;
    }

    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return XXSDImageFormatJPEG;
        case 0x89:
            return XXSDImageFormatPNG;
        case 0x47:
            return XXSDImageFormatGIF;
        case 0x49:
        case 0x4D:
            return XXSDImageFormatTIFF;
        case 0x52:
            if (data.length >= 12) {
                //RIFF....WEBP
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
                if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                    return XXSDImageFormatWebP;
                }
            }
            break;
        case 0x00:{
            if (data.length >= 12) {
                //....ftypheic ....ftypheix ....ftyphevc ....ftyphevx
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(4, 8)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"ftypheic"]
                        || [testString isEqualToString:@"ftypheix"]
                        || [testString isEqualToString:@"ftyphevc"]
                        || [testString isEqualToString:@"ftyphevx"]) {
                    return XXSDImageFormatHEIC;
                }
            }
            break;
        }
    }
    return XXSDImageFormatUndefined;
}

+ (nonnull CFStringRef)xxsd_UTTypeFromSDImageFormat:(XXSDImageFormat)format
{
    CFStringRef UTType;
    switch (format) {
        case XXSDImageFormatJPEG:
            UTType = kUTTypeJPEG;
            break;
        case XXSDImageFormatPNG:
            UTType = kUTTypePNG;
            break;
        case XXSDImageFormatGIF:
            UTType = kUTTypeGIF;
            break;
        case XXSDImageFormatTIFF:
            UTType = kUTTypeTIFF;
            break;
        case XXSDImageFormatWebP:
            UTType = kSDUTTypeWebP;
            break;
        case XXSDImageFormatHEIC:
            UTType = kSDUTTypeHEIC;
            break;
        default:
            UTType = kUTTypePNG;
            break;
    }
    return UTType;
}

@end
