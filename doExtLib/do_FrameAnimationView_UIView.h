//
//  do_FrameAnimationView_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_FrameAnimationView_IView.h"
#import "do_FrameAnimationView_UIModel.h"
#import "doIUIModuleView.h"

@interface do_FrameAnimationView_UIView : UIView<do_FrameAnimationView_IView, doIUIModuleView>
//可根据具体实现替换UIView
{
	@private
		__weak do_FrameAnimationView_UIModel *_model;
}

@end
