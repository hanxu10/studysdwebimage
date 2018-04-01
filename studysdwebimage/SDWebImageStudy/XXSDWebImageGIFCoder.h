//
//  XXSDWebImageGIFCoder.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDWebImageCoder.h"
/**
   内置编码器，使用支持GIF编码/解码的ImageIO
   @note `SDWebImageIOCoder`支持GIF，但仅支持静态（将使用第一帧）。
   @note “SDWebImageGIFCoder”用于完整的动画GIF - 性能比“FLAnimatedImage”差
   @note 如果您决定让所有`UIImageView`（包括`FLAnimatedImageView`）实例支持GIF。 您应该将此编码器添加到“SDWebImageCodersManager”，并确保它具有比“SDWebImageIOCoder”更高的优先级
   @note 为动画GIF推荐的方法是使用`FLAnimatedImage`。 它比用于GIF显示的“UIImageView”更高效
  */
@interface XXSDWebImageGIFCoder : NSObject <XXSDWebImageCoder>

+ (instancetype)sharedCoder;

@end
