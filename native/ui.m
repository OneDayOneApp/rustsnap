#import <AppKit/AppKit.h>
#import "model.h"
#import "menu_icon.h"
#import "hotkey.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
static void ShowMessage(NSString*title,NSString*detail){NSAlert*a=[NSAlert new];a.messageText=title;a.informativeText=detail?:@"";[a addButtonWithTitle:@"OK"];[a runModal];}
@interface Canvas:NSView<NSTextViewDelegate>
@property(nonatomic) NSImage *image;
@property NSSize noteDisplaySize;
@property NSMutableDictionary<NSNumber*,NSImage*> *mosaicCache;
@property void *model;
@property NSTextView *textEditor;
@property BOOL drawingGesture;
-(void)beginTextAtPoint:(NSPoint)point;
-(void)commitText;
-(void)cancelText;
-(void)load:(NSString*)path;
-(NSImage*)render;
@end
@implementation Canvas
@synthesize image=_image;
-(void)setImage:(NSImage*)image{_image=image;self.noteDisplaySize=image.size;self.mosaicCache=[NSMutableDictionary dictionary];}
-(void)drawMosaic:(RShape)mark{
    NSNumber *key=@(mark.width);NSImage *pixelated=self.mosaicCache[key];
    if(!pixelated){
        CGFloat block=MAX(6,mark.width*3);
        NSInteger w=MAX(1,ceil(self.bounds.size.width/block)),h=MAX(1,ceil(self.bounds.size.height/block));
        NSBitmapImageRep *small=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:small];
        [NSGraphicsContext saveGraphicsState];CGContextTranslateCTM(context.CGContext,0,h);CGContextScaleCTM(context.CGContext,1,-1);
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context.CGContext flipped:YES]];
        NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationHigh;
        [self.image drawInRect:NSMakeRect(0,0,w,h) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1 respectFlipped:YES hints:nil];
        [NSGraphicsContext restoreGraphicsState];
        small.size=self.bounds.size;pixelated=[[NSImage alloc]initWithSize:self.bounds.size];[pixelated addRepresentation:small];self.mosaicCache[key]=pixelated;
    }
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;CGContextSaveGState(context);
    CGFloat diameter=mark.width*8;
    if(mark.count==1){CGContextAddEllipseInRect(context,CGRectMake(mark.points[0].x-diameter/2,mark.points[0].y-diameter/2,diameter,diameter));CGContextClip(context);}
    else{
        CGMutablePathRef path=CGPathCreateMutable();CGPathMoveToPoint(path,NULL,mark.points[0].x,mark.points[0].y);
        for(NSUInteger i=1;i<mark.count;i++)CGPathAddLineToPoint(path,NULL,mark.points[i].x,mark.points[i].y);
        CGPathRef outline=CGPathCreateCopyByStrokingPath(path,NULL,diameter,kCGLineCapRound,kCGLineJoinRound,10);
        CGContextAddPath(context,outline);CGContextClip(context);CGPathRelease(outline);CGPathRelease(path);
    }
    NSImageInterpolation old=NSGraphicsContext.currentContext.imageInterpolation;NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationNone;
    [pixelated drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    NSGraphicsContext.currentContext.imageInterpolation=old;CGContextRestoreGState(context);
}
-(instancetype)initWithFrame:(NSRect)r{if(self=[super initWithFrame:r])_model=rust_model_new();return self;}
-(void)dealloc{rust_model_free(_model);}
-(BOOL)isFlipped{return YES;}
-(BOOL)acceptsFirstResponder{return YES;}
-(void)load:(NSString*)path{[self cancelText];NSImage *im=[[NSImage alloc]initWithContentsOfFile:path];if(!im){ShowMessage(@"Unable to open image",@"Choose a supported PNG, JPEG, TIFF, BMP or HEIC image.");return;}for(NSImageRep*rep in im.representations){if(rep.pixelsWide>0&&rep.pixelsHigh>0){im.size=NSMakeSize(rep.pixelsWide,rep.pixelsHigh);break;}}self.image=im;rust_model_reset(self.model,im.size.width,im.size.height);self.frame=NSMakeRect(0,0,im.size.width,im.size.height);[self setNeedsDisplay:YES];}
-(void)drawShape:(RShape)m{if(!m.count)return;if(m.tool==6){[self drawMosaic:m];return;}NSPoint a=NSMakePoint(m.points[0].x,m.points[0].y),b=NSMakePoint(m.points[m.count-1].x,m.points[m.count-1].y);NSColor*color=[NSColor colorWithSRGBRed:m.color.r green:m.color.g blue:m.color.b alpha:m.color.a];[color setStroke];NSBezierPath*p=[NSBezierPath bezierPath];p.lineWidth=m.width;p.lineCapStyle=NSLineCapStyleRound;p.lineJoinStyle=NSLineJoinStyleRound;NSRect r=NSMakeRect(m.bounds.x,m.bounds.y,m.bounds.width,m.bounds.height);if(m.tool==0)[p appendBezierPathWithRect:r];else if(m.tool==1)[p appendBezierPathWithOvalInRect:r];else if(m.tool==2){[p moveToPoint:a];[p lineToPoint:b];double q[6];rust_arrow(a.x,a.y,b.x,b.y,m.width,q);[p moveToPoint:NSMakePoint(q[0],q[1])];[p lineToPoint:b];[p lineToPoint:NSMakePoint(q[4],q[5])];}else if(m.tool==3||m.tool==5){if(m.tool==5){CGContextSetBlendMode(NSGraphicsContext.currentContext.CGContext,kCGBlendModeClear);p.lineWidth=m.width*6;}if(m.count==1){[color setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(a.x-p.lineWidth/2,a.y-p.lineWidth/2,p.lineWidth,p.lineWidth)]fill];return;}[p moveToPoint:a];for(NSUInteger i=1;i<m.count;i++)[p lineToPoint:NSMakePoint(m.points[i].x,m.points[i].y)];}else{[[NSString stringWithUTF8String:m.text]drawInRect:NSMakeRect(a.x,a.y,MAX(0,self.bounds.size.width-a.x),MAX(0,self.bounds.size.height-a.y)) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:MAX(14,m.width*6)],NSForegroundColorAttributeName:color}];return;}[p stroke];}
-(void)drawMarks:(BOOL)active{
    // Clear only the annotation layer, preserving the original screenshot and its alpha.
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);CGContextClipToRect(context,NSRectToCGRect(self.bounds));
    CGContextBeginTransparencyLayer(context,NULL);
    for(NSUInteger i=0;i<rust_model_count(self.model,active);i++){
        CGContextSaveGState(context);[self drawShape:rust_model_shape(self.model,i)];CGContextRestoreGState(context);
    }
    CGContextEndTransparencyLayer(context);CGContextRestoreGState(context);
}
-(void)drawRect:(NSRect)dirty{[NSGraphicsContext saveGraphicsState];NSRectClip(self.bounds);[[NSColor colorWithWhite:.15 alpha:1]setFill];NSRectFill(dirty);if(self.image)[self.image drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];[self drawMarks:YES];if(!self.image)[@"RustSnap · Capture or open an image to begin" drawAtPoint:NSMakePoint(30,40) withAttributes:@{NSForegroundColorAttributeName:NSColor.whiteColor,NSFontAttributeName:[NSFont systemFontOfSize:22]}];[NSGraphicsContext restoreGraphicsState];}
-(void)cancelOperation:(id)sender{rust_model_cancel(self.model);[self setNeedsDisplay:YES];}
-(void)beginTextAtPoint:(NSPoint)point{
    [self commitText];
    rust_model_begin(self.model,point.x,point.y);
    RShape style=rust_model_shape(self.model,rust_model_count(self.model,YES)-1);
    CGFloat fontSize=MAX(14,style.width*6);
    point.x=MIN(MAX(0,point.x),MAX(0,self.bounds.size.width-fontSize));
    point.y=MIN(MAX(0,point.y),MAX(0,self.bounds.size.height-fontSize*1.3));
    rust_model_begin(self.model,point.x,point.y);
    RShape active=rust_model_shape(self.model,rust_model_count(self.model,YES)-1);
    NSTextView *editor=[[NSTextView alloc]initWithFrame:NSMakeRect(point.x,point.y,self.bounds.size.width-point.x,self.bounds.size.height-point.y)];
    editor.delegate=self;editor.richText=NO;editor.importsGraphics=NO;editor.allowsUndo=YES;
    editor.font=[NSFont systemFontOfSize:fontSize];
    editor.textColor=[NSColor colorWithSRGBRed:active.color.r green:active.color.g blue:active.color.b alpha:active.color.a];
    editor.backgroundColor=[NSColor colorWithWhite:1 alpha:.15];editor.insertionPointColor=editor.textColor;
    editor.textContainerInset=NSZeroSize;editor.textContainer.lineFragmentPadding=0;
    editor.verticallyResizable=NO;editor.horizontallyResizable=NO;
    editor.accessibilityLabel=@"截图文字（回车确认，Shift+回车换行，Esc 取消文字）";
    self.textEditor=editor;[self addSubview:editor];[self.window makeFirstResponder:editor];
}
-(void)commitText{
    if(!self.textEditor)return;
    NSTextView *editor=self.textEditor;NSString *value=[editor.string copy];
    self.textEditor=nil;editor.delegate=nil;[editor removeFromSuperview];
    if([value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length){rust_model_text(self.model,value.UTF8String);rust_model_finish(self.model);}else rust_model_cancel(self.model);
    [self.window makeFirstResponder:self];[self setNeedsDisplay:YES];
}
-(void)cancelText{
    if(!self.textEditor)return;
    NSTextView *editor=self.textEditor;self.textEditor=nil;editor.delegate=nil;[editor removeFromSuperview];rust_model_cancel(self.model);
    [self.window makeFirstResponder:self];[self setNeedsDisplay:YES];
}
-(BOOL)textView:(NSTextView*)view doCommandBySelector:(SEL)command{
    if(command==@selector(cancelOperation:)){[self cancelText];return YES;}
    if(command==@selector(insertNewline:)&&!(NSApp.currentEvent.modifierFlags&NSEventModifierFlagShift)){[self commitText];return YES;}
    return NO;
}
-(void)mouseDown:(NSEvent*)e{
    if(!self.image)return;[self commitText];
    NSPoint a=[self convertPoint:e.locationInWindow fromView:nil];
    if(rust_model_tool(self.model)==4){[self beginTextAtPoint:a];return;}
    self.drawingGesture=YES;rust_model_begin(self.model,a.x,a.y);[self setNeedsDisplay:YES];
}
-(void)mouseDragged:(NSEvent*)e{if(!self.drawingGesture)return;NSPoint b=[self convertPoint:e.locationInWindow fromView:nil];rust_model_drag(self.model,b.x,b.y);[self setNeedsDisplay:YES];}
-(void)mouseUp:(NSEvent*)e{if(!self.drawingGesture)return;self.drawingGesture=NO;NSPoint b=[self convertPoint:e.locationInWindow fromView:nil];rust_model_drag(self.model,b.x,b.y);rust_model_finish(self.model);[self setNeedsDisplay:YES];}
-(NSImage*)render{[self commitText];if(!self.image)return nil;NSInteger w=(NSInteger)self.bounds.size.width,h=(NSInteger)self.bounds.size.height;for(NSImageRep *source in self.image.representations){if(source.pixelsWide>0&&source.pixelsHigh>0){w=source.pixelsWide;h=source.pixelsHigh;break;}}NSBitmapImageRep*rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];NSGraphicsContext*ctx=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];[NSGraphicsContext saveGraphicsState];CGContextTranslateCTM(ctx.CGContext,0,h);CGContextScaleCTM(ctx.CGContext,w/self.bounds.size.width,-h/self.bounds.size.height);[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:ctx.CGContext flipped:YES]];[self.image drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];[self drawMarks:NO];[NSGraphicsContext restoreGraphicsState];NSImage*out=[[NSImage alloc]initWithSize:self.bounds.size];[out addRepresentation:rep];return out;}
@end
#include "pinned_notes.m"
#include "capture_mode.m"
#include "preferences.m"

