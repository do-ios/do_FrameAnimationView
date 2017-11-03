//
//  do_FrameAnimationView_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_FrameAnimationView_UIView.h"

#import "doInvokeResult.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doJsonHelper.h"
#import "doIOHelper.h"
#import <ImageIO/ImageIO.h>
#import <QuartzCore/CoreAnimation.h>
#define MAXREPEAT 65535

@interface ImageObj : NSObject
@property(nonatomic , strong) NSString *imgUrl;
@property(nonatomic , assign) float duration;
@end

@implementation ImageObj
@synthesize imgUrl,duration;
@end

@implementation do_FrameAnimationView_UIView
{
    NSMutableArray *_imgs;
    NSInteger _repeat;
    NSInteger runCount;
    
    BOOL isGif;

    NSMutableArray *_frames;
    NSMutableArray *_frameDelayTimes;
    
    CGFloat _totalTime;         // seconds
    
    NSString *gifPath;
    
    CGImageSourceRef  _gifSourceRef;
    
    size_t _frameCount;
    size_t _index;

    CADisplayLink *_displayLink;
    
    //wtc code
    //解析gif后每一张图片的显示时间
    NSMutableArray *timeArray;
    //解析gif后的每一张图片数组
    NSMutableArray *imageArray;
    //gif动画总时间
    CGFloat totalTime;
    //gif宽度
    CGFloat width;
    //gif高度
    CGFloat height;
    BOOL isAnimating;
}


#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    isGif = NO;
    gifPath = @"";
    runCount = 0;
    
    self.contentMode = UIViewContentModeScaleAspectFit;
    
    isAnimating = NO;
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性,view-model(UIModel)类销毁时会递归调用<子view-model(UIModel)>的该方法，将上层的引用切断。所以如果self类有非原生扩展，需主动调用view-model(UIModel)的该方法。(App || Page)-->强引用-->view-model(UIModel)-->强引用-->view
    [self.layer removeAllAnimations];
    [self invalidateGIF];
    [_imgs removeAllObjects];
    _imgs = nil;
    [_frames removeAllObjects];
    _frames = nil;
    [_frameDelayTimes removeAllObjects];
    _frameDelayTimes = nil;

    [timeArray removeAllObjects];
    timeArray = nil;
    [imageArray removeAllObjects];
    imageArray = nil;
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改,如果添加了非原生的view需要主动调用该view的OnRedraw，递归完成布局。view(OnRedraw)<显示布局>-->调用-->view-model(UIModel)<OnRedraw>
    
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
- (void)startGif:(NSArray *)parms
{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer removeAllAnimations];
        self.layer.contents = nil;
    });
    
//    [self invalidateGIF];
    
    NSDictionary * _dictParms = [parms objectAtIndex:0];
    if ([doJsonHelper GetOneInteger:_dictParms :@"repeat" :1] == 0) {
        return;
    }
    
    //自己的代码实现

    [self initialization:parms];

    NSDictionary *_dictParas = [parms objectAtIndex:0];
    
    gifPath = [doJsonHelper GetOneText:_dictParas :@"data" :@""];
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    
//    CGImageSourceRef gifSourceRef;
    
    NSString *path = [doIOHelper GetLocalFileFullPath:_scritEngine.CurrentApp :gifPath];
    
    imageArray = [NSMutableArray array];
    timeArray = [NSMutableArray array];
    configImage((__bridge CFURLRef)[NSURL fileURLWithPath:path], timeArray, imageArray, &width,&height,&totalTime);
    
//    gifSourceRef = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
//    if (!gifSourceRef) {
//        return;
//    }
//    _gifSourceRef = gifSourceRef;
//    _frameCount = CGImageSourceGetCount(_gifSourceRef);
//
//    dispatch_async(dispatch_get_main_queue(), ^{
//        _frameCount = CGImageSourceGetCount(_gifSourceRef);
//    });
//    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(play)];
//    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    
    [self playGIF];
}

