//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"


//此类用于通过SDWebImageCoderHelper中的animatedImageWithFrame创建动画图像。
//注意，如果您需要指定动画图像循环计数，请在`UIImage + MultiFormat`中使用`sd_imageLoopCount`属性。
@interface XXSDWebImageFrame : NSObject

//当前帧对应的图片，不应该设置为一个动图
@property(nonatomic, strong, readonly) UIImage *image;

//当前帧要展示的时间。单位是秒。不应该设置为0
@property(nonatomic, assign, readonly) NSTimeInterval duration;

+ (instancetype)frameWithImage:(UIImage *)image duration:(NSTimeInterval)duration;

@end