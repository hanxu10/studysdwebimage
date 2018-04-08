//
//  UIView+XXWebCacheOperation.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_UIKIT || XXSD_MAC

#import "XXSDWebImageManager.h"

//这些方法用于支持取消UIView图像加载，它被设计为内部使用，而不是外部使用。
//所有stored operations都是weak的，所以在图像加载完成后会被删除。 如果您需要存储操作，请使用自己的类来为他们保持强引用。
@interface UIView (XXWebCacheOperation)

- (void)xxsd_setImageLoadOperation:(id<XXSDWebImageOperation>)operation forKey:(NSString *)key;


/**
  * 取消当前UIView和key的所有操作
  */
- (void)xxsd_cancelImageLoadOperationWithKey:(NSString *)key;

/**
  *只需删除与当前UIView和key对应的操作，而不取消它们
  *
  * @param key 识别操作的key
  */
- (void)xxsd_removeImageLoadOperationWithKey:(NSString *)key;

@end

#endif
