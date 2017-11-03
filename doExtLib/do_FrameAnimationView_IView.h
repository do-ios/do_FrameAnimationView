//
//  do_FrameAnimationView_UI.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol do_FrameAnimationView_IView <NSObject>

@required
//属性方法

//同步或异步方法
- (void)startGif:(NSArray *)parms;
- (void)startImages:(NSArray *)parms;
- (void)stop:(NSArray *)parms;


@end