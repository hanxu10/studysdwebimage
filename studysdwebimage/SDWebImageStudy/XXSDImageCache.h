//
//  XXSDImageCache.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCompat.h"
#import "XXSDImageCacheConfig.h"

typedef NS_ENUM(NSUInteger, XXSDImageCacheType) {
    /**
     * 该图像不在SDWebImage缓存，是从网上下载。
     */
    XXSDImageCacheTypeNone,
    /**
     * 该image是从磁盘缓存中获取的。
     */
    XXSDImageCacheTypeDisk,
    /**
     * 该image是从内存缓存中获取的。
     */
    XXSDImageCacheTypeMemory,
};

typedef NS_OPTIONS(NSUInteger, XXSDImageCacheOptions) {
    /**
     * 默认情况下，当图像缓存在内存中时，我们不会查询磁盘数据。 该掩码可以强制同时查询磁盘数据。
     */
    XXSDImageCacheQueryDataWhenInMemory = 1 << 0,
    /**
     * 默认情况下，我们同步查询内存缓存，异步查询磁盘缓存。 该掩码可以强制同步查询磁盘缓存。
     */
    XXSDImageCacheQueryDiskSync = 1 << 1,
};

typedef void(^XXSDCacheQueryCompletedBlock) (UIImage *image, NSData *data, XXSDImageCacheType cacheType);

typedef void(^XXSDWebImageCheckCacheCompletionBlock) (BOOL isIncache);

typedef void(^XXSDWebImageCalculateSizeBlock) (NSUInteger fileCount, NSUInteger totalSize);

/**
  * SDImageCache维护一个内存缓存和一个可选的磁盘缓存。 磁盘缓存写入操作被执行
  * 异步，因此它不会给UI添加不必要的延迟。
  */
@interface XXSDImageCache : NSObject

/**
  * 缓存配置对象 - 存储各种设置
  */
@property (nonatomic, strong, readonly) XXSDImageCacheConfig *config;

/**
   *内存中图像缓存的最大“总成本”。 成本函数是存储器中保存的像素数。
  */
@property (nonatomic, assign) NSUInteger maxMemoryCost;

/**
   *缓存应该容纳的最大对象数量。
  */
@property (nonatomic, assign) NSUInteger maxMemoryCountLimit;

#pragma mark - 单例和初始化

+ (instancetype)sharedImageCache;

/**
  * 使用特定的命名空间初始化一个新的缓存存储
  *
  * @参数ns用于此缓存存储的名称空间
  */
- (instancetype)initWithNamespace:(NSString *)ns;

- (instancetype)initWithNamespace:(NSString *)ns
               diskCacheDirectory:(NSString *)directory NS_DESIGNATED_INITIALIZER;

#pragma mark - Cache pahts

- (NSString *)makeDiskCachePath:(NSString *)fullNamespace;

/**
  * 添加一个只读缓存路径来搜索由SDImageCache预缓存的图像
  * 如果您想要将预先加载的图像与您的应用程序捆绑在一起，则很有用
  *
  * @param path 用于此只读缓存路径的路径
  */
- (void)addReadOnlyCachePath:(NSString *)path;

#pragma mark - 存储操作

/**
  * 将图像异步存储到指定密钥的内存和磁盘缓存中。
  *
  * @param image 要存储的图像
  * @param key 唯一的图像缓存键，通常是图像的绝对URL
  * @param completionBlock 操作完成后执行的块
  */
- (void)storeImage:(UIImage *)image
            forKey:(NSString *)key
        completion:(XXSDWebImageNoParamsBlock)completionBlock;

/**
  * 将图像异步存储到指定密钥的内存和磁盘缓存中。
  *
  * @param image 要存储的图像
  * @param key 唯一的图像缓存键，通常是图像的绝对URL
  * @param toDisk 如果是，则将映像存储到磁盘缓存
  * @param completionBlock 操作完成后执行的块
  */
- (void)storeImage:(UIImage *)image
            forKey:(NSString *)key
            toDisk:(BOOL)toDisk
        completion:(XXSDWebImageNoParamsBlock)completionBlock;

/**
  *将图像异步存储到指定密钥的内存和磁盘缓存中。
  *
  * @param image 要存储的图像
  * @param imageData 由服务器返回的图像数据，此表示将用于磁盘存储，而不是将给定的图像对象转换为可存储/压缩的图像格式，以节省质量和CPU
  * @param key 唯一的图像缓存键，通常是图像的绝对URL
  * @param toDisk 如果是，则将映像存储到磁盘缓存
  * @param completionBlock 操作完成后执行的块
  */
