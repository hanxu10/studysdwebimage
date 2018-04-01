//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCompat.h"
#import "XXSDWebImageFrame.h"


@interface XXSDWebImageCoderHelper : NSObject


/**
  使用frames数组返回一个动画图像。
  对于UIKit，将应用一个补丁，然后创建动画UIImage。 应用补丁是因为`+ [UIImage animatedImageWithImages：duration：]`只是使用每个图像的持续时间的平均值。 所以如果不同的帧有不同的持续时间，它将不起作用。 因此，我们重复指定帧的指定时间让它工作。
  对于AppKit，NSImage不支持GIF以外的动画。 这将尝试将帧编码为GIF格式，然后创建一个用于渲染的动画NSImage。 注意，如果输入帧包含完整的Alpha通道，则动画图像可能会丢失一些细节，因为GIF仅支持1位Alpha通道。 （对于1个像素，透明或者不透明）
*/
+ (UIImage *_Nullable)animatedImageWithFrames:(NSArray<XXSDWebImageFrame *> * _Nullable)frames;

/**
  从动画图像返回帧数组。
  对于UIKit，这将不应用上述描述的补丁，然后创建帧数组。 这也适用于普通的动画UIImage。
  对于AppKit，NSImage不支持GIF以外的动画。 这将尝试解码GIF imageRep，然后创建帧数组。

  @参数animatedImage动画图像。 如果它没有动画，则返回零
  @return框架数组
 */
+ (NSArray<XXSDWebImageFrame *> *)framesFromAnimatedImage:(UIImage *)animatedImage;

#if XXSD_UIKIT || XXSD_WATCH

//将EXIF图像方向转换为iOS版本。
+ (UIImageOrientation)imageOrientationFromEXIFOrientation:(NSInteger)exifOrientation;

//将ios方向转成EXIF图像方向
+ (NSInteger)exifOrientationFromImageOrientation:(UIImageOrientation)imageOrientation;

#endif
@end
