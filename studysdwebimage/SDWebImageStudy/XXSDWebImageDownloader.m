//
//  XXSDWebImageDownloader.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/4/3.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "XXSDWebImageDownloader.h"
#import "XXSDWebImageDownloaderOperation.h"

#define XXLOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define XXUNLOCK(lock) dispatch_semaphore_signal(lock);

@interface XXSDWebImageDownloadToken ()

@property (nonatomic, weak) NSOperation<XXSDWebImageDownloaderOperationInterface> *downloadOperation;

@end

@implementation XXSDWebImageDownloadToken

- (void)cancel
{
    if (self.downloadOperation) {
        XXSDWebImageDownloadToken *cancelToken = self.downloadOperationCancelToken;
        if (cancelToken) {
            [self.downloadOperation cancel:cancelToken];
        }
    }
}

@end

@interface XXSDWebImageDownloader () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, weak) NSOperation *lastAddedOperation;
@property (nonatomic, assign) Class operationClass;
@property (nonatomic, strong) NSMutableDictionary<NSURL *, XXSDWebImageDownloaderOperation *> *URLOperations;
@property (nonatomic, strong) XXSDHTTPHeadersMutableDictionary *HTTPHeaders;
@property (nonatomic, strong) dispatch_semaphore_t operationsLock;// a lock to keep the access to `URLOperations` thread-safe
@property (nonatomic, strong) dispatch_semaphore_t headersLock;// a lock to keep the access to `HTTPHeaders` thread-safe

// The session in which data tasks will run
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation XXSDWebImageDownloader

+ (instancetype)sharedDownloader
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    if (self = [super init]) {
        _operationClass = [XXSDWebImageDownloaderOperation class];
        _shouldDecompressImages = YES;
        _executionOrder = XXSDWebImageDownloaderFIFOExecutionOrder;
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 6;
        _downloadQueue.name = @"com.xuxu.XXSDWebImageDownloader";
        _URLOperations = [NSMutableDictionary dictionary];
#ifdef SD_WEBP
        _HTTPHeaders = [@{
                          @"Accept": @"image/webp,image/*;q=0.8"
                          } mutableCopy];
#else
        _HTTPHeaders = [@{
                          @"Accept": @"image/*;q=0.8"
                          } mutableCopy];
#endif
        _operationsLock = dispatch_semaphore_create(1);
        _headersLock = dispatch_semaphore_create(1);
        _downloadTimeout = 15.0;
        
        [self createNewSessionWithConfiguration:sessionConfiguration];
    }
    return self;
}

- (void)createNewSessionWithConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    [self cancelAllDownloads];
    
    if (self.session) {
        [self.session invalidateAndCancel];
    }
    
    sessionConfiguration.timeoutIntervalForRequest = self.downloadTimeout;
    
    /**
      * 为此任务创建会话
      * 我们将nil作为委托队列发送，以便会话创建一个串行操作队列以执行所有委托方法调用和完成处理程序调用。
     */
    self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                 delegate:self
                                            delegateQueue:nil];
}

- (void)invalidateSessionAndCancel:(BOOL)cancelPendingOperations
{
    if (self == [XXSDWebImageDownloader sharedDownloader]) {
        return;
    }
    if (cancelPendingOperations) {
        [self.session invalidateAndCancel];
    } else {
        [self.session finishTasksAndInvalidate];
    }
}

- (void)dealloc
{
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self.downloadQueue cancelAllOperations];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
    XXLOCK(self.headersLock);
    if (value) {
        self.HTTPHeaders[field] = value;
    } else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
    XXUNLOCK(self.headersLock);
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field
{
    if (!field) {
        return nil;
    }
    return [[self allHTTPHeaderFields] objectForKey:field];
}

