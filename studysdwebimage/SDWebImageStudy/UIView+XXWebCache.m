//
//  UIView+XXWebCache.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIView+XXWebCache.h"

#if XXSD_UIKIT || XXSD_MAC

#import <objc/runtime.h>
#import "UIView+XXWebCacheOperation.h"

NSString *const XXSDWebImageInternalSetImageGroupKey = @"XXSDWebImageInternalSetImageGroupKey";
NSString *const XXSDWebImageExternalCustomManagerKey = @"XXSDWebImageExternalCustomManagerKey";
const int64_t XXSDWebImageProgressUnitCountUnknown = 1LL;

static char imageURLKey;

#if XXSD_UIKIT
static char TAG_ACTIVITY_INDICATOR;
static char TAG_ACTIVITY_STYLE;
#endif
static char TAG_ACTIVITY_SHOW;

@implementation UIView (XXWebCache)

- (NSURL *)xxsd_imageURL
{
    return objc_getAssociatedObject(self, &imageURLKey);
}

- (NSProgress *)xxsd_imageProgress
{
    NSProgress *progress = objc_getAssociatedObject(self, @selector(xxsd_imageProgress));
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.xxsd_imageProgress = progress;
    }
    return progress;
}

- (void)setXxsd_imageProgress:(NSProgress *)xxsd_imageProgress
{
    objc_setAssociatedObject(self, @selector(xxsd_imageProgress), xxsd_imageProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)xxsd_internalSetImageWithURL:(NSURL *)url
                    placeholderImage:(UIImage *)image
                             options:(XXSDWebImageOptions)options
                        operationKey:(NSString *)operationKey
                       setImageBlock:(XXSDSetImageBlock)setImageBlock
                            progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                           completed:(XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_internalSetImageWithURL:url placeholderImage:image options:options operationKey:operationKey setImageBlock:setImageBlock progress:progressBlock completed:completedBlock context:nil];
}

- (void)xxsd_internalSetImageWithURL:(NSURL *)url
                    placeholderImage:(UIImage *)placeholder
                             options:(XXSDWebImageOptions)options
                        operationKey:(NSString *)operationKey
                       setImageBlock:(XXSDSetImageBlock)setImageBlock
                            progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                           completed:(XXSDExternalCompletionBlock)completedBlock
                             context:(NSDictionary<NSString *,id> *)context
{
    NSString *validOperationKey = operationKey ?: NSStringFromClass([self class]);
    [self xxsd_cancelImageLoadOperationWithKey:validOperationKey];
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (!(options & XXSDWebImageDelayPlaceholder)) {
        if ([context valueForKey:XXSDWebImageInternalSetImageGroupKey]) {
            dispatch_group_t group = [context valueForKey:XXSDWebImageInternalSetImageGroupKey];
            dispatch_group_enter(group);
        }
        dispatch_main_async_safe(^{
            [self xxsd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
        });
    }
    
    if (url) {
        if ([self xxsd_showActivityIndicatorView]) {
            [self xxsd_addActivityIndicator];
        }
        
        self.xxsd_imageProgress.totalUnitCount = 0;
        self.xxsd_imageProgress.completedUnitCount = 0;
        
        XXSDWebImageManager *manager;
        if ([context valueForKey:XXSDWebImageExternalCustomManagerKey]) {
            manager = (XXSDWebImageManager *)[context valueForKey:XXSDWebImageExternalCustomManagerKey];
        } else {
            manager = [XXSDWebImageManager sharedManager];
        }
        
        __weak typeof(self) wself = self;
        XXSDWebImageDownloaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL) {
            wself.xxsd_imageProgress.totalUnitCount = expectedSize;
            wself.xxsd_imageProgress.completedUnitCount = receivedSize;
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        
        id<XXSDWebImageOperation> operation = [manager loadImageWithURL:url options:options progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, XXSDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            
            [sself xxsd_removeActivityIndicator];
            //如果进度未更新，则将其标记为完成状态
            if (finished && !error && sself.xxsd_imageProgress.totalUnitCount == 0 && sself.xxsd_imageProgress.completedUnitCount == 0) {
                sself.xxsd_imageProgress.completedUnitCount = XXSDWebImageProgressUnitCountUnknown;
            }
            BOOL shouldCallCompletedBlock = finished || (options & XXSDWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & XXSDWebImageAvoidAutoSetImage)) || (!image && !(options & XXSDWebImageDelayPlaceholder)));
            XXSDWebImageNoParamsBlock callCompletedBlockClojure = ^ {
                if (!sself) {
                    return;
                }
                if (!shouldNotSetImage) {
                    [sself xxsd_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, error, cacheType, url);
                }
            };
            
            // case 1a: we got an image, but the SDWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the SDWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClojure);
                return;
            }

            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the SDWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & XXSDWebImageDelayPlaceholder) {
                // case 2b: we got no image and the SDWebImageDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
            XXSDWebImageTransition *transition = nil;
            if (finished && (options & XXSDWebImageForceTransition || cacheType == XXSDImageCacheTypeNone)) {
                transition = sself.xxsd_imageTransition;
            }
            if ([context valueForKey:XXSDWebImageInternalSetImageGroupKey]) {
                dispatch_group_t group = [context valueForKey:XXSDWebImageInternalSetImageGroupKey];
                dispatch_group_enter(group);
                dispatch_main_async_safe(^ {
                    [sself xxsd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
                });
                dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                    callCompletedBlockClojure();
                });
            } else {
                dispatch_main_async_safe(^ {
                    [sself xxsd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
                    callCompletedBlockClojure();
                });
            }
        }];
        [self xxsd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
        dispatch_main_async_safe(^{
            [self xxsd_removeActivityIndicator];
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:XXSDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, XXSDImageCacheTypeNone, url);
            }
        });
    }
}

