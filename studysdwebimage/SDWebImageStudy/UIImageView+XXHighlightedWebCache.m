//
//  UIImageView+XXHighlightedWebCache.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIImageView+XXHighlightedWebCache.h"

#if XXSD_UIKIT
#import "UIView+XXWebCacheOperation.h"
#import "UIView+XXWebCache.h"

@implementation UIImageView (XXHighlightedWebCache)

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
{
    [self xxsd_setHighlightedImageWithURL:url options:0 progress:nil completed:nil];
}

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                                options:(XXSDWebImageOptions)options
{
    [self xxsd_setHighlightedImageWithURL:url options:options progress:nil completed:nil];
}

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                              completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setHighlightedImageWithURL:url options:0 progress:nil completed:completedBlock];
}

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                                options:(XXSDWebImageOptions)options
                              completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    [self xxsd_setHighlightedImageWithURL:url options:options progress:nil completed:completedBlock];
}

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                                options:(XXSDWebImageOptions)options
                               progress:(nullable XXSDWebImageDownloaderProgressBlock)progressBlock
                              completed:(nullable XXSDExternalCompletionBlock)completedBlock
{
    __weak typeof(self)weakSelf = self;
    [self xxsd_internalSetImageWithURL:url
                      placeholderImage:nil
                               options:options
                          operationKey:@"UIImageViewImageOperationHighlighted"
                         setImageBlock:^(UIImage *image, NSData *imageData) {
                             weakSelf.highlightedImage = image;
                         }
                              progress:progressBlock
                             completed:completedBlock];
}

@end

#endif
