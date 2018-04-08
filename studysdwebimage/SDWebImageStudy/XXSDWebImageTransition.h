//
//  XXSDWebImageTransition.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_UIKIT || XXSD_MAC
#import "XXSDImageCache.h"

#if XXSD_UIKIT
typedef UIViewAnimationOptions XXSDWebImageAnimationOptions;
#else
typedef NS_OPTIONS(NSUInteger, XXSDWebImageAnimationOptions) {
    XXSDWebImageAnimationOptionAllowsImplicitAnimation = 1 << 0,// specify `allowsImplicitAnimation` for the `NSAnimationContext`
};
#endif

typedef void(^XXSDWebImageTransitionPreparesBlock)(UIView *view, UIImage *image, NSData *imageData, XXSDImageCacheType cacheType, NSURL *imageURL);
typedef void(^XXSDWebImageTransitionAnimationsBlock)(UIView *view, UIImage *image);
typedef void(^XXSDWebImageTransitionCompletionBlock)(BOOL finished);

@interface XXSDWebImageTransition : NSObject

/**
   默认情况下，在动画开始的时候把image设置给view。你可以禁止这个过程，自己提供设置image的过程。
 */
@property (nonatomic, assign) BOOL avoidAutoSetImage;

/**
   过渡动画的持续时间，以秒为单位。 默认为0.5。
  */
@property (nonatomic, assign) NSTimeInterval duration;

/**
   用于此过渡动画中所有动画的计时函数。（macOS）
  */
@property (nonatomic, strong) CAMediaTimingFunction *timingFunction NS_AVAILABLE_MAC(10_7);

@property (nonatomic, assign) XXSDWebImageAnimationOptions animationOptions;

/**
   在动画序列开始之前要执行的块对象。
  */
@property (nonatomic, copy) XXSDWebImageTransitionPreparesBlock prepares;

/**
   一个块对象，其中包含要对指定视图进行的更改。
  */
@property (nonatomic, copy) XXSDWebImageTransitionAnimationsBlock animations;

/**
   当动画序列结束时要执行的块对象。
  */
@property (nonatomic, copy) XXSDWebImageTransitionCompletionBlock completion;

@end

//创建转换的便捷方式。 请记住如果需要指定持续时间。
//对于UIKit，这些转换只使用相应的`animationOptions`
//对于AppKit，这些转换在`动画`中使用Core Animation。 所以你的view必须layer-backed。 在应用之前设置`wantsLayer = YES`。
@interface XXSDWebImageTransition (Conveniences)

#if __has_feature(objc_class_property)
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *fadeTransition;
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *flipFromLeftTransition;
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *flipFromRightTransition;
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *flipFromTopTransition;
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *flipFromBottomTransition;
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *curlUpTransition;
@property (nonatomic, strong, class, readonly) XXSDWebImageTransition *curlDownTransition;
#else
+ (nonnull instancetype)fadeTransition;
+ (nonnull instancetype)flipFromLeftTransition;
+ (nonnull instancetype)flipFromRightTransition;
+ (nonnull instancetype)flipFromTopTransition;
+ (nonnull instancetype)flipFromBottomTransition;
+ (nonnull instancetype)curlUpTransition;
+ (nonnull instancetype)curlDownTransition;
#endif

@end

#endif
