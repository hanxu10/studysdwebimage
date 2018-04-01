//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import "XXSDWebImageFrame.h"


@interface XXSDWebImageFrame ()

//当前帧对应的图片，不应该设置为一个动图
@property(nonatomic, strong, readwrite) UIImage *image;
//当前帧要展示的时间。单位是秒。不应该设置为0
@property(nonatomic, assign, readwrite) NSTimeInterval duration;

@end

@implementation XXSDWebImageFrame

+ (instancetype)frameWithImage:(UIImage *)image duration:(NSTimeInterval)duration
{
    XXSDWebImageFrame *frame = [[XXSDWebImageFrame alloc] init];
    frame.image = image;
    frame.duration = duration;
    return frame;
}

@end