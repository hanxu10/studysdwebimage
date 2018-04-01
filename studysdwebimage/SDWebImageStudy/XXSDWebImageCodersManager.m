//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageCodersManager.h"
#import "XXSDWebImageImageIOCoder.h"
#import "XXSDWebImageGIFCoder.h"
#ifdef SD_WEBP
#import "XXSDWebImageWebPCoder.h"
#endif

@interface XXSDWebImageCodersManager ()

@property (nonatomic, strong) NSMutableArray<XXSDWebImageCoder> *mutableCoders;
@property (nonatomic, strong) dispatch_queue_t mutableCodersAccessQueue;

@end

@implementation XXSDWebImageCodersManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _mutableCoders = [@[[XXSDWebImageImageIOCoder sharedCoder]] mutableCopy];
#ifdef SD_WEBP
        [_mutableCoders addObject:[SDWebImageWebPCoder sharedCoder]];
#endif
        _mutableCodersAccessQueue = dispatch_queue_create("com.xuxu.XXSDWebImageCodersManager", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - Coder IO operations

- (void)addCoder:(id <XXSDWebImageCoder>)coder
{
    if ([coder conformsToProtocol:@protocol(XXSDWebImageCoder)]) {
        dispatch_barrier_sync(self.mutableCodersAccessQueue, ^{
            [self.mutableCoders addObject:coder];
        });
    }
}

- (void)removeCoder:(nonnull id <XXSDWebImageCoder>)coder
{
    dispatch_barrier_sync(self.mutableCodersAccessQueue, ^{
        [self.mutableCoders removeObject:coder];
    });
}

- (NSArray<XXSDWebImageCoder> *)coders
{
    __block NSArray<XXSDWebImageCoder> *sortedCoders = nil;
    dispatch_sync(self.mutableCodersAccessQueue, ^{
        sortedCoders = (NSArray<XXSDWebImageCoder> *)[[[self.mutableCoders copy] reverseObjectEnumerator] allObjects];
    });
    return sortedCoders;
}

- (void)setCoders:(NSArray<XXSDWebImageCoder> *)coders {
    dispatch_barrier_sync(self.mutableCodersAccessQueue, ^{
        self.mutableCoders = [coders mutableCopy];
    });
}

#pragma mark - XXSDWebImageCoder

- (BOOL)canDecodeFromData:(nullable NSData *)data
{
    for (id<XXSDWebImageCoder> coder in self.coders) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canEncodeToFormat:(XXSDImageFormat)format
{
    for (id<XXSDWebImageCoder> coder in self.coders) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}

- (nullable UIImage *)decodedImageWithData:(nullable NSData *)data
{
    if (!data) {
        return nil;
    }
    for (id<XXSDWebImageCoder> coder in self.coders) {
        if ([coder canDecodeFromData:data]) {
            return [coder decodedImageWithData:data];
        }
    }
    return nil;
}

- (nullable UIImage *)decompressedImageWithImage:(nullable UIImage *)image data:(NSData *_Nullable *_Nonnull)data options:(nullable NSDictionary<NSString *, NSObject *> *)optionsDict
{
    if (!image) {
        return nil;
    }
    
    for (id<XXSDWebImageCoder> coder in self.coders) {
        if ([coder canDecodeFromData:*data]) {
            return [coder decompressedImageWithImage:image data:data options:optionsDict];
        }
    }
    return nil;
}


- (nullable NSData *)encodedDataWithImage:(nullable UIImage *)image format:(XXSDImageFormat)format
{
    if (!image) {
        return nil;
    }
    for (id<XXSDWebImageCoder> coder in self.coders) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format];
        }
    }
    return nil;
}

@end
