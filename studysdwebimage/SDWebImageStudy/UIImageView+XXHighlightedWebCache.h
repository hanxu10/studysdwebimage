//
//  UIImageView+XXHighlightedWebCache.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_UIKIT

#import "XXSDWebImageManager.h"

@interface UIImageView (XXHighlightedWebCache)

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url NS_REFINED_FOR_SWIFT;

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(XXSDWebImageOptions)options NS_REFINED_FOR_SWIFT;

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                            completed:(nullable XXSDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(XXSDWebImageOptions)options
                            completed:(nullable XXSDExternalCompletionBlock)completedBlock;

- (void)xxsd_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(XXSDWebImageOptions)options
                             progress:(nullable XXSDWebImageDownloaderProgressBlock)progressBlock
                            completed:(nullable XXSDExternalCompletionBlock)completedBlock;

@end

#endif
