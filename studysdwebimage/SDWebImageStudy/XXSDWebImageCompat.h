//
//  XXSDWebImageCompat.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/3/30.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifdef __OBJC_GC__
    #error XXSDWebImage does not support Objective-C Garbage Collection
#endif

#if !TARGET_OS_IPHONE && !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
#define XXSD_MAC 1
#else
#define XXSD_MAC 0
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    #define XXSD_UIKIT 1
#else
    #define XXSD_UIKIT 0
#endif

#if TARGET_OS_IOS
#define XXSD_IOS 1
#else
#define XXSD_IOS 0
#endif

#if TARGET_OS_TV
#define XXSD_TV 1
#else
#define XXSD_TV 0
#endif

#if TARGET_OS_WATCH
#define XXSD_WATCH 1
#else
#define XXSD_WATCH 0
#endif

#if XXSD_MAC
    #import <AppKit/AppKit.h>
    #ifndef UIImage
        #define UIImage NSImage
    #endif

    #ifndef UIImageView
        #define UIImageView NSImageView
    #endif

    #ifndef UIView
        #define UIView NSView
    #endif
#else
    #if __IPHONE_OS_VERSION_MIN_REQUIRED != 20000 && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
        #error XXSDWebImage does not support Deployment Target version < 5.0
    #endif

    #if XXSD_UIKIT
    #import <UIKit/UIKit.h>
    #endif
    #if XXSD_WATCH
        #import <WatchKit/WatchKit.h>
    #endif
#endif

FOUNDATION_EXPORT UIImage *XXSDScaledImageForKey(NSString *key, UIImage *image);

typedef void (^XXSDWebImageNoParamsBlock)(void);

FOUNDATION_EXPORT NSString *const XXSDWebImageErrorDomain;

#ifndef dispatch_queue_async_safe
#define dispatch_queue_async_safe(queue, block)\
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {\
        block();\
    } else {\
        dispatch_async(queue, block);\
    }
#endif

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) dispatch_queue_async_safe(dispatch_get_main_queue(), block)
#endif

