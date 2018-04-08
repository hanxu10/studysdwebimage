//
//  UIView+XXWebCacheOperation.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/7.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "UIView+XXWebCacheOperation.h"

#if XXSD_UIKIT || XXSD_MAC

#import <objc/runtime.h>

static char loadOperationKey;

//键是strong，值是weak，因为操作实例由SDWebImageManager的runningOperations属性保留
//我们应该使用lock来保持线程安全，因为这些方法可能不会从主队列中获取

typedef NSMapTable<NSString *, id<XXSDWebImageOperation>> XXSDOperationsDictionary;

@implementation UIView (XXWebCacheOperation)

- (XXSDOperationsDictionary *)xxsd_operationDictionary
{
    @synchronized (self) {
        XXSDOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
        if (operations) {
            return operations;
        }
        operations = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operations;
    }
}

- (void)xxsd_setImageLoadOperation:(id<XXSDWebImageOperation>)operation forKey:(NSString *)key
{
    if (key) {
        [self xxsd_cancelImageLoadOperationWithKey:key];
        if (operation) {
            XXSDOperationsDictionary *operationDictionary = [self xxsd_operationDictionary];
            @synchronized (self) {
                [operationDictionary setObject:operation forKey:key];
            }
        }
    }
}

- (void)xxsd_cancelImageLoadOperationWithKey:(NSString *)key
{
    XXSDOperationsDictionary *operationDictionary = [self xxsd_operationDictionary];
    id<XXSDWebImageOperation> operation;
    @synchronized (self) {
        operation = [operationDictionary objectForKey:key];
    }
    
    if (operation) {
        if ([operation conformsToProtocol:@protocol(XXSDWebImageOperation)]) {
            [operation cancel];
        }
        @synchronized (self) {
            [operationDictionary removeObjectForKey:key];
        }
    }
}

- (void)xxsd_removeImageLoadOperationWithKey:(NSString *)key
{
    if (key) {
        XXSDOperationsDictionary *operationDictionary = [self xxsd_operationDictionary];
        @synchronized (self) {
            [operationDictionary removeObjectForKey:key];
        }
    }
}

@end

#endif





























