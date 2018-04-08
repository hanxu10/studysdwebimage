//
//  XXSDWebImageTransition.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageTransition.h"

#if XXSD_UIKIT || XXSD_MAC

#if XXSD_MAC
#import <QuartzCore/QuartzCore.h>
#endif

@implementation XXSDWebImageTransition

- (instancetype)init
{
    if (self = [super init]) {
        self.duration = 0.5;
    }
    return self;
}

@end

@implementation XXSDWebImageTransition (Conveniences)

+ (XXSDWebImageTransition *)fadeTransition
{
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCrossDissolve;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionFade;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (XXSDWebImageTransition *)flipFromLeftTransition
{
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromLeft;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromLeft;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (XXSDWebImageTransition *)flipFromRightTransition
{
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromRight;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromRight;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (XXSDWebImageTransition *)flipFromTopTransition {
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromTop;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromTop;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (XXSDWebImageTransition *)flipFromBottomTransition
{
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromBottom;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromBottom;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (XXSDWebImageTransition *)curlUpTransition
{
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlUp;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromTop;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (XXSDWebImageTransition *)curlDownTransition
{
    XXSDWebImageTransition *transition = [XXSDWebImageTransition new];
#if XXSD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlDown;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromBottom;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

@end

#endif
