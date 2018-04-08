//
//  XXSDImageCache.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDImageCache.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSImage+XXWebCache.h"
#import "XXSDWebImageCodersManager.h"

#define XXLOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define XXUNLOCK(lock) dispatch_semaphore_signal(lock)

FOUNDATION_STATIC_INLINE NSUInteger XXSDCacheCostForImage(UIImage *image)
{
#if XXSD_MAC
    return image.size.height * image.size.width;
#elif XXSD_UIKIT || XXSD_WATCH
    return image.size.height * image.size.width * image.scale * image.scale;
#endif
}

//内存缓存，在内存警告时自动清除缓存并支持弱缓存。
@interface XXSDMemoryCache <KeyType, ObjectType> : NSCache <KeyType, ObjectType>

//strong - weak cache
@property (nonatomic, strong) NSMapTable<KeyType, ObjectType> *weakCache;

//一个锁以保证对`weakCache`线程安全的访问
@property (nonatomic, strong) dispatch_semaphore_t weakCacheLock;

@end

@implementation XXSDMemoryCache

//目前这在macOS上似乎没有用（macOS使用虚拟内存，并且在内存警告时不清除缓存）。 所以我们只在iOS / tvOS平台上覆盖。
//但是将来可能会有更多的选项和这个子类的功能。
#if XXSD_UIKIT
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (instancetype)init
{
    if (self = [super init]) {
        self.weakCache = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        self.weakCacheLock = dispatch_semaphore_create(1);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    //只移除cache，但是保留weak cache
    [super removeAllObjects];
}

- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g
{
    [super setObject:obj forKey:key cost:g];
    if (key && obj) {
        //存储weak cache
        XXLOCK(self.weakCacheLock);
        [self.weakCache setObject:obj forKey:key];
        XXUNLOCK(self.weakCacheLock);
    }
}

- (id)objectForKey:(id)key
{
    id obj = [super objectForKey:key];
    if (key && !obj) {
        XXLOCK(self.weakCacheLock);
        obj = [self.weakCache objectForKey:key];
        XXUNLOCK(self.weakCacheLock);
        if (obj) {
            //同步cache
            NSUInteger cost = 0;
            if ([obj isKindOfClass:[UIImage class]]) {
                cost = XXSDCacheCostForImage(obj);
            }
            [super setObject:obj forKey:key cost:cost];
        }
    }
    return obj;
}

- (void)removeObjectForKey:(id)key
{
    [super removeObjectForKey:key];
    if (key) {
        //移除weak cache
        XXLOCK(self.weakCacheLock);
        [self.weakCache removeObjectForKey:key];
        XXUNLOCK(self.weakCacheLock);
    }
}

- (void)removeAllObjects {
    [super removeAllObjects];
    // Manually remove should also remove weak cache
    XXLOCK(self.weakCacheLock);
    [self.weakCache removeAllObjects];
    XXUNLOCK(self.weakCacheLock);
}

#endif

@end

@interface XXSDImageCache ()

@property (nonatomic, strong) XXSDMemoryCache *memCache;
@property (nonatomic, strong) NSString *diskCachePath;
@property (nonatomic, strong) NSMutableArray<NSString *> *customPaths;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation XXSDImageCache

#pragma mark - Singleton, init, dealloc

+ (instancetype)sharedImageCache
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init
{
    return [self initWithNamespace:@"default"];
}

- (instancetype)initWithNamespace:(NSString *)ns
{
    NSString *path = [self makeDiskCachePath:ns];
    return [self initWithNamespace:ns diskCacheDirectory:path];
}

- (instancetype)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory
{
    if (self = [super init]) {
        NSString *fullNamespace = [@"com.xuxu.XXSDWebImageCache." stringByAppendingString:ns];
        
        _ioQueue = dispatch_queue_create("com.xuxu.XXSDWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        _config = [[XXSDImageCacheConfig alloc] init];
        
        _memCache = [[XXSDMemoryCache alloc] init];
        _memCache.name = fullNamespace;
        
        if (directory) {
            _diskCachePath = [directory stringByAppendingPathComponent:fullNamespace];
        } else {
            NSString *path = [self makeDiskCachePath:ns];
            _diskCachePath = path;
        }
        
        dispatch_sync(_ioQueue, ^{
            self.fileManager = [NSFileManager new];
        });
        
#if XXSD_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteOldFiles) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundDeleteOldFiles) name:UIApplicationDidEnterBackgroundNotification object:nil];
#endif
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cache paths

- (void)addReadOnlyCachePath:(NSString *)path
{
    if (!self.customPaths) {
        self.customPaths = [NSMutableArray array];
    }
    
    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}

- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path
{
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

- (NSString *)defaultCachePathForKey:(NSString *)key
{
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

- (NSString *)cachedFileNameForKey:(NSString *)key
{
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}

- (NSString *)makeDiskCachePath:(NSString *)fullNamespace
{
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:fullNamespace];
}

#pragma mark - 存储操作

- (void)storeImage:(UIImage *)image
            forKey:(NSString *)key
        completion:(XXSDWebImageNoParamsBlock)completionBlock
{
    [self storeImage:image imageData:nil forKey:key toDisk:YES completion:completionBlock];
}

- (void)storeImage:(UIImage *)image
            forKey:(NSString *)key
            toDisk:(BOOL)toDisk
        completion:(XXSDWebImageNoParamsBlock)completionBlock
{
    [self storeImage:image imageData:nil forKey:key toDisk:toDisk completion:completionBlock];
}

- (void)storeImage:(UIImage *)image
         imageData:(NSData *)imageData
            forKey:(NSString *)key
            toDisk:(BOOL)toDisk
        completion:(XXSDWebImageNoParamsBlock)completionBlock
{
    if (!image || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    
    //如果enable了内存缓存
    if (self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = XXSDCacheCostForImage(image);
        [self.memCache setObject:image forKey:key cost:cost];
    }
    
    if (toDisk) {
        dispatch_async(self.ioQueue, ^{
            @autoreleasepool {
                NSData *data = imageData;
                if (!data && image) {
                    //如果我们没有任何数据来检测图像格式，请检查它是否包含alpha通道以使用PNG或JPEG格式
                    XXSDImageFormat format;
                    if (XXSDCGImageRefContainsAlpha(image.CGImage)) {
                        format = XXSDImageFormatPNG;
                    } else {
                        format = XXSDImageFormatJPEG;
                    }
                    data = [[XXSDWebImageCodersManager sharedInstance] encodedDataWithImage:image format:format];
                }
                [self _storeImageDataToDisk:data forKey:key];
            }
            
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        });
    } else {
        if (completionBlock) {
            completionBlock();
        }
    }
}

- (void)storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key
{
    if (!imageData || !key) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self _storeImageDataToDisk:imageData forKey:key];
    });
}

- (void)_storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key
{
    if (!imageData || !key) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:_diskCachePath]) {
        [self.fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    //根据key获取cache path
    NSString *cachePathForKey = [self defaultCachePathForKey:key];
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    
    [imageData writeToURL:fileURL options:self.config.diskCacheWritingOptions error:nil];
    
    if (self.config.shouldDisableiCloud) {//禁用iCloud备份
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

#pragma mark - 查询和获取操作

- (void)diskImageExistsWithKey:(NSString *)key
                    completion:(XXSDWebImageCheckCacheCompletionBlock)completionBlock
{
    dispatch_async(self.ioQueue, ^{
        BOOL exists = [self _diskImageDataExistsWithKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskImageDataExistsWithKey:(NSString *)key
{
    if (!key) {
        return NO;
    }
    __block BOOL exists = NO;
    dispatch_sync(self.ioQueue, ^{
        exists = [self _diskImageDataExistsWithKey:key];
    });
    return exists;
}

// Make sure to call form io queue by caller
- (BOOL)_diskImageDataExistsWithKey:(NSString *)key
{
    if (!key) {
        return NO;
    }
    BOOL exists = [self.fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
    if (!exists) {
        exists = [self.fileManager fileExistsAtPath:[self defaultCachePathForKey:key].stringByDeletingPathExtension];
    }

    return exists;
}

- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key
{
    return [self.memCache objectForKey:key];
}

- (UIImage *)imageFromDiskCacheForKey:(NSString *)key
{
    UIImage *diskImage = [self diskImageForKey:key];
    if (diskImage && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = XXSDCacheCostForImage(diskImage);
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }
    return diskImage;
}

- (UIImage *)imageFromCacheForKey:(NSString *)key
{
    //先检查内存cache
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }
    
    //再检查磁盘cache
    image = [self imageFromDiskCacheForKey:key];
    return image;
}

- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key
{
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }
    
    data = [NSData dataWithContentsOfFile:defaultPath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }
    
    NSArray<NSString *> *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
        if (imageData) {
            return imageData;
        }
        
        imageData = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
        if (imageData) {
            return imageData;
        }
    }
    
    return nil;
}

- (UIImage *)diskImageForKey:(NSString *)key
{
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:key];
    return [self diskImageForKey:key data:data];
}

- (UIImage *)diskImageForKey:(NSString *)key data:(NSData *)data
{
    if (data) {
        UIImage *image = [[XXSDWebImageCodersManager sharedInstance] decodedImageWithData:data];
        image = [self scaledImageForKey:key image:image];
        if (self.config.shouldDecompressImages) {
            image = [[XXSDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&data options:@{XXSDWebImageCoderScaleDownLargeImageKey : @(NO)}];
        }
        return image;
    } else {
        return nil;
    }
}

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image
{
    return XXSDScaledImageForKey(key, image);
}

- (NSOperation *)queryCacheOperationForKey:(NSString *)key done:(XXSDCacheQueryCompletedBlock)doneBlock
{
    return [self queryCacheOperationForKey:key options:0 done:doneBlock];
}

- (NSOperation *)queryCacheOperationForKey:(NSString *)key options:(XXSDImageCacheOptions)options done:(XXSDCacheQueryCompletedBlock)doneBlock
{
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, XXSDImageCacheTypeNone);
        }
        return nil;
    }
    
    //首先检查内存缓存
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    BOOL shouldQueryMemoryOnly = (image && !(options & XXSDImageCacheQueryDataWhenInMemory));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, XXSDImageCacheTypeMemory);
        }
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    void (^queryDiskBlock)(void) = ^ {
        if (operation.isCancelled) {
            //如果cancelled，不调用completion
            return;
        }
        
        @autoreleasepool {
            NSData *diskData = [self diskImageDataBySearchingAllPathsForKey:key];
            UIImage *diskImage;
            XXSDImageCacheType cacheType = XXSDImageCacheTypeDisk;
            if (image) {
                diskImage = image;
                cacheType = XXSDImageCacheTypeMemory;
            } else if (diskData) {
                //仅在内存缓存未命中的情况下解码图像数据
                diskImage = [self diskImageForKey:key data:diskData];
                if (diskImage && self.config.shouldCacheImagesInMemory) {
                    NSUInteger cost = XXSDCacheCostForImage(diskImage);
                    [self.memCache setObject:diskImage forKey:key cost:cost];
                }
            }
            
            if (doneBlock) {
                if (options & XXSDImageCacheQueryDiskSync) {
                    doneBlock(diskImage, diskData, cacheType);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock(diskImage, diskData, cacheType);
                    });
                }
            }
        }
    };
    
    if (options & XXSDImageCacheQueryDiskSync) {
        queryDiskBlock();
    } else {
        dispatch_async(self.ioQueue, queryDiskBlock);
    }
    
    return operation;
}

