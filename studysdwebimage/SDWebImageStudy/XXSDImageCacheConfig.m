//
//  XXSDImageCacheConfig.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDImageCacheConfig.h"

//一周
static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7;

@implementation XXSDImageCacheConfig

- (instancetype)init
{
    if (self = [super init]) {
        _shouldDecompressImages = YES;
        _shouldDisableiCloud = YES;
        _shouldCacheImagesInMemory = YES;
        _diskCacheReadingOptions = 0;
        _diskCacheWritingOptions = NSDataWritingAtomic;
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        _maxCacheAge = 0;
    }
    return self;
}

@end