- (void)xxsd_cancelCurrentImageLoad
{
    [self xxsd_cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)xxsd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(XXSDSetImageBlock)setImageBlock
{
    
}

- (void)xxsd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(XXSDSetImageBlock)setImageBlock transition:(XXSDWebImageTransition *)transition cacheType:(XXSDImageCacheType)cacheType imageURL:(NSURL *)imageURL
{
    UIView *view = self;
    XXSDSetImageBlock finalSetImageBlock;
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    }
#if XXSD_UIKIT || XXSD_MAC
    else if ([view isKindOfClass:[UIImageView class]]){
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData) {
            imageView.image = setImage;
        };
    }
#endif
#if XXSD_UIKIT
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData){
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
#endif
    
    if (transition) {
#if XXSD_UIKIT
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            // 0持续时间,让UIKit渲染占位图和prepares block
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL finished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:transition.completion];
        }];
#elif SD_MAC
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull prepareContext) {
            // 0 duration to let AppKit render placeholder and prepares block
            prepareContext.duration = 0;
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                context.duration = transition.duration;
                context.timingFunction = transition.timingFunction;
                context.allowsImplicitAnimation = (transition.animationOptions & SDWebImageAnimationOptionAllowsImplicitAnimation);
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completionHandler:^{
                if (transition.completion) {
                    transition.completion(YES);
                }
            }];
        }];
#endif
    } else {
        if (finalSetImageBlock) {
            finalSetImageBlock(image, imageData);
        }
    }
}

- (void)xxsd_setNeedsLayout
{
#if SD_UIKIT
    [self setNeedsLayout];
#elif SD_MAC
    [self setNeedsLayout:YES];
#endif
}

#pragma mark - Image Transition

- (XXSDWebImageTransition *)xxsd_imageTransition
{
    return objc_getAssociatedObject(self, @selector(xxsd_imageTransition));
}

- (void)setXxsd_imageTransition:(XXSDWebImageTransition *)xxsd_imageTransition
{
    objc_setAssociatedObject(self, @selector(xxsd_imageTransition), xxsd_imageTransition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Activity indicator

#if XXSD_UIKIT

- (UIActivityIndicatorView *)activityIndicator
{
    return (UIActivityIndicatorView *)objc_getAssociatedObject(self, &TAG_ACTIVITY_INDICATOR);
}

- (void)setActivityIndicator:(UIActivityIndicatorView *)activityIndicator
{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_INDICATOR, activityIndicator, OBJC_ASSOCIATION_RETAIN);
}
#endif

- (void)xxsd_setShowActivityIndicatorView:(BOOL)show
{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_SHOW, @(show), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)xxsd_showActivityIndicatorView
{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_SHOW) boolValue];
}

#if XXSD_UIKIT

- (void)xxsd_setIndicatorStyle:(UIActivityIndicatorViewStyle)style
{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_STYLE, [NSNumber numberWithInt:style], OBJC_ASSOCIATION_RETAIN);
}

- (int)xxsd_getIndicatorStyle
{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_STYLE) intValue];
}
#endif

- (void)xxsd_addActivityIndicator
{
#if XXSD_UIKIT
    dispatch_main_async_safe(^{
        if (!self.activityIndicator) {
            self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:[self xxsd_getIndicatorStyle]];
            self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
            
            [self addSubview:self.activityIndicator];
            
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0
                                                              constant:0.0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0
                                                              constant:0.0]];
        }
        [self.activityIndicator startAnimating];
    });
#endif
}

- (void)xxsd_removeActivityIndicator
{
#if XXSD_UIKIT
    dispatch_main_async_safe(^{
        if (self.activityIndicator) {
            [self.activityIndicator removeFromSuperview];
            self.activityIndicator = nil;
        }
    });
#endif
}

@end

#endif












































