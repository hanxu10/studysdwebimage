//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"
#import "NSData+XXImageContentType.h"

@interface UIImage (XXMultiFormat)

@property (nonatomic, assign) NSUInteger xxsd_imageLoopCount;

+ (nullable UIImage *)xxsd_imageWithData:(nullable NSData *)data;
- (nullable NSData *)xxsd_imageData;
- (nullable NSData *)xxsd_imageDataAsFormat:(XXSDImageFormat)imageFormat;
@end