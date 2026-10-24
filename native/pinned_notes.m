// Persistent screenshot notes, independent of the annotation document.
@class RSPinBoard;
@interface RSPinPanel:NSPanel
@end
@implementation RSPinPanel
-(BOOL)canBecomeKeyWindow{return YES;}
@end
@interface RSPinImageView:NSImageView
@end
@implementation RSPinImageView
-(BOOL)mouseDownCanMoveWindow{return YES;}
-(void)mouseDown:(NSEvent*)event{[self.window performWindowDragWithEvent:event];}
@end
@interface RSPinnedNote:NSObject<NSWindowDelegate>
@property NSString *identifier;
@property NSImage *image;
@property RSPinPanel *window;
@property BOOL pinned;
@property BOOL visible;
@property(weak) RSPinBoard *board;
-(void)buildWindow;
@end
@interface RSPinBoard:NSObject
@property NSURL *storageURL;
@property NSMutableArray<RSPinnedNote*> *notes;
@property NSTimer *saveTimer;
-(instancetype)initWithStorageURL:(NSURL*)url;
-(RSPinnedNote*)addImage:(NSImage*)image error:(NSError**)error;
-(BOOL)save:(NSError**)error;
-(void)restore;
-(void)scheduleSave;
-(void)showAll;
@end
@implementation RSPinnedNote
-(void)buildWindow{
    // NSImage.size is the original on-screen selection size in points; its bitmap may be 2x.
    // Never shrink to a fraction of the desktop or enlarge small screenshots.
    NSSize size=self.image.size;
    CGFloat width=MAX(116,size.width),height=MAX(1,size.height);
    self.window=[[RSPinPanel alloc]initWithContentRect:NSMakeRect(0,0,width,height+30) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskUtilityWindow backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"RustSnap · 浮动便签";self.window.releasedWhenClosed=NO;self.window.delegate=self;
    self.window.hidesOnDeactivate=NO;self.window.floatingPanel=YES;self.window.level=self.pinned?NSFloatingWindowLevel:NSNormalWindowLevel;
    self.window.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.window.contentMinSize=NSMakeSize(116,31);self.window.movableByWindowBackground=YES;
    NSView *root=self.window.contentView;
    RSPinImageView *view=[[RSPinImageView alloc]initWithFrame:NSMakeRect(0,0,width,height)];view.image=self.image;
    view.imageScaling=NSImageScaleProportionallyDown;view.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;view.accessibilityLabel=@"截图便签，拖动图片移动窗口";[root addSubview:view];
    NSView *bar=[[NSView alloc]initWithFrame:NSMakeRect(0,height,width,30)];bar.autoresizingMask=NSViewWidthSizable|NSViewMinYMargin;[root addSubview:bar];
    NSArray *symbols=@[@"pin.fill",@"doc.on.doc",@"square.and.arrow.down"];
    NSArray *tips=@[@"置顶 / 取消置顶",@"复制截图",@"保存截图…"];
    SEL actions[]={@selector(togglePinned:),@selector(copyImage:),@selector(saveImage:)};
    for(NSUInteger i=0;i<3;i++){
        NSButton *button=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:tips[i]] target:self action:actions[i]];
        button.frame=NSMakeRect(8+i*38,2,32,26);button.bezelStyle=NSBezelStyleTexturedRounded;button.toolTip=tips[i];button.accessibilityLabel=tips[i];
        if(i==0){[button setButtonType:NSButtonTypePushOnPushOff];button.state=self.pinned?NSControlStateValueOn:NSControlStateValueOff;}
        [bar addSubview:button];
    }
    [self.window center];
}
-(void)togglePinned:(NSButton*)sender{self.pinned=!self.pinned;sender.state=self.pinned?NSControlStateValueOn:NSControlStateValueOff;self.window.level=self.pinned?NSFloatingWindowLevel:NSNormalWindowLevel;[self.board scheduleSave];}
-(void)copyImage:(id)sender{NSPasteboard *pasteboard=NSPasteboard.generalPasteboard;[pasteboard clearContents];if(![pasteboard writeObjects:@[self.image]])ShowMessage(@"无法复制",@"剪贴板未接受图片，请尝试保存截图。");}
-(void)saveImage:(id)sender{
    NSSavePanel *panel=[NSSavePanel savePanel];panel.allowedFileTypes=@[@"png"];panel.nameFieldStringValue=@"RustSnap-note.png";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result){
        if(result!=NSModalResponseOK)return;
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithData:self.image.TIFFRepresentation];NSError *error=nil;
        NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if(!png||![png writeToURL:panel.URL options:NSDataWritingAtomic error:&error])ShowMessage(@"无法保存便签",error.localizedDescription?:@"图片编码失败。");
    }];
}
-(void)windowDidMove:(NSNotification*)notification{[self.board scheduleSave];}
-(void)windowDidResize:(NSNotification*)notification{[self.board scheduleSave];}
-(BOOL)windowShouldClose:(NSWindow*)sender{
    // Closing hides a note; Show All can recover it without deleting its image.
    self.visible=NO;[sender orderOut:nil];[self.board scheduleSave];return NO;
}
@end
@implementation RSPinBoard
-(instancetype)initWithStorageURL:(NSURL*)url{if(self=[super init]){_storageURL=url;_notes=[NSMutableArray array];}return self;}
-(BOOL)save:(NSError**)error{
    [self.saveTimer invalidate];self.saveTimer=nil;
    if(![NSFileManager.defaultManager createDirectoryAtURL:self.storageURL withIntermediateDirectories:YES attributes:nil error:error])return NO;
    NSMutableArray *rows=[NSMutableArray array];
    for(RSPinnedNote *note in self.notes)[rows addObject:@{@"id":note.identifier,@"frame":NSStringFromRect(note.window.frame),@"displaySize":NSStringFromSize(note.image.size),@"pinned":@(note.pinned),@"visible":@(note.visible)}];
    NSData *data=[NSJSONSerialization dataWithJSONObject:rows options:0 error:error];
    return data&&[data writeToURL:[self.storageURL URLByAppendingPathComponent:@"notes.json"] options:NSDataWritingAtomic error:error];
}
-(void)scheduleSave{
    [self.saveTimer invalidate];__weak RSPinBoard *weakSelf=self;
    self.saveTimer=[NSTimer scheduledTimerWithTimeInterval:.25 repeats:NO block:^(NSTimer *timer){NSError *error=nil;if(![weakSelf save:&error])NSLog(@"RustSnap note layout save failed: %@",error.localizedDescription);}];
}
-(RSPinnedNote*)addImage:(NSImage*)image error:(NSError**)error{
    if(!image)return nil;
    if(![NSFileManager.defaultManager createDirectoryAtURL:self.storageURL withIntermediateDirectories:YES attributes:nil error:error])return nil;
    RSPinnedNote *note=[RSPinnedNote new];note.identifier=NSUUID.UUID.UUIDString;note.image=image;note.pinned=YES;note.visible=YES;
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithData:image.TIFFRepresentation];NSData *data=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if(!data||![data writeToURL:[self.storageURL URLByAppendingPathComponent:[note.identifier stringByAppendingString:@".png"]] options:NSDataWritingAtomic error:error])return nil;
    [note buildWindow];note.board=self;[self.notes addObject:note];
    // Cascade notes so repeated pin actions remain discoverable.
    NSRect frame=note.window.frame;frame.origin.x+=(self.notes.count-1)%8*22;frame.origin.y-=(self.notes.count-1)%8*22;[note.window setFrame:frame display:NO];
    if(![self save:error]){[self.notes removeObject:note];return nil;}
    [note.window orderFrontRegardless];return note;
}
-(void)restore{
    NSData *data=[NSData dataWithContentsOfURL:[self.storageURL URLByAppendingPathComponent:@"notes.json"]];if(!data)return;
    id rows=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![rows isKindOfClass:NSArray.class])return;
    for(id row in rows){
        if(![row isKindOfClass:NSDictionary.class]||![row[@"id"]isKindOfClass:NSString.class])continue;
        NSUUID *uuid=[[NSUUID alloc]initWithUUIDString:row[@"id"]];if(!uuid)continue;
        NSImage *image=[[NSImage alloc]initWithContentsOfURL:[self.storageURL URLByAppendingPathComponent:[uuid.UUIDString stringByAppendingString:@".png"]]];if(!image)continue;
        if([row[@"displaySize"]isKindOfClass:NSString.class]){
            NSSize size=NSSizeFromString(row[@"displaySize"]);
            if(isfinite(size.width)&&isfinite(size.height)&&size.width>0&&size.height>0&&size.width<20000&&size.height<20000)image.size=size;
        }
        RSPinnedNote *note=[RSPinnedNote new];note.identifier=uuid.UUIDString;note.image=image;note.pinned=[row[@"pinned"]respondsToSelector:@selector(boolValue)]?[row[@"pinned"]boolValue]:YES;
        note.visible=[row[@"visible"]respondsToSelector:@selector(boolValue)]?[row[@"visible"]boolValue]:YES;[note buildWindow];
        if([row[@"frame"]isKindOfClass:NSString.class]){
            NSRect frame=NSRectFromString(row[@"frame"]);BOOL onScreen=NO;
            if(isfinite(frame.origin.x)&&isfinite(frame.origin.y)&&isfinite(frame.size.width)&&isfinite(frame.size.height)&&frame.size.width>=116&&frame.size.height>=31&&frame.size.width<20000&&frame.size.height<20000){
                for(NSScreen *screen in NSScreen.screens)if(NSIntersectsRect(NSMakeRect(frame.origin.x,NSMaxY(frame)-40,frame.size.width,40),screen.visibleFrame)){onScreen=YES;break;}
                if(onScreen)[note.window setFrame:frame display:NO];
            }
        }
        note.board=self;[self.notes addObject:note];if(note.visible)[note.window orderFrontRegardless];
    }
}
-(void)showAll{for(RSPinnedNote *note in self.notes){note.visible=YES;[note.window orderFrontRegardless];}[self scheduleSave];}
-(void)dealloc{[self.saveTimer invalidate];for(RSPinnedNote *note in self.notes){note.window.delegate=nil;[note.window orderOut:nil];}}
@end