static NSImage *EditorIcon(NSString *symbol,NSString *description){
    NSImage *image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:description];
    if(!image&&[symbol isEqual:@"eraser"])image=CaptureEraserIcon(NO);
    if(!image)image=[NSImage imageWithSystemSymbolName:@"square" accessibilityDescription:description];
    image=[image copy];image.template=YES;image.accessibilityDescription=description;return image;
}
@interface Controller:NSObject<NSApplicationDelegate,NSWindowDelegate>
@property NSWindow *window;
@property Canvas *canvas;
@property NSScrollView *editorScroll;
@property NSTextField *zoomLabel;
@property NSString *initial;
@property NSStatusItem *statusItem;
@property RustSnapHotKey *captureHotKey;
@property CaptureSession *captureSession;
@property BOOL captureInProgress;
@property BOOL quitting;
@property BOOL explicitQuit;
@property NSUInteger captureGeneration;
@property PreferencesController *preferences;
@property NSMenuItem *captureMenuItem;
@property RSPinBoard *pinBoard;
@end
@implementation Controller
-(NSButton*)button:(NSString*)label action:(SEL)sel x:(CGFloat)x width:(CGFloat)w parent:(NSView*)v{
    NSDictionary *symbols=@{@"Capture":@"viewfinder",@"Open…":@"folder",@"Undo":@"arrow.uturn.backward",@"Copy":@"doc.on.doc",@"Export PNG…":@"square.and.arrow.up",@"ZoomOut":@"minus.magnifyingglass",@"ZoomIn":@"plus.magnifyingglass",@"Fit":@"arrow.up.left.and.arrow.down.right",@"Actual":@"1.square",@"Pin":@"pin"};
    NSDictionary *tips=@{@"Capture":@"截屏",@"Open…":@"打开图片…",@"Undo":@"撤销（⌘Z）",@"Copy":@"复制图片（⌘C）",@"Export PNG…":@"导出 PNG…",@"ZoomOut":@"缩小",@"ZoomIn":@"放大",@"Fit":@"适应窗口",@"Actual":@"原始大小（100%）",@"Pin":@"钉到桌面（⇧⌘P）"};
    NSString *tip=tips[label]?:label;
    NSButton *button=[NSButton buttonWithImage:EditorIcon(symbols[label]?:@"square",tip) target:self action:sel];
    button.frame=NSMakeRect(x,10,w,30);button.bezelStyle=NSBezelStyleTexturedRounded;
    button.imagePosition=NSImageOnly;button.imageScaling=NSImageScaleProportionallyDown;button.toolTip=tip;button.accessibilityLabel=tip;
    [v addSubview:button];return button;
}
-(void)populateEditorToolbar:(NSView*)bar{
    [self button:@"Capture" action:@selector(capture:) x:12 width:36 parent:bar];
    [self button:@"Open…" action:@selector(open:) x:56 width:36 parent:bar];
    NSSegmentedControl *tools=[[NSSegmentedControl alloc]initWithFrame:NSMakeRect(108,10,252,30)];
    tools.segmentCount=7;tools.trackingMode=NSSegmentSwitchTrackingSelectOne;tools.target=self;tools.action=@selector(tool:);
    NSArray *symbols=@[@"pencil.tip",@"rectangle",@"circle",@"arrow.up.right",@"textformat",@"eraser",@"square.grid.3x3.fill"];
    NSArray *tips=@[@"钢笔",@"矩形",@"椭圆",@"箭头",@"文字",@"橡皮擦",@"马赛克"];
    NSInteger order[]={3,0,1,2,4,5,6};
    for(NSInteger i=0;i<7;i++){[tools setImage:EditorIcon(symbols[i],tips[i]) forSegment:i];[tools setWidth:36 forSegment:i];[tools setToolTip:tips[i] forSegment:i];[tools setTag:order[i] forSegment:i];}
    tools.selectedSegment=1;tools.accessibilityLabel=@"标注工具";[bar addSubview:tools];
    NSColorWell *color=[[NSColorWell alloc]initWithFrame:NSMakeRect(378,10,38,30)];
    color.color=[NSColor colorWithSRGBRed:1 green:.2 blue:.2 alpha:1];color.target=self;color.action=@selector(color:);color.toolTip=@"标注颜色";color.accessibilityLabel=@"标注颜色";[bar addSubview:color];
    NSPopUpButton *width=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(426,10,68,30)];
    [width addItemsWithTitles:@[@"1 px",@"3 px",@"6 px",@"10 px"]];[width selectItemAtIndex:1];width.target=self;width.action=@selector(width:);width.toolTip=@"线宽 / 橡皮擦与马赛克范围";width.accessibilityLabel=@"线宽";[bar addSubview:width];
    [self button:@"Undo" action:@selector(undo:) x:514 width:36 parent:bar];
    [self button:@"Copy" action:@selector(copy:) x:558 width:36 parent:bar];
    [self button:@"Export PNG…" action:@selector(save:) x:602 width:36 parent:bar];
    [self button:@"ZoomOut" action:@selector(zoomOut:) x:666 width:36 parent:bar];
    self.zoomLabel=[NSTextField labelWithString:@"100%"];
    self.zoomLabel.frame=NSMakeRect(706,15,56,20);self.zoomLabel.alignment=NSTextAlignmentCenter;
    self.zoomLabel.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];self.zoomLabel.accessibilityLabel=@"视图缩放比例";[bar addSubview:self.zoomLabel];
    [self button:@"ZoomIn" action:@selector(zoomIn:) x:766 width:36 parent:bar];
    [self button:@"Fit" action:@selector(zoomToFit:) x:810 width:36 parent:bar];
    [self button:@"Actual" action:@selector(zoomActual:) x:854 width:36 parent:bar];
    [self button:@"Pin" action:@selector(pinCurrent:) x:900 width:36 parent:bar];
}
-(void)pinCurrent:(id)sender{
    NSImage *image=[self.canvas render];if(!image){ShowMessage(@"还没有截图",@"请先截屏或打开图片，再钉到桌面。");return;}
    if(self.canvas.noteDisplaySize.width>0&&self.canvas.noteDisplaySize.height>0)image.size=self.canvas.noteDisplaySize;
    NSError *error=nil;if(![self.pinBoard addImage:image error:&error])ShowMessage(@"无法创建浮动便签",error.localizedDescription?:@"请检查本机保存位置是否可写。");
}
-(void)showPinnedNotes:(id)sender{[self.pinBoard showAll];}
-(RSPinnedNote*)activePinnedNote{for(RSPinnedNote *note in self.pinBoard.notes)if(note.window==NSApp.keyWindow)return note;return nil;}
-(void)loadCaptureImage:(NSImage*)image{
    NSSize originalDisplaySize=image.size;
    NSBitmapImageRep *bitmap=CaptureBitmap(image);image.size=NSMakeSize(bitmap.pixelsWide,bitmap.pixelsHigh);
    self.canvas.image=image;self.canvas.noteDisplaySize=originalDisplaySize;self.canvas.frame=NSMakeRect(0,0,image.size.width,image.size.height);
    rust_model_reset(self.canvas.model,image.size.width,image.size.height);[self zoomActual:nil];[self.canvas setNeedsDisplay:YES];
}
-(void)configureEditorScroll:(NSScrollView*)scroll{
    self.editorScroll=scroll;scroll.allowsMagnification=YES;scroll.minMagnification=.1;scroll.maxMagnification=8;
    scroll.contentView.postsBoundsChangedNotifications=YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(zoomChanged:) name:NSViewBoundsDidChangeNotification object:scroll.contentView];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(zoomChanged:) name:NSScrollViewDidEndLiveMagnifyNotification object:scroll];
}
-(void)zoomChanged:(NSNotification*)notification{self.zoomLabel.stringValue=[NSString stringWithFormat:@"%.0f%%",self.editorScroll.magnification*100];}
-(void)setEditorZoom:(CGFloat)scale{
    if(!self.canvas.image)return;
    [self.canvas commitText];NSRect visible=self.canvas.visibleRect;
    [self.editorScroll setMagnification:MIN(self.editorScroll.maxMagnification,MAX(self.editorScroll.minMagnification,scale)) centeredAtPoint:NSMakePoint(NSMidX(visible),NSMidY(visible))];
    [self zoomChanged:nil];
}
-(void)zoomIn:(id)sender{[self setEditorZoom:self.editorScroll.magnification*1.25];}
-(void)zoomOut:(id)sender{[self setEditorZoom:self.editorScroll.magnification/1.25];}
-(void)zoomActual:(id)sender{[self setEditorZoom:1];}
-(void)zoomToFit:(id)sender{
    if(!self.canvas.image)return;[self.canvas commitText];[self.editorScroll magnifyToFitRect:self.canvas.bounds];[self zoomChanged:nil];
}
-(void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
-(void)applicationDidFinishLaunching:(NSNotification*)n{RegisterPreferenceDefaults(NSUserDefaults.standardUserDefaults);NSRect r=NSMakeRect(100,100,1100,760);self.window=[[NSWindow alloc]initWithContentRect:r styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];self.window.title=@"RustSnap — Screenshot & Annotation";self.window.minSize=NSMakeSize(960,320);self.window.delegate=self;NSView *root=self.window.contentView;NSView *bar=[[NSView alloc]initWithFrame:NSMakeRect(0,710,1100,50)];bar.autoresizingMask=NSViewWidthSizable|NSViewMinYMargin;[root addSubview:bar];[self populateEditorToolbar:bar];NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,0,1100,710)];scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;scroll.hasHorizontalScroller=YES;scroll.hasVerticalScroller=YES;self.canvas=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,1080,690)];scroll.documentView=self.canvas;[self configureEditorScroll:scroll];[root addSubview:scroll];NSMenu *menu=[NSMenu new];NSMenuItem *app=[NSMenuItem new];[menu addItem:app];NSMenu *am=[NSMenu new];[am addItemWithTitle:@"About RustSnap" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];NSMenuItem *settings=[am addItemWithTitle:@"偏好设置…" action:@selector(showPreferences:) keyEquivalent:@","];settings.target=self;NSMenuItem *quit=[am addItemWithTitle:@"Quit RustSnap" action:@selector(quitApplication:) keyEquivalent:@"q"];quit.target=self;app.submenu=am;NSMenuItem *edit=[NSMenuItem new];[menu addItem:edit];NSMenu *em=[[NSMenu alloc]initWithTitle:@"Edit"];NSMenuItem *undo=[em addItemWithTitle:@"Undo Annotation" action:@selector(undo:) keyEquivalent:@"z"];undo.target=self;NSMenuItem*redo=[em addItemWithTitle:@"Redo Annotation" action:@selector(redo:) keyEquivalent:@"Z"];redo.target=self;NSMenuItem *copy=[em addItemWithTitle:@"Copy Image" action:@selector(copy:) keyEquivalent:@"c"];copy.target=self;[em addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];[em addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];[em addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];edit.submenu=em;NSMenuItem *file=[NSMenuItem new];[menu addItem:file];NSMenu *fm=[[NSMenu alloc]initWithTitle:@"文件"];
NSMenuItem *save=[fm addItemWithTitle:@"保存截图…" action:@selector(save:) keyEquivalent:@"s"];save.target=self;
NSMenuItem *pin=[fm addItemWithTitle:@"钉到桌面" action:@selector(pinCurrent:) keyEquivalent:@"P"];pin.target=self;file.submenu=fm;
NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
self.pinBoard=[[RSPinBoard alloc]initWithStorageURL:[support URLByAppendingPathComponent:@"RustSnap/PinnedNotes" isDirectory:YES]];[self.pinBoard restore];
NSApp.mainMenu=menu;[self installStatusItem];[self installCaptureHotKey];if(self.initial.length){[self.canvas load:self.initial];if(![NSProcessInfo.processInfo.arguments containsObject:@"--background"])[self showWindow:nil];}}
-(void)installStatusItem{
    self.statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image=RustSnapMenuIcon();
    self.statusItem.button.toolTip=@"RustSnap · 截图与标注";
    NSMenu *menu=[NSMenu new];
    NSMenuItem *capture=[menu addItemWithTitle:@"截屏" action:@selector(capture:) keyEquivalent:@"s"];capture.target=self;capture.keyEquivalentModifierMask=NSEventModifierFlagControl|NSEventModifierFlagCommand;self.captureMenuItem=capture;[self updateCaptureMenuShortcut];
    NSMenuItem *show=[menu addItemWithTitle:@"打开标注窗口…" action:@selector(showWindow:) keyEquivalent:@""];show.target=self;
    NSMenuItem *pin=[menu addItemWithTitle:@"将当前截图钉到桌面" action:@selector(pinCurrent:) keyEquivalent:@""];pin.target=self;
    NSMenuItem *notes=[menu addItemWithTitle:@"显示全部浮动便签" action:@selector(showPinnedNotes:) keyEquivalent:@""];notes.target=self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *preferences=[menu addItemWithTitle:@"偏好设置…" action:@selector(showPreferences:) keyEquivalent:@","];preferences.target=self;
    [menu addItemWithTitle:@"关于 RustSnap" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[menu addItemWithTitle:@"退出 RustSnap" action:@selector(quitApplication:) keyEquivalent:@""];quit.target=self;
    self.statusItem.menu=menu;
}
-(void)showWindow:(id)sender{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    if(self.window.isMiniaturized)[self.window deminiaturize:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
-(BOOL)applicationShouldHandleReopen:(NSApplication*)app hasVisibleWindows:(BOOL)visible{
    // Reopening the app keeps it resident; the menu explicitly opens the editor.
    return NO;
}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)app{return NO;}
-(BOOL)windowShouldClose:(NSWindow*)sender{
    if(self.quitting)return YES;
    // Keep the document and status item alive; only Quit terminates the app.
    [sender orderOut:nil];return NO;
}
-(void)tool:(NSSegmentedControl*)s{[self.canvas commitText];rust_model_set_tool(self.canvas.model,(int)[s tagForSegment:s.selectedSegment]);}
-(void)color:(NSColorWell*)s{[self.canvas commitText];NSColor*c=[s.color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];rust_model_set_color(self.canvas.model,(RColor){c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent});}
-(void)width:(NSPopUpButton*)s{[self.canvas commitText];rust_model_set_width(self.canvas.model,[@[@1,@3,@6,@10][s.indexOfSelectedItem] doubleValue]);}
-(void)undo:(id)s{if([NSApp.keyWindow.firstResponder isKindOfClass:NSTextView.class]){[NSApp.keyWindow.firstResponder.undoManager undo];return;}if(self.captureInProgress&&!self.captureSession.finished&&[NSApp.keyWindow.contentView isKindOfClass:CaptureView.class]){[(CaptureView*)NSApp.keyWindow.contentView undo:s];return;}[self.canvas commitText];rust_model_undo(self.canvas.model);[self.canvas setNeedsDisplay:YES];}
-(void)redo:(id)s{if([NSApp.keyWindow.firstResponder isKindOfClass:NSTextView.class]){[NSApp.keyWindow.firstResponder.undoManager redo];return;}if(self.captureInProgress&&!self.captureSession.finished&&[NSApp.keyWindow.contentView isKindOfClass:CaptureView.class]){[(CaptureView*)NSApp.keyWindow.contentView redo:s];return;}[self.canvas commitText];rust_model_redo(self.canvas.model);[self.canvas setNeedsDisplay:YES];}
-(void)open:(id)s{NSOpenPanel*p=[NSOpenPanel openPanel];p.allowedFileTypes=@[@"png",@"jpg",@"jpeg",@"tiff",@"bmp",@"heic"];if([p runModal]==NSModalResponseOK){[self.canvas load:p.URL.path];[self zoomActual:nil];}}
-(void)updateCaptureMenuShortcut{
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    self.captureMenuItem.keyEquivalent=[d boolForKey:PrefShortcutEnabled]?[d stringForKey:PrefShortcutCharacter]:@"";
    self.captureMenuItem.keyEquivalentModifierMask=[d integerForKey:PrefShortcutModifiers];
}
-(void)installCaptureHotKey{
    if(!self.captureHotKey)self.captureHotKey=[RustSnapHotKey new];[self.captureHotKey invalidate];
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[self updateCaptureMenuShortcut];
    if(![d boolForKey:PrefShortcutEnabled])return;
    NSError *error=nil;
    if(![self.captureHotKey registerKeyCode:(UInt32)[d integerForKey:PrefShortcutCode] modifiers:[d integerForKey:PrefShortcutModifiers] target:self action:@selector(capture:) error:&error])ShowMessage(@"截图快捷键不可用",error.localizedDescription);
}
-(BOOL)applyShortcut:(UInt32)code modifiers:(NSEventModifierFlags)flags key:(NSString*)key error:(NSError**)error{
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    if(key.length&&![self.captureHotKey registerKeyCode:code modifiers:flags target:self action:@selector(capture:) error:error]){
        if([d boolForKey:PrefShortcutEnabled])[self.captureHotKey registerKeyCode:(UInt32)[d integerForKey:PrefShortcutCode] modifiers:[d integerForKey:PrefShortcutModifiers] target:self action:@selector(capture:) error:nil];
        return NO;
    }
    if(!key.length)[self.captureHotKey invalidate];
    [d setBool:key.length>0 forKey:PrefShortcutEnabled];[d setInteger:code forKey:PrefShortcutCode];[d setInteger:flags forKey:PrefShortcutModifiers];[d setObject:key forKey:PrefShortcutCharacter];[self updateCaptureMenuShortcut];return YES;
}
-(void)showPreferences:(id)sender{
    if(self.captureSession)[self.captureSession cancel];
    if(!self.preferences){
        self.preferences=[PreferencesController new];self.preferences.defaults=NSUserDefaults.standardUserDefaults;
        __weak Controller *weakSelf=self;
        self.preferences.shortcutChanged=^BOOL(UInt32 code,NSEventModifierFlags flags,NSString *key,NSError **error){return [weakSelf applyShortcut:code modifiers:flags key:key error:error];};
        self.preferences.recordingChanged=^(BOOL active){if(active)[weakSelf.captureHotKey invalidate];else [weakSelf installCaptureHotKey];};
    }
    [self.preferences show];
}
-(void)finishCaptureImage:(NSImage*)image saveDialog:(BOOL)save{
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    if([d boolForKey:@"captureOneX"])image=PreferenceOneXImage(image);
    [self loadCaptureImage:image];
    BOOL only=[d boolForKey:@"captureOnlyClipboard"],also=[d boolForKey:@"captureAlsoClipboard"];
    if(save){[NSApp activateIgnoringOtherApps:YES];if(![self saveCurrentImage])return;if(also)[self copy:nil];}
    else{
        if(!only){NSError *error=nil;if(!PreferenceWritePNG(image,[d stringForKey:@"captureSaveFolder"],&error)){ShowMessage(@"无法保存截图",error.localizedDescription);return;}}
        if(only||also)[self copy:nil];
    }
    if([d boolForKey:@"captureSound"])[[NSSound soundNamed:@"Tink"]play];
}
-(void)prepareForTermination{
    if(self.quitting)return;self.quitting=YES;[self.pinBoard save:nil];
    // Do not let an active shortcut recorder re-register a hot key on close.
    self.preferences.recorder.recordingChanged=nil;
    self.preferences.recorder.changed=nil;
    self.preferences.recorder.recording=NO;
    [self.captureHotKey invalidate];
    self.captureSession.completion=nil;[self.captureSession cancel];self.captureSession=nil;
    self.captureInProgress=NO;
    if(self.statusItem){[NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];self.statusItem=nil;}
}
-(void)enterMenuBarBackground{
    // Dock Quit dismisses the editor but keeps the status item and hot key alive.
    self.captureGeneration++;self.captureInProgress=NO;
    self.captureSession.completion=nil;[self.captureSession cancel];self.captureSession=nil;
    if(self.preferences.recorder.recording){
        self.preferences.recorder.title=self.preferences.recorder.savedTitle;
        [self.preferences.recorder stopRecording];
    }
    if(NSApp.modalWindow)[NSApp stopModalWithCode:NSModalResponseCancel];
    for(NSWindow *window in NSApp.windows)if(![window isKindOfClass:RSPinPanel.class])[window orderOut:nil];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)application{
    NSAppleEventDescriptor *reason=[NSAppleEventManager.sharedAppleEventManager.currentAppleEvent paramDescriptorForKeyword:kAEQuitReason];
    OSType code=reason.typeCodeValue;
    BOOL sessionEnding=code==kAEQuitAll||code==kAEShutDown||code==kAERestart||code==kAEReallyLogOut;
    if(!self.explicitQuit&&!sessionEnding){
        dispatch_async(dispatch_get_main_queue(),^{[self enterMenuBarBackground];});
        return NSTerminateCancel;
    }
    [self prepareForTermination];return NSTerminateNow;
}
-(void)quitApplication:(id)sender{
    self.explicitQuit=YES;
    // Only the explicit menu action/Command-Q requests full termination.
    if(NSApp.modalWindow)[NSApp stopModalWithCode:NSModalResponseCancel];
    [NSApp terminate:sender];
}
-(void)applicationWillTerminate:(NSNotification*)note{[self prepareForTermination];}
-(void)capture:(id)sender{
    if(self.quitting||self.captureInProgress)return;
    CFAbsoluteTime captureStart=CFAbsoluteTimeGetCurrent();
    self.captureInProgress=YES;NSUInteger generation=++self.captureGeneration;
    BOOL wasVisible=self.window.isVisible&&!self.window.isMiniaturized;
    [self.window orderOut:nil];
    NSArray<NSScreen*> *screens=NSScreen.screens;
    // ScreenCaptureKit excludes our windows explicitly; no fixed settling delay is needed.
    int64_t delay=0;if(@available(macOS 14.0,*)){}else delay=200*NSEC_PER_MSEC;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,delay),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        CFAbsoluteTime queryStart=CFAbsoluteTimeGetCurrent();__block CFAbsoluteTime queryEnd=queryStart;
        NSMutableArray<NSImage*> *images=[NSMutableArray array];NSString *failure=nil;
        NSArray<NSScreen*> *targets=screens;
        if(@available(macOS 14.0,*)){
            // Ask the capture API itself: a cached preflight result must not veto capture.
            dispatch_semaphore_t ready=dispatch_semaphore_create(0);
            __block SCShareableContent *content=nil;__block NSError *contentError=nil;
            [SCShareableContent getShareableContentExcludingDesktopWindows:NO onScreenWindowsOnly:YES completionHandler:^(SCShareableContent *value,NSError *error){
                content=value;contentError=error;dispatch_semaphore_signal(ready);
            }];
            dispatch_semaphore_wait(ready,DISPATCH_TIME_FOREVER);
            queryEnd=CFAbsoluteTimeGetCurrent();
            if(contentError)failure=[NSString stringWithFormat:@"%@ (%@ %ld)",contentError.localizedDescription,contentError.domain,(long)contentError.code];
            if(!content&&!failure)failure=@"系统没有返回可截取的屏幕。";
            if(!failure){
                // Capture displays concurrently, but preserve the NSScreen ordering for overlays.
                NSMutableArray *slots=[NSMutableArray arrayWithCapacity:targets.count];
                for(NSUInteger i=0;i<targets.count;i++)[slots addObject:NSNull.null];
                NSLock *lock=[NSLock new];__block NSString *snapshotFailure=nil;
                dispatch_group_t pending=dispatch_group_create();
                for(NSUInteger index=0;index<targets.count;index++){
                    NSScreen *screen=targets[index];
                    CGDirectDisplayID displayID=[screen.deviceDescription[@"NSScreenNumber"]unsignedIntValue];
                    SCDisplay *display=nil;
                    for(SCDisplay *candidate in content.displays)if(candidate.displayID==displayID){display=candidate;break;}
                    if(!display){[lock lock];snapshotFailure=@"显示器已断开或系统没有提供该屏幕，请重试。";[lock unlock];break;}
                    NSMutableArray<SCRunningApplication*> *excluded=[NSMutableArray array];
                    for(SCRunningApplication *application in content.applications)if(application.processID==NSProcessInfo.processInfo.processIdentifier)[excluded addObject:application];
                    SCContentFilter *filter=[[SCContentFilter alloc]initWithDisplay:display excludingApplications:excluded exceptingWindows:@[]];
                    SCStreamConfiguration *config=[SCStreamConfiguration new];
                    config.width=(size_t)llround(screen.frame.size.width*screen.backingScaleFactor);
                    config.height=(size_t)llround(screen.frame.size.height*screen.backingScaleFactor);
                    config.showsCursor=NO;
                    dispatch_group_enter(pending);
                    [SCScreenshotManager captureImageWithFilter:filter configuration:config completionHandler:^(CGImageRef image,NSError *error){
                        NSImage *snapshot=image?[[NSImage alloc]initWithCGImage:image size:screen.frame.size]:nil;
                        [lock lock];
                        if(snapshot)slots[index]=snapshot;
                        else snapshotFailure=error?[NSString stringWithFormat:@"%@ (%@ %ld)",error.localizedDescription,error.domain,(long)error.code]:@"系统未返回屏幕图像。";
                        [lock unlock];dispatch_group_leave(pending);
                    }];
                }
                dispatch_group_wait(pending,DISPATCH_TIME_FOREVER);
                failure=snapshotFailure;
                if(!failure)for(id image in slots){if(image==NSNull.null){failure=@"未能取得全部屏幕图像。";break;}[images addObject:image];}
            }
        }else{
        for(NSUInteger i=0;i<targets.count;i++){
            NSString *path=[NSTemporaryDirectory()stringByAppendingPathComponent:[NSString stringWithFormat:@"rustsnip-%@.png",NSUUID.UUID.UUIDString]];
            {
                NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
                task.arguments=@[@"-x",@"-D",[NSString stringWithFormat:@"%lu",(unsigned long)i+1],path];
                NSPipe *errors=[NSPipe pipe];task.standardError=errors;NSError *error=nil;
                if(![task launchAndReturnError:&error])failure=error.localizedDescription;
                else{[task waitUntilExit];if(task.terminationStatus!=0)failure=[[NSString alloc]initWithData:[errors.fileHandleForReading readDataToEndOfFile]encoding:NSUTF8StringEncoding];}
            }
            NSImage *image=[[NSImage alloc]initWithContentsOfFile:path];
            [[NSFileManager defaultManager]removeItemAtPath:path error:nil];
            if(!image){failure=failure.length?failure:@"无法读取屏幕图像。请在系统设置 → 隐私与安全性 → 屏幕与系统音频录制中允许 RustSnap，然后重新启动。";break;}
            [images addObject:image];
        }
        }
        CFAbsoluteTime snapshotsEnd=CFAbsoluteTimeGetCurrent();
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.quitting||generation!=self.captureGeneration)return;
            if(failure.length||images.count!=targets.count){self.captureInProgress=NO;if(wasVisible)[self showWindow:nil];ShowMessage(@"无法截屏",[NSString stringWithFormat:@"%@\n若错误为 SCStreamErrorDomain -3801，表示 macOS 拒绝了当前应用的屏幕访问。若设置已开启，请关闭并重新开启 RustSnap 的权限，再从安装位置重新启动。",failure?:@"无法读取屏幕图像。"]);return;}
            self.captureSession=[CaptureSession new];
            __weak Controller *weakSelf=self;
            self.captureSession.completion=^(NSImage *image,BOOL save,BOOL cancelled){
                Controller *owner=weakSelf;owner.captureInProgress=NO;
                if(cancelled){if(wasVisible)[owner showWindow:nil];}
                else if(image){
                    if(owner.captureSession.pinOnFinish){
                        if([NSUserDefaults.standardUserDefaults boolForKey:@"captureOneX"])image=PreferenceOneXImage(image);
                        [owner loadCaptureImage:image];[owner pinCurrent:nil];
                    }else [owner finishCaptureImage:image saveDialog:save];
                }
                dispatch_async(dispatch_get_main_queue(),^{owner.captureSession=nil;});
            };
            CFAbsoluteTime overlayStart=CFAbsoluteTimeGetCurrent();
            [self.captureSession showImages:images screens:targets];
            if(getenv("RUSTSNAP_CAPTURE_TIMING"))NSLog(@"RustSnap capture timing ms: query=%.1f snapshot=%.1f mainQueue=%.1f overlay=%.1f total=%.1f",(queryEnd-queryStart)*1000,(snapshotsEnd-queryEnd)*1000,(overlayStart-snapshotsEnd)*1000,(CFAbsoluteTimeGetCurrent()-overlayStart)*1000,(CFAbsoluteTimeGetCurrent()-captureStart)*1000);
        });
    });
}

