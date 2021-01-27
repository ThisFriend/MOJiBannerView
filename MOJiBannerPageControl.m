//
//  MOJiBannerPageControl.m
//  MOJiDict
//
//  Created by Ji Xiang on 2021/1/25.
//  Copyright © 2021 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiBannerPageControl.h"

static CGFloat const MOJiCarouselPageControlSpace              = 4.0;
static CGFloat const MOJiCarouselPageControlIndicatorW         = 4.0;
static CGFloat const MOJiCarouselPageControlSelectedIndicatorW = 10.0;
static CGFloat const MOJiCarouselPageControlIndicatorH         = 3.0;

@interface MOJiBannerPageControl()
@property (nonatomic, strong) UIView *contentV;
@property (nonatomic, strong) NSMutableArray<UIButton *> *pageIndicators;
@end

@implementation MOJiBannerPageControl

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configViews];
    }
    return self;
}

- (void)configViews {
    self.contentV = UIView.new;
    [self addSubview:self.contentV];
    
    [self.contentV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.bottom.mas_equalTo(self);
        make.height.mas_equalTo(MOJiCarouselPageControlIndicatorH);
    }];
}

- (void)configPageIndicatorsWithNumberOfPages:(NSInteger)numberOfPages {
    if (numberOfPages > self.pageIndicators.count) {
        for (NSInteger i = self.pageIndicators.count; i < numberOfPages; i++) {
            UIButton *pageIndicator = [self createPageIndicator];
            [self.contentV addSubview:pageIndicator];
            [self.pageIndicators addObject:pageIndicator];
        }
    } else if (numberOfPages < self.pageIndicators.count) {
        for (NSInteger i = numberOfPages; i < self.pageIndicators.count; i++) {
            UIButton *pageIndicator = self.pageIndicators[i];
            [pageIndicator removeFromSuperview];
        }
        
        [self.pageIndicators removeObjectsInRange:NSMakeRange(numberOfPages, self.pageIndicators.count - numberOfPages)];
    } else if (numberOfPages == 0) {
        for (NSInteger i = 0; i < self.pageIndicators.count; i++) {
            UIButton *pageIndicator = self.pageIndicators[i];
            [pageIndicator removeFromSuperview];
        }
        
        [self.pageIndicators removeAllObjects];
    } else {
        //如果传进来的页数跟目前一致，什么都不操作
    }
}

- (void)updateTintColorForPageIndicator:(UIButton *)pageIndicator {
    [pageIndicator setBackgroundImage:[UIImage imageWithColor:self.finalPageIndicatorTintColor] forState:UIControlStateNormal];
    [pageIndicator setBackgroundImage:[UIImage imageWithColor:self.finalCurrentPageIndicatorTintColor] forState:UIControlStateSelected];
}

- (UIColor *)finalPageIndicatorTintColor {
    return self.pageIndicatorTintColor ?: [UIColor colorWithRed:216/255.0f green:216/255.0f blue:216/255.0f alpha:1.0];
}

- (UIColor *)finalCurrentPageIndicatorTintColor {
    return self.currentPageIndicatorTintColor ?: [UIColor colorWithRed:255/255.0f green:82/255.0f blue:82/255.0f alpha:1.0];
}

- (void)setCurrentPageIndicatorTintColor:(UIColor *)currentPageIndicatorTintColor {
    _currentPageIndicatorTintColor = currentPageIndicatorTintColor;
 
    for (UIButton *pageIndicator in self.pageIndicators) {
        [pageIndicator setBackgroundImage:[UIImage imageWithColor:self.finalCurrentPageIndicatorTintColor] forState:UIControlStateSelected];
    }
}

- (void)setPageIndicatorTintColor:(UIColor *)pageIndicatorTintColor {
    _pageIndicatorTintColor = pageIndicatorTintColor;
    
    for (UIButton *pageIndicator in self.pageIndicators) {
        [pageIndicator setBackgroundImage:[UIImage imageWithColor:self.finalPageIndicatorTintColor] forState:UIControlStateNormal];
    }
}

- (void)setNumberOfPages:(NSInteger)numberOfPages {
    if (numberOfPages < 0) {
        numberOfPages = 0;
    }
    
    _numberOfPages = numberOfPages;
    
    [self configPageIndicatorsWithNumberOfPages:numberOfPages];
    
    UIButton *lastBtn = nil;
    for (NSInteger i = 0; i < self.pageIndicators.count; i++) {
        UIButton *pageIndicator = self.pageIndicators[i];
        [self updateTintColorForPageIndicator:pageIndicator];
        
        if (i == self.currentPage) {
            pageIndicator.selected = YES;
        } else {
            pageIndicator.selected = NO;
        }
        
        [pageIndicator mas_remakeConstraints:^(MASConstraintMaker *make) {
            if (i == 0) {
                make.left.mas_equalTo(self.contentV);
            } else {
                make.left.mas_equalTo(lastBtn.mas_right).offset(MOJiCarouselPageControlSpace);
            }
            if (i == self.currentPage) {
                make.size.mas_equalTo(CGSizeMake(MOJiCarouselPageControlSelectedIndicatorW, MOJiCarouselPageControlIndicatorH));
            } else {
                make.size.mas_equalTo(CGSizeMake(MOJiCarouselPageControlIndicatorW, MOJiCarouselPageControlIndicatorH));
            }
            
            if (i == self.pageIndicators.count - 1) {
                make.right.mas_equalTo(self.contentV);
            }
            
            make.top.mas_equalTo(self.contentV);
        }];
        
        lastBtn = pageIndicator;
    }
}

- (void)setCurrentPage:(NSInteger)currentPage {
    _currentPage = currentPage;
    
    if (self.pageIndicators.count > 0) {
        for (NSInteger i = 0; i < self.pageIndicators.count; i++) {
            UIButton *pageIndicator = self.pageIndicators[i];
            CGFloat pageIndicatorW = (i == currentPage ? MOJiCarouselPageControlSelectedIndicatorW : MOJiCarouselPageControlIndicatorW);
            pageIndicator.selected = (i == currentPage);
            
            [pageIndicator mas_updateConstraints:^(MASConstraintMaker *make) {
                make.size.mas_equalTo(CGSizeMake(pageIndicatorW, MOJiCarouselPageControlIndicatorH));
            }];
        }
    }
}

+ (CGFloat)pageControlHeight {
    return MOJiCarouselPageControlIndicatorH;
}

- (NSMutableArray<UIButton *> *)pageIndicators {
    if (!_pageIndicators) {
        _pageIndicators = NSMutableArray.array;
    }
    
    return _pageIndicators;
}

- (UIButton *)createPageIndicator {
    UIButton *pageIndicator              = UIButton.new;
    pageIndicator.userInteractionEnabled = NO;
    return pageIndicator;
}

@end
