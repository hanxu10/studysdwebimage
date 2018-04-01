//
//  SDAnimatedImageRep.h
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/1.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageCompat.h"

#if XXSD_MAC
// NSBitmapImageRep的子类来修复GIF循环次数问题，因为NSBitmapImageRep会通过使用kCGImagePropertyGIFDelayTime而不是kCGImagePropertyGIFUnclampedDelayTime来重置NSImageCurrentFrameDuration。
//建在GIF编码器中，使用它来代替`NSBitmapImageRep`来获得更好的GIF渲染效果。 如果你不想这样做，只需启用`SDWebImageImageIOCoder`，它只是调用`NSImage` API，实际上使用`NSBitmapImageRep`作为GIF图像。
@interface XXSDAnimatedImageRep : NSBitmapImageRep

@end

#endif