-(void)copy:(id)s{RSPinnedNote *note=[self activePinnedNote];if(note){[note copyImage:s];return;}if([NSApp.keyWindow.firstResponder isKindOfClass:NSTextView.class]){[(NSTextView*)NSApp.keyWindow.firstResponder copy:s];return;}if(self.captureInProgress&&!self.captureSession.finished&&[NSApp.keyWindow.contentView isKindOfClass:CaptureView.class]){[(CaptureView*)NSApp.keyWindow.contentView finishCopy:s];return;}NSImage*im=[self.canvas render];if(!im)return;NSPasteboard*p=NSPasteboard.generalPasteboard;[p clearContents];if(![p writeObjects:@[im]])ShowMessage(@"Unable to copy image",@"The system clipboard did not accept the image. Try exporting it as PNG.");}
-(void)save:(id)sender{
    RSPinnedNote *note=[self activePinnedNote];if(note){[note saveImage:sender];return;}
    if(self.captureInProgress&&!self.captureSession.finished&&[NSApp.keyWindow.contentView isKindOfClass:CaptureView.class]){[(CaptureView*)NSApp.keyWindow.contentView finishSave:sender];return;}
    [self saveCurrentImage];
}
-(BOOL)saveCurrentImage{
    NSImage *image=[self.canvas render];if(!image)return NO;
    NSSavePanel *panel=[NSSavePanel savePanel];panel.allowedFileTypes=@[@"png"];panel.nameFieldStringValue=@"RustSnap.png";
    panel.directoryURL=[NSURL fileURLWithPath:[NSUserDefaults.standardUserDefaults stringForKey:@"captureSaveFolder"]];
    if([panel runModal]!=NSModalResponseOK)return NO;
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithData:image.TIFFRepresentation];NSData *data=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];NSError *error=nil;
    if(!data||![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]){ShowMessage(@"无法保存 PNG",error.localizedDescription?:@"图片无法编码为 PNG。");return NO;}
    return YES;
}
@end
int run_app(const char *path){@autoreleasepool{[NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];static Controller*c;c=[Controller new];c.initial=[NSString stringWithUTF8String:path];NSApp.delegate=c;[NSApp run];return 0;}}

