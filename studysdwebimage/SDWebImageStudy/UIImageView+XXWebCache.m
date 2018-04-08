//
//  UIImageView+XXWebCache.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIImageView+XXWebCache.h"

#if XXSD_UIKIT || XXSD_MAC

#import <objc/runtime.h>
#import "UIView+XXWebCacheOperation.h"
#import "UIView+XXWebCache.h"

@implementation UIImageView (XXWebCache)

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
{
    [self xxsd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder
{
    [self xxsd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(XXSDWebImageOptions)options
{
    [self xxsd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(XXSDWebImageOptions)options completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(XXSDWebImageOptions)options
                  progress:(nullable XXSDWebImageDownloaderProgressBlock)progressBlock
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_internalSetImageWithURL:url
                      placeholderImage:placeholder
                               options:options
                          operationKey:nil
                         setImageBlock:nil
                              progress:progressBlock
                             completed:completedBlock];
}

#if XXSD_UIKIT

#pragma mark - Animation of multiple images

- (void)xxsd_setAnimationImagesWithURLs:(NSArray<NSURL *> *)arrayOfURLs
{
    [self xxsd_cancelCurrentAnimationImagesLoad];
    NSPointerArray *operationsArray = [self xxsd_animationOperationArray];
    
    [arrayOfURLs enumerateObjectsUsingBlock:^(NSURL * logoImageURL, NSUInteger idx, BOOL * _Nonnull stop) {
        __weak typeof(self) wself = self;
        id <XXSDWebImageOperation> operation = [[XXSDWebImageManager sharedManager] loadImageWithURL:logoImageURL options:0 progress:nil completed:^(UIImage *image, NSData *data, NSError *error, XXSDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            dispatch_main_async_safe(^{
                [sself stopAnimating];
                if (sself && image) {
                    NSMutableArray<UIImage *> *currentImages = [[sself animationImages] mutableCopy];
                    if (!currentImages) {
                        currentImages = [NSMutableArray array];
                    }
                    while (currentImages.count < idx) {
                        [currentImages addObject:image];
                    }
                    
                    currentImages[idx] = image;
                    
                    sself.animationImages = currentImages;
                    [sself setNeedsLayout];
                }
                [sself startAnimating];
            });
        }];
        @synchronized (self) {
            [operationsArray addPointer:(__bridge void *)operation];
        }
    }];
}

static char animationLoadOperationKey;

- (NSPointerArray *)xxsd_animationOperationArray
{
    @synchronized (self) {
        NSPointerArray *operationsArray = objc_getAssociatedObject(self, &animationLoadOperationKey);
        if (operationsArray) {
            return operationsArray;
        }
        operationsArray = [NSPointerArray weakObjectsPointerArray];
        objc_setAssociatedObject(self, &animationLoadOperationKey, operationsArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operationsArray;
    }
}

- (void)xxsd_cancelCurrentAnimationImagesLoad
{
    NSPointerArray *operationsArray = [self xxsd_animationOperationArray];
    if (operationsArray) {
        @synchronized (self) {
            for (id operation in operationsArray) {
                if ([operation conformsToProtocol:@protocol(XXSDWebImageOperation)]) {
                    [operation cancel];
                }
            }
            operationsArray.count = 0;
        }
    }
}


#endif

@end

#endif


















