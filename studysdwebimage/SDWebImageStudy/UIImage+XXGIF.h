//
//  UIImage+XXGIF.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

@interface UIImage (XXGIF)

/**
   *从NSData创建一个动画UIImage。
   *对于静态GIF，将创建一个Uimage，并将`images`数组设置为nil。 对于动画GIF，将创建一个image以及images数组。
  */
+ (UIImage *)xxsd_animatedGIFWithData:(NSData *)data;

- (BOOL)xxsd_isGIF;

@end