- (XXSDHTTPHeadersDictionary *)allHTTPHeaderFields
{
    XXLOCK(self.headersLock);
    XXSDHTTPHeadersDictionary *allHTTPHeaderFields = [self.HTTPHeaders copy];
    XXUNLOCK(self.headersLock);
    return allHTTPHeaderFields;
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads
{
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSUInteger)currentDownloadCount
{
    return _downloadQueue.operationCount;
}

- (NSInteger)maxConcurrentDownloads
{
    return _downloadQueue.maxConcurrentOperationCount;
}

- (NSURLSessionConfiguration *)sessionConfiguration
{
    return self.session.configuration;
}

- (void)setOperationClass:(Class)operationClass
{
    if (    operationClass
        && [operationClass isSubclassOfClass:[NSOperation class]]
        && [operationClass conformsToProtocol:@protocol(XXSDWebImageDownloaderOperationInterface)]) {
        _operationClass = operationClass;
    } else {
        _operationClass = [XXSDWebImageDownloaderOperation class];
    }
}

- (XXSDWebImageDownloadToken *)downloadImageWithURL:(NSURL *)url
                                            options:(XXSDWebImageDownloaderOptions)options
                                           progress:(XXSDWebImageDownloaderProgressBlock)progressBlock
                                          completed:(XXSDWebImageDownloaderCompletionBlock)completedBlock
{
    __weak XXSDWebImageDownloader *wself = self;
    
    return [self addProgressCallback:progressBlock completedBlock:completedBlock forURL:url createCallback:^XXSDWebImageDownloaderOperation *{
        __strong typeof(wself) sself = wself;
        NSTimeInterval timeoutInterval = sself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        
        //为了防止潜在的重复缓存（NSURLCache + SDImageCache），如果另有说明，我们禁用图像请求的缓存
        NSURLRequestCachePolicy cachePolicy = options & XXSDWebImageDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringCacheData;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:cachePolicy timeoutInterval:timeoutInterval];
        request.HTTPShouldHandleCookies = (options & XXSDWebImageDownloaderHandleCookies);
        request.HTTPShouldUsePipelining = YES;
        if (sself.headersFilter) {
            request.allHTTPHeaderFields = sself.headersFilter(url, [sself allHTTPHeaderFields]);
        } else {
            request.allHTTPHeaderFields = [sself allHTTPHeaderFields];
        }
        
        XXSDWebImageDownloaderOperation *operation = [[sself.operationClass alloc] initWithRequest:request inSession:sself.session options:options];
        operation.shouldDecompressImages = sself.shouldDecompressImages;
        
        if (sself.urlCredential) {
            operation.credential = sself.urlCredential;
        } else if (sself.username && sself.password) {
            operation.credential = [NSURLCredential credentialWithUser:sself.username password:sself.password persistence:NSURLCredentialPersistenceForSession];
        }
        
        if (options & XXSDWebImageDownloaderHightPriority) {
            operation.queuePriority = NSOperationQueuePriorityHigh;
        } else if (options & XXSDWebImageDownloaderLowPriority) {
            operation.queuePriority = NSOperationQueuePriorityLow;
        }
        
        //通过系统地添加新操作作为最后一个操作的依赖关系模仿LIFO执行顺序
        if (sself.executionOrder == XXSDWebImageDownloaderLIFOExecutionOrder) {
            [sself.lastAddedOperation addDependency:operation];
            sself.lastAddedOperation = operation;
        }
        
        return operation;
    }];
}

- (void)cancel:(XXSDWebImageDownloadToken *)token
{
    NSURL *url = token.url;
    if (!url) {
        return;
    }
    
    XXLOCK(self.operationsLock);
    XXSDWebImageDownloaderOperation *operation = [self.URLOperations objectForKey:url];
    if (operation) {
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOperations removeObjectForKey:url];
        }
    }
    XXUNLOCK(self.operationsLock);
}

- (XXSDWebImageDownloadToken *)addProgressCallback:(XXSDWebImageDownloaderProgressBlock)progressBlock completedBlock:(XXSDWebImageDownloaderCompletionBlock)completedBlock forURL:(NSURL *)url createCallback:(XXSDWebImageDownloaderOperation *(^)(void))createCallback
{
    //该URL将被用作回调字典的关键字，因此它不能为零。
    if (url == nil) {
        if (completedBlock) {
            completedBlock(nil, nil, nil, NO);
        }
        return nil;
    }
    
    XXLOCK(self.operationsLock);
    XXSDWebImageDownloaderOperation *operation = [self.URLOperations objectForKey:url];
    if (!operation) {
        operation = createCallback();
        __weak typeof(self) wself = self;
        operation.completionBlock = ^{
            __strong typeof(wself) sself = wself;
            if (!self) {
                return;
            }
            XXLOCK(sself.operationsLock);
            [sself.URLOperations removeObjectForKey:url];
            XXUNLOCK(sself.operationsLock);
        };
        [self.URLOperations setObject:operation forKey:url];
        //只有在根据Apple的文档完成所有配置后，才会将操作添加到操作队列中。
        //`addOperation：`不会同步执行`operation.completionBlock`，所以这不会导致死锁。
        [self.downloadQueue addOperation:operation];
    }
    XXUNLOCK(self.operationsLock);
    
    id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock];
    
    XXSDWebImageDownloadToken *token = [[XXSDWebImageDownloadToken alloc] init];
    token.downloadOperation = operation;
    token.url = url;
    token.downloadOperationCancelToken = downloadOperationCancelToken;
    
    return token;
}

- (void)setSuspended:(BOOL)suspended
{
    self.downloadQueue.suspended = suspended;
}

- (void)cancelAllDownloads
{
    [self.downloadQueue cancelAllOperations];
}

#pragma mark - Helper methods

- (XXSDWebImageDownloaderOperation *)operationWithTask:(NSURLSessionTask *)task
{
    XXSDWebImageDownloaderOperation *returnOperation = nil;
    for (XXSDWebImageDownloaderOperation *operation in  self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(nonnull NSURLResponse *)response
 completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler
{
    //确定运行此任务的操作并将其传递给委托方法
    XXSDWebImageDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [dataOperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    XXSDWebImageDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [dataOperation URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler
{
    XXSDWebImageDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [dataOperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(proposedResponse);
        }
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    XXSDWebImageDownloaderOperation *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [dataOperation URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    XXSDWebImageDownloaderOperation *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [dataOperation URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(request);
        }
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    XXSDWebImageDownloaderOperation *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [dataOperation URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    }
}

@end






























