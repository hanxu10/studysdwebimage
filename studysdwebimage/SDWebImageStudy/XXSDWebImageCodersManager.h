//
// Created by 旭旭 on 2018/3/30.
// Copyright (c) 2018 旭旭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXSDwebImageCoder.h"
/**
 全局对象持有编码器数组，以便我们避免将它们从对象传递给对象。
 在场景后面使用优先级队列，这意味着最新添加的编码器具有最高的优先级。
 这是在编码/解码某些东西时完成的，我们遍历列表并询问每个编码器是否可以处理当前数据。
 这样，用户可以添加他们的自定义编码器，同时保留我们现有的预置编码器
 
 注意：`coders` 的getter方法将以相反的顺序返回编码器
 例：
  - 默认情况下，我们在内部设置编码器=`IOCoder`，`WebPCoder`。 （不建议`GIFCoder`，仅在不想使用`FLAnimatedImage`获得GIF支持时才能添加）
  - 调用`coders`将返回`@ [WebPCoder，IOCoder]`
  - 调用`[addCoder：[MyCrazyCoder new]]`
  - 调用`coders`现在返回`@ [MyCrazyCoder，WebPCoder，IOCoder]`
 
 编码器
 ------
 编码器必须符合“SDWebImageCoder”协议, 如果编码器支持逐行解码需要符合“SDWebImageProgressiveCoder”
 一致性很重要，因为这样，他们将实现`canDecodeFromData`或`canEncodeToFormat`
 这些方法在数组中的每个编码器上调用（使用优先级顺序），直到其中一个返回YES。
 这意味着编码器可以将该数据/编码解码为该格式
 */

@interface XXSDWebImageCodersManager : NSObject<XXSDWebImageCoder>

+ (nonnull instancetype)sharedInstance;

//所有编码器。 编码器数组是优先级队列，这意味着后面添加的编码器将具有最高的优先级
@property (nonatomic, strong, nullable) NSArray<XXSDWebImageCoder> *coders;

- (void)addCoder:(id<XXSDWebImageCoder>)coder;

- (void)removeCoder:(nonnull id<XXSDWebImageCoder>)coder;

@end