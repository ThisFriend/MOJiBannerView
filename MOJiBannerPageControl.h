//
//  MOJiBannerPageControl.h
//  MOJiDict
//
//  Created by Ji Xiang on 2021/1/25.
//  Copyright © 2021 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MOJiBannerPageControl : UIView
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger numberOfPages;

@property(nonatomic, strong, nullable) UIColor *pageIndicatorTintColor;
@property(nonatomic, strong, nullable) UIColor *currentPageIndicatorTintColor;

+ (CGFloat)pageControlHeight;

@end

NS_ASSUME_NONNULL_END
