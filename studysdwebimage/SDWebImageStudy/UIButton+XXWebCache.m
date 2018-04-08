//
//  UIButton+XXWebCache.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIButton+XXWebCache.h"

#if XXSD_UIKIT
#import <objc/runtime.h>
#import "UIView+XXWebCache.h"
#import "UIView+XXWebCacheOperation.h"

static char imageURLStorageKey;

typedef NSMutableDictionary<NSString *, NSURL *> XXSDStateImageURLDictionary;

static inline NSString *imageURLKeyForState(UIControlState state)
{
    return [NSString stringWithFormat:@"image_%lu", (unsigned long)state];
}

static inline NSString * backgroundImageURLKeyForState(UIControlState state)
{
    return [NSString stringWithFormat:@"backgroundImage_%lu", (unsigned long)state];
}

static inline NSString * imageOperationKeyForState(UIControlState state)
{
    return [NSString stringWithFormat:@"UIButtonImageOperation%lu", (unsigned long)state];
}

static inline NSString * backgroundImageOperationKeyForState(UIControlState state)
{
    return [NSString stringWithFormat:@"UIButtonBackgroundImageOperation%lu", (unsigned long)state];
}


@implementation UIButton (XXWebCache)

- (NSURL *)xxsd_currentImageURL
{
    NSURL *url = [self xxsd_imageURLStorage][imageURLKeyForState(self.state)];
    if (!url) {
        url = [self xxsd_imageURLStorage][imageURLKeyForState(UIControlStateNormal)];
    }
    return url;
}

- (NSURL *)xxsd_imageURLForState:(UIControlState)state
{
    return [self xxsd_imageURLStorage][imageURLKeyForState(state)];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                    forState:(UIControlState)state
{
    [self xxsd_setImageWithURL:url forState:state placeholderImage:nil options:0 completed:nil];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                    forState:(UIControlState)state
            placeholderImage:(nullable UIImage *)placeholder
{
    [self xxsd_setImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:nil];
}


- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                    forState:(UIControlState)state
            placeholderImage:(nullable UIImage *)placeholder
                     options:(XXSDWebImageOptions)options
{
    [self xxsd_setImageWithURL:url forState:state placeholderImage:placeholder options:options completed:nil];

}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                    forState:(UIControlState)state
                   completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setImageWithURL:url forState:state placeholderImage:nil options:0 completed:completedBlock];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                    forState:(UIControlState)state
            placeholderImage:(nullable UIImage *)placeholder
                   completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:completedBlock];
}

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                    forState:(UIControlState)state
            placeholderImage:(nullable UIImage *)placeholder
                     options:(XXSDWebImageOptions)options
                   completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    if (!url) {
        [[self xxsd_imageURLStorage] removeObjectForKey:imageURLKeyForState(state)];
    } else {
        [self xxsd_imageURLStorage][imageURLKeyForState(state)] = url;
    }
    
    __weak typeof(self) weakSelf = self;
    [self xxsd_internalSetImageWithURL:url
                      placeholderImage:placeholder
                               options:options
                          operationKey:imageOperationKeyForState(state)
                         setImageBlock:^(UIImage *image, NSData *imageData) {
                             [weakSelf setImage:image forState:state];
                             
                         }
                              progress:nil
                             completed:completedBlock];
}

#pragma mark - Background Image

- (nullable NSURL *)xxsd_currentBackgroundImageURL
{
    NSURL *url = [self xxsd_imageURLStorage][backgroundImageURLKeyForState(self.state)];
    if (!url) {
        url = [self xxsd_imageURLStorage][backgroundImageURLKeyForState(UIControlStateNormal)];
    }
    return url;
}

- (nullable NSURL *)sd_backgroundImageURLForState:(UIControlState)state
{
    return [self xxsd_imageURLStorage][backgroundImageURLKeyForState(UIControlStateNormal)];
}

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                              forState:(UIControlState)state
{
    [self xxsd_setBackgroundImageWithURL:url forState:state placeholderImage:nil options:0 completed:nil];
}

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                              forState:(UIControlState)state
                      placeholderImage:(nullable UIImage *)placeholder
{
    [self xxsd_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:nil];

}

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                              forState:(UIControlState)state
                      placeholderImage:(nullable UIImage *)placeholder
                               options:(XXSDWebImageOptions)options
{
    [self xxsd_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options completed:nil];
}

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                              forState:(UIControlState)state
                             completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setBackgroundImageWithURL:url forState:state placeholderImage:nil options:0 completed:completedBlock];
}

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                              forState:(UIControlState)state
                      placeholderImage:(nullable UIImage *)placeholder
                             completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:completedBlock];
}

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                              forState:(UIControlState)state
                      placeholderImage:(nullable UIImage *)placeholder
                               options:(XXSDWebImageOptions)options
                             completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    if (!url) {
        [[self xxsd_imageURLStorage] removeObjectForKey:backgroundImageURLKeyForState(state)];
    } else {
        [self xxsd_imageURLStorage][backgroundImageURLKeyForState(state)] = url;
    }
    
    __weak typeof(self)weakSelf = self;
    [self xxsd_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                        operationKey:backgroundImageOperationKeyForState(state)
                       setImageBlock:^(UIImage *image, NSData *imageData) {
                           [weakSelf setBackgroundImage:image forState:state];
                       }
                            progress:nil
                           completed:completedBlock];

}

#pragma mark - Cancel

/**
 * Cancel the current image download
 */
- (void)xxsd_cancelImageLoadForState:(UIControlState)state
{
    [self xxsd_cancelImageLoadOperationWithKey:imageOperationKeyForState(state)];
}

/**
 * Cancel the current backgroundImage download
 */
- (void)xxsd_cancelBackgroundImageLoadForState:(UIControlState)state
{
    [self xxsd_cancelImageLoadOperationWithKey:backgroundImageOperationKeyForState(state)];
}

#pragma mark - private

- (XXSDStateImageURLDictionary *)xxsd_imageURLStorage
{
    XXSDStateImageURLDictionary *storage = objc_getAssociatedObject(self, &imageURLStorageKey);
    if (!storage) {
        storage = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &imageURLStorageKey, storage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return storage;
}

@end

#endif

