//
//  UIImageView+XXWebCache.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_UIKIT || XXSD_MAC

#import "XXSDWebImageManager.h"


@interface UIImageView (XXWebCache)

- (void)xxsd_setImageWithURL:(NSURL *)url NS_REFINED_FOR_SWIFT;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder NS_REFINED_FOR_SWIFT;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(XXSDWebImageOptions)options NS_REFINED_FOR_SWIFT;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(XXSDWebImageOptions)options
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(XXSDWebImageOptions)options
                  progress:(nullable XXSDWebImageDownloaderProgressBlock)progressBlock
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock;

#if XXSD_UIKIT

#pragma mark - Animation of multiple images

/**
 * Download an array of images and starts them in an animation loop
 *
 * @param arrayOfURLs An array of NSURL
 */
- (void)xxsd_setAnimationImagesWithURLs:(nonnull NSArray<NSURL *> *)arrayOfURLs;

- (void)xxsd_cancelCurrentAnimationImagesLoad;

#endif

@end

#endif
