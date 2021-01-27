//
//  MOJiBannerView.m
//  MOJiDict
//
//  Created by Ji Xiang on 2021/1/22.
//  Copyright © 2021 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import "MOJiBannerView.h"
#import "MOJiBannerPageControl.h"
#import "UIImageView+WebCache.h"

static CGFloat const MOJiBannerViewDefauleImageWidth     = 343; // 按照设计稿大小的默认宽度
static CGFloat const MOJiBannerViewDefaultImageHeight    = 148; // 按照设计稿大小的默认高度
static CGFloat const MOJiBannerViewForVerticalScreen     = 428; // 超出则视为横屏
static CGFloat const MOJiBannerViewDefaultPageTopToImage = 6;   // pageControl距离图片底部的间距

@implementation MOJiBannerConfig
@end

/**
 定时器 用来自动播放图片
 */
static NSTimer * bannerTimer;

@interface MOJiBannerView () <UIScrollViewDelegate>

@property (nonatomic, strong) UIView *contentV;
@property (nonatomic, strong) UIScrollView *mainScrollView;
@property (nonatomic, strong) MOJiBannerPageControl *pageControl;

@property (nonatomic, strong) NSMutableArray *dataArray; // 图片数组（前后各加一组原始数据）
@property (nonatomic, assign) NSInteger dataCount; // 图片数
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL settedDefaultOffset;

@property (nonatomic, strong) MASConstraint *cons_pageControlTopToBannerBottom;
@property (nonatomic, strong) MASConstraint *cons_pageControlToCenterX;
@property (nonatomic, strong) MASConstraint *cons_pageControlHeight;

@end

@implementation MOJiBannerView
- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self destroyTimer];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    //进入前后台都需要激活或者暂停定时器
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)appWillEnterForeground:(NSNotification *)notification {
    [self addTimer];
}

- (void)appDidEnterBackground {
    [self stopTimer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    //旋转的时候，移动到之前保存的索引位置，防止切换到其它位置
    if (self.dataCount > 1) {
        CGFloat offsetX = self.startingOffsetXOfTheDisplayGroup + self.bannerWidthWithSpacing * self.currentPage;
        [self.mainScrollView setContentOffset:CGPointMake(offsetX, 0) animated:NO];
    } else {
        [self.mainScrollView setContentOffset:CGPointZero animated:NO];
    }
    
    for (id subview in self.mainScrollView.subviews) {
        if ([subview isKindOfClass:UIImageView.class]) {
            [subview mas_updateConstraints:^(MASConstraintMaker *make) {
                make.size.mas_equalTo(CGSizeMake(self.bannerWidth, self.bannerHeight));
            }];
        }
    }
}

#pragma mark - config
- (void)setConfig:(MOJiBannerConfig *)config {
    _config = config;
    
    self.currentPage = 0;
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self updataConfigByDefault];
    
    if (config.urlArr.count > 0) {
        [self configBannerArr:config.urlArr];
    } else if (config.imageArr.count > 0) {
        [self configBannerArr:config.imageArr];
    }
    
    [self configViews];
    
    // 刷新数据
    [self refreshTheData];
    
    //初始化时加载定时器
    [self addTimer];
}

- (void)configViews {
    self.contentV = UIView.new;
    [self addSubview:self.contentV];
    [self.contentV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self);
    }];
    
    [self.contentV addSubview:self.mainScrollView];
    [self.mainScrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.contentV);
        make.left.mas_equalTo(self.contentV).offset(self.config.imageMargin);
        make.right.mas_equalTo(self.contentV).offset(-self.config.imageMargin);
        make.height.mas_equalTo(self.config.imageHeight);
    }];
    
    
    if (!self.config.hidePageContol && self.dataArray.count > 1) {
        self.pageControl = [[MOJiBannerPageControl alloc] init];
        [self.contentV addSubview:self.pageControl];
        [self pageControlDidRemakeConstraints];
        
        //重新初始化pageControl相关参数
        self.pageControl.pageIndicatorTintColor         = self.config.pageDefaultColor;
        self.pageControl.currentPageIndicatorTintColor  = self.config.pageSelectColor;
        self.pageControl.numberOfPages                  = self.dataCount;
        self.pageControl.currentPage                    = 0;
    } else {
        [self pageControlDidRemoveConstraints];
    }
}