void configImage(CFURLRef url,NSMutableArray *timeArray,NSMutableArray *imageArray,CGFloat *width,CGFloat *height,CGFloat *totalTime)
{
    
    NSDictionary *gifProperty = [NSDictionary dictionaryWithObject:@{@0:(NSString *)kCGImagePropertyGIFLoopCount} forKey:(NSString *)kCGImagePropertyGIFDictionary];
    //拿到ImageSourceRef后获取gif内部图片个数
    CGImageSourceRef ref = CGImageSourceCreateWithURL(url, (CFDictionaryRef)gifProperty);
    size_t count = CGImageSourceGetCount(ref);
    
    for (int i = 0; i < count; i++) {
        
        //添加图片
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(ref, i, (CFDictionaryRef)gifProperty);
        [imageArray addObject:CFBridgingRelease(imageRef)];
        
        //取每张图片的图片属性,是一个字典
        NSDictionary *dict = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(ref, i, (CFDictionaryRef)gifProperty));
        
        //取宽高
        if (width != NULL && height != NULL) {
            *width = [[dict valueForKey:(NSString *)kCGImagePropertyPixelWidth] floatValue];
            *height = [[dict valueForKey:(NSString *)kCGImagePropertyPixelHeight] floatValue];
        }
        
        //添加每一帧时间
        NSDictionary *tmp = [dict valueForKey:(NSString *)kCGImagePropertyGIFDictionary];
        [timeArray addObject:[tmp valueForKey:(NSString *)kCGImagePropertyGIFDelayTime]];
        
        //总时间
        *totalTime = *totalTime + [[tmp valueForKey:(NSString *)kCGImagePropertyGIFDelayTime] floatValue];
    }
}

- (void) playGIF {
    
    isAnimating = YES;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    
    //获取每帧动画起始时间在总时间的百分比
    NSMutableArray *percentageArray = [NSMutableArray array];
    CGFloat currentTime = 0.0;
    for (int i = 0; i < timeArray.count; i++) {
        NSNumber *percentage = [NSNumber numberWithFloat:currentTime/totalTime];
        [percentageArray addObject:percentage];
        currentTime = currentTime + [[timeArray objectAtIndex:i] floatValue];
    }
    [animation setKeyTimes:percentageArray];
    
    //添加每帧动画
    [animation setValues:imageArray];
    [imageArray removeAllObjects];
    //动画信息基本设置
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;

    [animation setDuration:totalTime];
    [animation setDelegate:self];
    [animation setRepeatCount:_repeat];
    
    //添加动画
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer addAnimation:animation forKey:@"gif"];
    });
    
    totalTime = 0.0;
}


- (void)invalidateGIF
{
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_displayLink invalidate];
    _displayLink = nil;
    if (_gifSourceRef) {
        CFRelease(_gifSourceRef);
        _gifSourceRef = nil;
    }
}

- (void)play{

    if (_index == _frameCount-1) {
        if (runCount >= _repeat) {
            [self invalidateGIF];
            _index = 0;
            return;
        }
        runCount ++;
    }
    if (!_gifSourceRef) {
        [self invalidateGIF];
        return ;
    }
    float nextFrameDuration = [self frameDurationAtIndex:MIN(_index+1, _frameCount-1)];
    
    if (_totalTime < nextFrameDuration) {
        _totalTime += _displayLink.duration;
        return;
    }
    
    _index ++;
    _index = _index%_frameCount;
    CGImageRef ref = CGImageSourceCreateImageAtIndex(_gifSourceRef, _index, NULL);
    self.layer.contents = (__bridge id)(ref);
    CGImageRelease(ref);
    _totalTime = 0;
    

}


