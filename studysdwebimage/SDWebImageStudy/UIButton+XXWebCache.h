//
//  UIButton+XXWebCache.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_UIKIT

#import "XXSDWebImageManager.h"

@interface UIButton (XXWebCache)

#pragma mark - Image

- (NSURL *)xxsd_currentImageURL;

- (NSURL *)xxsd_imageURLForState:(UIControlState)state;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state NS_REFINED_FOR_SWIFT;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
          placeholderImage:(nullable UIImage *)placeholder NS_REFINED_FOR_SWIFT;


- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
          placeholderImage:(nullable UIImage *)placeholder
                   options:(XXSDWebImageOptions)options NS_REFINED_FOR_SWIFT;


- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
          placeholderImage:(nullable UIImage *)placeholder
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;

- (void)xxsd_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
          placeholderImage:(nullable UIImage *)placeholder
                   options:(XXSDWebImageOptions)options
                 completed:(nullable XXSDExternalCompletionBlock)completedBlock;

#pragma mark - Background Image

- (nullable NSURL *)xxsd_currentBackgroundImageURL;

- (nullable NSURL *)sd_backgroundImageURLForState:(UIControlState)state;

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state NS_REFINED_FOR_SWIFT;

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                    placeholderImage:(nullable UIImage *)placeholder NS_REFINED_FOR_SWIFT;

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                    placeholderImage:(nullable UIImage *)placeholder
                             options:(XXSDWebImageOptions)options NS_REFINED_FOR_SWIFT;

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                           completed:(nullable XXSDExternalCompletionBlock)completedBlock;

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                    placeholderImage:(nullable UIImage *)placeholder
                           completed:(nullable XXSDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;

- (void)xxsd_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                    placeholderImage:(nullable UIImage *)placeholder
                             options:(XXSDWebImageOptions)options
                           completed:(nullable XXSDExternalCompletionBlock)completedBlock;

#pragma mark - Cancel

/**
 * Cancel the current image download
 */
- (void)xxsd_cancelImageLoadForState:(UIControlState)state;

/**
 * Cancel the current backgroundImage download
 */
- (void)xxsd_cancelBackgroundImageLoadForState:(UIControlState)state;

@end

#endif