int run_fixture(const char *path){@autoreleasepool{
[NSApplication sharedApplication];
Canvas*c=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,800,500)];
NSImage*base=[[NSImage alloc]initWithSize:NSMakeSize(800,500)];
[base lockFocusFlipped:YES];[[NSColor colorWithWhite:.96 alpha:1]setFill];NSRectFill(NSMakeRect(0,0,800,500));
[@"RustSnap · annotation test fixture" drawAtPoint:NSMakePoint(32,24) withAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:24],NSForegroundColorAttributeName:NSColor.blackColor}];
[@"Rectangle · ellipse · arrow · pen · text" drawAtPoint:NSMakePoint(32,65) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:16],NSForegroundColorAttributeName:NSColor.darkGrayColor}];[base unlockFocus];c.image=base;rust_model_reset(c.model,800,500);
NSArray*positions=@[@[@80,@130,@280,@270],@[@330,@130,@540,@270],@[@80,@340,@280,@420],@[@350,@360,@540,@420],@[@590,@180,@590,@180]];
for(NSInteger t=0;t<5;t++){NSArray*v=positions[t];rust_model_set_tool(c.model,(int)t);rust_model_set_width(c.model,4);rust_model_set_color(c.model,(RColor){t==4?0:1,0.2,0.2,1});rust_model_begin(c.model,[v[0]doubleValue],[v[1]doubleValue]);if(t==3){rust_model_drag(c.model,400,320);rust_model_drag(c.model,460,410);}if(t==4)rust_model_text(c.model,"RustSnap");else rust_model_drag(c.model,[v[2]doubleValue],[v[3]doubleValue]);rust_model_finish(c.model);}
NSImage*out=[c render];NSBitmapImageRep*r=[[NSBitmapImageRep alloc]initWithData:out.TIFFRepresentation];NSData*d=[r representationUsingType:NSBitmapImageFileTypePNG properties:@{}];return [d writeToFile:[NSString stringWithUTF8String:path] atomically:YES]?0:1;
}}

#include "integration.m"
