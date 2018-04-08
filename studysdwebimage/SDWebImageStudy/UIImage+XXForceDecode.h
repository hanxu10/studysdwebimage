//
//  UIImage+XXForceDecode.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/8.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (XXForceDecode)

+ (UIImage *)xx_decodedImageWithImage:(UIImage *)image;

+ (UIImage *)xx_decodedAndScaledDownImageWithImage:(UIImage *)image;

@end
