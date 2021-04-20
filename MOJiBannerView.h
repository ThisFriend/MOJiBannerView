//
//  MOJiBannerView.h
//  MOJiDict
//
//  Created by Ji Xiang on 2021/1/22.
//  Copyright © 2021 Hugecore Information Technology (Guangzhou) Co.,Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@interface MOJiBannerConfig : NSObject

/*
 配置的参数
 */
// 无法确定会展示何种类型的内容，因此这里只传入图片数据，点击的后续操作根据代理方法自行处理
@property (nonatomic, strong) NSArray<NSString *> *urlArr; // 需要显示的网络数据
@property (nonatomic, strong) NSArray<UIImage *> *imageArr; // 需要显示本地图片数据

@property (nonatomic, assign) CGFloat imageHeight;  // 图片高度，默认是148
@property (nonatomic, assign) CGFloat imageMargin;  // 图片左右内边距，默认是16
@property (nonatomic, assign) CGFloat imageSpacing; // 图片间距，默认是8
@property (nonatomic, assign) CGFloat cornerRadius; // 图片圆角，默认是8

@property (nonatomic, assign) NSTimeInterval timeInterval; // 图片滚动间隔，默认是4s

@property (nonatomic, assign) BOOL pageControlHidden;   // 是否隐藏pageControl, 默认为NO，展示
@property (nonatomic, strong) UIColor *pageSelectColor; // pageControl的圆点选中颜色
@property (nonatomic, strong) UIColor *pageDefaultColor; // pageControl的圆点未选中颜色

@end


@class MOJiBannerView;
@protocol MOJiBannerViewDelegate <NSObject>
@optional

/**
 Banner点击代理
 @param bannerView 本类
 @param currentPage 当前点击下标
 */
- (void)bannerView:(MOJiBannerView *)bannerView didSelectItemAtPage:(NSInteger)page;

@end

@interface MOJiBannerView : UIView

@property (nonatomic, weak) id<MOJiBannerViewDelegate> delegate;
@property (nonatomic, strong) MOJiBannerConfig *config; // 配置内容

- (void)destroyTimer; // 销毁定时器方法
- (NSInteger)maxNumberOfDataGroup; // 轮播图数据的循环组数，默认为3，在特殊情况下使用

@end

NS_ASSUME_NONNULL_END
