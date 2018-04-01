//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCoder.h"


/**
  内置支持PNG，JPEG，TIFF的编码器，支持逐行解码。
 
 GIF
  还支持静态GIF（意思只会处理第一帧）。
  对于完整的GIF支持，我们推荐`FLAnimatedImage`或者我们性能较低的`SDWebImageGIFCoder`
 
 HEIC
  该编码器还支持HEIC格式，因为ImageIO本身支持它。 但它取决于系统功能，因此它不适用于所有设备，请参阅：https：//devstreaming-cdn.apple.com/videos/wwdc/2017/511tj33587vdhds/511/511_working_with_heif_and_hevc.pdf

  解码（软件）：非模拟器 &&（iOS 11 || tvOS 11 || macOS 10.13）
  解码（硬件）：非模拟器 &&（（iOS 11 && A9Chip）||（macOS 10.13 && 6thGenerationIntelCPU））
  编码（软件）：macOS 10.13
  编码（硬件）：非模拟器 &&（（iOS 11 && A10FusionChip）||（macOS 10.13 && 6thGenerationIntelCPU））
 */

@interface XXSDWebImageImageIOCoder : NSObject <XXSDWebImageProgressiveCoder>

+ (nonnull instancetype)sharedCoder;

@end