//
//  ViewController.m
//  studysdwebimage
//
//  Created by 旭旭 on 2018/3/30.
//  Copyright © 2018年 旭旭. All rights reserved.
//

#import "ViewController.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "SDWebImageImageIOCoder.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetWidth(self.view.frame))];

    [self.view addSubview:imageView];

    NSData *data = nil;
    imageView.image = [[SDWebImageImageIOCoder sharedCoder] decompressedImageWithImage:[UIImage imageNamed:@"test.JPG"] data:&data options:@{SDWebImageCoderScaleDownLargeImagesKey: @1}];
}

@end