- (void)updataConfigByDefault {
    self.config.imageHeight         = self.config.imageHeight ?: self.defaultConfig.imageHeight;
    self.config.imageMargin         = self.config.imageMargin ?: self.defaultConfig.imageMargin;
    self.config.imageSpacing        = self.config.imageSpacing ?: self.defaultConfig.imageSpacing;
    self.config.cornerRadius        = self.config.cornerRadius ?: self.defaultConfig.cornerRadius;
    self.config.timeInterval        = self.config.timeInterval ?: self.defaultConfig.timeInterval;
    self.config.hidePageContol      = self.config.hidePageContol ?: self.defaultConfig.hidePageContol;
    self.config.pageSelectColor     = self.config.pageSelectColor ?: self.defaultConfig.pageSelectColor;
    self.config.pageDefaultColor    = self.config.pageDefaultColor ?: self.defaultConfig.pageDefaultColor;
}

- (void)configBannerArr:(NSArray *)arr {
    self.dataCount = arr.count;
    if (self && arr.count > 1) {
        self.dataArray = NSMutableArray.array;
        /**
         前后各加一组数据，防止横屏的情况下，因为图片大小的原因，最左和最右部分显示空白。
         注意：在图片个数非常少，且图片宽度不够的情况下，还是会造成此问题
         此时可以通过继承，然后重写方法解决，根据UI设计，基本不会用到
         */
        for (NSInteger i = 0; i < self.dataGroupNum; i++) {
            [self.dataArray addObjectsFromArray:arr];
        }
    } else {
        self.dataArray = [arr mutableCopy];
    }
}

// 刷新数据
- (void)refreshTheData {
    UIImageView *lastImgV = nil;
    for (NSInteger i = 0; i < self.dataArray.count; i ++) {
        UIImageView *imgV           = UIImageView.new;
        imgV.contentMode            = UIViewContentModeScaleAspectFill;
        imgV.clipsToBounds          = YES;
        imgV.layer.cornerRadius     = self.config.cornerRadius;
        imgV.layer.masksToBounds    = YES;
        imgV.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
        [imgV addGestureRecognizer:tap];
        
        [self.mainScrollView addSubview:imgV];
        
        id dataInfo = [self.dataArray objectAtIndex:i];
        if ([dataInfo isKindOfClass:[NSString class]]) {
            NSString *str = [self.dataArray objectAtIndex:i];
            [imgV sd_setImageWithURL:[NSURL URLWithString:str] placeholderImage:MDUIUtils.placeholderImage];
        } else {
            UIImage *image = [self.dataArray objectAtIndex:i];
            imgV.image     = image;
        }
        
        [imgV mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.mainScrollView);
            if (lastImgV) {
                make.left.mas_equalTo(lastImgV.mas_right).offset(self.config.imageSpacing);
            } else {
                make.left.mas_equalTo(self.mainScrollView);
            }
            make.size.mas_equalTo(CGSizeMake(self.bannerWidth, self.bannerHeight));
        }];
        lastImgV = imgV;
    }
}

- (void)pageControlDidRemoveConstraints {
    [self.cons_pageControlTopToBannerBottom uninstall];
    [self.cons_pageControlToCenterX         uninstall];
    [self.cons_pageControlHeight            uninstall];
}

- (void)pageControlDidRemakeConstraints {
    [self.pageControl mas_makeConstraints:^(MASConstraintMaker *make) {
        self.cons_pageControlTopToBannerBottom = make.top.mas_equalTo(self.mainScrollView.mas_bottom).offset(MOJiBannerViewDefaultPageTopToImage);
        self.cons_pageControlToCenterX = make.centerX.width.mas_equalTo(self.contentV);
        self.cons_pageControlHeight = make.height.mas_equalTo(MOJiBannerPageControl.pageControlHeight);
    }];
}

