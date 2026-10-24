// Frozen desktop selection with in-place annotations. Selection geometry lives in Rust.
#import "selection.h"
@class CaptureSession;
@interface CaptureWindow:NSWindow
@end
@implementation CaptureWindow
-(BOOL)canBecomeKeyWindow{return YES;}
-(BOOL)canBecomeMainWindow{return YES;}
@end
@interface CaptureCanvas:Canvas
@property BOOL interactive;
@property BOOL showHandles;
@property(copy) void(^cancelCapture)(void);
@end
@implementation CaptureCanvas
-(void)drawRect:(NSRect)dirty{
    [super drawRect:dirty];
    if(self.showHandles){
        NSColor *stroke=[NSColor colorWithSRGBRed:104./255 green:139./255 blue:222./255 alpha:.7];[stroke setStroke];
        NSBezierPath *border=[NSBezierPath bezierPathWithRect:self.bounds];border.lineWidth=4;[border stroke];
        for(int y=0;y<3;y++)for(int x=0;x<3;x++)if(x!=1||y!=1){
            NSBezierPath *circle=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x*self.bounds.size.width/2-4,y*self.bounds.size.height/2-4,8,8)];
            [NSColor.whiteColor setFill];[circle fill];[stroke setStroke];circle.lineWidth=2;[circle stroke];
        }
    }
}
-(void)keyDown:(NSEvent*)event{[self.superview keyDown:event];}
-(NSView*)hitTest:(NSPoint)p{return self.interactive?[super hitTest:p]:nil;}
-(void)cancelOperation:(id)sender{if(self.cancelCapture)self.cancelCapture();}
@end
// Reuse capture pixels directly; TIFF roundtrips block the main thread on Retina desktops.
static NSBitmapImageRep *CaptureBitmap(NSImage *image){
    for(NSImageRep *rep in image.representations)if([rep isKindOfClass:NSBitmapImageRep.class])return (NSBitmapImageRep*)rep;
    CGImageRef pixels=[image CGImageForProposedRect:NULL context:nil hints:nil];
    return pixels?[[NSBitmapImageRep alloc]initWithCGImage:pixels]:nil;
}
static NSImage *CaptureAsset(NSString *name){
    static NSMutableDictionary<NSString*,NSImage*> *cache;static dispatch_once_t once;
    dispatch_once(&once,^{cache=[NSMutableDictionary dictionary];});
    NSImage *cached=cache[name];if(cached)return cached;
    NSString *base=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"snip-toolbar"];
    if(![[NSFileManager defaultManager]fileExistsAtPath:base])base=[NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:@"assets/snip-toolbar"];
    NSImage *image=[[NSImage alloc]initWithContentsOfFile:[base stringByAppendingPathComponent:[name stringByAppendingString:@".png"]]];
    NSBitmapImageRep *retina=[[NSBitmapImageRep alloc]initWithData:[NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:[name stringByAppendingString:@"@2x.png"]]]];
    if(retina){retina.size=image.size;[image addRepresentation:retina];}if(image)cache[name]=image;return image;
}
static NSImage *CaptureEraserIcon(BOOL selected){
    return [NSImage imageWithSize:NSMakeSize(32,32) flipped:NO drawingHandler:^BOOL(NSRect rect){
        if(selected){[[NSColor colorWithWhite:.08 alpha:1]setFill];[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect,1,1) xRadius:3 yRadius:3]fill];}
        NSBezierPath *body=[NSBezierPath bezierPath];[body moveToPoint:NSMakePoint(6,12)];[body lineToPoint:NSMakePoint(19,25)];[body lineToPoint:NSMakePoint(28,16)];[body lineToPoint:NSMakePoint(16,4)];[body lineToPoint:NSMakePoint(13,4)];[body closePath];
        [NSColor.whiteColor setFill];[body fill];
        NSBezierPath *cap=[NSBezierPath bezierPath];[cap moveToPoint:NSMakePoint(6,12)];[cap lineToPoint:NSMakePoint(12,18)];[cap lineToPoint:NSMakePoint(22,10)];[cap lineToPoint:NSMakePoint(16,4)];[cap lineToPoint:NSMakePoint(13,4)];[cap closePath];
        [NSColor.grayColor setFill];[cap fill];return YES;
    }];
}
static NSImage *CapturePenIcon(BOOL selected){
    return [NSImage imageWithSize:NSMakeSize(32,32) flipped:NO drawingHandler:^BOOL(NSRect rect){
        if(selected){[[NSColor colorWithWhite:.08 alpha:1]setFill];[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect,1,1) xRadius:3 yRadius:3]fill];}
        NSBezierPath *nib=[NSBezierPath bezierPath];[nib moveToPoint:NSMakePoint(5,5)];[nib lineToPoint:NSMakePoint(10,22)];[nib lineToPoint:NSMakePoint(18,26)];[nib lineToPoint:NSMakePoint(26,18)];[nib lineToPoint:NSMakePoint(22,10)];[nib closePath];
        [NSColor.whiteColor setFill];[nib fill];
        [[NSColor colorWithWhite:.2 alpha:1]setStroke];NSBezierPath *slit=[NSBezierPath bezierPath];slit.lineWidth=1.5;[slit moveToPoint:NSMakePoint(5,5)];[slit lineToPoint:NSMakePoint(15,15)];[slit stroke];
        [[NSColor colorWithWhite:.2 alpha:1]setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(13,13,4,4)]fill];
        return YES;
    }];
}
static NSImage *CaptureMosaicIcon(BOOL selected){
    return [NSImage imageWithSize:NSMakeSize(32,32) flipped:NO drawingHandler:^BOOL(NSRect rect){
        if(selected){[[NSColor colorWithWhite:.08 alpha:1]setFill];[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect,1,1) xRadius:3 yRadius:3]fill];}
        for(int y=0;y<3;y++)for(int x=0;x<3;x++){[[NSColor colorWithWhite:((x+y)%3)*.25+.4 alpha:1]setFill];NSRectFill(NSMakeRect(6+x*7,6+y*7,6,6));}return YES;
    }];
}
@interface CaptureToolbar:NSView
@property NSImage *background;
@end
@implementation CaptureToolbar
-(BOOL)isFlipped{return YES;}
-(void)drawRect:(NSRect)dirty{[self.background drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];}
@end
@interface CaptureView:NSView
@property(weak) CaptureSession *session;
@property NSImage *background;
@property NSBitmapImageRep *backgroundBitmap;
@property NSScreen *screen;
@property void *selection;
@property CaptureCanvas *canvas;
@property CaptureToolbar *toolbar;
@property NSMutableArray<NSButton*> *toolButtons;
@property NSMutableArray<NSButton*> *strokeButtons;
@property NSTextField *sizeLabel;
@property BOOL selecting;
@property BOOL gestureMoved;
@property NSPoint downPoint;
@property NSPoint pointer;
@property NSRect hoverRect;
@property NSArray *windowRects;
@property NSInteger annotationTool;
@property BOOL editing;
@property NSTrackingArea *tracking;
-(void)syncSelection:(BOOL)reset;
-(void)finishCopy:(id)sender;
-(void)finishSave:(id)sender;
@end
@interface CaptureSession:NSObject
@property NSMutableArray<CaptureWindow*> *windows;
@property NSMutableArray<CaptureView*> *views;
@property(copy) void(^completion)(NSImage*,BOOL,BOOL);
@property BOOL finished;
@property BOOL pinOnFinish;
-(void)showImages:(NSArray<NSImage*>*)images screens:(NSArray<NSScreen*>*)screens;
-(void)finish:(CaptureView*)view save:(BOOL)save;
-(void)cancel;
@end
@implementation CaptureView
-(instancetype)initWithFrame:(NSRect)frame{
    if(self=[super initWithFrame:frame]){
        self.selection=rust_selection_new();rust_selection_reset(self.selection,frame.size.width,frame.size.height);
        self.annotationTool=-1;
        self.canvas=[[CaptureCanvas alloc]initWithFrame:NSZeroRect];
        __weak CaptureView *weakSelf=self;self.canvas.cancelCapture=^{[weakSelf.session cancel];};self.canvas.hidden=YES;rust_model_set_width(self.canvas.model,4);rust_model_set_color(self.canvas.model,(RColor){1,0,0,1});[self addSubview:self.canvas];
        self.toolbar=[[CaptureToolbar alloc]initWithFrame:NSMakeRect(0,0,345,79)];self.toolbar.background=CaptureAsset(@"bg_toolbar");self.toolbar.hidden=YES;[self addSubview:self.toolbar];
        self.toolButtons=[NSMutableArray array];
        NSArray *names=@[@"rectangle",@"ellipse",@"arrow",@"curve",@"text",@"eraser",@"mosaic",@"pin",@"cancel",@"done"];
        NSArray *tips=@[@"矩形",@"椭圆",@"箭头",@"画笔",@"文字",@"橡皮擦（仅擦除标注）",@"马赛克",@"钉到桌面",@"取消 Esc",@"完成并复制 Enter"];
        CGFloat xs[]={5,36,67,98,129,160,191,225,277,308};
        const int order[]={3,0,1,2,4,5,6,7,8,9};
        for(int slot=0;slot<10;slot++){
            int i=order[slot];
            NSButton *button=[NSButton buttonWithImage:(i==3?CapturePenIcon(NO):i==5?CaptureEraserIcon(NO):i==6?CaptureMosaicIcon(NO):i==7?[NSImage imageWithSystemSymbolName:@"pin" accessibilityDescription:@"钉到桌面"]:CaptureAsset([@"ico_" stringByAppendingString:names[i]])) target:self action:i<7?@selector(selectTool:):(i==7?@selector(finishPin:):(i==8?@selector(cancel:):@selector(finishCopy:)))];
            button.alternateImage=i==3?CapturePenIcon(YES):i==5?CaptureEraserIcon(YES):i==6?CaptureMosaicIcon(YES):i==7?nil:CaptureAsset([NSString stringWithFormat:@"ico_%@_active",names[i]]);button.tag=i;button.bordered=NO;button.frame=NSMakeRect(xs[slot],3,32,32);button.imageScaling=NSImageScaleNone;button.toolTip=tips[i];button.accessibilityLabel=tips[i];
            if(i==7)button.contentTintColor=NSColor.systemBlueColor;
            if(i<7){[button setButtonType:NSButtonTypeToggle];[self.toolButtons addObject:button];}
            [self.toolbar addSubview:button];
        }
        self.strokeButtons=[NSMutableArray array];
        for(int i=0;i<3;i++){
            NSString *name=@[@"s",@"m",@"l"][i];NSButton *b=[NSButton buttonWithImage:CaptureAsset([@"ico_stroke_" stringByAppendingString:name]) target:self action:@selector(chooseWidth:)];
            b.alternateImage=CaptureAsset([NSString stringWithFormat:@"ico_stroke_%@_active",name]);[b setButtonType:NSButtonTypeToggle];b.tag=i;b.bordered=NO;b.frame=NSMakeRect(5+31*i,44,32,32);b.toolTip=@[@"细",@"中",@"粗"][i];b.accessibilityLabel=b.toolTip;b.state=i==1?NSControlStateValueOn:NSControlStateValueOff;[self.strokeButtons addObject:b];[self.toolbar addSubview:b];
        }
        NSArray<NSColor*> *colors=@[NSColor.redColor,NSColor.yellowColor,NSColor.greenColor,NSColor.blueColor,NSColor.blackColor,NSColor.whiteColor];
        for(NSUInteger i=0;i<colors.count;i++){
            NSButton *b=[NSButton buttonWithTitle:@"" target:self action:@selector(chooseColor:)];b.tag=i;b.bordered=NO;b.wantsLayer=YES;b.layer.backgroundColor=[colors[i]colorUsingColorSpace:NSColorSpace.sRGBColorSpace].CGColor;b.layer.borderColor=NSColor.grayColor.CGColor;b.layer.borderWidth=1;b.frame=NSMakeRect(109+i*21,51,18,18);b.toolTip=@[@"红色",@"黄色",@"绿色",@"蓝色",@"黑色",@"白色"][i];b.accessibilityLabel=b.toolTip;[self.toolbar addSubview:b];
        }
        self.sizeLabel=[NSTextField labelWithString:@""];self.sizeLabel.font=[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];self.sizeLabel.textColor=NSColor.whiteColor;self.sizeLabel.drawsBackground=YES;self.sizeLabel.backgroundColor=[NSColor colorWithWhite:0 alpha:.75];self.sizeLabel.hidden=YES;[self addSubview:self.sizeLabel];

    }return self;
}
-(void)dealloc{rust_selection_free(self.selection);}
-(BOOL)isFlipped{return YES;}
-(BOOL)acceptsFirstResponder{return YES;}
-(void)updateTrackingAreas{
    [super updateTrackingAreas];if(self.tracking)[self removeTrackingArea:self.tracking];
    self.tracking=[[NSTrackingArea alloc]initWithRect:self.bounds options:NSTrackingMouseMoved|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:nil];[self addTrackingArea:self.tracking];
}
-(void)resetCursorRects{[self addCursorRect:self.bounds cursor:NSCursor.crosshairCursor];}
-(NSImage*)cropped:(NSRect)r{
    NSBitmapImageRep *bitmap=self.backgroundBitmap;
    CGFloat sx=bitmap.pixelsWide/self.bounds.size.width,sy=bitmap.pixelsHigh/self.bounds.size.height;
    CGRect pixels=CGRectMake(round(r.origin.x*sx),round(r.origin.y*sy),round(r.size.width*sx),round(r.size.height*sy));
    CGImageRef crop=CGImageCreateWithImageInRect(bitmap.CGImage,pixels);if(!crop)return nil;
    NSImage *image=[[NSImage alloc]initWithCGImage:crop size:r.size];CGImageRelease(crop);return image;
}
-(void)syncSelection:(BOOL)reset{
    if(!rust_selection_valid(self.selection)){self.toolbar.hidden=YES;self.sizeLabel.hidden=YES;self.canvas.hidden=YES;[self setNeedsDisplay:YES];return;}
    SelectionRect q=rust_selection_rect(self.selection);NSRect r=NSMakeRect(q.x,q.y,q.width,q.height);
    NSRect previous=self.canvas.frame;
    if(!self.canvas.image){
        self.canvas.image=[self cropped:r];rust_model_reset(self.canvas.model,q.width,q.height);
        self.annotationTool=-1;for(NSButton *button in self.toolButtons)button.state=NSControlStateValueOff;self.canvas.interactive=NO;
    }else if(!NSEqualRects(previous,r)){
        BOOL resized=!NSEqualSizes(previous.size,r.size);
        rust_model_reframe(self.canvas.model,q.width,q.height,resized?previous.origin.x-r.origin.x:0,resized?previous.origin.y-r.origin.y:0);
        self.canvas.image=[self cropped:r];
    }
    self.canvas.frame=r;self.canvas.hidden=NO;self.canvas.showHandles=!self.editing;[self.canvas setNeedsDisplay:YES];
    CGFloat x=MIN(MAX(8,NSMaxX(r)-345),MAX(8,self.bounds.size.width-353));
    CGFloat y=NSMaxY(r)+5;if(y+79>self.bounds.size.height-8)y=MAX(8,NSMinY(r)-84);
    self.toolbar.frame=NSMakeRect(x,y,345,79);self.toolbar.hidden=self.selecting;
    NSBitmapImageRep *bitmap=self.backgroundBitmap;
    self.sizeLabel.stringValue=[NSString stringWithFormat:@"%.0f × %.0f",q.width*bitmap.pixelsWide/self.bounds.size.width,q.height*bitmap.pixelsHigh/self.bounds.size.height];
    self.sizeLabel.frame=NSMakeRect(MAX(0,r.origin.x),MAX(0,r.origin.y-21),110,19);self.sizeLabel.hidden=NO;
    [self setNeedsDisplay:YES];
}
-(void)drawRect:(NSRect)dirty{
    [self.background drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    BOOL valid=rust_selection_valid(self.selection);SelectionRect q=rust_selection_rect(self.selection);
    NSRect r=valid?NSMakeRect(q.x,q.y,q.width,q.height):self.hoverRect;
    [[NSColor colorWithWhite:0 alpha:.6]setFill];
    if(NSIsEmptyRect(r))NSRectFillUsingOperation(self.bounds,NSCompositingOperationSourceOver);
    else{
        NSRect areas[]={NSMakeRect(0,0,self.bounds.size.width,NSMinY(r)),NSMakeRect(0,NSMaxY(r),self.bounds.size.width,self.bounds.size.height-NSMaxY(r)),NSMakeRect(0,NSMinY(r),NSMinX(r),r.size.height),NSMakeRect(NSMaxX(r),NSMinY(r),self.bounds.size.width-NSMaxX(r),r.size.height)};
        for(int i=0;i<4;i++)NSRectFillUsingOperation(areas[i],NSCompositingOperationSourceOver);
        if(!valid){[[NSColor colorWithWhite:0 alpha:.3]setFill];NSRectFillUsingOperation(r,NSCompositingOperationSourceOver);}
        [[NSColor colorWithSRGBRed:.408 green:.545 blue:.871 alpha:.7]setStroke];NSBezierPath *p=[NSBezierPath bezierPathWithRect:NSInsetRect(r,.5,.5)];p.lineWidth=4;[p stroke];
        if(valid&&!self.editing){
            for(int y=0;y<3;y++)for(int x=0;x<3;x++)if(x!=1||y!=1){NSRect h=NSMakeRect(NSMinX(r)+x*r.size.width/2-4,NSMinY(r)+y*r.size.height/2-4,8,8);NSBezierPath *circle=[NSBezierPath bezierPathWithOvalInRect:h];[NSColor.whiteColor setFill];[circle fill];[[NSColor colorWithSRGBRed:104./255 green:139./255 blue:222./255 alpha:.7]setStroke];circle.lineWidth=2;[circle stroke];}
        }
    }
    if(!valid){
        NSRect hint=NSMakeRect(MIN(MAX(10,self.pointer.x+18),self.bounds.size.width-258),MIN(MAX(10,self.pointer.y+22),self.bounds.size.height-45),248,32);
        [[NSColor colorWithWhite:.08 alpha:.9]setFill];[[NSBezierPath bezierPathWithRoundedRect:hint xRadius:5 yRadius:5]fill];
        [@"拖动选择区域 · 单击选窗口 · Esc 取消" drawInRect:NSInsetRect(hint,10,8) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12],NSForegroundColorAttributeName:NSColor.whiteColor}];
    }
}
-(void)mouseMoved:(NSEvent*)event{
    self.pointer=[self convertPoint:event.locationInWindow fromView:nil];self.hoverRect=NSZeroRect;
    if(!rust_selection_valid(self.selection))for(NSValue *value in self.windowRects){NSRect r=value.rectValue;if(NSPointInRect(self.pointer,r)){self.hoverRect=r;break;}}
    [self setNeedsDisplay:YES];
}
-(void)mouseDown:(NSEvent*)event{
    NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];
    if(self.editing)return;
    if(event.clickCount==2&&rust_selection_valid(self.selection)){[self finishCopy:nil];return;}
    if(rust_selection_hit(self.selection,p.x,p.y)<0){self.canvas.image=nil;self.canvas.hidden=YES;}
    self.downPoint=p;self.gestureMoved=NO;self.selecting=YES;self.toolbar.hidden=YES;
    rust_selection_down(self.selection,p.x,p.y);[self syncSelection:NO];
}
-(void)mouseDragged:(NSEvent*)event{
    if(self.editing)return;
    NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];self.gestureMoved|=hypot(p.x-self.downPoint.x,p.y-self.downPoint.y)>2;
    rust_selection_drag_constrained(self.selection,p.x,p.y,(event.modifierFlags&NSEventModifierFlagShift)!=0);[self syncSelection:YES];
}
-(void)mouseUp:(NSEvent*)event{
    if(self.editing)return;
    if(!self.gestureMoved&&!NSIsEmptyRect(self.hoverRect)&&!rust_selection_valid(self.selection)){
        rust_selection_clear(self.selection);rust_selection_down(self.selection,self.hoverRect.origin.x,self.hoverRect.origin.y);
        rust_selection_drag(self.selection,NSMaxX(self.hoverRect),NSMaxY(self.hoverRect));
    }
    rust_selection_up(self.selection);self.selecting=NO;[self syncSelection:YES];
}
-(void)selectTool:(NSButton*)sender{
    [self.canvas commitText];self.annotationTool=sender.tag;self.canvas.interactive=YES;self.editing=YES;self.canvas.showHandles=NO;[self.canvas setNeedsDisplay:YES];
    for(NSButton *button in self.toolButtons)button.state=button==sender?NSControlStateValueOn:NSControlStateValueOff;
    rust_model_set_tool(self.canvas.model,(int)self.annotationTool);[self.window makeFirstResponder:self.canvas];[self setNeedsDisplay:YES];
}
-(void)chooseColor:(NSButton*)sender{
    [self.canvas commitText];
    NSArray<NSColor*> *colors=@[NSColor.redColor,NSColor.yellowColor,NSColor.greenColor,NSColor.blueColor,NSColor.blackColor,NSColor.whiteColor];
    NSColor *c=[colors[sender.tag]colorUsingColorSpace:NSColorSpace.sRGBColorSpace];rust_model_set_color(self.canvas.model,(RColor){c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent});
    for(NSView *view in self.toolbar.subviews)if([view isKindOfClass:NSButton.class]&&view.wantsLayer)view.layer.borderWidth=view==sender?2:1;
}
-(void)chooseWidth:(NSButton*)sender{
    [self.canvas commitText];
    rust_model_set_width(self.canvas.model,[@[@2,@4,@6][sender.tag]doubleValue]);
    for(NSButton *button in self.strokeButtons)button.state=button==sender?NSControlStateValueOn:NSControlStateValueOff;
}
-(void)undo:(id)sender{[self.canvas commitText];rust_model_undo(self.canvas.model);[self.canvas setNeedsDisplay:YES];}
-(void)redo:(id)sender{[self.canvas commitText];rust_model_redo(self.canvas.model);[self.canvas setNeedsDisplay:YES];}
-(void)cancel:(id)sender{[self.session cancel];}
-(void)cancelOperation:(id)sender{[self.session cancel];}
-(void)rightMouseDown:(NSEvent*)event{[self.session cancel];}
-(void)finishCopy:(id)sender{if(rust_selection_valid(self.selection))[self.session finish:self save:NO];}
-(void)finishPin:(id)sender{if(rust_selection_valid(self.selection)){self.session.pinOnFinish=YES;[self.session finish:self save:NO];}}
-(void)finishSave:(id)sender{if(rust_selection_valid(self.selection))[self.session finish:self save:YES];}
-(void)keyDown:(NSEvent*)event{
    NSString *key=event.charactersIgnoringModifiers.lowercaseString;
    if(event.keyCode==53){[self.session cancel];return;}
    if(event.keyCode==36||event.keyCode==76){[self finishCopy:nil];return;}
    if(!self.editing&&rust_selection_valid(self.selection)&&event.keyCode>=123&&event.keyCode<=126){
        double dx=event.keyCode==123?-1:(event.keyCode==124?1:0),dy=event.keyCode==125?1:(event.keyCode==126?-1:0);
        rust_selection_nudge(self.selection,dx,dy);[self syncSelection:NO];return;
    }
    if(event.modifierFlags&NSEventModifierFlagCommand){
        if([key isEqual:@"s"]){[self finishSave:nil];return;}
        if([key isEqual:@"c"]){[self finishCopy:nil];return;}
        if([key isEqual:@"z"]){if(event.modifierFlags&NSEventModifierFlagShift)[self redo:nil];else [self undo:nil];return;}
    }
    [super keyDown:event];
}
@end
@implementation CaptureSession
-(void)showImages:(NSArray<NSImage*>*)images screens:(NSArray<NSScreen*>*)screens{
    self.windows=[NSMutableArray array];self.views=[NSMutableArray array];
    NSArray *inventory=CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly|kCGWindowListExcludeDesktopElements,kCGNullWindowID));
    CGFloat mainTop=NSMaxY(NSScreen.screens.firstObject.frame);
    for(NSUInteger i=0;i<images.count;i++){
        NSScreen *screen=screens[i];CaptureWindow *window=[[CaptureWindow alloc]initWithContentRect:screen.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.title=@"RustSnap — 截屏";window.releasedWhenClosed=NO;window.level=NSStatusWindowLevel+1;window.opaque=YES;window.hasShadow=NO;window.acceptsMouseMovedEvents=YES;
        window.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
        CaptureView *view=[[CaptureView alloc]initWithFrame:NSMakeRect(0,0,screen.frame.size.width,screen.frame.size.height)];view.background=images[i];view.backgroundBitmap=CaptureBitmap(images[i]);view.screen=screen;view.session=self;
        NSMutableArray *rects=[NSMutableArray array];
        for(NSDictionary *info in inventory){
            if([info[(__bridge NSString*)kCGWindowOwnerPID]intValue]==NSProcessInfo.processInfo.processIdentifier||[info[(__bridge NSString*)kCGWindowLayer]intValue]!=0)continue;
            CGRect cg; if(!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)info[(__bridge NSString*)kCGWindowBounds],&cg))continue;
            NSRect r=NSMakeRect(cg.origin.x-NSMinX(screen.frame),cg.origin.y-(mainTop-NSMaxY(screen.frame)),cg.size.width,cg.size.height);r=NSIntersectionRect(r,view.bounds);
            if(r.size.width>20&&r.size.height>20)[rects addObject:[NSValue valueWithRect:r]];
        }
        view.windowRects=rects;window.contentView=view;[self.views addObject:view];[self.windows addObject:window];[window orderFrontRegardless];
        if(NSPointInRect(NSEvent.mouseLocation,screen.frame)){[window makeKeyAndOrderFront:nil];[window makeFirstResponder:view];}
    }
    [NSApp activateIgnoringOtherApps:YES];
}
-(void)finish:(CaptureView*)view save:(BOOL)save{
    if(self.finished)return;NSImage *image=[view.canvas render];if(!image)return;
    self.finished=YES;for(NSWindow *w in self.windows)[w orderOut:nil];
    if(self.completion)self.completion(image,save,NO);[self.windows removeAllObjects];[self.views removeAllObjects];
}
-(void)cancel{
    if(self.finished)return;self.finished=YES;for(NSWindow *w in self.windows)[w orderOut:nil];
    if(self.completion)self.completion(nil,NO,YES);[self.windows removeAllObjects];[self.views removeAllObjects];
}
@end
