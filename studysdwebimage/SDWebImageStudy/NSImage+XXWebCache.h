//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_MAC

#import <Cocoa/Cocoa.h>

@interface NSImage (XXWebCache)

- (CGImageRef)CGImage;
- (NSArray<NSImage *> *)images;
- (BOOL)isGIF;

@end

#endif