- (float)frameDurationAtIndex:(size_t)index{
    CFDictionaryRef dictRef = CGImageSourceCopyPropertiesAtIndex(_gifSourceRef, index, NULL);
    NSDictionary *dict = (__bridge NSDictionary *)dictRef;
    NSDictionary *gifDict = (dict[(NSString *)kCGImagePropertyGIFDictionary]);
    NSNumber *unclampedDelayTime = gifDict[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    NSNumber *delayTime = gifDict[(NSString *)kCGImagePropertyGIFDelayTime];
    if (unclampedDelayTime.floatValue) {
        return unclampedDelayTime.floatValue;
    }else if (delayTime.floatValue) {
        return delayTime.floatValue;
    }else{
        return 1/24.0;
    }
}


- (void)startImages:(NSArray *)parms
{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer removeAllAnimations];
        self.layer.contents = nil;
    });
    
    NSDictionary * _dictParms = [parms objectAtIndex:0];
    if ([doJsonHelper GetOneInteger:_dictParms :@"repeat" :1] == 0) {
        return;
    }
    
    //自己的代码实现
    isGif = NO;
    [self initialization:parms];
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    _imgs = [NSMutableArray array];
    NSArray *a = [doJsonHelper GetOneArray:_dictParas :@"data"];
    for (NSInteger i = 0; i<a.count; i++) {
        id obj = [a objectAtIndex:i];
        ImageObj *img = [[ImageObj alloc] init];
        img.imgUrl = [doJsonHelper GetOneText:obj :@"path" :@""];
        img.duration = [doJsonHelper GetOneInteger:obj :@"duration" :0]/1000.0;
        [_imgs addObject:img];
    }
    [self playImgs:parms];
}

- (void)initialization:(NSArray *)parms
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
        [self.layer removeAllAnimations];
    });

    NSDictionary *_dictParas = [parms objectAtIndex:0];
    _repeat = [doJsonHelper GetOneInteger:_dictParas :@"repeat" :1];
    if (_repeat < 0){
        _repeat = MAXREPEAT;
    }
   
    _frames = [NSMutableArray array];
    _frameDelayTimes = [NSMutableArray array];
    _totalTime = 0.0f;
}
#pragma mark -
#pragma mark - 同步异步方法的实现

- (void)stop:(NSArray *)parms
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer removeAllAnimations];
        self.layer.contents = [_frames lastObject];
    });
    [self invalidateGIF];
}

#pragma mark - playGif
#pragma mark - playImgs
- (void)playImgs:(NSArray *)parms
{
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];

    _frameDelayTimes = [NSMutableArray array];
    _totalTime = 0;
    for (NSInteger i = 0; i<_imgs.count; i++) {
        ImageObj *img = [self getImg:i];
        NSString *path = img.imgUrl;
        path = [doIOHelper GetLocalFileFullPath:_scritEngine.CurrentApp :path];
        CGImageRef image = [UIImage imageWithContentsOfFile:path].CGImage;
        if (image) {
            [_frameDelayTimes addObject:@(img.duration)];
            [_frames addObject:(__bridge id)image];
            _totalTime += img.duration;
        }
    }

    [self playContent];
}

- (ImageObj *)getImg:(NSInteger)index
{
    return  [_imgs objectAtIndex:index];
}


#pragma mark - play content
- (void)playContent
{
    self.layer.speed = 1.0;
    self.contentMode = UIViewContentModeScaleAspectFit;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:3];
    CGFloat currentTime = 0;
    NSInteger count = _frameDelayTimes.count;
    for (int i = 0; i < count; ++i) {
        [times addObject:[NSNumber numberWithFloat:(currentTime / _totalTime)]];
        currentTime += [[_frameDelayTimes objectAtIndex:i] floatValue];
    }
    [times addObject:@(1.000)];

    [animation setKeyTimes:times];
    
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:3];

    images  = [NSMutableArray arrayWithArray:_frames];
    
    [_frames removeAllObjects];
    
    [animation setValues:images];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    animation.cumulative = YES;
    animation.calculationMode =  kCAAnimationDiscrete;
    animation.duration = _totalTime;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    animation.delegate = self;
    animation.repeatCount = _repeat;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.layer addAnimation:animation forKey:@"frameAnimation"];
    });
}

#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}

@end
