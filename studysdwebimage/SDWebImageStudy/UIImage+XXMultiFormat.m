//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "UIImage+XXMultiFormat.h"

#import "objc/runtime.h"
#import "XXSDWebImageCodersManager.h"


@implementation UIImage (XXMultiFormat)

#if XXSD_MAC

- (NSUInteger)sd_imageLoopCount {
    NSUInteger imageLoopCount = 0;
    for (NSImageRep *rep in self.representations) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            NSBitmapImageRep *bitmapRep = (NSBitmapImageRep *)rep;
            imageLoopCount = [[bitmapRep valueForProperty:NSImageLoopCount] unsignedIntegerValue];
            break;
        }
    }
    return imageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)sd_imageLoopCount {
    for (NSImageRep *rep in self.representations) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            NSBitmapImageRep *bitmapRep = (NSBitmapImageRep *)rep;
            [bitmapRep setProperty:NSImageLoopCount withValue:@(sd_imageLoopCount)];
            break;
        }
    }
}

#else

- (NSUInteger)xxsd_imageLoopCount
{
    NSUInteger imageLoopCount = 0;
    NSNumber *value = objc_getAssociatedObject(self, @selector(xxsd_imageLoopCount));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageLoopCount = value.unsignedIntegerValue;
    }
    return imageLoopCount;
}

- (void)setXxsd_imageLoopCount:(NSUInteger)xxsd_imageLoopCount
{
    NSNumber *value = @(xxsd_imageLoopCount);
    objc_setAssociatedObject(self, @selector(xxsd_imageLoopCount), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
#endif

+ (nullable UIImage *)xxsd_imageWithData:(nullable NSData *)data
{
    return nil;
}

@end