#pragma mark - 移除操作

- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable XXSDWebImageNoParamsBlock)completion
{
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable XXSDWebImageNoParamsBlock)completion
{
    if (key == nil) {
        return;
    }
    
    if (self.config.shouldCacheImagesInMemory) {
        [self.memCache removeObjectForKey:key];
    }
    
    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [self.fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion){
        completion();
    }
}

#pragma mark - 内存缓存设置

- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost
{
    self.memCache.totalCostLimit = maxMemoryCost;
}

- (NSUInteger)maxMemoryCost
{
    return self.memCache.totalCostLimit;
}

- (NSUInteger)maxMemoryCountLimit
{
    return self.memCache.countLimit;
}

- (void)setMaxMemoryCountLimit:(NSUInteger)maxCountLimit
{
    self.memCache.countLimit = maxCountLimit;
}

#pragma mark - 缓存清理操作

- (void)clearMemory
{
    [self.memCache removeAllObjects];
}

- (void)clearDiskOnCompletion:(XXSDWebImageNoParamsBlock)completion
{
    dispatch_async(self.ioQueue, ^{
        [self.fileManager removeItemAtPath:self.diskCachePath error:nil];
        [self.fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)deleteOldFiles
{
    [self deleteOldFilesWithCompletionBlock:nil];
}

- (void)deleteOldFilesWithCompletionBlock:(XXSDWebImageNoParamsBlock)completionBlock
{
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:resourceKeys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.config.maxCacheAge];
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
            NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
            
            if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }
            
            //存储对此文件的引用并说明其总大小。
            NSNumber *totalAllcoatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += totalAllcoatedSize.unsignedIntegerValue;
            cacheFiles[fileURL] = resourceValues;
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [self.fileManager removeItemAtURL:fileURL error:nil];
        }
        
        //如果我们的剩余磁盘缓存超出配置的最大大小，执行基于大小的清理。 我们先删除最早的文件。
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            //将最大缓存大小的一半作为这个清理过程的目标。
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;
            
            //按剩余缓存文件的最后修改时间排序（最老的排在第一个）。
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
            }];
            
            for (NSURL *fileURL in sortedFiles) {
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
        
    });
}

#if XXSD_UIKIT

- (void)backgroundDeleteOldFiles
{
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        //通过标记停止或彻底结束任务来清理任何未完成的任务业务。
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

#endif

#pragma mark - Cache info

- (NSUInteger)getSize
{
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [self.fileManager attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

- (NSUInteger)getDiskCount
{
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
        count = fileEnumerator.allObjects.count;
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(XXSDWebImageCalculateSizeBlock)completionBlock
{
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount++;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end

















