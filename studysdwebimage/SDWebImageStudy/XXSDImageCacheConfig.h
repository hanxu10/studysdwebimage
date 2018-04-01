//
//  XXSDImageCacheConfig.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCompat.h"

@interface XXSDImageCacheConfig : NSObject

/**
   *解压(下载和缓存的)图像可以提高性能，但会消耗大量内存。
   *默认为YES。 如果由于内存消耗过多而导致崩溃，请将其设置为NO。
  */
@property (nonatomic, assign) BOOL shouldDecompressImages;

/**
  * 禁用iCloud备份[默认为YES]
  */
@property (nonatomic, assign) BOOL shouldDisableiCloud;

/**
  * 使用内存缓存[默认为YES]
  */
@property (nonatomic, assign) BOOL shouldCacheImagesInMemory;

/**
   *从磁盘读取缓存时的读取选项。
   *默认为0.您可以将其设置为“NSDataReadingMappedIfSafe”以提高性能。
  */
@property (nonatomic, assign) NSDataReadingOptions diskCacheReadingOptions;

/**
   *将缓存写入磁盘时的写入选项。
   *默认为`NSDataWritingAtomic`。 您可以将其设置为“NSDataWritingWithoutOverwriting”以防止覆盖现有文件。
  */
@property (nonatomic, assign) NSDataWritingOptions diskCacheWritingOptions;

/**
  * 将图像保存在缓存中的最长时间，以秒为单位。
  */
@property (nonatomic, assign) NSInteger maxCacheAge;

/**
  * 缓存的最大大小，以字节为单位。
  */
@property (nonatomic, assign) NSUInteger maxCacheSize;

@end