// 点击图片触发的手势方法
- (void)tapAction:(UITapGestureRecognizer *)tap {
    if ([self.delegate respondsToSelector:@selector(selectBannerView:currentPage:)]) {
        [self.delegate selectBannerView:self currentPage:self.currentPage];
    }
}

#pragma mark - scrollView delegate
// 滚动视图开始手动拖拽时出发
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (bannerTimer && self.dataArray.count > 1) {
        [bannerTimer setFireDate:[NSDate distantFuture]];
    }
}

// 滚动视图正在滚动 (拖拽过程中触发的方法)
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.currentPage             = [self getCurrentPageWithOffsetX:scrollView.contentOffset.x];
    self.pageControl.currentPage = self.currentPage;
}

// 滚动视图完成减速时调用 (就是手动拖拽完成后)
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self changeTheScrollViewOffSet:scrollView];
}

// 滚动视图完成减速时调用 (就是手动拖拽完成后)
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self changeTheScrollViewOffSet:scrollView];
}

// 手动拖动视图抬起时，decelerate为NO说明定死位置，为YES说明还在继续滚动，走scrollViewDidEndScrollingAnimation方法
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self changeTheScrollViewOffSet:scrollView];
    }
}

- (void)changeTheScrollViewOffSet:(UIScrollView *)scrollView {
    if (bannerTimer && self.dataArray.count > 1) {
        /**
         设置定时器的触发时间
         延后2秒后触发
         */
        [bannerTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:2.f]];
    }
    
    //获取当前滚动视图的偏移量
    CGFloat currentPointX = scrollView.contentOffset.x;
    //获取就近的一个图片
    CGFloat nearbyNum     = roundf(currentPointX / self.bannerWidthWithSpacing);
    //获取当前应该展示的内容下标
    NSInteger currentPage = [self getCurrentPageWithOffsetX:currentPointX];
    
    WEAKSELF
    [UIView animateWithDuration:0.2 animations:^{
        wSelf.mainScrollView.contentOffset = CGPointMake(nearbyNum * wSelf.bannerWidthWithSpacing, 0);
        wSelf.currentPage                  = currentPage;
        wSelf.pageControl.currentPage      = currentPage;
    } completion:^(BOOL finished) {
        wSelf.mainScrollView.contentOffset = CGPointMake(self.startingOffsetXOfTheDisplayGroup + currentPage * wSelf.bannerWidthWithSpacing, 0);
    }];
    
}