- (void)storeImage:(UIImage *)image
         imageData:(NSData *)imageData
            forKey:(NSString *)key
            toDisk:(BOOL)toDisk
        completion:(XXSDWebImageNoParamsBlock)completionBlock;

/**
  * 将image NSData同步存储在给定密钥的磁盘缓存中。
  *
  * @warning 此方法是同步的，请确保从ioQueue调用它
  *
  * @param imageData 要存储的图像数据
  * @param key 唯一的图像缓存键，通常是图像的绝对URL
  */
- (void)storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key;

#pragma mark - 队列和取操作
/**
  * 异步检查图像是否存在于磁盘缓存中（不加载图像）
  *
  * @param key 描述url的key
  * @param completionBlock 当检查完成时要执行的块。
  * @note 完成块将始终在主队列上执行
  */
- (void)diskImageExistsWithKey:(NSString *)key completion:(XXSDWebImageCheckCacheCompletionBlock)completionBlock;

/**
  * 同步检查图像数据是否存在于磁盘缓存中（不加载图像）
  *
  * @param key 描述url的key
  */
- (BOOL)diskImageDataExistsWithKey:(NSString *)key;

/**
  * 异步查询缓存并在完成时调用完成的操作。
  *
  * @param key 用于存储想要的图像的唯一键
  * @param doneBlock 完成块。 如果操作被取消，将不会被调用
  *
  * @返回包含缓存操作的NSOperation实例
  */
- (NSOperation *)queryCacheOperationForKey:(NSString *)key done:(XXSDCacheQueryCompletedBlock)doneBlock;

/**
  * 异步查询缓存并在完成时调用完成的操作。
  *
  * @param key 用于存储想要的图像的唯一键
  * @param options 用于指定用于此缓存查询的选项的掩码
  * @param doneBlock 完成块。 如果操作被取消，将不会被调用
  *
  * @返回包含缓存操作的NSOperation实例
  */
- (NSOperation *)queryCacheOperationForKey:(NSString *)key options:(XXSDImageCacheOptions)options done:(XXSDCacheQueryCompletedBlock)doneBlock;

/**
  * 同步查询内存缓存。
  *
  * @param key 用于存储图像的唯一键
  */
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key;

/**
  * 同步查询磁盘缓存。
  *
  * @param key 用于存储图像的唯一键
  */
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key;

/**
  * 检查内存缓存后，同步查询缓存（内存和/或磁盘）。
  *
  * @param key 用于存储图像的唯一键
  */
- (UIImage *)imageFromCacheForKey:(NSString *)key;

#pragma mark - cache清除操作

/**
  * 清除所有内存缓存的图像
  */
- (void)clearMemory;

/**
  * 异步清除所有磁盘缓存的图像。 非阻塞方法 - 立即返回。
  * @param completion 缓存过期完成后应执行的块（可选）
  */
- (void)clearDiskOnCompletion:(XXSDWebImageNoParamsBlock)completion;

/**
  * 异步从磁盘中删除所有过期的缓存图像。 非阻塞方法 - 立即返回。
  * @param completionBlock 缓存过期完成后应执行的块（可选）
  */
- (void)deleteOldFilesWithCompletionBlock:(XXSDWebImageNoParamsBlock)completionBlock;

#pragma mark - Cache info
/**
  * 获取磁盘缓存使用的大小
  */
- (NSUInteger)getSize;

/**
  * 获取磁盘缓存中的图像数量
  */
- (NSUInteger)getDiskCount;

/**
  * 异步计算磁盘缓存的大小。
  */
- (void)calculateSizeWithCompletionBlock:(XXSDWebImageCalculateSizeBlock)completionBlock;

#pragma mark - Cache Paths

/**
  * 获取特定key的缓存路径（需要缓存路径根文件夹）
  *
  * @param key  (可以使用cacheKeyForURL从url中获得)
  * @param path 缓存路径根文件夹
  *
  * @return 缓存路径
  */
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;

/**
  * 获取某个key的默认缓存路径
  *
  * @param key  (可以使用cacheKeyForURL从url中获得)
  *
  * @return 默认的缓存路径
  */
- (NSString *)defaultCachePathForKey:(NSString *)key;

@end