#pragma mark - timer
// 初始化定时器
- (void)addTimer {
    if (self.dataArray.count < 2) return;
    [self stopTimer];
    
    //初始化定时器 时间戳:X秒 目标:本类 方法选择器:timerFunction 用户信息:nil 是否循环:yes
    bannerTimer = [NSTimer scheduledTimerWithTimeInterval:self.config.timeInterval target:self selector:@selector(timerFunctiontion:) userInfo:nil repeats:YES];
    
    /**
     将定时器添加到当前线程中(currentRunLoop 当前线程)
     [NSRunLoop currentRunLoop]可以的到一个当前线程下的NSRunLoop对象
     addTimer:添加一个定时器
     forMode:什么模式
     NSRunLoopCommonModes 共同模式
     */
    [[NSRunLoop currentRunLoop] addTimer:bannerTimer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    if (!bannerTimer) return;
    
    [bannerTimer invalidate];
}

// 销毁定时器
- (void)destroyTimer {
    [bannerTimer invalidate];
    bannerTimer = nil;
}

// 实现定时器方法
- (void)timerFunctiontion:(NSTimer *)timer {
    
    // 获取当前图片的位置
    CGFloat currentX = self.mainScrollView.contentOffset.x;
    // 获取下一张图片的位置
    CGFloat nextX = currentX + self.bannerWidthWithSpacing;
    // 获取显示组后第一张图片的位置
    CGFloat lastGroupFirstX = (self.dataGroupNum / 2 + 1) * self.oneGroupWidth;
    
    WEAKSELF
    //如果滚动视图上将要显示的下一张图片是第一张时
    if (nextX == lastGroupFirstX) {
        [UIView animateWithDuration:0.2 animations:^{
            wSelf.mainScrollView.contentOffset = CGPointMake(nextX, 0);
            wSelf.currentPage                  = 0;
            wSelf.pageControl.currentPage      = wSelf.currentPage;
        } completion:^(BOOL finished) {
            //移动到第一张图片
            wSelf.mainScrollView.contentOffset = CGPointMake((lastGroupFirstX - self.oneGroupWidth), 0);
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            wSelf.mainScrollView.contentOffset = CGPointMake(nextX, 0);
            wSelf.currentPage                  = [wSelf getCurrentPageWithOffsetX:nextX];
            wSelf.pageControl.currentPage      = wSelf.currentPage;
        } completion:^(BOOL finished) {}];
    }
}

// 获取当前坐标位置对应的下标，currentPage
- (NSInteger)getCurrentPageWithOffsetX:(CGFloat)offsetX {
    NSInteger num = roundf(offsetX / self.bannerWidthWithSpacing);
    return num % self.dataGroupNum;
}

#pragma mark - setter/getter
- (UIScrollView *)mainScrollView {
    if (!_mainScrollView) {
        _mainScrollView               = UIScrollView.new;
        _mainScrollView.delegate      = self;
        _mainScrollView.scrollEnabled = YES;
        _mainScrollView.bounces       = NO;
        _mainScrollView.showsVerticalScrollIndicator   = NO;
        _mainScrollView.showsHorizontalScrollIndicator = NO;
        _mainScrollView.clipsToBounds = NO;
        
        if (self.dataArray.count > 1) {
            _mainScrollView.contentSize = CGSizeMake(self.dataArray.count * self.bannerWidthWithSpacing - self.config.imageSpacing, self.bannerHeight);
        } else {
            _mainScrollView.contentSize = CGSizeMake(self.bannerWidth, self.bannerHeight);
        }
    }
    return _mainScrollView;
}

- (MOJiBannerConfig *)defaultConfig {
    MOJiBannerConfig *defaultConfig = MOJiBannerConfig.new;
    defaultConfig.imageHeight       = MOJiBannerViewDefaultImageHeight;
    defaultConfig.imageMargin       = 16;
    defaultConfig.imageSpacing      = 8;
    defaultConfig.timeInterval      = 4;
    defaultConfig.cornerRadius      = 8;
    
    defaultConfig.hidePageContol    = NO;
    defaultConfig.pageSelectColor   = UIColorFromRGB(0xFF4E4E);
    defaultConfig.pageDefaultColor  = UIColorFromRGB(0xD8D8D8);
    return defaultConfig;
}

// 一张图的宽度
- (CGFloat)bannerWidth {
    // 刚进入的时候frame为zero
    if (self.frame.size.width == 0) {
        return MOJiBannerViewDefauleImageWidth;
    }
    
    // 这里按照iPhone12 Pro Max最大屏幕宽度428来计算，超过即视为横屏
    if (self.frame.size.width > MOJiBannerViewForVerticalScreen) {
        return MOJiBannerViewDefauleImageWidth;
    } else {
        return self.frame.size.width - 2 * self.config.imageMargin;
    }
}

// 一张图的高度
- (CGFloat)bannerHeight {
    return self.config.imageHeight;
}

// 一张图加一个图间距的宽度，方便计算
- (CGFloat)bannerWidthWithSpacing {
    return self.bannerWidth + self.config.imageSpacing;
}

/**
 设置为奇数！！！
 最小为3！！！
 可由子类重写！
 */
- (NSInteger)maxNumberOfDataGroup {
    return 3;
}

// 对maxNumberOfDataGroup的修正
- (NSInteger)dataGroupNum {
    if (self.maxNumberOfDataGroup < 3) {
        return 3;
    }
    
    return (self.maxNumberOfDataGroup % 2 > 0) ? self.maxNumberOfDataGroup : (self.maxNumberOfDataGroup + 1);
}

// 一组数据的展示宽度，方便计算
- (CGFloat)oneGroupWidth {
    return self.dataCount * self.bannerWidthWithSpacing;
}

// 用于显示的一组图片的起始位置
- (CGFloat)startingOffsetXOfTheDisplayGroup {
    return (self.dataGroupNum - 1 ) / 2 * self.oneGroupWidth;
}

@end
